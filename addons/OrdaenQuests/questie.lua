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

-- A list of numbers, every one (a creature's tooltip asks by number, so none is left out), the rest dropped.
local function idsOf(list)
	local ids = {}
	if type(list) ~= "table" then return ids end
	for _, id in ipairs(list) do
		if type(id) == "number" then ids[#ids + 1] = id end
	end
	return ids
end

-- The numbers a mask holds, bit n (from 0) the number n + 1: QuestieDB's races and classes a quest is for, by the
-- client's race and class numbers; none for 0 or no mask (every one).
local function bitsOf(mask)
	local numbers = {}
	if type(mask) ~= "number" or mask <= 0 then return numbers end
	for n = 1, 32 do
		if bit.band(mask, bit.lshift(1, n - 1)) ~= 0 then numbers[#numbers + 1] = n end
	end
	return numbers
end

-- A requirement `{ id, amount }` (a faction and a standing, a skill line and a rank); nil for none.
local function pairOf(pair)
	if type(pair) ~= "table" or type(pair[1]) ~= "number" or type(pair[2]) ~= "number" then return nil end
	return { id = pair[1], amount = pair[2] }
end

-- QuestieDB's drop chances of the items quests ask for, `{ [item] = { [creature] = percent } }`: its support data
-- holds them as Lua text, read once a session on the first ask; false where it holds none or it doesn't read.
local chances
local function chancesOf(item)
	if chances == nil then
		chances = false
		local support = _G.LibQuestieDB.Support
		local drops = support and support.Get and support.Get("QuestieClassicItemDrops")
		local text = drops and drops.wowheadData
		if type(text) == "string" then
			local chunk = loadstring(text)
			local ok, read = false, nil
			if chunk then ok, read = pcall(chunk) end
			if ok and type(read) == "table" then chances = read end
		end
	end
	return chances and chances[item] or nil
end

-- The creatures that drop an item, each with its chance where QuestieDB has one (`{ creature, chance? }`).
local function sourcesOf(item, droppers)
	local known = chancesOf(item)
	local sources = {}
	for _, creature in ipairs(idsOf(droppers)) do
		local chance = known and known[creature]
		sources[#sources + 1] = { creature = creature, chance = type(chance) == "number" and chance or nil }
	end
	return sources
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
	local givers, takers, targets, wanted, drops = {}, {}, {}, {}, {}
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
					local droppers = items.Get(item, "npcDrops")
					addFigures(targets, npcs, "npc", droppers)
					drops[#drops + 1] = { item = item, name = type(named) == "string" and named or "", sources = sourcesOf(item, droppers) }
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
	local most = quests.Get(id, "requiredMaxLevel")
	return {
		name = type(title) == "string" and title or "",
		level = type(level) == "number" and level or 0,
		minLevel = type(least) == "number" and least or 0,
		maxLevel = type(most) == "number" and most or 0,
		races = bitsOf(quests.Get(id, "requiredRaces")),
		classes = bitsOf(quests.Get(id, "requiredClasses")),
		after = idsOf(quests.Get(id, "preQuestGroup")),
		afterAny = idsOf(quests.Get(id, "preQuestSingle")),
		exclusive = idsOf(quests.Get(id, "exclusiveTo")),
		minStanding = pairOf(quests.Get(id, "requiredMinRep")),
		maxStanding = pairOf(quests.Get(id, "requiredMaxRep")),
		skill = pairOf(quests.Get(id, "requiredSkill")),
		task = taskOf(quests.Get(id, "objectivesText")),
		zone = type(zone) == "number" and zone or 0,
		givers = givers,
		takers = takers,
		targets = targets,
		items = wanted,
		drops = drops,
		reputation = reputationOf(quests.Get(id, "reputationReward")),
		next = type(next) == "number" and next or 0,
		nextName = type(next) == "number" and next > 0 and type(quests.Get(next, "name")) == "string" and quests.Get(next, "name") or "",
	}
end

function questie.npc(id)
	return figureOf(_G.LibQuestieDB.Npc, "npc", id)
end

-- The quests an NPC gives and those it takes back, by their numbers; nil for an NPC QuestieDB doesn't know.
function questie.npcQuests(id)
	local npcs = _G.LibQuestieDB.Npc
	if type(id) ~= "number" or not npcs.Exists(id) then return nil end
	return { starts = idsOf(npcs.Get(id, "questStarts")), ends = idsOf(npcs.Get(id, "questEnds")) }
end

LunaType.addon(name)["questie"] = questie
