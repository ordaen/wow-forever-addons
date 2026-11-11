-- Made by lunatype from OrdaenTooltips/quests.luna: change the source, not this file.
local R = LunaType
local __insert = table.insert
local __OrdaenTooltips_text_clean = R.addon("OrdaenTooltips")["text"].clean
local __OrdaenTooltips_colors_GOLD = R.addon("OrdaenTooltips")["colors"].GOLD
local __string_toNumber = R.string.toNumber
local __OrdaenTooltips_colors_GREEN = R.addon("OrdaenTooltips")["colors"].GREEN
local __OrdaenTooltips_model_named = R.addon("OrdaenTooltips")["model"].named
local M = {}
R.addon("OrdaenTooltips")["quests"] = M
local QUEST_TITLE, QUEST_OBJECTIVE, QUEST_PLAYER, quests
QUEST_TITLE = 17
QUEST_OBJECTIVE = 8
QUEST_PLAYER = 18

function quests(lines, party)
	local rows = {}
	local member = nil
	for __i1 = 1, #lines do
		local line = lines[__i1]
		repeat
			local text = __OrdaenTooltips_text_clean(line.left)
			if text == nil then
				break
			end
			if line.kind == 17 then
				member = nil
				__insert(rows, { left = text, color = __OrdaenTooltips_colors_GOLD, opens = "None" })
			elseif line.kind == 18 then
				member = text
			elseif line.kind == 8 then
				local have, need = (text):match("(%d+)%s*/%s*(%d+)")
				local label = ((((text):gsub("%s*:?%s*%d+%s*/%s*%d+%s*", ""))):gsub("^%s*%-%s*", ""))
				local counted = have ~= nil and need ~= nil and (__string_toNumber(have) or 0) >= (__string_toNumber(need) or 0)
				local done = line.completed == true or counted
				local __t2
				if have ~= nil and need ~= nil then
					__t2 = have .. "/" .. need
				else
					__t2 = nil
				end
				local value = __t2
				if member == nil then
					local __t3
					if done then
						__t3 = __OrdaenTooltips_colors_GREEN
					else
						__t3 = nil
					end
					__insert(rows, { left = label, right = value, rightColor = __t3, opens = __OrdaenTooltips_model_named("quest") })
				elseif party then
					local __t4
					if done then
						__t4 = __OrdaenTooltips_colors_GREEN
					else
						__t4 = nil
					end
					__insert(rows, { left = member, right = value, rightColor = __t4, indent = true, opens = __OrdaenTooltips_model_named("quest") })
				end
			end
		until true
	end
	return rows
end

M.QUEST_TITLE = QUEST_TITLE
M.QUEST_OBJECTIVE = QUEST_OBJECTIVE
M.QUEST_PLAYER = QUEST_PLAYER
M.quests = quests
