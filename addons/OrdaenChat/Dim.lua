-- Game messages dimmed: loot, crafting ("X creates ..."), experience, honour, reputation, skill, money, currency,
-- openings and pet info show in the theme's muted colour (token color.muted), so conversations stand out. A chat
-- message filter (Blizzard's ChatFrameUtil.AddMessageEventFilter) recolours the line; links in it keep their own
-- colour, and the rest of the line returns to the muted colour after each one. Messages with secret values are left
-- alone.
-- Cost: the filters are registered only while the feature is on. A filter runs per chat window showing the message;
-- the recoloured line is built once per message (the windows after the first reuse it). These messages come a few
-- times a minute at most.
local _, ns = ...

local Dim = {}
ns.Dim = Dim

local UI = OrdaenCore.UI

-- All documented in api/forever/<CURRENT> (forever-lint FL1).
local EVENTS = {
	"CHAT_MSG_TRADESKILLS", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_CURRENCY", "CHAT_MSG_SKILL",
	"CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_HONOR_GAIN", "CHAT_MSG_COMBAT_FACTION_CHANGE",
	"CHAT_MSG_COMBAT_MISC_INFO", "CHAT_MSG_OPENING", "CHAT_MSG_PET_INFO",
}
local FALLBACK = { 0.6, 0.6, 0.6 }

local on = false
local open = "|cff999999" -- the muted colour's escape, from the theme
local lastIn, lastOut -- the last message and its recoloured line (shared by the chat windows showing it)

local function readColor()
	local c = UI.Color("color.muted", FALLBACK) or FALLBACK
	open = ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5))
	lastIn, lastOut = nil, nil
end

local function filter(_, _, message, ...)
	if type(message) ~= "string" or issecretvalue(message) then
		return false, message, ...
	end
	if message ~= lastIn then
		lastIn = message
		lastOut = open .. message:gsub("|r", "|r" .. open) .. "|r"
	end
	return false, lastOut, ...
end

local function onThemeChanged()
	if on then
		readColor()
	end
end

local listening = false

--- Dim game messages: the "dimEvents" feature's OnEnable.
function Dim.Enable()
	on = true
	readColor()
	for _, event in ipairs(EVENTS) do
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
	for _, event in ipairs(EVENTS) do
		ChatFrameUtil.RemoveMessageEventFilter(event, filter)
	end
	lastIn, lastOut = nil, nil
end
