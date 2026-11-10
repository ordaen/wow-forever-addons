-- A module's window (design development/framework/module, «Windows»): declared in its spec (`windows = { main = {} }`)
-- and made by the engine at mount as `self.windows.main`. The framework owns whether it's shown and the page it's on,
-- so every opener is a toggle: no setter exists but Open, Close and Toggle.
local _, ns = ...

---@class OrdaenWindow
---@field shown OrdaenValueSignal boolean
---@field page OrdaenValueSignal string: "" for the window's first page
---@field guard (fun(): boolean)|nil asked before closing; false keeps it open (it asks the player first)
local Window = {}
local WindowMeta = { __index = Window }

---@return OrdaenWindow
function ns.NewWindow()
	return setmetatable({ shown = ns.NewValue(false), page = ns.NewValue("") }, WindowMeta)
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
