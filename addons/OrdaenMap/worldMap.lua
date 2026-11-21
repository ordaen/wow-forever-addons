-- Blizzard's `WorldMapFrame`, the frame OpenMap hosts in, read for Ordaen Map (declared in worldMap.d.luna). Nothing is
-- written to Blizzard's map: its scripts are hooked, never replaced, and no size, point or attribute of it is set (a
-- value an addon writes into the panel's code taints closing the map in a fight).
local name = ...

local worldMap = {}
-- The client's globals as the runtime reads them (the game's `_G`).
local client = LunaType.client

local function frame()
	local found = client.WorldMapFrame
	if type(found) == "table" and found.GetCanvas then return found end
	return nil
end

function worldMap.canvas()
	local map = frame()
	return map and map:GetCanvas() or nil
end

function worldMap.shownMap()
	local map = frame()
	if not map or not map:IsShown() then return 0 end
	return map:GetMapID() or 0
end

-- The one listener, and whether the hooks are in place: a hook can't be taken off, so it calls whoever listens now.
local listener = nil
local hooked = false

local function heard()
	if listener then listener() end
end

function worldMap.listen(run)
	listener = run
	local map = frame()
	if map and not hooked then
		hooked = true
		map:HookScript("OnShow", heard)
		map:HookScript("OnHide", heard)
		client.hooksecurefunc(map, "OnMapChanged", heard)
		local log = map.QuestLog
		if type(log) == "table" and log.HookScript then
			log:HookScript("OnShow", heard)
			log:HookScript("OnHide", heard)
			log:HookScript("OnSizeChanged", heard)
		end
	end
end

-- The map's side panel (`WorldMapFrame.QuestLog`) while it shows, and its size in UI units; nil and 0 while it doesn't.
function worldMap.sidePanel()
	local map = frame()
	local log = map and map.QuestLog
	if type(log) ~= "table" or not log.IsVisible or not log:IsVisible() then return nil, 0, 0 end
	return log, log:GetWidth(), log:GetHeight()
end

function worldMap.forget()
	listener = nil
end

-- Blizzard's quest pins (its `QuestDataProvider`, pins `QuestPinTemplate`) of every quest but one while that one is
-- shown on the map (0: none). Its provider makes its pins again as the map shows or turns: they are hidden after each
-- time (its `RefreshAllData` hooked, never replaced), and those hidden shown again as the one is let go. Nothing but a
-- pin's visibility is touched.
local onlyQuest = 0
local hiddenPins = {}
local pinsHooked = false

local function hideOthers()
	hiddenPins = {}
	local map = frame()
	if not map or onlyQuest == 0 then return end
	for pin in map:EnumeratePinsByTemplate("QuestPinTemplate") do
		if pin.questID ~= onlyQuest and pin:IsShown() then
			pin:Hide()
			hiddenPins[#hiddenPins + 1] = pin
		end
	end
end

function worldMap.onlyQuest(quest)
	local map = frame()
	if not map then return end
	if not pinsHooked and type(map.dataProviders) == "table" then
		for provider in pairs(map.dataProviders) do
			if type(provider) == "table" and provider.GetPinTemplate and provider:GetPinTemplate() == "QuestPinTemplate" then
				client.hooksecurefunc(provider, "RefreshAllData", hideOthers)
				pinsHooked = true
			end
		end
	end
	if quest == onlyQuest then return end
	for _, pin in ipairs(hiddenPins) do pin:Show() end
	onlyQuest = quest
	hideOthers()
end

function worldMap.tip(owner, lines)
	client.GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	for i, line in ipairs(lines) do
		if i == 1 then
			client.GameTooltip:AddLine(line, 1, 1, 1)
		else
			client.GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
		end
	end
	client.GameTooltip:Show()
end

function worldMap.untip()
	client.GameTooltip:Hide()
end

-- Ordaen's section of a dungeon's card in OpenMap: `run(mapID, names)` gives its title and lines as one list (none
-- for no section), which OpenMap takes as a title and a list.
function worldMap.dungeonSection(run)
	client.OpenMapAPI.RegisterDungeonSection("OrdaenMap", function(info)
		local names = {}
		for i, instance in ipairs(info.instances or {}) do names[i] = instance.name end
		local said = run(info.mapID or 0, names)
		if #said == 0 then return nil end
		local lines = {}
		for i = 2, #said do lines[i - 1] = said[i] end
		return said[1], lines
	end)
end

function worldMap.noDungeonSection()
	client.OpenMapAPI.RegisterDungeonSection("OrdaenMap", nil)
end

-- OpenMap's townsfolk (vendors, trainers, rares, mailboxes) from QuestieDB's NPCs and objects, in Questie's shape, so
-- they stay where Questie is off; the zone of an area by `maps` (Map's generated table). Contract 4 of it, as the
-- caller has checked.
function worldMap.townsfolk(maps)
	local db = client.LibQuestieDB
	-- Its entities by name (`LibQuestieDB.Npc`), as its API sets them.
	local npcs, objects = db.Npc, db.Object
	client.OpenMapAPI.RegisterTownsfolkProvider("OrdaenMap", {
		db = {
			NPCPointers = npcs.GetAllIds(true),
			npcFlags = db.Enum.npcFlags,
			QueryNPCSingle = function(id, field) return npcs.Get(id, field) end,
			QueryObjectSingle = function(id, field) return objects.Get(id, field) end,
		},
		zones = { GetUiMapIdByAreaId = function(_, area) return maps[area] end },
	})
end

function worldMap.noTownsfolk()
	client.OpenMapAPI.RegisterTownsfolkProvider("OrdaenMap", nil)
end

LunaType.addon(name)["worldMap"] = worldMap
