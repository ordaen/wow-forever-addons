-- Ordaen Bags, the window (the user's design, approved on the design page 2026-11-07): an OrdaenCore.UI window.
--   top     the search box; on the right the sort order (a dropdown: Blizzard's menu), the quick actions in our
--           bronze button (arrange, the bag slots, settings) and the close button in our red accent
--   bags    the bag strip (the bag slots button): each bag with its free slots; hovering one lights up its items
--   left    the category tabs with their counts (a bronze bar marks the shown one)
--   right   the shown tab's page: its sections side by side, wrapping (a caption over a grid of slots, by item
--           subclass), then one free slot with the count (Blizzard's own button of the first free slot)
--   bottom  the free slots and money
-- The framework draws a cell per item; Blizzard's own item buttons (Slots.lua) sit over the cells after each draw.
--
-- Cost: the window and its blocks are made on the first open, then changed in place. Its events (bag updates,
-- locks, cooldowns, search, money) are registered only while it is open. A scan reads every slot once per
-- BAG_UPDATE_DELAYED (the game's own calls return a table per slot; nothing else is made).
local _, ns = ...

local UI = OrdaenCore.UI
local L = ns.L
local Categories, Data, Slots = ns.Categories, ns.Data, ns.Slots

local View = {}
ns.View = View

local SLOT = 37 -- Blizzard's item button
local SLOT_GAP = 2
local ICON = "Interface\\AddOns\\OrdaenCore\\media\\icon-"
local CAPTION_EM = 7 -- a caption letter's width, roughly (UI units), for packing sections into rows
local SECTION_GAP = 24 -- between sections side by side (UI units; the user asked for bigger gaps, 2026-11-07)

-- The sort orders the dropdown offers (the setting "sort"): the order of the items inside each section.
local SORTS = {
	{ id = "bags", label = "SORT_BAGS" },
	{ id = "quality", label = "SORT_QUALITY" },
	{ id = "name", label = "SORT_NAME" },
	{ id = "ilvl", label = "SORT_ILVL" },
	{ id = "count", label = "SORT_COUNT" },
	{ id = "type", label = "SORT_TYPE" },
}

local win ---@type OrdaenUIWindow|nil
-- The sidebar and the page are components of their own (embedded in the window): the tabs take clicks and the page
-- carries the slots on its frame.
local sidebar ---@type OrdaenUIComponent|nil
local itemsPane ---@type OrdaenUIComponent|nil
local sortButton ---@type OrdaenUIComponent|nil
local searchBox ---@type OrdaenUIInput|nil
local quickButtons = {} ---@type table<string, OrdaenUIComponent> name -> a quick action (dev dump)
local bagStrip ---@type OrdaenUIComponent|nil
local bagStripCell = { colSpan = 2, hidden = true } -- the bag strip's cell in the window: hidden until asked for
local selected = "all" -- the tab shown (not saved: the window opens on all items)
local litBag = nil -- the bag whose items the bag strip lights up (hovered)

-- blocks, made once (build)
local tabButtons = {} ---@type table<string, OrdaenUIComponent> tab id -> its button
local tabTexts = {} ---@type table<string, table> tab id -> its label element ({ format, args = { label, count } })
local tabCells = {} ---@type table<string, table> tab id -> its cell in the sidebar (hidden when the tab is off)

-- Each tab's setting key ("tabs.<id>"), made once (no string per layout).
local tabKeys = {}
for _, tab in ipairs(Categories.TABS) do
	tabKeys[tab.id] = "tabs." .. tab.id
end

-- Whether a tab shows in the sidebar: "All" always; the others while their setting is on, and with "hide empty
-- tabs" only while they hold something.
local function tabShown(id, count)
	if id == "all" then
		return true
	end
	local A = ns.Addon
	if A:Get(tabKeys[id]) == false then
		return false
	end
	return not (A:Get("hideEmpty") and (count or 0) == 0)
end
-- the shown tab's page: rows of sections (packed side by side), the free slot last
-- The page: its rows of sections in `body`, room above each caption. The body is as wide as the slots per row and
-- the page keeps the tallest height it had while the window is open, so changing tabs never resizes the window.
local body = { columns = { "auto" }, gap = 20, padding = 0 }
local content = { style = "tabPage", columns = { "auto" }, body }
local rows = {} -- pool: { columns, gap, sections... } blocks, one per row of sections
local sections = {} -- pool: { caption, grid } blocks
local cells = {} -- pool of slot cells, the first `cellsUsed` in use
local cellsUsed = 0
local cellItem = {} ---@type table<table, OrdaenBagsItem> cell -> the item drawn there
local groups = {} ---@type OrdaenBagsGroup[]
local freeItem = { texture = nil, count = 0, locked = false, quest = false, noValue = false, filtered = false,
	bound = false, questActive = false, ilvl = 0 } -- what the free slot's button shows
local freeCell = { width = SLOT, height = SLOT }
local freeSection = { columns = { "auto" }, gap = "xs", { text = "", style = "label" }, { columns = { SLOT },
	freeCell } }
local freeText = { format = NUM_FREE_SLOTS, args = { 0 }, style = "label" }
local moneyText = { text = "", align = "right" }
local sortText = { text = "", style = "control" }
local bagButtons = {} ---@type table<number, OrdaenUIComponent> bag -> its button in the bag strip
local bagIcons = {} ---@type table<number, table> bag -> its image element
local bagCounts = {} ---@type table<number, table> bag -> its count element
local fixedColumns = {} -- n -> { SLOT, SLOT, ... } (n slots across)

local function columnsOf(n)
	local list = fixedColumns[n]
	if not list then
		list = {}
		for i = 1, n do
			list[i] = SLOT
		end
		fixedColumns[n] = list
	end
	return list
end

local rowColumns = {} -- n -> { "auto", ... } (n sections in a row)
local function autoColumns(n)
	local list = rowColumns[n]
	if not list then
		list = {}
		for i = 1, n do
			list[i] = "auto"
		end
		rowColumns[n] = list
	end
	return list
end

local function setting(key, fallback)
	local db = ns.Addon.db
	local value = db and db[key]
	if value == nil then
		return fallback
	end
	return value
end

-- Blizzard's labels start in either case ("Рецепты", "снаряжение"): the first letter up, Cyrillic too (UTF-8:
-- а-п D0 B0-BF -> D0 90-9F, р-я D1 80-8F -> D0 A0-AF, ё D1 91 -> D0 81). Once per label, at build.
local function capitalized(text)
	local b1, b2 = text:byte(1, 2)
	if b1 == 0xD0 and b2 and b2 >= 0xB0 and b2 <= 0xBF then
		return string.char(0xD0, b2 - 0x20) .. text:sub(3)
	elseif b1 == 0xD1 and b2 and b2 >= 0x80 and b2 <= 0x8F then
		return string.char(0xD0, b2 + 0x20) .. text:sub(3)
	elseif b1 == 0xD1 and b2 == 0x91 then
		return string.char(0xD0, 0x81) .. text:sub(3)
	end
	if b1 and b1 < 0x80 then
		return text:sub(1, 1):upper() .. text:sub(2)
	end
	return text -- already a capital (or a letter with no case): left as it is
end
View.Capitalized = capitalized -- specs

-- letters in a UTF-8 string (not bytes), for the caption width estimate
local function letters(text)
	local _, n = text:gsub("[^\128-\191]", "")
	return n
end

-- The bags ----------------------------------------------------------------------------------------------------------

local function scan()
	Data.Reset()
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS + (NUM_REAGENTBAG_SLOTS or 0) do
		local reagent = bag > NUM_BAG_SLOTS
		Data.AddFree(C_Container.GetContainerNumFreeSlots(bag) or 0, reagent, bag)
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
				local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
				local isQuest = quest ~= nil and (quest.isQuestItem == true or quest.questID ~= nil)
				local item = Data.Add(bag, slot, classID, subClassID, info.quality, isQuest)
				item.texture, item.count, item.link = info.iconFileID, info.stackCount or 1, info.hyperlink
				item.name = info.itemName
				item.ilvl = info.hyperlink and C_Item.GetDetailedItemLevelInfo(info.hyperlink) or 0
				item.bound, item.locked = info.isBound == true, info.isLocked == true
				item.noValue, item.filtered = info.hasNoValue == true, info.isFiltered == true
				item.questID, item.questActive = quest and quest.questID, quest ~= nil and quest.isActive == true
			elseif not reagent then
				Data.Empty(bag, slot)
			end
		end
	end
end

local function updateMoney()
	moneyText.text = GetMoneyString(GetMoney(), true)
end

local function sortLabel()
	local current = setting("sort", "bags")
	for _, sort in ipairs(SORTS) do
		if sort.id == current then
			return L[sort.label]
		end
	end
	return L.SORT_BAGS
end

local function section(i)
	local s = sections[i]
	if not s then
		local caption = { text = "", style = "label" }
		local grid = { gap = SLOT_GAP, padding = 0 }
		s = { columns = { "auto" }, gap = "xs", caption = caption, grid = grid, caption, grid }
		sections[i] = s
	end
	return s
end

local function row(i)
	local r = rows[i]
	if not r then
		r = { gap = SECTION_GAP, rowAlign = "start" }
		rows[i] = r
	end
	return r
end

-- How wide a section draws (UI units, roughly): its grid, or its caption when that is longer.
local function sectionWidth(n, caption)
	local grid = n * SLOT + (n - 1) * SLOT_GAP
	local text = letters(caption) * CAPTION_EM
	return grid > text and grid or text
end

-- packing state for one layout (file locals: no closure per layout)
local current, inRow, rowWidth, rowCount, limit

local function closeRow()
	if current then
		current.columns = autoColumns(inRow)
		for k = #current, inRow + 1, -1 do
			current[k] = nil
		end
	end
end

-- Put a section in the current row, or start a new row when it doesn't fit (a section never splits).
local function place(block, w)
	if not current or (inRow > 0 and rowWidth + SECTION_GAP + w > limit) then
		closeRow()
		rowCount = rowCount + 1
		current, inRow, rowWidth = row(rowCount), 0, 0
		body[rowCount] = current
	end
	inRow = inRow + 1
	current[inRow] = block
	rowWidth = rowWidth + (inRow > 1 and SECTION_GAP or 0) + w
end

-- The shown tab's sections, packed into rows no wider than the slots per row; the free slot ends the last row.
-- Blizzard's buttons follow on render.
local function layout()
	if not (win and sidebar and itemsPane and sortButton) then
		return
	end
	if selected ~= "all" and not tabShown(selected, Data.counts[selected]) then
		selected = "all" -- the tab shown was turned off (or emptied, with empty tabs hidden)
	end
	local across = setting("columns", 10)
	limit = across * SLOT + (across - 1) * SLOT_GAP
	body.minWidth = limit
	current, inRow, rowWidth, rowCount = nil, 0, 0, 0
	local n = Data.Group(selected, groups, setting("sort", "bags"))
	Slots.HideAll()
	local used = 0
	for i = 1, n do
		local group = groups[i]
		local s = section(i)
		local label = Categories.SectionLabel(group.section)
		s.caption.text = label
		local grid = s.grid
		local shown = math.min(across, group.n)
		grid.columns = columnsOf(shown)
		for j = 1, group.n do
			used = used + 1
			local cell = cells[used]
			if not cell then
				cell = { width = SLOT, height = SLOT }
				cells[used] = cell
			end
			grid[j] = cell
			cellItem[cell] = group[j]
		end
		for j = #grid, group.n + 1, -1 do
			grid[j] = nil
		end
		place(s, sectionWidth(shown, label))
	end
	local free = Data.free
	if selected == "all" and free.firstBag ~= nil then
		freeSection[1].text = L.FREE
		freeItem.count = free.bags
		place(freeSection, sectionWidth(1, L.FREE))
	end
	closeRow()
	for i = #body, rowCount + 1, -1 do
		body[i] = nil
	end
	cellsUsed = used
	for _, tab in ipairs(Categories.TABS) do
		local count = Data.counts[tab.id]
		tabTexts[tab.id].args[2] = count
		tabCells[tab.id].hidden = not tabShown(tab.id, count)
		local button = tabButtons[tab.id]
		button.block.style = tab.id == selected and "listTabSelected" or "listTab"
		button:Refresh()
	end
	for bag, count in pairs(bagCounts) do
		count.args[1] = free.ofBag[bag] or 0
		if bag > BACKPACK_CONTAINER then
			bagIcons[bag].image = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bag)) or nil
		end
		bagButtons[bag]:Refresh()
	end
	freeText.args[1] = free.bags
	sortText.text = sortLabel()
	sortButton:Refresh()
	sidebar:Refresh()
	itemsPane:Refresh() -- draws the cells: its render places the buttons
	win:Refresh() -- the panes' new sizes
end

local waitingForCombat = false

local function afterCombat()
	waitingForCombat = false
	layout()
end

local function waitForCombat()
	if not waitingForCombat then
		waitingForCombat = true
		ns.Addon:AfterCombat(afterCombat)
	end
end

local function lightFor(button, item)
	button:SetAlpha((litBag == nil or item.bag == litBag) and 1 or 0.3)
end

-- Drawn: Blizzard's button over each cell (made now if new; in combat a new one waits for it to end), and the free
-- slot's button (the first free slot's own) over its cell.
local function onRender()
	if not itemsPane then
		return
	end
	local frame = itemsPane.frame
	local height = frame:GetHeight()
	if height > (content.minHeight or 0) then
		content.minHeight = height -- the next tab keeps it (reset when the window closes or the width changes)
	end
	for i = 1, cellsUsed do
		local cell = cells[i]
		local item = cellItem[cell]
		local x, y = itemsPane:RectOf(cell)
		if item and x then
			local button = Slots.Get(item.bag, item.slot)
			if button then
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
				Slots.Fill(button, item)
				lightFor(button, item)
				button:Show()
			else
				waitForCombat()
			end
		end
	end
	local free = Data.free
	local x, y = itemsPane:RectOf(freeCell)
	if x and free.firstBag then
		local button = Slots.Get(free.firstBag, free.firstSlot)
		if button then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
			freeItem.bag, freeItem.slot = free.firstBag, free.firstSlot
			Slots.Fill(button, freeItem) -- empty: Blizzard's own empty-slot art
			SetItemButtonCount(button, free.bags) -- and how many are free
			button:SetAlpha(1)
			button:Show()
		else
			waitForCombat()
		end
	end
end

-- Events while the window is open -----------------------------------------------------------------------------------

local function onBagsChanged()
	scan()
	layout()
end

local lockBag, lockSlot -- the slot ITEM_LOCK_CHANGED names, for updateLock

local function updateLock(button, item)
	if item.bag == lockBag and item.slot == lockSlot then
		local info = C_Container.GetContainerItemInfo(lockBag, lockSlot)
		item.locked = info ~= nil and info.isLocked == true
		SetItemButtonDesaturated(button, item.locked)
	end
end

local function onLock(_, bag, slot)
	if not slot then
		return -- an equipped item's slot
	end
	lockBag, lockSlot = bag, slot
	Slots.EachShown(updateLock)
end

local function updateCooldown(button, item)
	button:UpdateCooldown(item.texture)
end

local function onCooldowns()
	Slots.EachShown(updateCooldown)
end

local function updateSearch(button, item)
	if item == freeItem then
		return
	end
	local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
	item.filtered = info ~= nil and info.isFiltered == true
	button:SetMatchesSearch(not item.filtered)
end

local function onSearchResult()
	Slots.EachShown(updateSearch)
end

local function onMoney()
	updateMoney()
	if win then
		win:Refresh()
	end
end

local EVENTS = {
	BAG_UPDATE_DELAYED = onBagsChanged,
	ITEM_LOCK_CHANGED = onLock,
	BAG_UPDATE_COOLDOWN = onCooldowns,
	INVENTORY_SEARCH_UPDATE = onSearchResult,
	PLAYER_MONEY = onMoney,
}

local function listen(on)
	local A = ns.Addon
	for event, fn in pairs(EVENTS) do
		if on then
			A:On(event, fn)
		else
			A:Off(event, fn)
		end
	end
end

-- The sort dropdown: Blizzard's menu with a choice per order, then Blizzard's own clean-up of the bags -------------

local function isSort(id)
	return setting("sort", "bags") == id
end

local function setSort(id)
	ns.Addon:Set("sort", id) -- the addon's onChange lays the window out again
end

local function onCleanUp()
	C_Container.SortBags()
end

local function sortMenu(_, root)
	for _, sort in ipairs(SORTS) do
		root:CreateRadio(L[sort.label], isSort, setSort, sort.id)
	end
	root:CreateDivider()
	root:CreateButton(BAG_CLEANUP_BAGS, onCleanUp)
end

local function onSortClick(self)
	MenuUtil.CreateContextMenu(self.frame, sortMenu)
end

-- Quick actions ----------------------------------------------------------------------------------------------------

local function onArrange()
	-- Blizzard's clean-up: it moves the items in the bags (in Blizzard's order); the window shows them in the chosen
	-- order anyway. Moving them in the chosen order is the next step (an item mover of our own).
	C_Container.SortBags()
end

local function onToggleBags()
	if bagStrip and win then
		bagStripCell.hidden = not bagStripCell.hidden
		if bagStripCell.hidden then
			bagStrip:Hide()
		else
			bagStrip:Show()
		end
		win:Refresh()
	end
end

local function onSettings()
	ns.Addon:OpenSettings()
end

local function onClose()
	View.Close()
end

local function relight()
	Slots.EachShown(lightFor)
end

-- A small tooltip for a quick action: its name over what it does (made once per button).
local function actionTip(title, text)
	return UI.Tooltip({ columns = { "auto" }, gap = "xs", { text = title, style = "title" }, { text = text } },
		{ side = "below" })
end

local function iconButton(style, icon, tip, onClick)
	return UI.Button({
		style = style, width = 34, height = 34, padding = 0, rowAlign = "center", tooltip = tip,
		on = { click = onClick },
		{ image = ICON .. icon, size = 18, color = "color.icon", align = "center" },
	})
end

-- The resize grip: dragging it sideways changes the slots per row (the "columns" setting; onChange relays out). The
-- window is held by its top left meanwhile, so it grows to the right, under the cursor. The cursor is read per frame
-- only while the button is held.
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local MIN_COLUMNS, MAX_COLUMNS = 4, 24 -- settings.jsonc "columns"
local dragFrom, dragColumns -- cursor x (UI units) and the slots per row when the drag began

local function cursorX()
	return GetCursorPosition() / UIParent:GetEffectiveScale()
end

local function onGripUpdate()
	local columns = dragColumns + math.floor((cursorX() - dragFrom) / (SLOT + SLOT_GAP) + 0.5)
	columns = math.max(MIN_COLUMNS, math.min(MAX_COLUMNS, columns))
	if columns ~= setting("columns", 10) then
		ns.Addon:Set("columns", columns)
	end
end

local function onGripDown(self)
	win:HoldBy("TOPLEFT")
	dragFrom, dragColumns = cursorX(), setting("columns", 10)
	self.frame:SetScript("OnUpdate", onGripUpdate)
end

local function onGripUp(self)
	self.frame:SetScript("OnUpdate", nil)
	ns.Debug:Logf("bags: resized to %d slots per row", setting("columns", 10))
end

-- Building the window (first open) ---------------------------------------------------------------------------------

local function onSearch(_, text)
	C_Container.SetItemSearch(text or "")
end

local grip -- the resize grip (bottom right of the window)

local function onHidden()
	content.minHeight = nil
	if grip then
		grip.frame:SetScript("OnUpdate", nil) -- closed mid-drag
	end
	listen(false)
	Slots.HideAll()
	ns.Takeover.WindowHidden()
end

local function bagEnter(self)
	litBag = self.bag
	relight()
end

local function bagLeave()
	litBag = nil
	relight()
end

local function buildBagStrip()
	local strip = { gap = "sm", rowAlign = "center" }
	local columns = {}
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local icon = { image = bag == BACKPACK_CONTAINER and "Interface\\Buttons\\Button-Backpack-Up" or nil,
			size = SLOT, crop = true, align = "center", valign = "center" }
		local count = { format = "%d", args = { 0 }, style = "value", onTop = true, align = "right", valign = "bottom" }
		bagIcons[bag], bagCounts[bag] = icon, count
		local button = UI.Button({
			style = "slot", width = SLOT, height = SLOT, padding = 0,
			tooltip = actionTip(bag == BACKPACK_CONTAINER and BAG_NAME_BACKPACK or BAGSLOTTEXT, L.TIP_BAG_TEXT),
			on = { enter = bagEnter, leave = bagLeave },
			icon, count,
		})
		if not button then
			return nil
		end
		button.bag = bag
		bagButtons[bag] = button
		columns[#columns + 1] = "auto"
		strip[#strip + 1] = { embed = button }
	end
	strip.columns = columns
	return strip
end

local function build()
	local search = UI.Input({ name = "OrdaenBagsSearch", width = 200, placeholder = SEARCH, on = { change = onSearch } })
	-- the dropdown's art is a 26 px field with a shadow (82, 2026-11-07): give it its height
	sortButton = UI.Button({ style = "dropdown", on = { click = onSortClick }, sortText })
	local arrange = iconButton("pushButton", "sort", actionTip(L.TIP_SORT, L.TIP_SORT_TEXT), onArrange)
	local bags = iconButton("pushButton", "bag", actionTip(L.TIP_BAGS, L.TIP_BAGS_TEXT), onToggleBags)
	local settings = iconButton("pushButton", "settings", actionTip(SETTINGS, L.TIP_SETTINGS_TEXT), onSettings)
	local close = iconButton("pushButtonAccent", "close", nil, onClose)
	if not (search and sortButton and arrange and bags and settings and close) then
		return false -- OrdaenCore_UI can't load (the player was told)
	end
	searchBox = search
	quickButtons.arrange, quickButtons.bags, quickButtons.settings, quickButtons.close = arrange, bags, settings, close
	quickButtons.sort = sortButton
	-- the sidebar: a tab per category (Blizzard's words, first letter up, with its count)
	local tabs = { columns = { "auto" }, gap = 0, padding = 0 }
	for _, tab in ipairs(Categories.TABS) do
		local label = { format = "%s (%d)", args = { capitalized(_G[tab.label] or tab.id), 0 } }
		tabTexts[tab.id] = label
		local id = tab.id
		local button = UI.Button({ style = "listTab", on = {
			click = function()
				selected = id
				layout()
			end,
		}, label })
		if not button then
			return false
		end
		tabButtons[tab.id] = button
		local cell = { embed = button }
		tabCells[tab.id] = cell
		tabs[#tabs + 1] = cell
	end
	-- One width for every tab, the widest label's with a three-digit count: each tab is its own frame (it takes clicks),
	-- so its hover and selected fill span the sidebar only when they share a width. Measured once, here.
	local widest = 0
	for _, tab in ipairs(Categories.TABS) do
		local label, button = tabTexts[tab.id], tabButtons[tab.id]
		label.args[2] = 999
		button:Refresh()
		widest = math.max(widest, button.frame:GetWidth())
		label.args[2] = 0
	end
	for _, tab in ipairs(Categories.TABS) do
		tabButtons[tab.id].block.width = widest
	end
	local strip = buildBagStrip()
	sidebar, itemsPane = UI.Block(tabs), UI.Block(content)
	bagStrip = strip and UI.Block(strip)
	if not (sidebar and itemsPane and bagStrip) then
		return false
	end
	bagStripCell.embed = bagStrip
	bagStrip:Hide()
	local top = {
		colSpan = 2, columns = { "auto", "1fr", "auto", "auto", "auto", "auto", "auto" }, gap = "sm", rowAlign = "center",
		{ embed = search },
		{ text = "" },
		{ embed = sortButton },
		{ embed = arrange },
		{ embed = bags },
		{ embed = settings },
		{ embed = close },
	}
	local footer = { colSpan = 2, columns = { "1fr", "auto" }, gap = "md", padding = { 0, "sm", 0, "sm" }, freeText,
		moneyText }
	win = UI.Window({
		-- the tabs as wide as their labels, touching the page (no gap between them); the page takes the rest
		name = "OrdaenBagsWindow", columns = { "auto", "1fr" }, gap = { 0, "lg" }, padding = { 28, "xl", "xl", "xl" },
		top, bagStripCell, { embed = sidebar }, { embed = itemsPane }, footer,
	}, { point = "BOTTOMRIGHT", x = -80, y = 120 })
	if not win then
		return false
	end
	itemsPane:On("render", onRender)
	win.frame:HookScript("OnHide", onHidden)
	grip = UI.Button({
		parent = win.frame, width = 16, height = 16, padding = 0,
		tooltip = actionTip(L.TIP_RESIZE, L.TIP_RESIZE_TEXT),
		on = { mousedown = onGripDown, mouseup = onGripUp },
		{ image = GRIP, size = 16 },
	})
	if grip then
		grip:SetPoint("BOTTOMRIGHT", win.frame, "BOTTOMRIGHT", -6, 6)
	end
	local Debug = ns.Debug
	if Debug:IsEnabled() then
		local probe = itemsPane.frame:CreateTexture()
		for _, name in ipairs({ "sort", "bag", "close", "settings" }) do
			probe:SetTexture(ICON .. name)
			Debug:Logf("bags: icon-%s -> file %s", name, tostring(probe:GetTextureFileID()))
		end
		probe:SetTexture(nil)
	end
	Slots.SetHost(itemsPane.frame)
	return true
end

--- Open the window (the bag key, a bag button, a vendor: Takeover.lua).
function View.Open()
	if not win and not build() then
		return
	end
	if win and not win:IsShown() then
		listen(true)
		scan()
		updateMoney()
		win:Show()
		layout()
	end
end

--- Close it (Escape and the close button too; closing it closes Blizzard's bags, Takeover.lua).
function View.Close()
	if win and win:IsShown() then
		win:Hide()
	end
end

---@return boolean
function View.IsOpen()
	return win ~= nil and win:IsShown()
end

--- The settings changed (slots per row, the sort order): lay out again if open.
function View.Relayout()
	if win and win:IsShown() then
		content.minHeight = nil -- a new width: the page's height starts over
		layout()
	end
end

-- Dev dump of one frame and what it draws: its size, level, visibility and alpha, each texture (atlas or file, layer,
-- size, shown, colour), and its child frames the same way, two levels deep. Made only on Send state.
local function round(v)
	return v and math.floor(v * 10 + 0.5) / 10 or nil
end

local function describe(frame, depth)
	local w, h = frame:GetSize()
	local out = {
		type = frame:GetObjectType(), name = frame:GetName(), size = { round(w), round(h) },
		level = frame.GetFrameLevel and frame:GetFrameLevel() or nil, shown = frame:IsShown(),
		visible = frame:IsVisible(), alpha = round(frame:GetEffectiveAlpha()), points = frame:GetNumPoints(),
		textures = {},
	}
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "Texture" then
			local tw, th = region:GetSize()
			local r, g, b, a = region:GetVertexColor()
			local layer, sub = region:GetDrawLayer()
			out.textures[#out.textures + 1] = {
				atlas = region:GetAtlas(), file = region:GetTextureFilePath(), layer = layer, sublevel = sub,
				size = { round(tw), round(th) }, shown = region:IsShown(), alpha = round(region:GetAlpha()),
				color = { round(r), round(g), round(b), round(a) },
			}
		end
	end
	if depth > 0 then
		out.children = {}
		for _, child in ipairs({ frame:GetChildren() }) do
			out.children[#out.children + 1] = describe(child, depth - 1)
		end
	end
	return out
end

--- Dev-mode state (Send state): the tab, the counts, the window's place, and how the search box and the quick
--- actions draw (for the renderer owner: their art didn't show in game, 2026-11-07).
---@return table
function View.Dump()
	local controls = {}
	if searchBox then
		controls.search = describe(searchBox.frame, 2)
	end
	for name, button in pairs(quickButtons) do
		controls[name] = describe(button.frame, 2)
	end
	-- every item the last scan found, one line each: where it is, what it is, where the window files it
	local list = {}
	for i = 1, Data.Count() do
		local item = Data.Item(i)
		list[i] = string.format("%d/%d %s x%d: tab %s, section %d (%s)", item.bag, item.slot, item.name or "?",
			item.count, item.tab, item.section, Categories.SectionLabel(item.section))
	end
	return {
		list = list,
		selected = selected,
		counts = Data.counts,
		free = Data.free,
		items = Data.Count(),
		rows = #body,
		shown = win ~= nil and win:IsShown(),
		controls = controls,
	}
end
