-- Ordaen Bags, the model: every item in the bags (from a scan, Window.lua) with its tab and section, the count per
-- tab, and a tab's items grouped in sections (ordered by Categories.SectionOf). Pure: the scan hands in what the
-- game says about each slot, so specs drive it.
--
-- Cost: records, groups and lists are reused tables; a scan and a grouping make no new tables once the pools are
-- as big as the bags.
local _, ns = ...

local Categories = ns.Categories

local Data = {}
ns.Data = Data

--- One item in the bags, as the last scan saw it (reused between scans).
---@class OrdaenBagsItem
---@field bag number
---@field slot number
---@field tab string Categories.TabOf
---@field section number Categories.SectionOf
---@field texture number|string|nil
---@field count number
---@field quality number|nil
---@field link string|nil
---@field bound boolean
---@field locked boolean
---@field noValue boolean
---@field filtered boolean the game's search doesn't match it (C_Container.SetItemSearch)
---@field quest boolean
---@field questID number|nil
---@field questActive boolean

--- A section of a tab: its id (Categories.SectionOf) and its items, in scan order (bag, then slot).
---@class OrdaenBagsGroup
---@field section number
---@field n number items in it
---@field [integer] OrdaenBagsItem

local items = {} ---@type OrdaenBagsItem[] reused records, the first `count` are live
local count = 0
local counts = {} ---@type table<string, number> tab id -> items in it ("all": every item)
Data.counts = counts
local free = { bags = 0, reagent = 0 } -- free slots: the bags, and the reagent bag
Data.free = free

--- Start a scan: no items, every tab empty.
function Data.Reset()
	count = 0
	for _, tab in ipairs(Categories.TABS) do
		counts[tab.id] = 0
	end
	free.bags, free.reagent = 0, 0
end

--- Count free slots of one bag (reagent: the reagent bag's).
---@param n number
---@param reagent boolean
function Data.AddFree(n, reagent)
	if reagent then
		free.reagent = free.reagent + n
	else
		free.bags = free.bags + n
	end
end

--- Add the item in one slot (the scan calls this for every slot that holds one). Returns its record, for the scan
--- to fill in the fields the window draws (texture, count, quality, ...).
---@param bag number
---@param slot number
---@param classID number|nil
---@param subClassID number|nil
---@param quality number|nil
---@param isQuest boolean|nil
---@return OrdaenBagsItem
function Data.Add(bag, slot, classID, subClassID, quality, isQuest)
	count = count + 1
	local item = items[count]
	if not item then
		item = {}
		items[count] = item
	end
	item.bag, item.slot, item.quality, item.quest = bag, slot, quality, isQuest == true
	item.tab = Categories.TabOf(classID, quality, isQuest)
	item.section = Categories.SectionOf(classID, subClassID)
	counts[item.tab] = counts[item.tab] + 1
	counts.all = counts.all + 1
	return item
end

---@return number items found by the last scan
function Data.Count()
	return count
end

---@param i number 1 .. Data.Count()
---@return OrdaenBagsItem
function Data.Item(i)
	return items[i]
end

local pool = {} ---@type OrdaenBagsGroup[] groups, reused
local bySection = {} -- section -> its group, for the grouping running now

local function sectionOrder(a, b)
	return a.section < b.section
end

--- A tab's items in sections, ordered by section: fills `out` (out[1..n], the rest cleared) and returns n.
---@param tab string a tab id ("all": every item)
---@param out OrdaenBagsGroup[] reused by the caller
---@return number n sections
function Data.Group(tab, out)
	for key in pairs(bySection) do
		bySection[key] = nil
	end
	local n = 0
	for i = 1, count do
		local item = items[i]
		if tab == "all" or item.tab == tab then
			local group = bySection[item.section]
			if not group then
				n = n + 1
				group = pool[n]
				if not group then
					group = { section = 0, n = 0 }
					pool[n] = group
				end
				group.section, group.n = item.section, 0
				bySection[item.section] = group
				out[n] = group
			end
			group.n = group.n + 1
			group[group.n] = item
		end
	end
	for i = #out, n + 1, -1 do
		out[i] = nil
	end
	table.sort(out, sectionOrder)
	return n
end
