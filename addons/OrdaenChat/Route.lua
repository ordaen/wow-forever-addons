-- Messages split by whose they are: your crafting and openings (gathering, chests) in General, other players' in
-- Journal (the user's split, 2026-11-06). Blizzard puts a message type in a tab as a whole, so both tabs get these
-- types (TabLayout.lua) and a chat message filter hides the other half in each. Other tabs show them as Blizzard does.
-- Messages with secret values are left alone (shown).
-- Cost: two filters (registered once, at the first login of the "layout" feature); each returns at once for a chat
-- window other than General and Journal.
local _, ns = ...

local Route = {}
ns.Route = Route

-- All documented in api/forever/<CURRENT> (forever-lint FL1).
local SPLIT = { "CHAT_MSG_TRADESKILLS", "CHAT_MSG_OPENING" }

local myGUID, myName

-- A Lua pattern matching a line built from Blizzard's format string ("%s creates %s.", ruRU "%1$s создает: %2$s."):
-- the format's own placeholders match any text, everything else literally.
local PLACEHOLDER = "\1"
local function patternOf(format)
	if type(format) ~= "string" or format == "" then
		return nil
	end
	local p = format:gsub("%%%d*%$?[sd]", PLACEHOLDER)
	p = p:gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
	return "^" .. p:gsub(PLACEHOLDER, ".+") .. "$"
end

-- Crafting and opening lines carry no sender (name and GUID are empty, 2026-11-06): whose they are is in the text,
-- Blizzard's first or third person line. Built once, from the client's own strings (every language).
local textual -- event -> { mine = pattern, others = pattern }
local function patterns()
	if not textual then
		textual = {
			CHAT_MSG_TRADESKILLS = {
				mine = patternOf(TRADESKILL_LOG_FIRSTPERSON), others = patternOf(TRADESKILL_LOG_THIRDPERSON),
			},
			CHAT_MSG_OPENING = { mine = patternOf(OPEN_LOCK_SELF), others = patternOf(OPEN_LOCK_OTHER) },
		}
	end
	return textual
end

--- Whether a message is about the player: from its text for crafting and openings (Blizzard's first or third
--- person line), else its sender's GUID (payload 12) or name (payload 2, maybe with a realm). Secret parts count as
--- yours (shown where yours go).
---@param event string
---@param message string
---@param name any
---@param guid any
---@return boolean
function Route.IsMine(event, message, name, guid)
	if not myName then
		myGUID, myName = UnitGUID("player"), UnitName("player")
	end
	local p = patterns()[event]
	if p and type(message) == "string" and not issecretvalue(message) then
		if p.mine and message:find(p.mine) then
			return true
		end
		if p.others and message:find(p.others) then
			return false
		end
	end
	if type(guid) == "string" and guid ~= "" and not issecretvalue(guid) then
		return guid == myGUID
	end
	if type(name) ~= "string" or issecretvalue(name) or name == "" then
		return true -- no sender: a line about you
	end
	return name == myName or name:match("^([^%-]+)") == myName
end

local function filter(frame, event, message, ...)
	local general, journal = frame == ChatFrame1, frame == ChatFrame2
	if not (general or journal) or type(message) ~= "string" or issecretvalue(message) then
		return false
	end
	local name, guid = ..., (select(11, ...))
	local mine = Route.IsMine(event, message, name, guid)
	if (general and not mine) or (journal and mine) then
		return true -- shown in the other tab
	end
	return false
end

local registered = false

--- Start splitting (once).
function Route.Enable()
	myGUID, myName = UnitGUID("player"), UnitName("player")
	if registered then
		return
	end
	registered = true
	for _, event in ipairs(SPLIT) do
		ChatFrameUtil.AddMessageEventFilter(event, filter)
	end
end
