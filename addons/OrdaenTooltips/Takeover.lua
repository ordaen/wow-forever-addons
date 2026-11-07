-- Ordaen Tooltips, taking over: the native tooltips (GameTooltip, ItemRefTooltip, the comparison tooltips) stay
-- shown and keep their content and their owners, so every addon that fills or checks them works as before; we make
-- them invisible (alpha 0) and draw our view in their place. Anything we can't read safely stays native.
--
-- Hooks (hooksecurefunc / HookScript: Blizzard's code is untouched):
--   Show, SetShown, OnShow      read, draw ours, native alpha 0 (every show resets it to 1)
--   SetAlpha                    the native's fades go to our view; the native goes back to 0
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
	local beside = owner and ns.Addon.db.anchorToButtons and Owner.IsButton(owner) and owner or nil
	state.view:Follow(native, viewOf, beside)
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

-- Blizzard fades a unit's tooltip out when the mouse leaves the unit (FadeOut, run inside the game: no SetAlpha we
-- see). Dev probe: what the native's alpha does during that fade, while ours is still shown (2026-11-07: both
-- showed for a moment on mouse leave).
local function alphaText(native)
	local a = native:GetAlpha()
	return isSecret(a) and "<secret>" or string.format("%.2f", a)
end

local function onFadeOut(native)
	if ns.Debug:IsEnabled() then
		local state = states[native]
		ns.Debug:Logf("takeover: %s FadeOut, native alpha %s, ours shown %s", native:GetName() or "?",
			alphaText(native), tostring(state and state.view:IsShown()))
		for _, delay in ipairs({ 0.1, 0.3 }) do
			C_Timer.After(delay, function()
				ns.Debug:Logf("takeover: %s +%.1fs after FadeOut: native alpha %s, shown %s, ours shown %s",
					native:GetName() or "?", delay, alphaText(native), tostring(native:IsShown()),
					tostring(state and state.view:IsShown()))
			end)
		end
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
function Takeover.Describe()
	local out = {}
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
