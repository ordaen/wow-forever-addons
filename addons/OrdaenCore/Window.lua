-- A module's window (design development/framework/module, «Windows»): declared in its spec (`windows = { main = {} }`)
-- and made by the engine at mount as `self.windows.main`. The framework owns whether it's shown and the page it's on,
-- so every opener is a toggle: no setter exists but Open, Close and Toggle. It also keeps where the player left it and
-- its size (saved: the module's db, one small entry per window, as the design's windows/ says: remembered per window),
-- so a module draws it with `game.ui:Window({ attributes = { window = self.windows.main, ... } })` and never handles
-- a move or a resize.
local _, ns = ...

---@class OrdaenWindow
---@field shown OrdaenValueSignal boolean
---@field page OrdaenValueSignal string: "" for the window's first page
---@field guard (fun(): boolean)|nil asked before closing; false keeps it open (it asks the player first)
---@field x table stored number: its centre's offset from the screen's centre (UI units, y down)
---@field y table stored number
---@field width table stored number: its body's width (UI units)
---@field height table stored number
local Window = {}
local WindowMeta = { __index = Window }

-- its place and size: stored values of the module (path "window#<name>"), the size's defaults from the declaration
local PLACE = { type = "number", default = 0 }

---@param module table the module (its db)
---@param name string the window's name in the declaration ("main")
---@param spec table its declaration: `width`, `height` (the body's default size, UI units)
---@return OrdaenWindow
function ns.NewWindow(module, name, spec)
	local path = "window#" .. name
	local Stored = ns.State.Stored
	return setmetatable({
		shown = ns.NewValue(false), page = ns.NewValue(""),
		x = Stored(module, path, "x", PLACE), y = Stored(module, path, "y", PLACE),
		width = Stored(module, path, "width", { type = "number", default = spec.width or 0 }),
		height = Stored(module, path, "height", { type = "number", default = spec.height or 0 }),
	}, WindowMeta)
end

--- Where it is and its body's size: x, y, width, height (read, not followed: the Window keeps its own while dragged).
function Window:Place()
	return self.x:Peek(), self.y:Peek(), self.width:Peek(), self.height:Peek()
end

--- Keep where the player left it (a move or resize ended).
function Window:SetPlace(x, y, width, height)
	self.x:Set(x)
	self.y:Set(y)
	self.width:Set(width)
	self.height:Set(height)
end

--- Whether it's shown; read in a render, the render follows it.
function Window:IsShown()
	return self.shown:Get()
end

--- The page it's on ("" for its first).
function Window:Page()
	return self.page:Get()
end

--- Show it, on `page` when given (else on the page it was on).
---@param page string|nil
function Window:Open(page)
	if page and page ~= "" then
		self.page:Set(page)
	end
	self.shown:Set(true)
end

--- Hide it, unless its guard keeps it open (unsaved changes: the guard asks the player, who closes it again).
function Window:Close()
	if self.guard and not self.guard() then
		return
	end
	self.shown:Set(false)
end

--- What every opener does: closed, it opens (on `page`); open on that page or with no page, it closes; open on
--- another page, it goes to that page.
---@param page string|nil
function Window:Toggle(page)
	if self.shown:Peek() and (not page or page == "" or page == self.page:Peek()) then
		self:Close()
	else
		self:Open(page)
	end
end

--- Set what's asked before it closes (once, in the module's setup).
---@param fn fun(): boolean true: it may close
function Window:Guard(fn)
	self.guard = fn
end
