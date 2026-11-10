-- Ordaen Settings: the one Ordaen settings window (design settings/): Ordaen's own page (General: the global settings,
-- this module's own Settings) and every module in the list on the left with its switch, the chosen one's page beside
-- it (its tabs from the page descriptions the build writes, `import("pages")`; the page itself the module's own
-- Settings, drawn in its context by game.ui:ModuleSettings). On demand: Ordaen loads and mounts it at the first bare
-- /ordaen, never at login, and `open` shows the window. Themes join the list with their page.
local Define = import("@ordaen/define")
local L = import("locales")
local pages = import("pages")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WIDTH, HEIGHT = 1160 * PX, 700 * PX -- the window's body at first (design SETTINGS_SIZE)
local MIN_WIDTH, MIN_HEIGHT = 900 * PX, 480 * PX -- the smallest it resizes to: the list, a row and the foot fit
local DIM = { 0.639, 0.592, 0.498, 1 } -- --o-dim #a3977f
local SELF = "OrdaenSettings" -- Ordaen's own page is this module's Settings

local BODY = { columns = { "auto", "1fr" }, height = "100%" }
local LIST = { columns = 1 }
-- the list's heading over the modules: small capitals in the dim colour, 10 px above, 4 below
local HEADING = { padding = { 10 * PX, 16 * PX, 4 * PX, 16 * PX } }
-- the page beside the list: a darker panel, its content scrolling above its foot
local PAGE = { background = { 0, 0, 0, 0.25 }, height = "100%" }
local FOOT_HEIGHT = 34 * PX -- a PushButton's
local SCROLL = { position = "absolute", left = 0, right = 0, top = 0, bottom = (18 + 6) * PX + FOOT_HEIGHT,
	padding = { 14 * PX, 18 * PX, 0, 18 * PX }, columns = 1, gap = 14 * PX, overflow = "scroll" }
-- the page's foot (design .sw-foot): how to open the page at the left, «Откатить» after a save and «Сохранить» at
-- the bottom right
local FOOT = { position = "absolute", left = 18 * PX, right = 18 * PX, bottom = 18 * PX, height = FOOT_HEIGHT,
	columns = { "1fr", "auto" }, yAlign = "center", gap = 12 * PX }
local SAVE_ROW = { columns = { "auto", "auto" }, gap = 8 * PX }
local HINT = 13 * PX
-- the question on closing with unsaved changes (design .sw-confirm)
local CONFIRM_WIDTH = 440 * PX
local INK = { 0.91, 0.863, 0.769, 1 } -- --o-ink

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

-- the page shown: a module's folder, or this one's (General) while the window is on its first page
local function At(self)
	local page = self.windows.main:Page()
	return page == "" and SELF or page
end

local function List(game, self)
	game.ui:ListTab({ attributes = { label = L.LIST_GLOBAL, icon = game.Ordaen.icon,
		selected = At(self) == SELF, OnClick = self.picks[SELF] } })
	game.ui:Box({ attributes = HEADING, slots = { default = Heading } })
	game.ui:Box({ attributes = LIST, slots = { default = ModuleList } })
end

-- a module's page: its tabs (when it has more than one) and the picked one, or a word that it's off
local function ModulePage(game, self)
	local folder = At(self)
	local names = tabNames[folder]
	if #names > 1 then
		game.ui:Tabs({ attributes = { tabs = tabNames[At(self)], selected = self.state.tab, OnSelect = self.pickTab } })
	end
	game.ui:ModuleSettings({ attributes = { module = At(self), tab = self.state.tab, draft = self.draft } })
end

local function Off(game)
	game.ui:Text({ attributes = { text = L.MODULE_OFF, textColor = DIM, textSize = 15 * PX } })
end

local function Content(game, self)
	local module = self.modules[At(self)]
	if At(self) == SELF or module and module.on:Get() then
		game.ui:Box({ key = At(self), attributes = { columns = 1, gap = 14 * PX }, slots = { default = ModulePage } })
	else
		game.ui:Box({ attributes = { columns = 1 }, slots = { default = Off } })
	end
end

local function Unchanged(_, self)
	return self.draft.changed:Get() == 0
end
local function SaveButtons(game, self)
	if self.draft.saved:Get() then
		game.ui:PushButton({ attributes = { label = L.ROLLBACK, width = 130 * PX, OnClick = self.rollback } })
	end
	game.ui:PushButton({ attributes = { label = L.SAVE, width = 140 * PX, disabled = Unchanged(game, self),
		OnClick = self.save } })
end
local function Opens(game, self)
	if At(self) == SELF then
		game.ui:Text({ attributes = { text = L.OPENS_PAGE, textColor = DIM, textSize = HINT } })
	end
end
local function Foot(game)
	game.ui:Box({ attributes = {}, slots = { default = Opens } })
	game.ui:Box({ attributes = SAVE_ROW, slots = { default = SaveButtons } })
end

local function Page(game)
	game.ui:Box({ attributes = SCROLL, slots = { default = Content } })
	game.ui:Box({ attributes = FOOT, slots = { default = Foot } })
end

local function Body(game)
	game.ui:Box({ attributes = LIST, slots = { default = List } })
	game.ui:Box({ attributes = PAGE, slots = { default = Page } })
end

local function Window(game)
	game.ui:Box({ attributes = BODY, slots = { default = Body } })
end

local function Question(game)
	game.ui:Text({ attributes = { text = L.UNSAVED_ASK, textColor = INK, textSize = 15 * PX } })
end
local function Answers(game, self)
	game.ui:PushButton({ attributes = { label = L.CANCEL, width = 120 * PX, OnClick = self.stay } })
	game.ui:PushButton({ attributes = { label = L.DONT_SAVE, width = 150 * PX, OnClick = self.closeDiscarding } })
	game.ui:PushButton({ attributes = { label = L.SAVE, width = 140 * PX, OnClick = self.closeSaving } })
end

return Define.Module({
	title = "Ordaen Settings",

	onDemand = true,

	windows = { main = { width = WIDTH, height = HEIGHT } },

	Setup = function(game, self)
		Define.Ephemeral({
			tab = { type = "number", default = 1 }, -- its tab
			closing = { type = "boolean", default = false }, -- asking about unsaved changes
		})
		-- the window's one draft: every page's changes wait in it until «Сохранить» (design settings/)
		local draft = game.Settings:Draft()
		local window = self.windows.main
		-- closing asks first while anything is unsaved; saved or discarded, it closes
		window:Guard(function()
			if draft.changed:Peek() > 0 then
				self.state.closing = true
				return false
			end
			self.state.closing = false
			return true
		end)
		local function close()
			self.state.closing = false
			window:Close()
		end
		local modules = {}
		for i = 1, #game.Modules do
			modules[game.Modules[i].folder] = game.Modules[i]
		end
		-- each module's entry, made once (the list of modules is fixed for the session); it reads the page shown
		local shown = window.page -- module entries are folders: never "" (the first page)
		-- a click per entry, made once: shows that page, its first tab
		local picks = setmetatable({}, { __index = function(t, at)
			local function Pick()
				window:Open(at)
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
			draft = draft,
			save = function()
				draft:Save()
			end,
			rollback = function()
				draft:Rollback()
			end,
			stay = function()
				self.state.closing = false
			end,
			closeSaving = function()
				draft:Save()
				close()
			end,
			closeDiscarding = function()
				draft:Discard()
				close()
			end,
			modules = modules,
			moduleCalls = moduleCalls,
			picks = picks,
			pickTab = function(i)
				self.state.tab = i
			end,
			-- closing asks first while anything is unsaved
		}
	end,

	Render = function(game, self)
		if self.windows.main:IsShown() then
			game.ui:Window({ attributes = { title = game.Ordaen.title, window = self.windows.main, minWidth = MIN_WIDTH,
				minHeight = MIN_HEIGHT }, slots = { default = Window } })
			if self.state.closing then
				game.ui:Dialog({ attributes = { title = L.UNSAVED_TITLE, width = CONFIRM_WIDTH },
					slots = { default = Question, buttons = Answers } })
			end
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
		-- /ordaen, /ordaen <module> and every Ordaen button: open on that page, or close (design module, «Windows»)
		toggle = { help = L.CMD_TOGGLE, Run = function(game, self, word)
			local folder = ""
			for i = 1, #game.Modules do
				local module = game.Modules[i]
				if word ~= "" and module.folder:gsub("^Ordaen", ""):lower() == word then
					folder = module.folder
				end
			end
			local before = self.windows.main:Page()
			self.windows.main:Toggle(folder)
			if self.windows.main:Page() ~= before then
				self.state.tab = 1
			end
		end },
	},
})
