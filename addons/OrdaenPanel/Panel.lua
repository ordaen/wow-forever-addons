-- Ordaen Panel's drawing: one OrdaenCore.UI panel on a screen edge. Left: the game menu buttons and the social
-- button; middle: the experience (or reputation) bar; right: gold, the backpack currencies and the bags.
-- Blizzard's buttons stay Blizzard's (clicks, menus, alerts): each sits in a slot of the panel and is dressed in the
-- theme's button look (UI.Dress). We only declare blocks and move Blizzard's frames into slots; OrdaenCore.UI draws.
--
-- Cost: the block tables are made once (again only when the edge or button size changes, a settings change);
-- events update fields in place and refresh. Nothing runs per frame; a 0.25 s ticker runs only while the mouse is
-- over a "show on mouseover" panel, to notice it leaving through a Blizzard button.
local _, ns = ...

local UI = OrdaenCore.UI
local L = ns.L

local View = {}
ns.View = View

local MONEY_FORMAT = "%d|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
	.. " %d|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
	.. " %d|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
local CURRENCY_FORMAT = "%d|T%s:0:0:2:0|t"
local MAX_CURRENCIES = 6
local SOCIAL_BUTTON = "QuickJoinToastButton" -- in the API dump (1.60.1-70790)

-- "friendly" -> "color.reputation.friendly", made once per standing
local REP_TOKEN = setmetatable({}, {
	__index = function(t, standing)
		local token = "color.reputation." .. standing
		t[standing] = token
		return token
	end,
})

-- Blocks (made by build(), changed in place) ---------------------------------------------------------------------

local panel ---@type OrdaenUIPanel|nil
local spec, left, middle, right, microGroup, socialGroup, bagGroup
local barHolder ---@type OrdaenUIComponent|nil the middle group: a component of its own, for its tooltip
local xp = {
	bar = 0, min = 0, max = 1, quest = 0, overlay = 0, animate = true,
	color = "color.xp", questColor = "color.quest", overlayColor = "color.rested",
	format = "%d%%", args = { 0 }, style = "small", sections = 20,
}
local social = { format = "", args = { 0, 0 }, style = "value" }
local money = { format = MONEY_FORMAT, args = { 0, 0, 0 }, style = "value" }
local currencyTexts = {}
for i = 1, MAX_CURRENCIES do
	currencyTexts[i] = { format = CURRENCY_FORMAT, args = { 0, "" }, style = "value", hidden = true }
end
local bagText = { format = "%d", args = { 0 }, style = "value" }

-- The bar's tooltip: experience in numbers, rested and quest XP, the session's rate and time to level.
local tipName = { text = "", style = "title", hidden = true }
local tipValue = { format = "%d / %d (%d%%)", args = { 0, 0, 0 } }
local tipRested = { format = "", args = { 0, 0 }, hidden = true }
local tipQuest = { format = "", args = { 0 }, hidden = true }
local tipRate = { format = "", args = { 0 }, hidden = true }
local tipLevel = { format = "", args = { 0, 0 }, hidden = true }
local tooltip ---@type OrdaenUITooltip|nil

-- Slots: an empty block the size of a button, embedded in a group; a Blizzard button is anchored to it.
local slots = {} ---@type OrdaenUIComponent[] pooled
local slotOf = {} ---@type table<table, OrdaenUIComponent> Blizzard button -> its slot
local homes = {} ---@type table<table, table> Blizzard button -> { parent, point, relativeTo, relativePoint, x, y }
local dresses = {} ---@type table<table, OrdaenUIDress>
local placing = false
local size = 24

local function db()
	return ns.Addon.db
end

local function horizontal()
	local edge = db().edge
	return edge == "bottom" or edge == "top"
end

-- A group's columns: one per child in a row, or one column on a side edge. Rare (layout changes): may allocate.
local function columns(n)
	if not horizontal() then
		return { "auto" }
	end
	local out = {}
	for i = 1, math.max(n, 1) do
		out[i] = "auto"
	end
	return out
end

-- Putting Blizzard's buttons in slots ------------------------------------------------------------------------------

local function place(button)
	local slot = slotOf[button]
	if not slot or placing then
		return
	end
	placing = true
	button:SetParent(slot.frame)
	button:ClearAllPoints()
	button:SetPoint("CENTER", slot.frame, "CENTER")
	placing = false
end

-- Blizzard's layout code moves its buttons (vehicle UI, Edit Mode): put ours back right after. Hooked once per
-- button; does nothing for a button we gave back.
local hooked = {}
local function hookPlacement(button)
	if hooked[button] then
		return
	end
	hooked[button] = true
	hooksecurefunc(button, "SetPoint", place)
	hooksecurefunc(button, "SetParent", place)
	-- Found at runtime, so the build can't claim them: another bar addon moving them is a conflict (Conflict.lua).
	ns.Addon:Claim(button, { "SetPoint", "SetParent" }, button:GetName() or "a Blizzard button")
end

-- Blizzard's icon of a button, for our look of it: its normal texture's atlas or file, else its `icon` region.
-- A texture's atlas or file, if it has one.
local function art(texture)
	if not (texture and texture.GetAtlas) then
		return nil, nil
	end
	local atlas = texture:GetAtlas()
	if atlas then
		return nil, atlas
	end
	return texture:GetTexture(), nil
end

-- Blizzard's icon of a button: its own `icon` (a bag's item), else its normal texture, else the first texture
-- region with art (QuickJoinToastButton draws its icon on a plain region).
local function iconOf(button)
	local file, atlas = art(rawget(button, "icon"))
	if file or atlas then
		return file, atlas
	end
	file, atlas = art(button.GetNormalTexture and button:GetNormalTexture())
	if file or atlas then
		return file, atlas
	end
	for _, region in ipairs({ button:GetRegions() }) do
		if region:IsObjectType("Texture") then
			file, atlas = art(region)
			if file or atlas then
				return file, atlas
			end
		end
	end
	return nil, nil
end

-- Blizzard's text on the buttons we hold (a bag's free slots, the friends count): we show our own next to them,
-- and theirs doesn't fit the smaller button. Alphas kept to give back.
local textAlphas = {}
local function hideTexts(button)
	for _, region in ipairs({ button:GetRegions() }) do
		if region:IsObjectType("FontString") then
			if textAlphas[region] == nil then
				textAlphas[region] = region:GetAlpha()
			end
			region:SetAlpha(0)
		end
	end
end

local function showTexts(button)
	for _, region in ipairs({ button:GetRegions() }) do
		local alpha = textAlphas[region]
		if alpha then
			region:SetAlpha(alpha)
			textAlphas[region] = nil
		end
	end
end

local function slotFor(i)
	local slot = slots[i]
	if not slot then
		slot = UI.Block({ width = size, height = size })
		slots[i] = slot
	end
	if slot then
		slot.block.width, slot.block.height = size, size
		slot:Refresh()
	end
	return slot
end

local function take(button, slot, texts)
	if not homes[button] then
		local home = { button:GetParent() }
		if button:GetNumPoints() > 0 then
			home[2], home[3], home[4], home[5], home[6] = button:GetPoint(1)
		end
		homes[button] = home
	end
	slotOf[button] = slot
	hookPlacement(button)
	place(button)
	local icon, atlas = iconOf(button)
	local dress = dresses[button]
	if dress then
		dress:SetIcon(icon, atlas)
		dress:Apply()
	else
		dresses[button] = UI.Dress(button, { icon = icon, atlas = atlas, iconSize = size - 4 })
	end
	if texts then
		hideTexts(button)
	end
	ns.Addon.Debug:Logf("held %s: icon %s", button:GetName() or "?", tostring(atlas or icon))
end

local function giveBack(button)
	if not slotOf[button] then
		return
	end
	slotOf[button] = nil
	showTexts(button)
	local dress = dresses[button]
	if dress then
		dress:Undress()
	end
	local home = homes[button]
	if home then
		placing = true
		button:SetParent(home[1])
		button:ClearAllPoints()
		if home[2] then
			button:SetPoint(home[2], home[3], home[4], home[5], home[6])
		end
		placing = false
	end
end

-- Fill a group block with slots for `buttons` (from slot index `first`); returns the next free slot index.
local function fillGroup(group, buttons, first, extra, texts)
	local n = 0
	for i = #group, 1, -1 do
		group[i] = nil
	end
	for _, button in ipairs(buttons) do
		local slot = slotFor(first + n)
		if slot then
			n = n + 1
			group[n] = { embed = slot }
			take(button, slot, texts)
		end
	end
	if extra then
		group[n + 1] = extra
	end
	group.columns = columns(n + (extra and 1 or 0))
	group.hidden = n == 0 and not extra
	return first + n
end

-- The buttons of each group ----------------------------------------------------------------------------------------

local bagButtons = {}
local BAG_NAMES = {
	"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
	"CharacterReagentBag0Slot",
}

-- Blizzard's bag bar: its buttons (backpack, bag slots, reagent bag) in its order; not the expand toggle.
local function readBags()
	for i = #bagButtons, 1, -1 do
		bagButtons[i] = nil
	end
	local seen = {}
	if BagsBar then
		for _, child in ipairs({ BagsBar:GetChildren() }) do
			if child:IsObjectType("Button") and child ~= BagBarExpandToggle then
				bagButtons[#bagButtons + 1], seen[child] = child, true
			end
		end
	end
	for _, name in ipairs(BAG_NAMES) do -- not all in the API dump: looked up by name, logged below
		local button = _G[name]
		if type(button) == "table" and button.GetObjectType and not seen[button] then
			bagButtons[#bagButtons + 1], seen[button] = button, true
		end
	end
	local Debug = ns.Addon.Debug
	if Debug:IsEnabled() then
		local names = {}
		for i, b in ipairs(bagButtons) do
			names[i] = (b:GetName() or "?") .. (b:IsShown() and "" or " (hidden)")
		end
		Debug:Logf("bags: %d buttons (BagsBar %s): %s", #bagButtons, BagsBar and "found" or "missing",
			table.concat(names, ", "))
	end
	table.sort(bagButtons, ns.Micro.Before)
	for i = 1, math.floor(#bagButtons / 2) do -- Blizzard lays the bag bar out right to left: backpack first
		local j = #bagButtons + 1 - i
		bagButtons[i], bagButtons[j] = bagButtons[j], bagButtons[i]
	end
end

local socialButtons = {}

-- The group settings the buttons were last placed for: data events of a group don't move buttons, only turning a
-- group on or off does.
local placedFor = { micromenu = nil, social = nil, bags = nil }

-- Which Blizzard buttons each group holds now, and who gets theirs back (rare: group or layout changes).
local function placeButtons()
	local s = db()
	placedFor.micromenu, placedFor.social, placedFor.bags = s.micromenu, s.social, s.bags
	for button in pairs(slotOf) do
		giveBack(button)
	end
	local next = 1
	if s.micromenu then
		next = fillGroup(microGroup, ns.MicroButtons, next)
	else
		fillGroup(microGroup, {}, next)
	end
	for i = #socialButtons, 1, -1 do
		socialButtons[i] = nil
	end
	local quickJoin = _G[SOCIAL_BUTTON]
	if s.social and quickJoin then
		socialButtons[1] = quickJoin
	end
	next = fillGroup(socialGroup, socialButtons, next, s.social and social or nil, true)
	if s.bags then
		readBags()
		fillGroup(bagGroup, bagButtons, next, bagText, true)
	else
		fillGroup(bagGroup, {}, next)
	end
end

-- Building the panel ----------------------------------------------------------------------------------------------

local function onBarEnter(self)
	if tooltip then
		tooltip:Show(self.frame)
	end
end

local function onBarLeave(self)
	if tooltip then
		tooltip:Hide(self.frame)
	end
end

local hoverTicker ---@type OrdaenTicker|nil

local function setHover(on)
	local State = ns.State
	if State.hover == on then
		return
	end
	State.hover = on
	View.Update("visibility")
	if hoverTicker then
		if on then
			hoverTicker:Start()
		else
			hoverTicker:Stop()
		end
	end
end

local function onPanelEnter()
	setHover(true)
end

local function checkHover()
	if panel and not panel:IsMouseOver() then
		setHover(false)
	end
end

local function build()
	local s = db()
	size = s.buttonSize
	local across = horizontal()
	microGroup = microGroup or { gap = 2 }
	socialGroup = socialGroup or { gap = "xs", align = "center" }
	bagGroup = bagGroup or { gap = 2 }
	left = left or { gap = "md", align = "left", microGroup, socialGroup }
	left.columns = across and { "auto", "auto" } or { "auto" }
	right = right or { gap = "md", align = "right", money }
	for i = 1, MAX_CURRENCIES do
		right[1 + i] = currencyTexts[i]
	end
	right[MAX_CURRENCIES + 2] = bagGroup
	right.columns = columns(MAX_CURRENCIES + 2)
	if not barHolder then
		tooltip = UI.Tooltip({
			columns = { "auto" },
			gap = "xs",
			tipName, tipValue, tipRested, tipQuest, tipRate, tipLevel,
		}, { side = "above" })
		barHolder = UI.Block({ width = 200, xp })
		if barHolder then
			barHolder:On("enter", onBarEnter)
			barHolder:On("leave", onBarLeave)
		end
	end
	middle = middle or { embed = barHolder, align = "center" }
	xp.height = math.max(10, math.floor(size * 0.5))
	if barHolder then
		-- the bar in the middle of the row's height (blocks align only across, so a top padding)
		barHolder.block.height = size + 4
		barHolder.block.padding = { math.floor((size + 4 - xp.height) / 2), 0, 0, 0 }
	end
	if across then
		-- equal side columns: the bar stays in the middle of the screen whatever the sides hold
		spec = {
			columns = { "1fr", "auto", "1fr" }, gap = "lg", padding = { 0, "sm", 0, "sm" }, height = size + 8,
			left, middle, right,
		}
	else
		spec = { columns = { "auto" }, gap = "md", padding = { "sm", "xs", "sm", "xs" }, left, middle, right }
	end
	social.format = L.SOCIAL_FORMAT
	tipRested.format, tipQuest.format = L.TIP_RESTED, L.TIP_QUESTS
	tipRate.format, tipLevel.format = L.TIP_RATE, L.TIP_LEVEL
	if panel then
		panel.block = spec
		panel.panel.edge, panel.panel.fit = s.edge, s.fit
		panel:Place()
	else
		panel = UI.Panel(spec, { edge = s.edge, fit = s.fit })
		if panel then
			panel:On("enter", onPanelEnter)
			hoverTicker = ns.Addon:Every(0.25, checkHover)
		end
	end
end

-- Updates (from ns.Changed) ---------------------------------------------------------------------------------------

-- Blizzard's experience and reputation bars (StatusTrackingBarManager's containers): parked on a hidden frame
-- while ours shows, given back when it goes. Not in the API dump on Forever, so looked up by name and logged.
local STATUS_BARS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local parking ---@type Frame|nil
local parked = {} ---@type table<table, table|false> bar -> its parent before (false: not parked)

local function park(bar)
	if parked[bar] and bar:GetParent() ~= parking then
		bar:SetParent(parking)
	end
end

local function parkBlizzardBars(on)
	for _, name in ipairs(STATUS_BARS) do
		local bar = _G[name]
		if type(bar) == "table" and bar.GetObjectType then
			if on and not parked[bar] then
				if not parking then
					parking = CreateFrame("Frame")
					parking:Hide()
				end
				parked[bar] = bar:GetParent()
				if parked[bar] == nil then
					parked[bar] = UIParent
				end
				bar:SetParent(parking)
				if not hooked[bar] then
					hooked[bar] = true
					hooksecurefunc(bar, "SetParent", park)
					ns.Addon:Claim(bar, { "SetParent" }, name)
				end
				ns.Addon.Debug:Logf("experience: Blizzard's %s hidden", name)
			elseif not on and parked[bar] then
				local home = parked[bar]
				parked[bar] = false
				bar:SetParent(home)
			end
		elseif on then
			ns.Addon.Debug:Logf("experience: no %s on this client", name)
		end
	end
end

local function updateExperience()
	local s = db()
	parkBlizzardBars(s.experience)
	local model = ns.Segments.experience.model
	local shown = s.experience and model.kind ~= nil
	middle.hidden = not shown
	if not shown then
		return
	end
	xp.bar, xp.max, xp.quest, xp.overlay = model.value, model.max, model.quest, model.overlay
	xp.color = model.kind == "reputation" and REP_TOKEN[model.standing] or "color.xp"
	xp.args[1] = model.percent
	tipName.hidden = model.kind ~= "reputation"
	tipName.text = model.name or ""
	tipValue.args[1], tipValue.args[2], tipValue.args[3] = model.value, model.max, model.percent
	local rested = model.overlay - model.quest
	tipRested.hidden = rested <= 0
	tipRested.args[1], tipRested.args[2] = rested, model.restedPercent
	local quest = model.quest - model.value
	tipQuest.hidden = quest <= 0
	tipQuest.args[1] = quest
	local perHour, seconds, gains = ns.Data.Rate(ns.Segments.experience.session, GetTime(), model.max - model.value)
	tipRate.hidden = perHour == nil
	tipRate.args[1] = perHour and math.floor(perHour) or 0
	tipLevel.hidden = seconds == nil
	tipLevel.args[1], tipLevel.args[2] = seconds and math.ceil(seconds / 60) or 0, gains or 0
	if barHolder then
		barHolder.block.width = horizontal() and math.max(120, math.floor(UIParent:GetWidth() * 0.3)) or 8 * size
		barHolder:Refresh()
	end
	if tooltip and tooltip:IsShown() then
		tooltip:Refresh()
	end
end

local function updateSocial()
	local m = ns.Segments.social.model
	social.args[1], social.args[2] = m.friends + m.bnet, m.guild
end

local function updateCurrencies()
	local s = db()
	local m = ns.Segments.currencies.model
	money.hidden = not s.currencies
	money.args[1], money.args[2], money.args[3] = m.gold, m.silver, m.copper
	for i = 1, MAX_CURRENCIES do
		local entry, text = m.list[i], currencyTexts[i]
		text.hidden = not s.currencies or i > m.count
		if entry and not text.hidden then
			text.args[1], text.args[2] = entry.quantity, entry.icon
		end
	end
end

local function updateBags()
	local m = ns.Segments.bags.model
	bagText.format = m.reagentFree > 0 and "%d (%d)" or "%d"
	bagText.args[1], bagText.args[2] = m.free, m.reagentFree
end

local function updateVisibility()
	if not panel then
		return
	end
	local v = db().visibility
	local shown = ns.Visibility.Shown(v, ns.State)
	local target = shown and 1 or v.fadedAlpha
	if panel.targetAlpha ~= target then
		panel:FadeTo(target)
	end
end

--- What the dev window's "Send state" records: the buttons we hold and where, Blizzard's bars, the panel.
function View.Dump()
	local Debug = ns.Addon.Debug
	local held = {}
	for button, slot in pairs(slotOf) do
		held[#held + 1] = { name = button:GetName(), shown = button:IsShown(), w = button:GetWidth(),
			h = button:GetHeight(), slotShown = slot.frame:IsShown() }
	end
	local bars = {}
	for _, name in ipairs(STATUS_BARS) do
		local bar = _G[name]
		bars[name] = type(bar) == "table" and bar.GetObjectType and Debug:Snapshot(bar) or "missing"
	end
	return {
		size = size,
		held = held,
		micro = #ns.MicroButtons,
		bags = #bagButtons,
		blizzardBars = bars,
		panel = panel and Debug:Snapshot(panel.frame) or "not built",
	}
end

--- A segment changed (ns.Changed): update its fields and redraw. "layout": the edge, fit or button size changed;
--- "micromenu", "social", "bags" also move Blizzard's buttons (rare). Text and bar changes only set fields.
---@param segment string
function View.Update(segment)
	if not UI then
		return
	end
	if not panel or segment == "layout" then
		build()
		if not panel then
			return -- OrdaenCore_UI can't load (the player was told)
		end
		placeButtons()
		updateExperience()
		updateSocial()
		updateCurrencies()
		updateBags()
	elseif segment == "micromenu" or segment == "social" or segment == "bags" then
		local s = db()
		if placedFor[segment] ~= s[segment] or segment == "micromenu" then
			placeButtons() -- the group went on or off (the micro menu also on a re-read of Blizzard's buttons)
		end
		if segment == "social" then
			updateSocial()
		elseif segment == "bags" then
			updateBags()
		end
	elseif segment == "experience" then
		local wasHidden = middle.hidden
		updateExperience()
		if middle.hidden == wasHidden then
			return -- only the bar's own component changed
		end
	elseif segment == "currencies" then
		updateCurrencies()
	elseif segment == "visibility" then
		updateVisibility()
		return
	end
	panel:Refresh()
	updateVisibility()
end
