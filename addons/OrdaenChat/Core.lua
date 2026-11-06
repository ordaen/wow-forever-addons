-- Ordaen Chat's start: declares the addon to the Ordaen Core framework (SavedVariables, settings page, slash
-- commands) and its features: the default tabs (once per character), new channels sorted into the Channels tab,
-- and the input group. The social button isn't ours: Ordaen Panel takes it.
--
-- Conflicts: Prat-3.0 restyles the chat input, its fonts, and moves or hides the chat menu button (its Edit box,
-- Font and Buttons modules, on by default), so the player is asked at login (Core's dialog: keep ours, keep Prat,
-- keep both). Any addon changing what we claim (below, and the build's claims) is found at runtime too. Either way
-- the input group and the chat's look step aside: with "keep both" the other addon keeps the chat's look; the tabs
-- and whispers don't overlap and stay on.
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenChatDB",
	charDb = "OrdaenChatCharDB",
	defaults = { chatLook = true, inputGroup = true, sortChannels = true },
	charDefaults = {},
	slash = { "/ochat", "/ordaenchat" },
	conflicts = { "Prat-3.0" },
	dump = function()
		return { tabs = ns.Tabs.Describe(), whispers = ns.Whispers.Describe(), input = ns.Input.Describe(),
			look = ns.Look.Describe() }
	end,
	settings = {
		title = "SETTINGS_TITLE",
		{ key = "chatLook", label = "CHAT_LOOK", tooltip = "CHAT_LOOK_TOOLTIP" },
		{ key = "inputGroup", label = "INPUT_GROUP", tooltip = "INPUT_GROUP_TOOLTIP" },
		{ key = "sortChannels", label = "SORT_CHANNELS", tooltip = "SORT_CHANNELS_TOOLTIP" },
	},
})
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A
ns.Debug = A.Debug
function ns.Print(...)
	A:Print(...)
end

local layout = A:Feature("layout")
layout:OnEnable(function()
	ns.Tabs.ApplyOnce(A.charDb)
end)

local yielded = false -- another addon owns the chat's look (a conflict): input group and look stay off
local function ownLook()
	return not yielded
end

-- Windows, tabs and fonts in the theme (Look.lua).
local look = A:Feature("look", { setting = "chatLook", when = ownLook })
look:OnEnable(function()
	ns.Look.Enable()
end)
look:OnDisable(function()
	ns.Look.Disable()
end)

local sortChannels = A:Feature("sortChannels", { setting = "sortChannels" })
sortChannels:OnEnable(function()
	ns.Tabs.SortChannels(sortChannels)
end)

-- Claims the build can't see (it claims what the code calls on frames it can name: the chat buttons' SetParent,
-- ClearAllPoints, SetPoint and SetSize). Another addon calling these is a conflict (Conflict.lua):
-- - the chat menu button hidden or faded: Prat's Buttons module does that, and we never call these ourselves;
-- - the first window's input art and background: UI.Dress hides them, through names built at runtime. Only the
--   first window's: an addon restyling the chat restyles that one too, and claiming all ten windows' art reported
--   one conflict per texture (30 records for Prat, 2026-11-06). Focus art is Blizzard's to toggle on every focus.
local menuButton = _G.ChatFrameMenuButton
if menuButton then
	A:Claim(menuButton, { "Hide", "SetAlpha" }, "ChatFrameMenuButton")
end
for _, name in ipairs({ "ChatFrame1EditBoxLeft", "ChatFrame1EditBoxMid", "ChatFrame1EditBoxRight",
	"ChatFrame1Background" }) do
	local texture = _G[name]
	if texture then
		A:Claim(texture, { "Hide", "SetAlpha" }, name)
	end
end

local inputGroup = A:Feature("inputGroup", { setting = "inputGroup", when = ownLook })
inputGroup:OnEnable(function()
	ns.Input.Enable()
end)
inputGroup:OnDisable(function()
	ns.Input.Disable()
end)

-- Step aside for the other addon, and leave the Core to record and ask (nothing recorded here: unhandled until
-- the player decides; with "keep both" the Core records it as accepted).
A:OnConflict(function(other, what)
	A.Debug:Logf("conflict with %s (%s): the input group and the look step aside", other, what)
	if not yielded then
		yielded = true
		ns.Input.StepAside()
		inputGroup:Refresh()
		look:Refresh()
	end
end)

A:Command("tabs", function()
	ns.Tabs.Apply(A.charDb)
end, "HELP_TABS")

A:Command("tab", function(channel)
	channel = channel and channel:match("^%s*(.-)%s*$")
	if channel and channel ~= "" then
		ns.Tabs.ForChannel(channel)
	end
end, "HELP_TAB")
