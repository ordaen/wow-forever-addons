-- Ordaen Bags, the window (the user's design, 2026-11-07): an OrdaenCore.UI window with the search box, Blizzard's
-- sort and a close button at the top, the category tabs down the left with their counts, the chosen tab's items in
-- sections (a caption over a grid of slots, by item subclass), and the free slots and money at the bottom. The
-- framework draws a cell per item; Blizzard's own item buttons (Slots.lua) sit over the cells after each draw.
--
-- Cost: the window and its blocks are made on the first open, then changed in place. Its events (bag updates,
-- locks, cooldowns, search, money) are registered only while it is open. A scan reads every slot once per
-- BAG_UPDATE_DELAYED (the game's own calls return a table per slot; nothing else is made).
local _, ns = ...

local UI = OrdaenCore.UI
local Categories, Data, Slots = ns.Categories, ns.Data, ns.Slots

local View = {}
ns.View = View

local SLOT = 37 -- Blizzard's item button

local win ---@type OrdaenUIWindow|nil
-- The tabs and the items each on their own surface (embedded in the window): only a surface's root block wears
-- Blizzard's art, so a nested inset would draw nothing. The slots sit on the items pane's frame.
local sidebar ---@type OrdaenUIComponent|nil
local itemsPane ---@type OrdaenUIComponent|nil
local selected = "all" -- the tab shown (not saved: the window opens on all items)

-- blocks, made once (build)
local tabButtons = {} ---@type table<string, OrdaenUIComponent> tab id -> its button
local tabTexts = {} ---@type table<string, table> tab id -> its label element ({ format, args = { label, count } })
-- the sections of the shown tab: the items pane's block, in Blizzard's inset (as the tabs beside it)
local content = { style = "inset", columns = { "auto" }, gap = "md", padding = "md" }
local sections = {} -- pool: { caption, grid } blocks
local cells = {} -- pool of slot cells, the first `cellsUsed` in use
local cellsUsed = 0
local cellItem = {} ---@type table<table, OrdaenBagsItem> cell -> the item drawn there
local groups = {} ---@type OrdaenBagsGroup[]
local freeText = { format = NUM_FREE_SLOTS, args = { 0 }, style = "label" }
local moneyText = { text = "", align = "right" }
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

local function columns()
	local db = ns.Addon.db
	return db and db.columns or 10
end

-- The bags ----------------------------------------------------------------------------------------------------------

local function scan()
	Data.Reset()
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS + (NUM_REAGENTBAG_SLOTS or 0) do
		local reagent = bag > NUM_BAG_SLOTS
		Data.AddFree(C_Container.GetContainerNumFreeSlots(bag) or 0, reagent)
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
				local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
				local isQuest = quest ~= nil and (quest.isQuestItem == true or quest.questID ~= nil)
				local item = Data.Add(bag, slot, classID, subClassID, info.quality, isQuest)
				item.texture, item.count, item.link = info.iconFileID, info.stackCount or 1, info.hyperlink
				item.bound, item.locked = info.isBound == true, info.isLocked == true
				item.noValue, item.filtered = info.hasNoValue == true, info.isFiltered == true
				item.questID, item.questActive = quest and quest.questID, quest ~= nil and quest.isActive == true
			end
		end
	end
end

local function updateMoney()
	moneyText.text = GetMoneyString(GetMoney(), true)
end

-- The shown tab's sections: a caption and a grid of cells per section; Blizzard's buttons follow on render.
local function layout()
	if not win then
		return
	end
	local across = columns()
	local n = Data.Group(selected, groups)
	Slots.HideAll()
	local used = 0
	for i = 1, n do
		local group = groups[i]
		local section = sections[i]
		if not section then
			local caption = { text = "", style = "label" }
			local grid = { gap = 2, padding = 0 }
			section = { columns = { "auto" }, gap = "xs", caption = caption, grid = grid, caption, grid }
			sections[i] = section
		end
		section.caption.text = Categories.SectionLabel(group.section)
		local grid = section.grid
		grid.columns = columnsOf(math.min(across, group.n))
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
		content[i] = section
	end
	for i = #content, n + 1, -1 do
		content[i] = nil
	end
	cellsUsed = used
	for _, tab in ipairs(Categories.TABS) do
		tabTexts[tab.id].args[2] = Data.counts[tab.id]
		local button = tabButtons[tab.id]
		if tab.id == selected then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
	end
	freeText.args[1] = Data.free.bags
	for _, tab in ipairs(Categories.TABS) do
		tabButtons[tab.id]:Refresh()
	end
	sidebar:Refresh()
	itemsPane:Refresh() -- draws the cells: its render places the buttons
	win:Refresh() -- the panes' new sizes
end

local waitingForCombat = false

-- Drawn: Blizzard's button over each cell (made now if new; in combat a new one waits for it to end).
local function onRender()
	if not itemsPane then
		return
	end
	local frame = itemsPane.frame
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
				button:Show()
			elseif not waitingForCombat then
				waitingForCombat = true
				ns.Addon:AfterCombat(function()
					waitingForCombat = false
					layout()
				end)
			end
		end
	end
end

-- Events while the window is open -----------------------------------------------------------------------------------

local function onBagsChanged()
	scan()
	layout()
end

local function onLock(_, bag, slot)
	if not slot then
		return -- an equipped item's slot
	end
	Slots.EachShown(function(button, item)
		if item.bag == bag and item.slot == slot then
			local info = C_Container.GetContainerItemInfo(bag, slot)
			item.locked = info ~= nil and info.isLocked == true
			SetItemButtonDesaturated(button, item.locked)
		end
	end)
end

local function updateCooldown(button, item)
	button:UpdateCooldown(item.texture)
end

local function onCooldowns()
	Slots.EachShown(updateCooldown)
end

local function updateSearch(button, item)
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

-- Building the window (first open) ---------------------------------------------------------------------------------

local function onSearch(_, text)
	C_Container.SetItemSearch(text or "")
end

local function onSort()
	C_Container.SortBags()
end

local function onClose()
	View.Close()
end

local function onHidden()
	listen(false)
	Slots.HideAll()
	ns.Takeover.WindowHidden()
end

local function build()
	local search = UI.Input({ name = "OrdaenBagsSearch", width = 160, placeholder = SEARCH, on = { change = onSearch } })
	local sort = UI.Button({ style = "pushButton", on = { click = onSort }, { text = BAG_CLEANUP_BAGS } })
	local close = UI.Button({ style = "closeButton", width = 28, height = 28, on = { click = onClose } })
	if not (search and sort and close) then
		return false -- OrdaenCore_UI can't load (the player was told)
	end
	local tabs = { style = "inset", columns = { "auto" }, gap = "xs", padding = "sm" } -- the sidebar's block
	for i, tab in ipairs(Categories.TABS) do
		local label = { format = "%s (%d)", args = { _G[tab.label] or tab.id, 0 } }
		tabTexts[tab.id] = label
		local id = tab.id
		local button = UI.Button({ padding = "xs", on = {
			click = function()
				selected = id
				layout()
			end,
		}, label })
		if not button then
			return false
		end
		tabButtons[tab.id] = button
		tabs[i] = { embed = button }
	end
	sidebar, itemsPane = UI.Block(tabs), UI.Block(content)
	if not (sidebar and itemsPane) then
		return false
	end
	local header = {
		colSpan = 2, columns = { "auto", "1fr", "auto", "auto" }, gap = "sm", rowAlign = "center",
		{ text = INVENTORY_TOOLTIP, style = "title" },
		{ embed = search, align = "right" },
		{ embed = sort },
		{ embed = close },
	}
	local footer = { colSpan = 2, columns = { "1fr", "auto" }, gap = "md", freeText, moneyText }
	win = UI.Window({
		-- the tabs as wide as their labels, the items pane takes the rest; room inside the window's frame
		name = "OrdaenBagsWindow", columns = { "auto", "1fr" }, gap = "md", padding = { 28, "lg", "lg", "lg" },
		header, { embed = sidebar }, { embed = itemsPane }, footer,
	}, { point = "BOTTOMRIGHT", x = -80, y = 120 })
	if not win then
		return false
	end
	itemsPane:On("render", onRender)
	win.frame:HookScript("OnHide", onHidden)
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

--- The settings changed (slots per row): lay out again if open.
function View.Relayout()
	if win and win:IsShown() then
		layout()
	end
end

--- Dev-mode state (Send state): the tab, the counts, the window's place.
---@return table
function View.Dump()
	return {
		selected = selected,
		counts = Data.counts,
		free = Data.free,
		items = Data.Count(),
		sections = #content,
		shown = win ~= nil and win:IsShown(),
	}
end
