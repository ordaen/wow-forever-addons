-- Game messages coloured by whose they are. What happens to you keeps Blizzard's colour (skill-ups blue, experience
-- purple, money yellow, your loot green: the player's own chat colour settings); other players' activity and the
-- crafting log ("X creates Y", repeated for every item crafted) show in the theme's muted colour (token color.muted),
-- so conversations and your own progress stand out. A chat message filter (Blizzard's
-- ChatFrameUtil.AddMessageEventFilter) recolours a muted line; links in it keep their own colour, and the rest of the
-- line returns to the muted colour after each one. Messages with secret values are left alone.
-- Cost: filters are registered only for the muted kinds, only while the feature is on. A filter runs per chat window
-- showing the message; the recoloured line is built once per message (the windows after the first reuse it).
local _, ns = ...

local Dim = {}
ns.Dim = Dim

local UI = OrdaenCore.UI

-- Per event (all documented in api/forever/<CURRENT>, forever-lint FL1): `mine` / `others` true = muted. Events not
-- listed keep Blizzard's colour (skill, experience, honour, reputation, money, currency, pet info, misc info).
-- Other players' crafting and openings show in Journal (Route.lua), muted there.
local RULES = {
	CHAT_MSG_LOOT = { mine = false, others = true },
	CHAT_MSG_OPENING = { mine = false, others = true },
	CHAT_MSG_TRADESKILLS = { mine = false, others = true },
}
local FALLBACK = { 0.6, 0.6, 0.6 }

local on = false
local open = "|cff999999" -- the muted colour's escape, from the theme
local lastIn, lastOut -- the last message and its recoloured line (shared by the chat windows showing it)
local myGUID, myName

local function readColor()
	local c = UI.Color("color.muted", FALLBACK) or FALLBACK
	open = ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5))
	lastIn, lastOut = nil, nil
end

-- Whether a message is about the player: its sender's GUID (payload 12) or name (payload 2, maybe with a realm).
local function isMine(name, guid)
	if type(guid) == "string" and guid ~= "" and not issecretvalue(guid) then
		return guid == myGUID
	end
	if type(name) ~= "string" or issecretvalue(name) or name == "" then
		return true -- no sender: a line about you ("You receive loot")
	end
	return name == myName or name:match("^([^%-]+)") == myName
end

local function muted(message)
	if message ~= lastIn then
		lastIn = message
		lastOut = open .. message:gsub("|r", "|r" .. open) .. "|r"
	end
	return lastOut
end

local function filter(_, event, message, ...)
	local rule = RULES[event]
	if not rule or type(message) ~= "string" or issecretvalue(message) then
		return false, message, ...
	end
	local name, guid = ..., (select(11, ...))
	local dim
	if isMine(name, guid) then
		dim = rule.mine
	else
		dim = rule.others
	end
	if not dim then
		return false, message, ...
	end
	return false, muted(message), ...
end

local function onThemeChanged()
	if on then
		readColor()
	end
end

local listening = false

--- Colour game messages by whose they are: the "dimEvents" feature's OnEnable.
function Dim.Enable()
	on = true
	myGUID, myName = UnitGUID("player"), UnitName("player")
	readColor()
	for event in pairs(RULES) do
		ChatFrameUtil.AddMessageEventFilter(event, filter)
	end
	if not listening then
		listening = true
		EventRegistry:RegisterCallback("OrdaenUI.ThemeChanged", onThemeChanged, Dim)
	end
end

--- Back to Blizzard's colours for new lines (lines already shown keep theirs).
function Dim.Disable()
	on = false
	for event in pairs(RULES) do
		ChatFrameUtil.RemoveMessageEventFilter(event, filter)
	end
	lastIn, lastOut = nil, nil
end

--- The rules, for specs and the dev-mode dump.
Dim.RULES = RULES
