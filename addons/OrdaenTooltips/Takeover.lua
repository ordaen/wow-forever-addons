-- Ordaen Tooltips, taking over: the native tooltips (GameTooltip, ItemRefTooltip, the comparison tooltips) stay
-- shown and keep their content and their owners, so every addon that fills or checks them works as before; we make
-- them invisible (alpha 0) and draw our view in their place. Anything we can't read safely stays native.
--
-- Hooks (hooksecurefunc / HookScript: Blizzard's code is untouched):
--   Show, SetShown, OnShow      read, draw ours, native alpha 0 (every show resets it to 1)
--   SetAlpha                    the native's fades go to our view; the native goes back to 0
--   SetPoint                    the view follows (the comparison tooltips are anchored after their Show)
--   OnHide, OnTooltipCleared    ours hides
-- While a view is shown, one shared ticker (every 0.25 s) notices lines rewritten in place without a new Show.
local _, ns = ...

local Takeover = {}
ns.Takeover = Takeover

local Reader, View, Owner = ns.Reader, ns.View, ns.Owner

-- The comparison tooltips ("currently equipped") anchor to GameTooltip; their views anchor to its view.
local NATIVES = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local CHECK_INTERVAL = 0.25

local feature -- the "takeover" feature (Core.lua)
---@class OrdaenTooltipsState
---@field view OrdaenTooltipsView
---@field model OrdaenTooltipsModel
---@field alpha number|nil the native's wanted alpha
---@field settingAlpha boolean

---@type table<table, OrdaenTooltipsState> native tooltip -> its state (typed, so a removed view field is an error)
local states = {}
local shownCount = 0
local ticker

local isSecret = issecretvalue or function()
	return false
end

-- The view drawn for a native tooltip, for anchoring one view to another (made once).
local function viewOf(frame)
	local state = states[frame]
	return state and state.view or nil
end

local function setNativeAlpha(native, state, alpha)
	state.settingAlpha = true
	native:SetAlpha(alpha)
	state.settingAlpha = false
end

local function showView(state)
	if not state.view:IsShown() then
		state.view:Show()
		shownCount = shownCount + 1
		if shownCount == 1 then
			ticker:Start()
		end
	end
end

local function hideView(state)
	if state.view:IsShown() then
		state.view:Hide()
		shownCount = shownCount - 1
		if shownCount == 0 then
			ticker:Stop()
		end
	end
end

-- Leave `native` as Blizzard made it for this show.
local function restore(native, state)
	hideView(state)
	setNativeAlpha(native, state, state.alpha or 1)
end

-- The shown native whose view is drawn, between `native` (centre x) and `anchor` (centre anchorX) and nearest to
-- `native`: the one its view hangs from. Nil when none is. Allocates nothing.
local function nearest(native, anchor, x, anchorX)
	local best, bestX
	for other, state in pairs(states) do
		if other ~= native and other ~= anchor and state.view:IsShown() then
			local ox = other:GetCenter()
			if ox and not isSecret(ox) and (ox - x) * (anchorX - ox) > 0 and (not bestX
				or math.abs(ox - x) < math.abs(bestX - x)) then
				best, bestX = other, ox
			end
		end
	end
	return best
end

-- Put the view where the native is, or beside the button it's for ("beside buttons").
local function place(native, state, owner)
	local beside = owner and ns.Addon.db.anchorToButtons and Owner.IsButton(owner) and owner or nil
	state.view:Follow(native, viewOf, beside, nearest)
end

local function draw(native)
	local state = states[native]
	if not (state and feature.enabled) then
		return
	end
	if not Reader.Read(native, state.model) or state.model.count == 0 then
		restore(native, state)
		return
	end
	-- The button hovered: its key binding goes in the hotkey; with "beside buttons" on, the view goes beside it.
	local owner = Owner.Of(native)
	state.view:Fill(state.model, owner)
	place(native, state, owner)
	state.view:SetAlpha(state.alpha or 1)
	showView(state)
	setNativeAlpha(native, state, 0)
	ns.Debug:Verbosef("takeover: %s drawn (%d rows), native alpha now %s", native:GetName() or "?", state.model.count,
		isSecret(native:GetAlpha()) and "<secret>" or tostring(native:GetAlpha()))
end

-- Show on a hidden tooltip fires its OnShow inside, then our Show hook: it's drawn twice on that first show. Kept on
-- purpose: addons add lines and call Show again in the same frame, and that second draw must not be skipped (a
-- same-frame stamp dropped their lines, 2026-11-07). Draws happen per show, never per frame.
local function onShown(native)
	draw(native)
end

local function onSetShown(native, shown)
	if not isSecret(shown) and shown then
		draw(native)
	end
end

-- Blizzard anchors the comparison tooltips after showing them (the views followed the anchor of the show before and
-- overlapped, 2026-11-07): a native moved while its view shows moves the view, without a redraw.
local function onMoved(native)
	local state = states[native]
	if state and state.view:IsShown() then
		place(native, state, Owner.Of(native))
	end
end

local function onHidden(native)
	local state = states[native]
	if state then
		state.alpha = nil -- another addon's fade lasts one show (the game resets the native's alpha on Show)
		hideView(state)
	end
end

local function onAlpha(native, alpha)
	local state = states[native]
	if not state or state.settingAlpha then
		return
	end
	if isSecret(alpha) or type(alpha) ~= "number" then
		-- An alpha we can't read (a secret one): ours keeps its own, Blizzard's is hidden again while ours shows.
		ns.Debug:Verbosef("takeover: %s alpha set to an unreadable value", native:GetName() or "?")
		if state.view:IsShown() then
			setNativeAlpha(native, state, 0)
		end
		return
	end
	if alpha == 0 then
		return
	end
	state.alpha = alpha
	if state.view:IsShown() then
		state.view:SetAlpha(alpha)
		setNativeAlpha(native, state, 0)
	end
end

-- Blizzard fades a unit's tooltip out when the mouse leaves the unit (FadeOut, run inside the game): the fade sets
-- the native back to full alpha every frame, where our hooks can't see it, so Blizzard's tooltip showed beside ours
-- for the fade (dev probe, 2026-11-07: alpha 0 at FadeOut, 1.00 after 0.1 s and 0.3 s). While ours is drawn, the
-- native is hidden at once instead (as addons' OnLeave handlers do); its OnHide takes ours with it.
local function onFadeOut(native)
	local state = states[native]
	if state and state.view:IsShown() then
		native:Hide()
	end
end

-- Lines rewritten in place, without a new Show (talent and quest windows do that).
local function check()
	for native, state in pairs(states) do
		if state.view:IsShown() and Reader.Changed(native, state.model) then
			draw(native)
		end
	end
end

local function attach(native)
	local view = View.New("OrdaenTooltips" .. native:GetName())
	if not view then
		return
	end
	states[native] = { view = view, model = Reader.NewModel(), alpha = nil, settingAlpha = false }
	-- We set its alpha; another addon doing that too (another tooltip replacement) is a conflict the Core reports.
	-- The build can't see it (the tooltip is a local here), so it's claimed by hand.
	ns.Addon:Claim(native, { "SetAlpha" }, native:GetName())
	feature:Hook(native, "Show", onShown)
	feature:Hook(native, "SetShown", onSetShown)
	feature:Hook(native, "SetAlpha", onAlpha)
	feature:Hook(native, "SetPoint", onMoved)
	if native.FadeOut then
		feature:Hook(native, "FadeOut", onFadeOut)
	end
	native:HookScript("OnShow", onShown)
	native:HookScript("OnHide", onHidden)
	native:HookScript("OnTooltipCleared", onHidden)
end

--- Start drawing the native tooltips our way (the takeover feature's OnEnable).
---@param f OrdaenFeature
function Takeover.Enable(f)
	feature = f
	if not ticker then
		ticker = f:Every(CHECK_INTERVAL, check)
		ticker:Stop() -- runs only while a view is shown
		for _, name in ipairs(NATIVES) do
			local native = _G[name]
			if native and Reader.CanModify(native) then
				attach(native)
			end
		end
	end
	for native in pairs(states) do
		if native:IsShown() then
			draw(native)
		end
	end
end

--- Give every native tooltip back as it is (the feature's OnDisable).
function Takeover.Disable()
	for native, state in pairs(states) do
		restore(native, state)
	end
end

--- What the dev-mode dump records.
-- One line of text per value (the dump keeps two levels of tables): `k=v` pairs in key order, tables nested in braces
-- up to a few levels, secret values named, never read.
local function flatten(value, depth)
	if isSecret(value) then
		return "<secret>"
	end
	if type(value) ~= "table" then
		return type(value) == "string" and string.format("%q", value) or tostring(value)
	end
	if depth > 3 then
		return "{...}"
	end
	local keys = {}
	for k in pairs(value) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, k in ipairs(keys) do
		local v = value[k]
		-- A colour shows as its hex value; functions (a colour's methods) are left out.
		if type(v) == "table" and v.GetRGB and not isSecret(v) then
			parts[#parts + 1] = string.format("%s=#%02x%02x%02x", tostring(k), (v.r or 0) * 255, (v.g or 0) * 255,
				(v.b or 0) * 255)
		elseif type(v) ~= "function" then
			parts[#parts + 1] = tostring(k) .. "=" .. flatten(v, depth + 1)
		end
	end
	return "{" .. table.concat(parts, " ") .. "}"
end

-- The last tooltip data per kind, as the game gave it: its fields but the lines, then each line on its own.
local function probe()
	local out = {}
	for kind, data in pairs(ns.Reader.lastData) do
		local entry = {}
		local top = {}
		for k, v in pairs(data) do
			if k ~= "lines" then
				top[k] = v
			end
		end
		entry.fields = flatten(top, 1)
		local lines = data.lines
		if type(lines) == "table" and not isSecret(lines) then
			for i, line in ipairs(lines) do
				entry[string.format("line%02d", i)] = flatten(line, 1)
			end
		end
		out[tostring(kind)] = entry
	end
	return out
end

-- Blizzard's strings the character tab's stat tooltips use (their client language), for tooltips inside tooltips.
local PROBE_STRINGS = { "SPELL_STAT1_NAME", "SPELL_STAT2_NAME", "SPELL_STAT3_NAME", "SPELL_STAT4_NAME",
	"SPELL_STAT5_NAME", "DEFAULT_STAT2_TOOLTIP", "DEFAULT_STAT3_TOOLTIP", "DEFAULT_STAT4_TOOLTIP", "STAT_ARMOR_TOOLTIP",
	"ARMOR_TOOLTIP", "STAT_ARMOR_TARGET_TOOLTIP", "STAT_ARMOR_TOTAL_TOOLTIP", "MELEE_ATTACK_POWER_TOOLTIP",
	"RANGED_ATTACK_POWER_TOOLTIP", "ATTACK_SPEED_TOOLTIP1", "STAT_ATTACK_SPEED_BASE_TOOLTIP", "DAMAGE_PER_SECOND",
	"DAMAGE_TOOLTIP", "STAT_BLOCK_TOOLTIP", "CR_BLOCK_TOOLTIP", "CR_CRIT_MELEE_TOOLTIP", "CR_DODGE_TOOLTIP",
	"STAT_HEALTH_TOOLTIP", "STAT_MANA_TOOLTIP", "RESISTANCE_TOOLTIP_SUBTEXT", "RESISTANCE0_NAME", "RESISTANCE1_NAME",
	"RESISTANCE2_NAME", "RESISTANCE3_NAME", "RESISTANCE4_NAME", "RESISTANCE5_NAME", "RESISTANCE6_NAME",
	"PAPERDOLLFRAME_TOOLTIP_FORMAT", "STAT_TOOLTIP_BONUS_AP", "STAT_NO_BENEFIT_TOOLTIP", "STAT_USELESS_TOOLTIP",
	"STAT_AVERAGE_ITEM_LEVEL_TOOLTIP", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_EQUIP", "ITEM_UNIQUE", "DURABILITY",
	"ITEM_LEVEL", "STAT_ATTACK_POWER", "STAT_MOVEMENT_GROUND_TOOLTIP" }

-- The character tab's stat frames as Blizzard filled them (`tooltip`, `tooltip2`: its logic's own text for this
-- character), found under PaperDollFrame and CharacterFrame; only after the character tab was open once.
local function paperDoll()
	local out, seen = {}, {}
	local function scan(frame, depth)
		if type(frame) ~= "table" or seen[frame] or depth > 6 or type(frame.GetChildren) ~= "function" then
			return
		end
		seen[frame] = true
		local t1, t2 = rawget(frame, "tooltip"), rawget(frame, "tooltip2")
		if type(t1) == "string" or type(t2) == "string" then
			out[frame:GetDebugName()] = tostring(t1) .. " || " .. tostring(t2)
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			scan(child, depth + 1)
		end
	end
	scan(rawget(_G, "CharacterFrame"), 1)
	return out
end

function Takeover.Describe()
	local strings = {}
	for _, name in ipairs(PROBE_STRINGS) do
		local v = rawget(_G, name)
		strings[name] = v == nil and false or tostring(v)
	end
	local out = { probe = probe(), strings = strings, paperDoll = paperDoll() }
	for native, state in pairs(states) do
		local view, model = state.view, state.model
		local header = view.header
		local stats, shownRows = {}, 0
		for i = 1, view.stats.shown do
			local value = view.stats.values[i]
			stats[i] = value.format:format(value.args[1])
		end
		for _, row in pairs(view.rows) do
			shownRows = shownRows + (row.block.hidden and 0 or 1)
		end
		local divider = false ---@type integer|false the row with the divider
		for i, row in pairs(view.rows) do
			if not row.block.hidden and not row.divider.hidden then
				divider = i
			end
		end
		out[native:GetName()] = {
			shown = view:IsShown(), rows = model.count, alpha = state.alpha or 1,
			title = header.titleText.text, subtitle = not header.subtitleText.hidden and header.subtitleText.text or false,
			icon = not header[1].hidden and header.iconImage.image or false, dividerAt = divider,
			price = model.priceRow and model.rows[model.priceRow].right or false,
			priceLabel = model.priceRow and model.rows[model.priceRow].left or false,
			hotkey = view.component.block.hotkey or false,
			stats = not view.stats.hidden and stats or false, shownRows = shownRows,
		}
	end
	return out
end
