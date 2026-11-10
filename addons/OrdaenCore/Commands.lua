-- `/ordaen`, Ordaen's one slash command (design: development/framework/module, «Commands»):
--   /ordaen                         the help (the settings window, once it exists)
--   /ordaen help                    every module's commands
--   /ordaen <module>                that module's commands (its settings page, once the window exists)
--   /ordaen <module> help           the same
--   /ordaen <module> <command> ...  runs the command, with the rest of the line as its arguments
-- <module> is the module's folder without "Ordaen", lower case (OrdaenBags: bags), the same word everywhere; addons
-- that aren't modules (the debug addon) take a word of their own with OrdaenCore.AddCommands. Command words are
-- lower case letters, digits and hyphens; "help" and "reset" are the Core's. A module that is off says so and isn't
-- loaded.
-- Each command runs through the engine (its writes flush after it) in its own protected call.
local _, ns = ...

local Core, Engine, L = ns.Core, ns.Engine, ns.L
local format, lower, match, sort, pairs = string.format, string.lower, string.match, table.sort, pairs

---@class OrdaenCommands
local Commands = {}
ns.Commands = Commands

local groups = {} -- word -> { title, list = { command -> { Run, help } }, module? }
local off = {} -- word -> title, for every module the AddOns list has (a module that loaded goes to groups)

local WORD = "^[a-z0-9%-]+$"
local SETTINGS = "OrdaenSettings" -- the settings window: an on-demand module, its `open` command opens it
local RESERVED = { help = true, reset = true } -- the Core's own: every module's help, and its settings reset

local function say(text)
	print("|cffd9a54aOrdaen|r " .. text)
end

-- Checked when a group is added: a bad word is a bug in the addon, reported once, the group kept without it.
local function valid(group, word)
	if type(word) ~= "string" or not match(word, WORD) or RESERVED[word] then
		geterrorhandler()(format("Ordaen: /ordaen %s: %q can't be a command word (lower case letters, digits, hyphens;"
			.. " not help or reset)", group, tostring(word)))
		return false
	end
	return true
end

local function add(word, title, commands, module)
	local list = {}
	for command, entry in pairs(commands or {}) do
		if valid(word, command) and type(entry) == "table" and type(entry.Run) == "function" then
			list[command] = entry
		end
	end
	groups[word] = { title = title, list = list, module = module }
	off[word] = nil
end

--- The word a module answers to: its folder without "Ordaen", lower case.
---@param folder string
function Commands.Word(folder)
	return lower((folder:gsub("^Ordaen", "")))
end

--- A module the AddOns list has, before it loads: `/ordaen <word>` says it's off until it mounts.
---@param folder string
function Commands.Know(folder)
	local word = Commands.Word(folder)
	if not groups[word] then
		off[word] = folder:gsub("^Ordaen", "")
	end
end

--- A mounted module's `commands` (its declaration's): Run(game, self, arguments), self its root component.
---@param module table
---@param commands table?
function Commands.AddModule(module, commands)
	add(Commands.Word(module.name), (module.name:gsub("^Ordaen", "")), commands, module)
end

--- Commands of an addon that isn't a module (the debug addon): `/ordaen <word> <command> ...` calls Run(arguments).
---@param word string lower case letters, digits and hyphens
---@param commands table<string, { Run: fun(arguments: string), help: string? }>
function Core.AddCommands(word, commands)
	if type(word) ~= "string" or not match(word, WORD) or RESERVED[word] then
		error(format("OrdaenCore.AddCommands: %q can't be a word for /ordaen", tostring(word)), 2)
	end
	add(word, word, commands, nil)
end

local function sorted(t)
	local out = {}
	for k in pairs(t) do
		out[#out + 1] = k
	end
	sort(out)
	return out
end

local function groupHelp(word)
	local group = groups[word]
	local commands = sorted(group.list)
	if #commands == 0 then
		say(format(L.NO_COMMANDS, group.title))
		return
	end
	for _, command in ipairs(commands) do
		local help = group.list[command].help
		say(help and format("/ordaen %s %s: %s", word, command, help) or format("/ordaen %s %s", word, command))
	end
end

local function help()
	say(L.HELP_TITLE)
	for _, word in ipairs(sorted(groups)) do
		if next(groups[word].list) then
			groupHelp(word)
		end
	end
end

--- Open the settings window (its `open` command); false when it isn't installed or can't load.
function Commands.OpenSettings()
	local settings = ns.App.OpenOnDemand(SETTINGS)
	local open = settings and groups[Commands.Word(SETTINGS)]
	open = open and open.list.open
	if not open then
		return false
	end
	Engine:Handle(open.Run, settings.game, settings.root, "")
	return true
end

local function run(line)
	local word, command, arguments = match(line or "", "^%s*(%S*)%s*(%S*)%s*(.-)%s*$")
	word, command = lower(word), lower(command)
	if word == "" then -- the settings window, where it's installed; else the commands
		if not Commands.OpenSettings() then
			help()
		end
		return
	end
	if word == "help" then
		help()
		return
	end
	if word == "ordaen" and command == "reset" then -- Ordaen's own: the global settings
		ns.Globals.Reset()
		say(format(L.SETTINGS_RESET, "Ordaen"))
		return
	end
	local group = groups[word]
	if not group then
		say(off[word] and format(L.MODULE_OFF, off[word]) or format(L.UNKNOWN_MODULE, word))
		return
	end
	if command == "" or command == "help" then
		groupHelp(word)
		return
	end
	if command == "reset" then -- the Core's: the module's settings to their defaults
		local module = group.module
		if module then
			ns.State.ResetSettings(module)
			say(format(L.SETTINGS_RESET, group.title))
		end
		return
	end
	local entry = group.list[command]
	if not entry then
		say(format(L.UNKNOWN_COMMAND, group.title, command, word))
		return
	end
	local module = group.module
	if module then
		Engine:Handle(entry.Run, module.game, module.root, arguments)
	else
		Engine:Handle(entry.Run, arguments)
	end
end

SLASH_ORDAEN1 = "/ordaen"
SlashCmdList.ORDAEN = run

-- Ordaen in Blizzard's own options (Параметры → Модификации), where players look for an addon's settings: picking it
-- opens Ordaen's window and closes Blizzard's. Blizzard's panel reopens on the category picked last, so its canvas also
-- shows when the panel opens: then it only offers a button, or «Параметры» would always open Ordaen's window.
ns.Stage.Login:Subscribe(function()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then
		return
	end
	local function Open()
		if Commands.OpenSettings() and SettingsPanel then
			HideUIPanel(SettingsPanel)
		end
	end
	local opened -- GetTime() when Blizzard's panel last opened: a canvas shown in that frame wasn't picked
	if SettingsPanel then
		SettingsPanel:HookScript("OnShow", function()
			opened = GetTime()
		end)
	end
	local canvas = CreateFrame("Frame")
	local button = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	button:SetSize(200, 26)
	button:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
	button:SetText(L.SETTINGS_OPEN)
	button:SetScript("OnClick", Open)
	canvas:SetScript("OnShow", function()
		if opened ~= GetTime() then
			Open()
		end
	end)
	local _, title = C_AddOns.GetAddOnInfo("OrdaenCore")
	local category = Settings.RegisterCanvasLayoutCategory(canvas, title or "Ordaen")
	Settings.RegisterAddOnCategory(category)
	Commands.optionsCategory = category
end, false)
