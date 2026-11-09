-- Bindings (design: development/framework/signal, «Bindings»): a drawn field kept current by its own expression, not
-- by re-running the render. The build lifts each attribute that reads state out of a drawing call into a shared
-- expression (`__exprs`, one function per distinct text in a file) and gives the call `bind = { field = fn }`. The
-- first time a call draws its entry, each distinct expression becomes one Binding: an observer that runs the
-- expression tracked and writes its result into every field it feeds (Backend:SetField). A change to what it read
-- re-runs that binding alone, after the components above it (parents first); the render that drew the call doesn't
-- run. The entry's release ends its bindings.
local _, ns = ...

local Tracking, Scheduler = ns.Tracking, ns.Scheduler
local xpcall = xpcall

---@class OrdaenBinding
---@field fn fun(game: table, self: table, item: any): any the expression
---@field fields string[] the fields it feeds
---@field nFields integer
---@field node table the backend node
---@field owner table the instance whose render (or slot) drew the call: the expression's self
---@field item any the call's key: the expression's item
---@field value any the last value written
local Binding = {}
local BindingMeta = { __index = Binding }

local seq = 0 -- creation order within a depth, after the instances' own effects (their numbers are below 2^31)

---@param fn function
---@param node table
---@param owner table
---@param item any
---@return OrdaenBinding
function ns.NewBinding(fn, node, owner, item)
	seq = seq + 1
	return setmetatable({
		fn = fn, fields = {}, nFields = 0, node = node, owner = owner, item = item,
		order = owner._depth * 4294967296 + 2147483648 + seq, dirty = false, alive = true,
		sources = {}, nSources = 0,
	}, BindingMeta)
end

function Binding:Mark()
	if self.dirty or not self.alive then
		return
	end
	self.dirty = true
	Scheduler.Queue(self)
end

--- Run the expression (its reads tracked) and write the value into every field it feeds, if it changed.
function Binding:Run()
	self.dirty = false
	Tracking.Clear(self)
	local previous = Tracking.observer
	Tracking.observer = self
	local owner = self.owner
	local ok, value = xpcall(self.fn, ns.OnError, owner._game, owner, self.item)
	Tracking.observer = previous
	if not ok or value == self.value and self.written then
		return
	end
	self.value, self.written = value, true
	local backend, node, fields = ns.Backend, self.node, self.fields
	for i = 1, self.nFields do
		backend:SetField(node, fields[i], value)
	end
end

--- The entry is gone: stop observing.
function Binding:End()
	self.alive = false
	Tracking.Clear(self)
end

--- Bind `entry`'s node to the call's `bind` map (field -> expression), one Binding per distinct expression, and
--- write each field once. `entry.bindings` keeps them for the release.
---@param entry table
---@param bind table<string, function>
---@param owner table
---@param item any
function ns.Bind(entry, bind, owner, item)
	local list = entry.bindings
	if not list then
		list = {}
		entry.bindings = list
	end
	local n = 0
	for field, fn in pairs(bind) do
		local b
		for i = 1, n do
			if list[i].fn == fn then
				b = list[i]
				break
			end
		end
		if not b then
			b = ns.NewBinding(fn, entry.node, owner, item)
			n = n + 1
			list[n] = b
		end
		b.nFields = b.nFields + 1
		b.fields[b.nFields] = field
	end
	entry.nBindings = n
	entry.bind = bind
	for i = 1, n do
		list[i]:Run()
	end
end

--- End `entry`'s bindings (its release, or a call that binds differently).
---@param entry table
function ns.Unbind(entry)
	local list = entry.bindings
	if not list then
		return
	end
	for i = 1, entry.nBindings or 0 do
		list[i]:End()
		list[i] = nil
	end
	entry.nBindings, entry.bind = 0, nil
end
