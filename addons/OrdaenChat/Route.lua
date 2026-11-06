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

-- Whether a message is about the player: its sender's GUID (payload 12) or name (payload 2, maybe with a realm).
function Route.IsMine(name, guid)
	if type(guid) == "string" and guid ~= "" and not issecretvalue(guid) then
		return guid == myGUID
	end
	if type(name) ~= "string" or issecretvalue(name) or name == "" then
		return true -- no sender: a line about you
	end
	return name == myName or name:match("^([^%-]+)") == myName
end

local function filter(frame, _, message, ...)
	local general, journal = frame == ChatFrame1, frame == ChatFrame2
	if not (general or journal) or type(message) ~= "string" or issecretvalue(message) then
		return false
	end
	local name, guid = ..., (select(11, ...))
	local mine = Route.IsMine(name, guid)
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
