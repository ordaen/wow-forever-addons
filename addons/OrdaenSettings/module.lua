-- Ordaen Settings: the one Ordaen settings window (design settings/): Ordaen's own page (General: the global settings,
-- this module's own Settings) and every module in the list on the left with its switch, the chosen one's page beside
-- it (its tabs from the page descriptions the build writes, `import("pages")`; the page itself the module's own
-- Settings, drawn in its context by game.ui:ModuleSettings). On demand: Ordaen loads and mounts it at the first bare
-- /ordaen, never at login, and `open` shows the window. Themes join the list with their page.
local Define = import("@ordaen/define")
local L = import("locales")
local pages = import("pages")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WIDTH, HEIGHT = 1160 * PX, 700 * PX -- the window's body (design SETTINGS_SIZE)
-- the window body's content: its height less the body's padding (14 and 12 px inside the wood's 3 px)
local CONTENT_HEIGHT = HEIGHT - (14 + 3 + 12 + 3) * PX
local DIM = { 0.639, 0.592, 0.498, 1 } -- --o-dim #a3977f
local SELF = "OrdaenSettings" -- Ordaen's own page is this module's Settings

local BODY = { columns = { "auto", "1fr" }, height = CONTENT_HEIGHT }
local LIST = { columns = 1 }
-- the list's heading over the modules: small capitals in the dim colour, 10 px above, 4 below
local HEADING = { padding = { 10 * PX, 16 * PX, 4 * PX, 16 * PX } }
-- the page beside the list: a darker panel, its content scrolling
local PAGE = { background = { 0, 0, 0, 0.25 }, padding = { 14 * PX, 18 * PX, 18 * PX, 18 * PX }, columns = 1,
	gap = 14 * PX, overflow = "scroll" }

-- each module's tab names, from its page description, made once
local tabNames = setmetatable({}, { __index = function(t, folder)
	local names = {}
	local page = pages[folder]
	for i, tab in ipairs(page and page.tabs or {}) do
		names[i] = tab.title
	end
	t[folder] = names
	return names
end })

local function ModuleList(game, self)
	local calls = self.moduleCalls
	for i = 1, #calls do
		game.ui:ModuleTab(calls[i])
	end
end

local function Heading(game)
	game.ui:Text({ attributes = { text = L.LIST_MODULES:upper(), textColor = DIM, textSize = 12 * PX,
		textFamily = Define.Theme.font.numbers } })
end

local function List(game, self)
	game.ui:ListTab({ attributes = { label = L.LIST_GLOBAL, icon = game.Ordaen.icon,
		selected = self.state.at == SELF, OnClick = self.picks[SELF] } })
	game.ui:Box({ attributes = HEADING, slots = { default = Heading } })
	game.ui:Box({ attributes = LIST, slots = { default = ModuleList } })
end

-- a module's page: its tabs (when it has more than one) and the picked one, or a word that it's off
local function ModulePage(game, self)
	local folder = self.state.at
	local names = tabNames[folder]
	if #names > 1 then
		game.ui:Tabs({ attributes = { tabs = tabNames[self.state.at], selected = self.state.tab, OnSelect = self.pickTab } })
	end
	game.ui:ModuleSettings({ attributes = { module = self.state.at, tab = self.state.tab } })
end

local function Off(game)
	game.ui:Text({ attributes = { text = L.MODULE_OFF, textColor = DIM, textSize = 15 * PX } })
end

local function Page(game, self)
	local module = self.modules[self.state.at]
	if self.state.at == SELF or module and module.on:Get() then
		game.ui:Box({ key = self.state.at, attributes = { columns = 1, gap = 14 * PX }, slots = { default = ModulePage } })
	else
		game.ui:Box({ attributes = { columns = 1 }, slots = { default = Off } })
	end
end

local function Body(game)
	game.ui:Box({ attributes = LIST, slots = { default = List } })
	game.ui:Box({ attributes = PAGE, slots = { default = Page } })
end

local function Window(game)
	game.ui:Box({ attributes = BODY, slots = { default = Body } })
end

return Define.Module({
	title = "Ordaen Settings",

	onDemand = true,

	Setup = function(game, self)
		Define.Ephemeral({
			shown = { type = "boolean", default = false },
			at = { type = "string", default = SELF }, -- the page shown: a module's folder (this one's: General)
			tab = { type = "number", default = 1 }, -- its tab
		})
		local modules = {}
		for i = 1, #game.Modules do
			modules[game.Modules[i].folder] = game.Modules[i]
		end
		-- each module's entry, made once (the list of modules is fixed for the session); it reads the page shown
		local shown = Define.Signal(self.state.at)
		-- a click per entry, made once: shows that page, its first tab
		local picks = setmetatable({}, { __index = function(t, at)
			local function Pick()
				self.state.at = at
				self.state.tab = 1
			end
			t[at] = Pick
			return Pick
		end })
		local moduleCalls = {}
		for i = 1, #game.Modules do
			local module = game.Modules[i]
			moduleCalls[i] = { key = module.folder, attributes = { module = module, shown = shown,
				OnClick = picks[module.folder] } }
		end
		return {
			modules = modules,
			moduleCalls = moduleCalls,
			picks = picks,
			pickTab = function(i)
				self.state.tab = i
			end,
			hide = function()
				self.state.shown = false
			end,
		}
	end,

	Render = function(game, self)
		if self.state.shown then
			game.ui:Window({ attributes = { title = game.Ordaen.title, width = WIDTH, height = HEIGHT, OnClose = self.hide },
				slots = { default = Window } })
		end
	end,

	-- Ordaen's own page (design settings/, General): the global settings every module follows, on three tabs
	Settings = function(game)
		game.ui:SettingsTab({ attributes = { title = L.GLOBAL_TAB_SCALE }, slots = { default = function()
			game.ui:Slider({ attributes = { value = game.Settings.scale } })
			game.ui:Dropdown({ attributes = { value = game.Settings.density } })
			game.ui:Checkbox({ attributes = { value = game.Settings.pixel } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.GLOBAL_TAB_NUMBERS }, slots = { default = function()
			game.ui:Dropdown({ attributes = { value = game.Settings.numberFormat } })
			game.ui:Checkbox({ attributes = { value = game.Settings.numberRound } })
			game.ui:Slider({ attributes = { value = game.Settings.numberPrecision,
				disabled = game.Settings.numberRound:Get() } })
			game.ui:Dropdown({ attributes = { value = game.Settings.numbers } })
			game.ui:NumbersExample({ attributes = { title = L.NUMBERS_EXAMPLE } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.GLOBAL_TAB_BEHAVIOR }, slots = { default = function()
			game.ui:Checkbox({ attributes = { value = game.Settings.sounds } })
			game.ui:Dropdown({ attributes = { value = game.Settings.clock } })
		end } })
	end,

	commands = {
		open = { help = L.CMD_OPEN, Run = function(_, self)
			self.state.shown = true
		end },
	},
})
