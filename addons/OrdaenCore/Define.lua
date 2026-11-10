-- Define (design: development/framework/structure#define): what modules import as "@ordaen/define". The build reads
-- these calls; in the MVP they also run, doing at runtime what the build will do ahead of time.
local _, ns = ...

local Engine, State = ns.Engine, ns.State
local setmetatable, rawget, rawset, getmetatable = setmetatable, rawget, rawset, getmetatable

---@class OrdaenDefine
local Define = {}
ns.Define = Define

-- `Comp.state.<name>` on a declaration: the component's persistent value, without mounting it (a settings page binds
-- it with Define.Signal)
local DeclarationStateMeta = {
	__index = function(state, name)
		return State.OfDeclaration(rawget(state, "_declaration"), name)
	end,
}

--- A component; its name is its file's ("components/sellJunk" → "sellJunk").
---@param declaration table { Setup, Render }
function Define.Component(declaration)
	local path = ns.App.currentFile
	declaration.name = path and path:match("([^/]+)$") or "component"
	declaration.module = ns.App.currentModule
	declaration.state = setmetatable({ _declaration = declaration }, DeclarationStateMeta)
	return declaration
end

--- Ordaen's global settings by name, for a look setting that follows one: `follows = Define.Global.scale`.
Define.Global = setmetatable({}, {
	__index = function(_, name)
		return ns.Globals.Get(name)
	end,
})

--- A value as a signal: what the build leaves of `Define.Signal(…)` around a state path is the value object itself.
function Define.Signal(value)
	return value
end

--- The module: its root component plus what only a package has (title, icon, conflicts, ...).
---@param declaration table
function Define.Module(declaration)
	declaration.name = "module"
	return declaration
end

--- The component library's declaration (addons/OrdaenLibrary/module.lua): a load-on-demand addon of components any
--- module draws by name (`game.ui:Button`), loaded at the first such call; never mounted, never in the module list.
function Define.Library(declaration)
	declaration.name = "library"
	declaration.library = true
	return declaration
end

---@param spec table<string, table>
function Define.Persistent(spec)
	State.Declare(Engine.setupInstance, spec, true)
end

---@param spec table<string, table>
function Define.Ephemeral(spec)
	State.Declare(Engine.setupInstance, spec, false)
end

--- A reference: the child's public part, stable, empty while it isn't mounted.
function Define.Ref(component) -- luacheck: ignore 212
	return Engine.NewHandle()
end

local RefsMeta = {
	__index = function(refs, key)
		local handle = Engine.NewHandle()
		refs[key] = handle
		return handle
	end,
}

--- References by key, for a loop.
function Define.Refs(component) -- luacheck: ignore 212
	return setmetatable({}, RefsMeta)
end

--- An event a component fires with `:Fire(...)` and offers in its public `signals`: others run a handler on it with
--- `self:On(event, handler)` (from a watch, so it subscribes again when the component comes back).
function Define.Event()
	return ns.NewEvent()
end

--- A public slot others draw into. Not built in the MVP: what's drawn into one goes nowhere.
function Define.Slot()
	return ns.NULL
end

--- A game file (file ID or path) or, imported, one of the module's own: the value the backend draws.
function Define.Asset(file)
	return file
end

---@param name string
function Define.AssetAtlas(name)
	return { atlas = name }
end

-- Theme references: interned, one table per path, made on first use. The backend resolves them (ns.Theme).
local ThemeRefMeta = {}
ThemeRefMeta.__index = function(ref, key)
	local path = rawget(ref, "path")
	local child = setmetatable({ path = path and (path .. "." .. key) or key }, ThemeRefMeta)
	rawset(ref, key, child)
	return child
end

Define.Theme = setmetatable({}, ThemeRefMeta)

--- A theme reference's value now (the active theme's), for a component that places things by it: a frame's reach,
--- a size. Drawing takes the reference itself (the backend follows a theme change); this reads it once.
---@param ref table a theme reference (Define.Theme.frame.small)
function Define.ThemeValue(ref)
	return ns.Theme[rawget(ref, "path")]
end

--- Whether `value` is a theme reference (its path is `value.path`, "color.surface").
function ns.IsThemeRef(value)
	return getmetatable(value) == ThemeRefMeta
end
