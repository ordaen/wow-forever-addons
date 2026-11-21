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

-- Blizzard's quest marks on its map, of the quest shown alone: its quest pins (its `QuestDataProvider`, pins
-- `QuestPinTemplate`) and its quest's shaded area (`QuestBlobDataProvider`, one `QuestBlobPinTemplate` pin, a
-- `QuestPOIFrame`). `quest` is the one shown (its area drawn: the map's focused quest); 0 for every quest's, as the
-- game has them. The providers make their pins again as the map shows or turns, and the area's pin draws again on its
-- own events: the others are hidden after each time (`RefreshAllData` and the pin's `Refresh` hooked, never replaced),
-- and shown again as the quest is let go. Nothing but a pin's visibility and the map's focused quest is touched.
local MARKS = { QuestPinTemplate = true, QuestBlobPinTemplate = true }
local onlyQuest = 0
local hiddenPins = {}
local hookedMarks = {}

local function hideOthers()
	local map = frame()
	if not map or onlyQuest == 0 then return end
	for template in pairs(MARKS) do
		for pin in map:EnumeratePinsByTemplate(template) do
			if pin.questID ~= onlyQuest and pin:IsShown() then
				pin:Hide()
				hiddenPins[pin] = true
			end
		end
	end
end

-- Whether the provider is one of the quest marks', told by the mixin it was made from. `GetPinTemplate` is asked of
-- no other provider: Blizzard's take what the pin is for (the vignettes' indexes its info and raises without it).
-- A client whose mixins are empty (the stand-in's) has the quest providers alone, which take nothing.
local PROVIDERS = { "QuestDataProviderMixin", "QuestBlobDataProviderMixin" }
local function marksProvider(provider)
	if type(provider) ~= "table" then return false end
	local known = false
	for _, name in ipairs(PROVIDERS) do
		local mixin = client[name]
		local refresh = type(mixin) == "table" and mixin.RefreshAllData
		if type(refresh) == "function" then
			known = true
			if provider.RefreshAllData == refresh then return true end
		end
	end
	if known or not provider.GetPinTemplate then return false end
	return MARKS[provider:GetPinTemplate()] == true
end

-- The providers' and the area pin's refreshes, each hooked once.
local function hookMarks(map)
	if type(map.dataProviders) ~= "table" then return end
	for provider in pairs(map.dataProviders) do
		if marksProvider(provider) and not hookedMarks[provider] then
			client.hooksecurefunc(provider, "RefreshAllData", hideOthers)
			hookedMarks[provider] = true
		end
	end
	for pin in map:EnumeratePinsByTemplate("QuestBlobPinTemplate") do
		if not hookedMarks[pin] and pin.Refresh then
			client.hooksecurefunc(pin, "Refresh", hideOthers)
			hookedMarks[pin] = true
		end
	end
end

function worldMap.onlyQuest(quest)
	local map = frame()
	if not map then return end
	hookMarks(map)
	if quest == onlyQuest then return end
	for pin in pairs(hiddenPins) do pin:Show() end
	hiddenPins = {}
	onlyQuest = quest
	if map.SetFocusedQuestID and map.ClearFocusedQuestID then
		if quest ~= 0 then map:SetFocusedQuestID(quest) else map:ClearFocusedQuestID() end
	end
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
