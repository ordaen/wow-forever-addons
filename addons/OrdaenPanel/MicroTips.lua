-- Ordaen Panel: richer tooltips for the game menu buttons the panel holds. Like a spell tooltip in Ordaen Tooltips:
-- the title, up to three key numbers in columns (value over caption), rows of "name: value" (attributes, points per
-- talent tree), up to three lines of text, the key at the bottom. Buttons without anything to add (Spellbook, Legacy,
-- Shop, Help, the game menu) keep Blizzard's tooltip, and so does any button while it is greyed out or has nothing
-- to show (no guild, not in a queue).
--
-- Cost: nothing until a button is hovered; then one read of the game's state.
local _, ns = ...

local UI = OrdaenCore.UI
local L = ns.L

local MicroTips = {}
ns.MicroTips = MicroTips

-- The tooltip: built once, fields change per hover. ---------------------------------------------------------------

local title = { text = "", style = "title" }
-- The same sections as a spell tooltip in Ordaen Tooltips (OrdaenCore.UI): key numbers in columns (value over
-- caption), rows of name and value (Strength 120; Fury 21), then a few lines of text. Each sits the theme's section
-- gap below the one before.
local stats = UI.Stats(3)
local rows = UI.Rows(6)
local lines = {}
for i = 1, 3 do
	lines[i] = { text = "", hidden = true }
end
local textBlock = { style = "section", columns = { "auto" }, gap = "xs", hidden = true, lines[1], lines[2], lines[3] }
local tip = UI.Tooltip({ columns = { "auto" }, gap = 0, title, stats, rows, textBlock }, { side = "above" })

local textLines = 0

local function reset()
	stats:Clear()
	rows:Clear()
	textLines = 0
	for i = 1, 3 do
		lines[i].hidden = true
	end
	textBlock.hidden = true
end

local function row(name, value)
	if name then
		rows:Add(name, value)
	end
end

local function line(text)
	if textLines >= 3 or not text or text == "" then
		return
	end
	textLines = textLines + 1
	lines[textLines].text = text
	lines[textLines].hidden = false
	textBlock.hidden = false
end

local function finish()
	return stats.shown > 0 or rows.shown > 0 or textLines > 0
end

-- Per button: fill the tooltip; false = nothing to add (Blizzard's tooltip stays). ---------------------------------

local function character()
	local _, equipped = GetAverageItemLevel()
	if equipped and equipped > 0 then
		stats:Add(equipped, STAT_AVERAGE_ITEM_LEVEL, "%.1f")
	end
	local lowest, worstSlot = nil, nil
	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local current, maximum = GetInventoryItemDurability(slot)
		if current and maximum and maximum > 0 then
			local percent = current / maximum * 100
			if not lowest or percent < lowest then
				lowest, worstSlot = percent, slot
			end
		end
	end
	if lowest then
		stats:Add(math.floor(lowest + 0.5), DURABILITY, "%d%%")
	end
	-- the attributes, as the character sheet shows them (with buffs)
	row(SPELL_STAT1_NAME, select(2, UnitStat("player", 1)))
	row(SPELL_STAT2_NAME, select(2, UnitStat("player", 2)))
	row(SPELL_STAT3_NAME, select(2, UnitStat("player", 3)))
	row(SPELL_STAT4_NAME, select(2, UnitStat("player", 4)))
	row(SPELL_STAT5_NAME, select(2, UnitStat("player", 5)))
	if lowest and lowest < 50 then
		local link = GetInventoryItemLink("player", worstSlot)
		line(link and L.MT_MOST_WORN:format(link, math.floor(lowest + 0.5)))
	end
	return finish()
end

local function professions()
	local list = { GetProfessions() } -- on hover only
	for i = 1, 5 do
		local index = list[i]
		if index then
			local name, _, rank, maxRank = GetProfessionInfo(index)
			if name then
				stats:Add(string.format("%d/%d", rank or 0, maxRank or 0), name)
			end
		end
	end
	return finish()
end

-- Forever's talents: the class has one "specialization" (the class itself), so the trees (Arms, Fury, Protection) come
-- from the trait system: the active config's tree, its nodes, the points bought in each, summed per sub-tree. The
-- game's documentation doesn't list these structures' fields, so they're read defensively and logged (dev mode):
-- what Forever really gives decides the next step.
local spentBySubTree, subTreeOrder = {}, {}

local function talents()
	local _, classPoints, specPoints = C_ClassTalents.HasUnspentTalentPoints()
	stats:Add((classPoints or 0) + (specPoints or 0), L.MT_UNSPENT)
	local configID = C_ClassTalents.GetActiveConfigID()
	if not configID then
		return finish() -- no talents yet (below level 10)
	end
	local config = C_Traits.GetConfigInfo(configID)
	local treeID = config and config.treeIDs and config.treeIDs[1]
	for k in pairs(spentBySubTree) do
		spentBySubTree[k] = nil
	end
	for i = #subTreeOrder, 1, -1 do
		subTreeOrder[i] = nil
	end
	local nodes, loose = treeID and C_Traits.GetTreeNodes(treeID) or {}, 0
	for _, nodeID in ipairs(nodes) do
		local node = C_Traits.GetNodeInfo(configID, nodeID)
		local ranks = node and (node.ranksPurchased or node.currentRank) or 0
		if ranks > 0 then
			local sub = node.subTreeID
			if sub then
				if not spentBySubTree[sub] then
					spentBySubTree[sub] = 0
					subTreeOrder[#subTreeOrder + 1] = sub
				end
				spentBySubTree[sub] = spentBySubTree[sub] + ranks
			else
				loose = loose + ranks
			end
		end
	end
	table.sort(subTreeOrder)
	for _, sub in ipairs(subTreeOrder) do
		local info = C_Traits.GetSubTreeInfo(configID, sub)
		row(info and info.name or tostring(sub), spentBySubTree[sub])
	end
	local Debug = ns.Addon.Debug
	if Debug:IsEnabled() then
		local currencies = {}
		for _, c in ipairs(treeID and C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
			currencies[#currencies + 1] = string.format("%s: %s spent of %s", tostring(c.traitCurrencyID),
				tostring(c.spent), tostring(c.maxQuantity))
		end
		Debug:Logf("micro tip talents: config %s, tree %s, %d nodes, %d sub-trees, %d ranks outside them; currencies %s",
			tostring(configID), tostring(treeID), #nodes, #subTreeOrder, loose, table.concat(currencies, "; "))
		-- where Forever keeps Arms / Fury / Protection: node groups, or columns of one tree (dev probe)
		local function fields(t)
			local out = {}
			for k, v in pairs(type(t) == "table" and t or {}) do
				out[#out + 1] = tostring(k) .. "=" .. (type(v) == "table" and ("{" .. table.concat(v, ",") .. "}")
					or tostring(v))
			end
			table.sort(out)
			return table.concat(out, " ")
		end
		for i, group in ipairs(treeID and C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
			Debug:Logf("micro tip talents: group %d: %s", i, fields(group))
		end
		for _, nodeID in ipairs(nodes) do
			local node = C_Traits.GetNodeInfo(configID, nodeID)
			if node and (node.ranksPurchased or 0) > 0 then
				Debug:Logf("micro tip talents: node %d ranks %d posX %s posY %s groups {%s} subTree %s", nodeID,
					node.ranksPurchased, tostring(node.posX), tostring(node.posY),
					table.concat(node.groupIDs or {}, ","), tostring(node.subTreeID))
			end
		end
		local xs = {}
		for _, nodeID in ipairs(nodes) do
			local node = C_Traits.GetNodeInfo(configID, nodeID)
			if node and node.posX then
				xs[#xs + 1] = node.posX
			end
		end
		table.sort(xs)
		Debug:Logf("micro tip talents: node posX from %s to %s", tostring(xs[1]), tostring(xs[#xs]))
	end
	return finish()
end

local function questLog()
	local _, quests = C_QuestLog.GetNumQuestLogEntries()
	local ready = 0
	for i = 1, (C_QuestLog.GetNumQuestLogEntries()) do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID and C_QuestLog.ReadyForTurnIn(info.questID) then
			ready = ready + 1
			line(L.MT_READY_QUEST:format(info.title or ""))
		end
	end
	stats:Add(string.format("%d/%d", quests or 0, C_QuestLog.GetMaxNumQuestsCanAccept() or 0), L.MT_QUESTS)
	stats:Add(ready, L.MT_READY)
	stats:Add(C_QuestLog.GetNumQuestWatches() or 0, L.MT_TRACKED)
	return finish()
end

local function guild()
	if not IsInGuild() then
		return false
	end
	local total, online = GetNumGuildMembers()
	local _, rankName = GetGuildInfo("player")
	stats:Add(online or 0, L.MT_ONLINE)
	stats:Add(total or 0, L.MT_MEMBERS)
	if rankName then
		stats:Add(rankName, L.MT_RANK)
	end
	line(GetGuildRosterMOTD())
	return finish()
end

local function minutes(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function groupFinder()
	local category = LE_LFG_CATEGORY_LFD
	if GetLFGMode(category) ~= "queued" then
		return false
	end
	-- (hasData, ..., instanceName [11], averageWait [12], ..., myWait [16], queuedTime [17])
	local instanceName = select(11, GetLFGQueueStats(category))
	local myWait, queuedTime = select(16, GetLFGQueueStats(category))
	stats:Add(minutes(queuedTime and (GetTime() - queuedTime)), L.MT_IN_QUEUE)
	if myWait and myWait > 0 then
		stats:Add(minutes(myWait), L.MT_WAIT)
	end
	line(instanceName)
	return finish()
end

local function collections()
	local mounts = 0
	for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do -- on hover only
		if select(11, C_MountJournal.GetMountInfoByID(id)) then
			mounts = mounts + 1
		end
	end
	stats:Add(mounts, L.MT_MOUNTS)
	local _, pets = C_PetJournal.GetNumPets()
	stats:Add(pets or 0, L.MT_PETS)
	stats:Add(C_ToyBox.GetNumLearnedDisplayedToys() or 0, L.MT_TOYS)
	return finish()
end

local PROVIDERS = {
	CharacterMicroButton = character,
	ProfessionMicroButton = professions,
	TalentMicroButton = talents,
	QuestLogMicroButton = questLog,
	GuildMicroButton = guild,
	LFDMicroButton = groupFinder,
	CollectionsMicroButton = collections,
}

-- Showing and hiding ----------------------------------------------------------------------------------------------

local current ---@type table|nil the button whose tooltip is ours now

-- Blizzard's title without its key ("Quest Log |cffffd200(L)|r" -> "Quest Log"); the key goes to the bottom.
local function titleOf(button)
	local text = rawget(button, "tooltipText")
	if type(text) ~= "string" then
		return button:GetName() or ""
	end
	return (text:gsub("%s*|c%x%x%x%x%x%x%x%x%(.-%)|r%s*$", ""))
end

local function fill(button)
	reset()
	local provider = PROVIDERS[button:GetName() or ""]
	return provider and provider() or false
end

local function onEnter(button)
	local view = ns.View
	if not (view and view.Holds(button)) then
		return -- given back (game menu off): Blizzard's tooltip, as before
	end
	if not button:IsEnabled() then
		return -- greyed out: Blizzard's tooltip says why (level, locked)
	end
	local name = button:GetName() or ""
	local ok, filled = pcall(fill, button)
	if not ok then
		ns.Addon.Debug:Warnf("micro tip %s: %s", name, tostring(filled))
		return
	end
	if not filled then
		return
	end
	title.text = titleOf(button)
	local command = rawget(button, "commandName")
	tip.hotkey = type(command) == "string" and UI.Binding(command) or nil
	GameTooltip:Hide()
	current = button
	tip:Show(button)
end

local function onLeave(button)
	if current == button then
		current = nil
		tip:Hide(button)
	end
end

local hooked = {}

--- A micro button the panel holds: our tooltip on hover where we have one (Blizzard's otherwise). Once per button.
---@param button table
function MicroTips.Attach(button)
	if hooked[button] or not PROVIDERS[button:GetName() or ""] then
		return
	end
	hooked[button] = true
	button:HookScript("OnEnter", onEnter)
	button:HookScript("OnLeave", onLeave)
end
