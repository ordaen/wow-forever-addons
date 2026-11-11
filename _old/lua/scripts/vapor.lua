-- Vapor: how should a changed value reach the screen? A prototype, measured offline in the fake client
-- (tests/fake/wow.lua) on the built Ordaen (.ordaen/check/dist: `ordaen test` or `ordaen lint` builds it), with Lua
-- VM instructions counted by a hook (deterministic: a running game doesn't disturb it; C functions count 0, so it
-- compares engine strategies with each other, never with WoW) and the Lua heap after a full collection.
--
-- The same screen three ways: a grid of N texts, each showing one value signal.
--   render   today: one component per text; a change re-runs that component's render, which draws its text call
--            (the call diffed against its last attributes, then the backend's Set).
--   link     a binding object per text: the signal's observer is the binding itself (one table, its methods on a
--            shared metatable), which reads the value through a shared expression function and writes the field.
--   closure  a binding per text that holds a closure made for it (the expression with the item captured).
-- Both binding kinds write the node through the backend's Set with the text's own attribute table; a dedicated
-- SetField would cut the backend's share for both alike.
--
-- Run from the repo root: ordaen lua scripts/vapor.lua [N]
package.path = "./?.lua;" .. package.path
local Fake = require("tests.fake.wow")

local N = tonumber(arg and arg[1]) or 1000
local DIST = ".ordaen/check/dist"

local function client()
	local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
	wow:Login()
	return wow, wow.addons.OrdaenCore.ns
end

-- Instructions `fn` runs (sampled every 7 VM instructions: a prime, so loops don't alias with it).
local function count(fn)
	local n = 0
	debug.sethook(function()
		n = n + 7
	end, "", 7)
	fn()
	debug.sethook()
	return n
end

local function heap()
	collectgarbage("collect")
	collectgarbage("collect")
	return collectgarbage("count")
end

-- A module the engine can mount components of, with `components/<name>` from `declarations`.
local function fakeModule(ns, declarations)
	local module = { name = "OrdaenVapor", ns = {}, cache = {} }
	function module.Import(_, path)
		return declarations[path]
	end
	return module, ns.Game.ForModule(module)
end

local STRATEGIES = {}

-- render: today's way --------------------------------------------------------------------------------------------
function STRATEGIES.render(ns, values)
	local calls = {}
	for i = 1, N do
		calls[i] = { attributes = { text = "" } }
	end
	local Item = ns.Define.Component({
		Render = function(g, self)
			local i = self._key
			local call = calls[i]
			call.attributes.text = values[i]:Get()
			g.ui:Text(1, call)
		end,
	})
	local items = {}
	for i = 1, N do
		items[i] = { key = i }
	end
	local function Cells(g)
		for i = 1, N do
			g.ui:Item(2, items[i])
		end
	end
	local Grid = ns.Define.Component({
		Render = function(g)
			g.ui:Box(1, { attributes = { columns = 10 }, slots = { default = Cells } })
		end,
	})
	local module, game = fakeModule(ns, { ["components/item"] = Item })
	return function()
		ns.Engine:Mount(nil, Grid, 0, {}, ns.Game.Layer.Screen, module, game)
	end
end

-- The bindings' common part: a grid drawn once, its text nodes captured as the backend makes them.
local function staticGrid(ns, values)
	local texts, calls = {}, {}
	for i = 1, N do
		calls[i] = { attributes = { text = values[i]:Peek() } }
	end
	local Grid = ns.Define.Component({
		Render = function(g)
			g.ui:Box(1, { attributes = { columns = 10 }, slots = { default = function(g2)
				for i = 1, N do
					g2.ui:Text(2, { key = i, attributes = calls[i].attributes })
				end
			end } })
		end,
	})
	local module, game = fakeModule(ns, {})
	local Create = ns.Backend.Create
	return function()
		ns.Backend.Create = function(backend, kind)
			local node = Create(backend, kind)
			if kind == "text" then
				texts[#texts + 1] = node
			end
			return node
		end
		ns.Engine:Mount(nil, Grid, 0, {}, ns.Game.Layer.Screen, module, game)
		ns.Scheduler.Flush()
		ns.Backend.Create = Create
	end, texts, calls
end

-- the scheduler runs what it queued by its own Run (Signal.lua), so these bindings need no engine change
local order = 2 ^ 40 -- after every component: bindings run once their parents have

-- link: a binding object, the expression shared --------------------------------------------------------------------
local Link = {}
local LinkMeta = { __index = Link }

function Link:Mark()
	if not self.dirty then
		self.dirty = true
		self.Scheduler.Queue(self)
	end
end

function Link:Run()
	self.dirty = false
	local source = self.source
	source.notified = nil -- the binding reads only this source: it stays subscribed, so the next write marks again
	local v = self.expr(source)
	local a = self.attributes
	if a.text ~= v then
		a.text = v
		self.node.src = nil -- (the prototype's stand-in for a SetField: Set skips the table it drew last)
		self.backend:Set(self.node, a)
	end
end

local function value(source)
	return source.value
end

function STRATEGIES.link(ns, values)
	local draw, texts, calls = staticGrid(ns, values)
	return function()
		draw()
		for i = 1, N do
			order = order + 1
			local link = setmetatable({ binding = true, source = values[i], node = texts[i],
				attributes = calls[i].attributes, expr = value, dirty = false, alive = true, order = order,
				Scheduler = ns.Scheduler, backend = ns.Backend }, LinkMeta)
			local observers = values[i].observers or {}
			values[i].observers = observers
			observers[link] = true
		end
	end
end

-- closure: a binding holding its own closure ------------------------------------------------------------------------
local Closure = {}
local ClosureMeta = { __index = Closure }
Closure.Mark = Link.Mark

function Closure:Run()
	self.dirty = false
	self.fn()
end

function STRATEGIES.closure(ns, values)
	local draw, texts, calls = staticGrid(ns, values)
	return function()
		draw()
		local backend = ns.Backend
		for i = 1, N do
			order = order + 1
			local source, node, a = values[i], texts[i], calls[i].attributes
			local binding = setmetatable({ binding = true, dirty = false, alive = true, order = order,
				Scheduler = ns.Scheduler }, ClosureMeta)
			binding.fn = function()
				source.notified = nil
				local v = source.value
				if a.text ~= v then
					a.text = v
					node.src = nil
					backend:Set(node, a)
				end
			end
			local observers = source.observers or {}
			source.observers = observers
			observers[binding] = true
		end
	end
end

-- Measure ---------------------------------------------------------------------------------------------------------

local rows = {}
for _, name in ipairs({ "render", "link", "closure" }) do
	local wow, ns = client()
	local values = {}
	for i = 1, N do
		values[i] = ns.NewValue(i)
	end
	local mount = STRATEGIES[name](ns, values)
	local before = heap()
	local mountInsn = count(function()
		mount()
		ns.Scheduler.Flush()
	end)
	local kept = heap() - before
	local flush = ns.Scheduler.Flush
	local one = count(function()
		values[math.floor(N / 2)]:Set(-1)
		flush()
	end)
	local all = count(function()
		for i = 1, N do
			values[i]:Set(i * 7)
		end
		flush()
	end)
	local same = count(function()
		for i = 1, N do
			values[i]:Set(i * 7) -- equal: nothing to do
		end
		flush()
	end)
	-- the screen shows the values: every text node's text
	local shown, wrong = 0, 0
	local layer = ns.Game.Layer.Screen.node
	local function walk(node)
		if node.kind == "text" then
			shown = shown + 1
			local t = node.fs:GetText()
			if t ~= tostring(values[shown]:Peek()) then
				wrong = wrong + 1
			end
		end
		for i = 1, node.count or 0 do
			walk(node.children[i])
		end
	end
	walk(layer)
	rows[#rows + 1] = string.format("%-8s mount %9d insn, kept %8.1f KB (%5.0f B/text) | one changed %7d | all changed"
		.. " %9d (%6.0f/text) | %d unchanged writes %7d | %d texts, %d wrong, %d errors", name, mountInsn, kept,
		kept * 1024 / N, one, all, all / N, N, same, shown, wrong, #wow.errors)
	if #wow.errors > 0 then
		rows[#rows + 1] = "  first error: " .. wow.errors[1]:sub(1, 300)
	end
end
print(string.format("Vapor, %d texts (Lua VM instructions; heap kept after the mount)", N))
for _, r in ipairs(rows) do
	print(r)
end
