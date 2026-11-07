-- Ordaen Panel's drawing: one OrdaenCore.UI panel on a screen edge. Left: the game menu buttons and the social
-- button; middle: the experience (or reputation) bar; right: gold, the backpack currencies and the bags.
-- Blizzard's buttons stay Blizzard's (clicks, menus, alerts): each group is a row of cells drawn in the panel, and
-- each button sits invisibly over its cell. We only declare blocks and move Blizzard's frames; OrdaenCore.UI draws.
--
-- Cost: the block tables are made once (again only when the edge or button size changes, a settings change);
-- events update fields in place and refresh. Nothing runs per frame; a 0.25 s ticker runs only while the mouse is
-- over a "show on mouseover" panel, to notice it leaving through a Blizzard button.
local _, ns = ...

local UI = OrdaenCore.UI
local L = ns.L

local View = {}
ns.View = View

local GOLD_FORMAT = "%d|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_FORMAT = "%d|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_FORMAT = "%d|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
local CURRENCY_FORMAT = "%d|T%s:0:0:2:0|t"
local MAX_CURRENCIES = 6
local SOCIAL_BUTTON = "QuickJoinToastButton" -- in the API dump (1.60.1-70790)

-- The bar's colours come from the palette (OrdaenCore.Colors, the player's pick in Ordaen Core's settings): XP in
-- blue, rested and quest XP that blue fainter; a reputation in its standing's palette colour.
local Colors = OrdaenCore.Colors
local STANDING_COLOR = {
	hated = "red", hostile = "red", unfriendly = "orange", neutral = "yellow",
	friendly = "green", honored = "green", revered = "green", exalted = "green",
}

-- Blocks (made by build(), changed in place) ---------------------------------------------------------------------

local panel ---@type OrdaenUIPanel|nil
local spec, left, middle, right, microGroup, bagRow
local barHolder ---@type OrdaenUIComponent|nil the middle group: a component of its own, for its tooltip
local xp = {
	bar = 0, min = 0, max = 1, quest = 0, overlay = 0, animate = true,
	color = Colors:Get("blue"), questColor = Colors:Get("blue"), overlayColor = Colors:Get("blue"),
	format = "%d%%", args = { 0 }, style = "onBar", sections = 20,
}
-- The social button's tooltip (no title: it's beside the button it describes).
local tipFriends = { format = "", args = { 0 } }
local tipBnet = { format = "", args = { 0 } }
local tipGuild = { format = "", args = { 0, 0 }, hidden = true }
local socialTip ---@type OrdaenUITooltip|nil
-- Gold, silver and copper: a zero amount isn't shown (copper stays when it's all there is).
local gold = { format = GOLD_FORMAT, args = { 0 }, style = "value" }
local silver = { format = SILVER_FORMAT, args = { 0 }, style = "value" }
local copper = { format = COPPER_FORMAT, args = { 0 }, style = "value" }
local money = { columns = { "auto", "auto", "auto" }, gap = "xs", rowAlign = "center", gold, silver, copper }
local currencyTexts = {}
for i = 1, MAX_CURRENCIES do
	currencyTexts[i] = { format = CURRENCY_FORMAT, args = { 0, "" }, style = "value", hidden = true }
end
-- Each bag's free slots, over its icon's bottom-right corner (an onTop text in the bag's cell).
local bagCounts = {} ---@type table<table, table> bag button -> its count element
local bagIds = {} ---@type table<table, integer> bag button -> its bag id

-- The bar's tooltip: experience in numbers, rested and quest XP, the session's rate and time to level.
local tipName = { text = "", style = "title", hidden = true }
local tipValue = { format = "%d / %d (%d%%)", args = { 0, 0, 0 } }
local tipRested = { format = "", args = { 0, 0 }, hidden = true }
local tipQuest = { format = "", args = { 0 }, hidden = true }
local tipRate = { format = "", args = { 0 }, hidden = true }
local tipLevel = { format = "", args = { 0, 0 }, hidden = true }
local tooltip ---@type OrdaenUITooltip|nil

-- Cells: each group of buttons is one row of "iconButton" cells drawn in the panel itself, so touching cells share
-- one border (the engine collapses them). Each Blizzard button is dressed with style "none" (its art hidden,
-- nothing drawn, its size left alone) and sits invisibly over its cell, placed from the panel's "render" event; while
-- it's hovered its cell lights.
local hookSocialTip -- defined with the social tooltip, below
local visibleArt -- dev, below
local cellOf = {} ---@type table<table, table> Blizzard button -> its cell (a block in the panel)
local cells = {} ---@type table<table, table> Blizzard button -> its cell, kept to reuse
local homes = {} ---@type table<table, table> Blizzard button -> { parent, point, relativeTo, relativePoint, x, y }
local sizes = {} ---@type table<table, number[]> Blizzard button -> its size before
local dresses = {} ---@type table<table, OrdaenUIDress>
local placing = false
-- Sizes, all from the panel's height (setting `height`): square cells fill it; an icon's picture shows at half the
-- cell (iconSide; each atlas box scaled by its CONTENT), bag icons fill the cell; the bar is 60 %.
local size = 60 -- the panel's height
local cellWidth = 48
local iconSide = 36

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

-- The right side's columns: one per shown child. A column per possible child (6 currencies) left the empty ones'
-- gaps after the bags, so they didn't reach the right edge (2026-11-07). One table per count, made once: currencies
-- change on events.
local rightTracks = {}
local function fitRight()
	if not right then
		return
	end
	if not horizontal() then
		right.columns = columns(1)
		return
	end
	local n = 0
	for i = 1, MAX_CURRENCIES + 2 do
		local child = right[i]
		if child and not child.hidden then
			n = n + 1
		end
	end
	n = math.max(n, 1)
	local tracks = rightTracks[n]
	if not tracks then
		tracks = columns(n)
		rightTracks[n] = tracks
	end
	right.columns = tracks
end

-- Putting Blizzard's buttons over their cells ----------------------------------------------------------------------

local function place(button)
	local cell = cellOf[button]
	if not cell or placing or not panel then
		return
	end
	local x, y, w, h = panel:RectOf(cell)
	if not x then
		return -- the cell isn't drawn (yet)
	end
	placing = true
	button:SetParent(panel.frame)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", x, -y)
	button:SetSize(w, h)
	placing = false
end

-- The player's portrait changed (gear, form, a new look): the character cell draws it again.
local function onPortraitChanged(_, unit)
	if unit == "player" and panel then
		panel:Refresh()
	end
end

-- The panel was drawn: every button over its cell.
local function onPanelDrawn()
	for button in pairs(cellOf) do
		place(button)
	end
end

-- Blizzard greys out a button that can't be used yet (talents before level 10): its cell's icon follows, in the
-- theme's colour for disabled things. Runs on Blizzard's Enable/Disable, rare.
local function followEnabled(button)
	local cell = cellOf[button]
	local icon = cell and cell[1]
	if not icon then
		return
	end
	local color = (not button:IsEnabled()) and "color.disabled" or nil
	local Debug = ns.Addon.Debug
	if Debug:IsEnabled() then
		Debug:Verbosef("enabled %s: %s (%s)", button:GetName() or "?", tostring(button:IsEnabled()),
			tostring(rawget(button, "tooltipText")))
	end
	if icon.color ~= color then
		icon.color = color
		if panel then
			panel:Refresh()
		end
	end
end

-- Its cell lights while Blizzard's (invisible) button is hovered.
local function lightCell(button, lit)
	local cell = cellOf[button]
	if lit and not button:IsEnabled() then
		return -- Blizzard disabled it (the game menu is open, not yet available): no hover look
	end
	if cell and panel and cell.highlight ~= lit then
		cell.highlight = lit
		panel:Refresh()
	end
end

local function onButtonEnter(button)
	lightCell(button, true)
end

local function onButtonLeave(button)
	lightCell(button, false)
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
	hooksecurefunc(button, "Enable", followEnabled)
	hooksecurefunc(button, "Disable", followEnabled)
	hooksecurefunc(button, "SetEnabled", followEnabled)
	button:HookScript("OnEnter", onButtonEnter)
	button:HookScript("OnLeave", onButtonLeave)
	-- Found at runtime, so the build can't claim them: another bar addon moving them is a conflict (Conflict.lua).
	ns.Addon:Claim(button, { "SetPoint", "SetParent" }, button:GetName() or "a Blizzard button")
end

-- Art around an icon, never the icon: hover and highlight frames (the first test picked
-- "UI-HUD-ActionBar-IconFrame-Mouseover" for the character and social buttons).
local function decoration(name)
	return type(name) == "string" and (name:find("IconFrame") or name:find("Mouseover") or name:find("Highlight")
		or name:find("Border")) ~= nil
end

-- A texture's atlas or file, if it has one that isn't decoration.
local function art(texture)
	if not (texture and texture.GetAtlas) then
		return nil, nil
	end
	local atlas = texture:GetAtlas()
	if atlas then
		if decoration(atlas) then
			return nil, nil
		end
		return nil, atlas
	end
	local file = texture:GetTexture()
	if decoration(file) then
		return nil, nil
	end
	return file, nil
end

-- No art found (the social button may draw its icon on child frames): the friends toast icon.
local FALLBACK_ICON = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon"

-- Buttons whose icon Blizzard draws some other way (the character button shows the player's portrait).
local OWN_ICONS = {
	CharacterMicroButton = "UI-HUD-MicroMenu-CharacterInfo-Up", -- only when its portrait can't be found
}

-- The social button: Blizzard's art for it carries its own frame (quickjoin-button-friendslist-up), so a plain
-- glyph like the other buttons': the first of these atlases the client has, else the friends toast icon file.
local SOCIAL_ATLASES = { "socialqueuing-icon-group", "groupfinder-icon-friend" }
local function socialIcon()
	for _, atlas in ipairs(SOCIAL_ATLASES) do
		if C_Texture.GetAtlasInfo(atlas) then
			return nil, atlas
		end
	end
	return FALLBACK_ICON, nil
end

-- The character button shows the player's face: our own portrait image in its cell (the renderer draws it with
-- SetPortraitTexture), not Blizzard's portrait texture, whose mask, crop and size Blizzard keeps setting (it came out
-- small and squashed, 2026-11-06). Blizzard's art on the button goes like on every other button.
local PORTRAIT_BUTTON = "CharacterMicroButton"

-- An atlas icon keeps its proportions (Blizzard's micro icons are taller than wide): fit into the icon square.
-- How much of its atlas box each micro icon's picture fills (the larger of its visible width and height over the
-- box height). Blizzard's micro atlases leave different empty margins, so equal boxes look unequal. Measured from
-- the panel's pixels in game (screenshot 2026-11-06, boxes 36 units high); re-measure when Blizzard changes the art.
local CONTENT = {
	ProfessionMicroButton = 0.56, SpellbookMicroButton = 0.58, TalentMicroButton = 0.50,
	QuestLogMicroButton = 0.64, GuildMicroButton = 0.61, LFDMicroButton = 0.44, CollectionsMicroButton = 0.53,
	StoreMicroButton = 0.56, MainMenuMicroButton = 0.67, HelpMicroButton = 0.67,
	QuickJoinToastButton = 0.68, -- socialqueuing-icon-group (measured at 34 of a 50 box)
}
local CONTENT_DEFAULT = 0.6

-- Box size for an icon whose picture should show `visible` units: never more than the cell.
local function boxFor(name, visible)
	return math.min(size - 4, math.floor(visible / (CONTENT[name] or CONTENT_DEFAULT) + 0.5))
end

local function fitIcon(icon, atlas, name)
	local side = boxFor(name, iconSide)
	if icon.crop then
		side = size - 4 -- an item icon (a bag) fills its cell, inside the panel's lines
	end
	local info = atlas and C_Texture.GetAtlasInfo(atlas)
	if info and info.width and info.height and info.width > 0 and info.height > 0 then
		local ratio = info.width / info.height
		icon.size = nil
		icon.width = ratio < 1 and math.floor(side * ratio + 0.5) or side
		icon.height = ratio < 1 and side or math.floor(side / ratio + 0.5)
	else
		icon.size, icon.width, icon.height = side, nil, nil
	end
end

-- Blizzard's icon of a button: its own `icon` (a bag's item), else its normal texture, else the first texture
-- region with art (QuickJoinToastButton draws its icon on a plain region).
local function iconOf(button)
	local own = OWN_ICONS[button:GetName() or ""]
	if own then
		return nil, own
	end
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
	return FALLBACK_ICON, nil
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

-- Our tooltip on the social button instead of Blizzard's (CLAUDE.md: adopted buttons show ours). Hooked once.
local socialHooked = false
local function onSocialEnter(button)
	if socialTip then
		GameTooltip:Hide()
		socialTip.hotkey = UI.Binding("TOGGLESOCIAL") -- the friends list's key, at the bottom
		socialTip:Show(button)
	end
end

local function onSocialLeave(button)
	if socialTip then
		socialTip:Hide(button)
	end
end

function hookSocialTip(button)
	if socialHooked then
		return
	end
	socialHooked = true
	socialTip = UI.Tooltip({ columns = { "auto" }, gap = "xs", tipFriends, tipBnet, tipGuild }, { side = "above" })
	button:HookScript("OnEnter", onSocialEnter)
	button:HookScript("OnLeave", onSocialLeave)
end

-- The cell of `button`: an "iconButton" block the button's size with its icon centred (none for the portrait).
local function cellFor(button)
	local name = button:GetName()
	-- A button look with side edges only: the panel's own top and bottom lines frame the row. rowAlign: the icon
	-- in the middle of the cell's height (a fixed-height block centres its row only when asked).
	local cell = cells[button] or {
		style = "iconButton", padding = 0, rowAlign = "center", edges = { top = false, bottom = false },
	}
	cells[button] = cell
	if horizontal() then
		cell.width, cell.height = cellWidth, size
	else
		cell.width, cell.height = size, cellWidth
	end
	cell.highlight = false
	if name == PORTRAIT_BUTTON then
		local face = cell[1] or { portrait = "player", crop = true, align = "center", valign = "center" }
		face.size = size - 4 -- the whole cell, inside the panel's lines, like a bag
		cell[1] = face
		return cell
	end
	local icon, atlas
	if name == SOCIAL_BUTTON then
		icon, atlas = socialIcon()
	else
		icon, atlas = iconOf(button)
	end
	local el = cell[1] or { align = "center", valign = "center" }
	el.image, el.atlas = icon, atlas
	-- item icons (bags) lose their own border and fill the cell; atlases and the social glyph are drawn whole
	el.crop = icon ~= nil and name ~= SOCIAL_BUTTON
	fitIcon(el, atlas, name)
	cell[1] = el
	return cell
end

-- Another addon already holding the button (Bartender4's micro bar parents them to BT4BarMicroMenu): its frame's
-- global name was set by that addon, so issecurevariable names it. Recorded, not asked: we take the button anyway, and
-- a multi-purpose addon can't be turned off for this (the player turns off its bar).
local function noteHolder(button)
	local parent = button:GetParent()
	local name = parent and parent:GetName()
	if not name then
		return
	end
	local secure, owner = issecurevariable(name)
	if not secure and owner and not owner:find("^Ordaen") then
		ns.Addon:Conflict(owner, (button:GetName() or "a button") .. " was on " .. name, true)
	end
end

-- Dev: the textures of a held button (and its children) that still show, for art Dress doesn't reach (the grey
-- shape behind the quest log's icon). Only from dev logging and the dump.
function visibleArt(button, out, frame, path)
	out = out or {}
	frame = frame or button
	path = path or (button:GetName() or "?")
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") and region:IsVisible() and region:GetAlpha() > 0
			then
			out[#out + 1] = path .. ":" .. tostring(region:GetAtlas() or region:GetTexture()) .. "@"
				.. region:GetDrawLayer() .. " a" .. string.format("%.2f", region:GetAlpha())
		end
	end
	for i, child in ipairs({ frame:GetChildren() }) do
		visibleArt(button, out, child, path .. "/" .. (child:GetName() or ("#" .. i)))
	end
	return out
end

local function take(button, cell, texts)
	texts = texts or button:GetName() == SOCIAL_BUTTON -- its friends count: ours is in its tooltip
	if not homes[button] then
		noteHolder(button)
		local home = { button:GetParent() }
		if button:GetNumPoints() > 0 then
			home[2], home[3], home[4], home[5], home[6] = button:GetPoint(1)
		end
		homes[button] = home
		sizes[button] = { button:GetWidth(), button:GetHeight() }
	end
	cellOf[button] = cell
	hookPlacement(button)
	local dress = dresses[button]
	if dress then
		dress:Apply()
	else
		dresses[button] = UI.Dress(button, { style = "none", size = "frame" })
	end
	local Debug = ns.Addon.Debug
	if Debug:IsEnabled() then
		local seen = visibleArt(button)
		if #seen > 0 then
			Debug:Logf("still visible on %s: %s", button:GetName() or "?", table.concat(seen, ", "))
		end
	end
	if button:GetName() == SOCIAL_BUTTON then
		hookSocialTip(button)
	end
	if texts then
		hideTexts(button)
	end
	followEnabled(button)
	local el = cell[1]
	ns.Addon.Debug:Logf("held %s \"%s\"%s: %s", button:GetName() or "?", tostring(rawget(button, "tooltipText")),
		button:IsEnabled() and "" or " (disabled)",
		el and tostring(el.atlas or el.image) or "its portrait")
end

local function giveBack(button)
	if not cellOf[button] then
		return
	end
	cellOf[button] = nil
	showTexts(button)
	local dress = dresses[button]
	if dress then
		dress:Undress()
	end
	local home, before = homes[button], sizes[button]
	placing = true
	if home then
		button:SetParent(home[1])
		button:ClearAllPoints()
		if home[2] then
			button:SetPoint(home[2], home[3], home[4], home[5], home[6])
		end
	end
	if before then
		button:SetSize(before[1], before[2])
	end
	placing = false
end

-- Fill a row block with a cell per button (touching: gap 0, padding 0, so the borders collapse).
-- `atRight`: the row ends at the panel's right edge (the bags): its last cell has no line on its right. Otherwise it
-- starts at the left edge (the micro menu): its first cell has none on its left. Nothing to separate them from there.
local function fillRow(row, buttons, texts, atRight)
	for i = #row, 1, -1 do
		row[i] = nil
	end
	for i, button in ipairs(buttons) do
		local cell = cellFor(button)
		if atRight then
			cell.edges.left = nil
			cell.edges.right = i < #buttons and nil or false
		else
			cell.edges.left = i > 1 and nil or false
			cell.edges.right = nil
		end
		row[i] = cell
		take(button, cell, texts)
	end
	row.columns = columns(#buttons)
	row.hidden = #buttons == 0
end

-- The buttons of each group ----------------------------------------------------------------------------------------

local bagButtons = {}

-- A bag button's bag id, from Blizzard's fixed names (the dump lists no bag-id method on them): the backpack is 0,
-- CharacterBag<n>Slot is n + 1, the reagent bag comes after the bags. nil for anything else.
local function bagIdOf(button)
	local name = button:GetName() or ""
	if name == "MainMenuBarBackpackButton" then
		return BACKPACK_CONTAINER
	end
	local n = name:match("^CharacterBag(%d+)Slot$")
	if n then
		return tonumber(n) + 1
	end
	n = name:match("^CharacterReagentBag(%d+)Slot$")
	if n then
		return NUM_BAG_SLOTS + tonumber(n) + 1
	end
	return nil
end

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

local leftButtons = {} -- the micro buttons, then the social button

-- The group settings the buttons were last placed for: data events of a group don't move buttons, only turning a
-- group on or off does.
local placedFor = { micromenu = nil, social = nil, bags = nil }

-- Which Blizzard buttons each group holds now, and who gets theirs back (rare: group or layout changes).
local NONE = {}

local function placeButtons()
	local s = db()
	placedFor.micromenu, placedFor.social, placedFor.bags = s.micromenu, s.social, s.bags
	for button in pairs(cellOf) do
		giveBack(button)
	end
	-- the micro buttons and the social button in one row: neighbours share one line, no gap between groups
	for i = #leftButtons, 1, -1 do
		leftButtons[i] = nil
	end
	if s.micromenu then
		for i, button in ipairs(ns.MicroButtons) do
			leftButtons[i] = button
		end
	end
	local quickJoin = _G[SOCIAL_BUTTON]
	if s.social and quickJoin then
		leftButtons[#leftButtons + 1] = quickJoin
	end
	fillRow(microGroup, leftButtons)
	if s.bags then
		readBags()
		fillRow(bagRow, bagButtons, true, true)
		for _, button in ipairs(bagButtons) do
			local id = bagIdOf(button)
			bagIds[button] = id
			local count = bagCounts[button]
			if not count then
				count = { format = "%d", args = { 0 }, style = "small", onTop = true, align = "right", valign = "bottom" }
				bagCounts[button] = count
			end
			count.hidden = id == nil
			cells[button][2] = count
		end
	else
		fillRow(bagRow, NONE)
	end
	fitRight()
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
	size = s.height
	cellWidth = size -- square cells
	iconSide = math.floor(size * 0.5 + 0.5)
	local across = horizontal()
	-- rows of touching cells (gap 0, padding 0): one border line between two buttons
	microGroup = microGroup or { gap = 0, padding = 0, rowAlign = "center" }
	bagRow = bagRow or { gap = 0, padding = 0, rowAlign = "center" }
	left = left or { gap = 0, align = "left", rowAlign = "center", microGroup }
	left.columns = { "auto" }
	right = right or { gap = "md", align = "right", rowAlign = "center", money }
	for i = 1, MAX_CURRENCIES do
		right[1 + i] = currencyTexts[i]
	end
	right[MAX_CURRENCIES + 2] = bagRow
	fitRight()
	if not barHolder then
		tooltip = UI.Tooltip({
			columns = { "auto" },
			gap = "xs",
			tipName, tipValue, tipRested, tipQuest, tipRate, tipLevel,
		}, { side = "above" })
		barHolder = UI.Block({ width = 200, padding = 0, xp })
		if barHolder then
			barHolder:On("enter", onBarEnter)
			barHolder:On("leave", onBarLeave)
		end
	end
	middle = middle or { embed = barHolder, align = "center" }
	xp.height = math.floor(size * 0.6 + 0.5)
	-- One top block for the panel's life, changed in place (a new table lost the panel's look: a transparent
	-- background after moving the height slider, 2026-11-06).
	spec = spec or { style = "panel" }
	spec[1], spec[2], spec[3] = left, middle, right
	if across then
		-- equal side columns: the bar stays in the middle of the screen whatever the sides hold
		-- no side padding: the micro menu starts at the left edge, the bags end at the right one
		spec.columns, spec.gap, spec.padding = { "1fr", "auto", "1fr" }, "lg", 0
		spec.height, spec.rowAlign = size, "center"
	else
		spec.columns, spec.gap, spec.padding = { "auto" }, "md", { "sm", "xs", "sm", "xs" }
		spec.height, spec.rowAlign = nil, nil
	end
	tipFriends.format, tipBnet.format, tipGuild.format = L.TIP_FRIENDS, L.TIP_BNET, L.TIP_GUILD
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
			panel:On("render", onPanelDrawn)
			panel:On("UNIT_PORTRAIT_UPDATE", onPortraitChanged)
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

-- The player picked another palette colour (Ordaen Core's settings): the bar's tables already changed in place.
local function onPalette()
	if barHolder then
		barHolder:Refresh()
	end
end
Colors:On("change", onPalette)

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
	local colour = Colors:Get(model.kind == "reputation" and STANDING_COLOR[model.standing] or "blue")
	xp.color, xp.questColor, xp.overlayColor = colour, colour, colour
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
		barHolder.block.width = horizontal() and math.max(120, math.floor(UIParent:GetWidth() * 0.3)) or 4 * size
		barHolder:Refresh()
	end
	if tooltip and tooltip:IsShown() then
		tooltip:Refresh()
	end
end

local function updateSocial()
	local m = ns.Segments.social.model
	tipFriends.args[1], tipBnet.args[1] = m.friends, m.bnet
	tipGuild.hidden = not m.inGuild
	tipGuild.args[1], tipGuild.args[2] = m.guild, m.guildTotal
	if socialTip and socialTip:IsShown() then
		socialTip:Refresh()
	end
end

local function updateCurrencies()
	local s = db()
	local m = ns.Segments.currencies.model
	money.hidden = not s.currencies
	gold.args[1], silver.args[1], copper.args[1] = m.gold, m.silver, m.copper
	gold.hidden = m.gold == 0
	silver.hidden = m.silver == 0
	copper.hidden = m.copper == 0 and (m.gold > 0 or m.silver > 0)
	for i = 1, MAX_CURRENCIES do
		local entry, text = m.list[i], currencyTexts[i]
		text.hidden = not s.currencies or i > m.count
		if entry and not text.hidden then
			text.args[1], text.args[2] = entry.quantity, entry.icon
		end
	end
	fitRight()
end

local function updateBags()
	local m = ns.Segments.bags.model
	for _, button in ipairs(bagButtons) do
		local count, id = bagCounts[button], bagIds[button]
		if count and id then
			count.args[1] = m.freeOf[id] or 0
			count.hidden = (m.sizeOf[id] or 0) == 0 -- an empty bag slot: no count
		end
	end
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
	for button, cell in pairs(cellOf) do
		local x, y, w, h
		if panel then
			x, y, w, h = panel:RectOf(cell)
		end
		local entry = { name = button:GetName(), shown = button:IsShown(), w = button:GetWidth(),
			h = button:GetHeight(), cell = x and { x, y, w, h } or "not drawn", art = visibleArt(button) }
		held[#held + 1] = entry
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
			-- a bag equipped or taken off: its slot's icon changed
			for _, button in ipairs(bagButtons) do
				if cellOf[button] then
					cellFor(button)
				end
			end
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
