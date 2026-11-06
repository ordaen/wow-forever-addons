-- Ordaen Chat's start: declares the addon to the Ordaen Core framework (SavedVariables, settings page, slash
-- commands) and its features: the default tabs (once per character), new channels sorted into the Channels tab,
-- and the input group. The social button isn't ours: Ordaen Panel takes it.
--
-- Conflicts: Prat-3.0 restyles the chat input and moves or hides the chat menu button (its Edit box and Buttons
-- modules, on by default), so the player is asked at login (Core's dialog: keep ours, keep Prat, keep both). Any
-- addon changing what the input group claims (below) is found at runtime too. Either way the input group steps
-- aside: with "keep both" the other addon keeps the input; the tabs and whispers don't overlap and stay on.
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenChatDB",
	charDb = "OrdaenChatCharDB",
	defaults = { inputGroup = true, sortChannels = true },
	charDefaults = {},
	slash = { "/ochat", "/ordaenchat" },
	conflicts = { "Prat-3.0" },
	dump = function()
		return { tabs = ns.Tabs.Describe(), whispers = ns.Whispers.Describe(), input = ns.Input.Describe() }
	end,
	settings = {
		title = "SETTINGS_TITLE",
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

local sortChannels = A:Feature("sortChannels", { setting = "sortChannels" })
sortChannels:OnEnable(function()
	ns.Tabs.SortChannels(sortChannels)
end)

-- What the input group changes on Blizzard's frames, found by name (the build can't name them yet: claims.rs
-- follows only direct `Global:Method` calls; remove these once it covers them). Another addon calling these is a
-- conflict (Conflict.lua). Only the first window's input art: an addon that restyles inputs restyles that one too,
-- and claiming all ten windows' art reported one conflict per texture (30 records for Prat, 2026-11-06). Its focus
-- art is Blizzard's to toggle on every focus.
local menuButton = _G.ChatFrameMenuButton
if menuButton then
	A:Claim(menuButton, { "SetPoint", "SetParent", "Hide", "SetAlpha" }, "ChatFrameMenuButton")
end
for _, part in ipairs({ "Left", "Mid", "Right" }) do
	local name = "ChatFrame1EditBox" .. part
	local texture = _G[name]
	if texture then
		A:Claim(texture, { "Hide", "SetAlpha" }, name)
	end
end

local yielded = false -- another addon owns the input (a conflict): the input group stays off this session
local inputGroup = A:Feature("inputGroup", {
	setting = "inputGroup",
	when = function()
		return not yielded
	end,
})
inputGroup:OnEnable(function()
	ns.Input.Enable()
end)
inputGroup:OnDisable(function()
	ns.Input.Disable()
end)

-- Step aside for the other addon, and leave the Core to record and ask (nothing recorded here: unhandled until
-- the player decides; with "keep both" the Core records it as accepted).
A:OnConflict(function(other, what)
	A.Debug:Logf("conflict with %s (%s): the input group steps aside", other, what)
	if not yielded then
		yielded = true
		ns.Input.StepAside()
		inputGroup:Refresh()
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
