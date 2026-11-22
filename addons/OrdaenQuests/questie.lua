-- QuestieDB's public API, read for Ordaen Quests (declared in questie.d.luna). QuestieDB is GPLv3: it is called from
-- the player's own install through `_G.LibQuestieDB`, and nothing of its code or data is copied here. Each `Get` of a
-- table field is a fresh copy (its value contract): a quest's facts are read once and kept by the caller.
local name = ...

local questie = {}

-- Spots kept of one NPC or object, and NPCs or objects kept of one list: a creature with hundreds of spawns, an item
-- dropped by dozens, stay bounded.
local SPOTS_MOST = 40
local FIGURES_MOST = 12


-- Its spawns `{ [area] = { { x, y }, ... } }`, 0 to 100, as spots 0 to 1.
local function spotsOf(spawns)
	local spots = {}
	if type(spawns) ~= "table" then return spots end
	for area, points in pairs(spawns) do
		if type(area) == "number" and area > 0 and type(points) == "table" then
			for _, point in ipairs(points) do
				if #spots >= SPOTS_MOST then return spots end
				local x, y = point[1], point[2]
				if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 then
					spots[#spots + 1] = { area = area, x = x / 100, y = y / 100 }
				end
			end
		end
	end
	return spots
end

-- An NPC or an object (`kind`: "npc", "object"), its name in the client's language where QuestieDB has it.
local function figureOf(db, kind, id)
	if type(id) ~= "number" or not db.Exists(id) then return nil end
	local named = db.Get(id, "name")
	return { id = id, kind = kind, name = type(named) == "string" and named or "", spots = spotsOf(db.Get(id, "spawns")) }
end

local function addFigures(into, db, kind, ids)
	if type(ids) ~= "table" then return end
	for _, id in ipairs(ids) do
		if #into >= FIGURES_MOST then return end
		local figure = figureOf(db, kind, id)
		if figure then into[#into + 1] = figure end
	end
end

-- Each entry of an objective's list is `{ id, text? }`.
local function addTargets(into, db, kind, list)
	if type(list) ~= "table" then return end
	for _, entry in ipairs(list) do
		if type(entry) == "table" then addFigures(into, db, kind, { entry[1] }) end
	end
end

-- Its objectives' text `{ line, ... }` as one paragraph.
local function taskOf(lines)
	if type(lines) ~= "table" then return "" end
	local kept = {}
	for _, line in ipairs(lines) do
		if type(line) == "string" and line ~= "" then kept[#kept + 1] = line end
	end
	return table.concat(kept, " ")
end

-- Its reputation rewards `{ { faction, amount }, ... }`.
local function reputationOf(list)
	local gains = {}
	if type(list) ~= "table" then return gains end
	for _, pair in ipairs(list) do
		if type(pair) == "table" and type(pair[1]) == "number" and type(pair[2]) == "number" and pair[2] ~= 0 then
			gains[#gains + 1] = { faction = pair[1], amount = pair[2] }
		end
	end
	return gains
end

function questie.quest(id)
	local found = _G.LibQuestieDB
	local quests, npcs, objects, items = found.Quest, found.Npc, found.Object, found.Item
	if not quests.Exists(id) then return nil end
	local givers, takers, targets, wanted = {}, {}, {}, {}
	local starts = quests.Get(id, "startedBy")
	if type(starts) == "table" then
		addFigures(givers, npcs, "npc", starts[1])
		addFigures(givers, objects, "object", starts[2])
	end
	local ends = quests.Get(id, "finishedBy")
	if type(ends) == "table" then
		addFigures(takers, npcs, "npc", ends[1])
		addFigures(takers, objects, "object", ends[2])
	end
	local objectives = quests.Get(id, "objectives")
	if type(objectives) == "table" then
		addTargets(targets, npcs, "npc", objectives[1])
		addTargets(targets, objects, "object", objectives[2])
		if type(objectives[3]) == "table" then
			for _, entry in ipairs(objectives[3]) do
				local item = type(entry) == "table" and entry[1]
				if type(item) == "number" and items.Exists(item) then
					local named = items.Get(item, "name")
					if type(named) == "string" and named ~= "" then wanted[#wanted + 1] = { id = item, name = named } end
					addFigures(targets, npcs, "npc", items.Get(item, "npcDrops"))
					addFigures(targets, objects, "object", items.Get(item, "objectDrops"))
				end
			end
		end
	end
	local title = quests.Get(id, "name")
	local level = quests.Get(id, "questLevel")
	local zone = quests.Get(id, "zoneOrSort")
	local next = quests.Get(id, "nextQuestInChain")
	local least = quests.Get(id, "requiredLevel")
	return {
		name = type(title) == "string" and title or "",
		level = type(level) == "number" and level or 0,
		minLevel = type(least) == "number" and least or 0,
		task = taskOf(quests.Get(id, "objectivesText")),
		zone = type(zone) == "number" and zone or 0,
		givers = givers,
		takers = takers,
		targets = targets,
		items = wanted,
		reputation = reputationOf(quests.Get(id, "reputationReward")),
		next = type(next) == "number" and next or 0,
		nextName = type(next) == "number" and next > 0 and type(quests.Get(next, "name")) == "string" and quests.Get(next, "name") or "",
	}
end

function questie.npc(id)
	return figureOf(_G.LibQuestieDB.Npc, "npc", id)
end

LunaType.addon(name)["questie"] = questie
