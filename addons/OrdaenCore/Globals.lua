-- Ordaen's global settings (design: settings/index.md, «Общие»; development/framework/app, the root's state): the
-- settings every module follows, on Ordaen's own page of the settings window. Stored like a module's settings
-- (only what differs from the default, account-wide in OrdaenCoreDB), read as `game.Settings.<name>` and named by a
-- module's look setting as `follows = Define.Global.<name>`. The look itself (fonts, colours, textures, animations)
-- is the theme's, not a setting here.
local _, ns = ...

local State = ns.State
local error, tostring = error, tostring

---@class OrdaenGlobals
local Globals = {}
ns.Globals = Globals

---@enum OrdaenDensity
Globals.Density = { Compact = "compact", Normal = "normal", Roomy = "roomy" }
---@enum OrdaenNumberFormat
Globals.NumberFormat = { Space = "space", Comma = "comma", Dot = "dot" }
---@enum OrdaenLargeNumbers
Globals.LargeNumbers = { Full = "full", Short = "short" }
---@enum OrdaenClock
Globals.Clock = { H24 = "24", H12 = "12" }

-- What the «Общие» tabs hold (Масштаб, Числа, Поведение), with the design's defaults. A choice's `order` is its
-- menu's order, which the build writes for a module's settings; this file isn't built, so it's written here and
-- globals_spec fails when it and the enum drift apart.
local SPEC = {
	scale = { type = "number", default = 1, min = 0.7, max = 1.5, step = 0.05, unit = "percent", setting = true },
	density = { type = "choice", choices = Globals.Density, order = { "compact", "normal", "roomy" },
		default = Globals.Density.Normal, setting = true },
	pixel = { type = "boolean", default = true, setting = true },
	numberFormat = { type = "choice", choices = Globals.NumberFormat, order = { "space", "comma", "dot" },
		default = Globals.NumberFormat.Space, setting = true },
	numberRound = { type = "boolean", default = false, setting = true },
	numberPrecision = { type = "number", default = 2, min = 0, max = 3, step = 1, setting = true },
	numbers = { type = "choice", choices = Globals.LargeNumbers, order = { "full", "short" },
		default = Globals.LargeNumbers.Short, setting = true },
	sounds = { type = "boolean", default = true, setting = true },
	clock = { type = "choice", choices = Globals.Clock, order = { "24", "12" },
		default = Globals.Clock.H24, setting = true },
}
Globals.spec = SPEC

-- Ordaen as the store's module: its account-wide table, given at its ADDON_LOADED (Globals.Load)
local store = { name = "OrdaenCore" }

--- Ordaen's SavedVariables are there (its ADDON_LOADED): the global settings can be read from now on.
---@param db table OrdaenCoreDB
function Globals.Load(db)
	store.db, store.charDb = db, db -- every global is account-wide
end

--- The global setting `name` (the same stored value every reader shares); an unknown name is an error.
---@param name string
function Globals.Get(name)
	local spec = SPEC[name]
	if not spec then
		error("Ordaen: no global setting " .. tostring(name), 3)
	end
	if not store.db then
		error("Ordaen: the global settings are read before Ordaen loaded them", 3)
	end
	return State.Stored(store, "global", name, spec)
end

--- `Define.Global.<name>` and `game.Settings.<name>`: the global settings by name.
Globals.ByName = setmetatable({}, {
	__index = function(_, name)
		return Globals.Get(name)
	end,
})

--- `game.Settings:Draft()`: a new draft of settings changes for the settings window (State.NewDraft). Not a setting:
--- settings are named in lower camel case.
rawset(Globals.ByName, "Draft", function()
	return State.NewDraft()
end)

--- Every global setting back to its default (`/ordaen reset` for Ordaen itself).
function Globals.Reset()
	for name in pairs(SPEC) do
		Globals.Get(name):Reset()
	end
end
