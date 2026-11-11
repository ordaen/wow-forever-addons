-- The LunaType runtime: what compiled code calls. Ownership, cells and what follows them, events and tasks; it
-- knows nothing of components or of the game. A host drives it by calling `update(now)` once a frame.
--
-- Fields the runtime keeps on a table carry a `$` in their key, which no LunaType name can have, so they never meet
-- a field of the program.
local R = {}
LunaType = R

local pairs, setmetatable, byte = pairs, setmetatable, string.byte
local floor = math.floor

-- `"$math"` and `"$string"`: Lua's own libraries, and the few functions the language adds to them.
R.math = setmetatable({
	round = function(x)
		return floor(x + 0.5)
	end,
}, { __index = math })
R.string = setmetatable({ of = tostring, toNumber = tonumber }, { __index = string })
function R.string.contains(text, part)
	return string.find(text, part, 1, true) ~= nil
end
function R.string.captures(text, pattern)
	local a, b, c, d = string.match(text, pattern)
	if a == nil then
		return nil
	end
	return { a, b, c, d }
end

function R.string.split(text, separator)
	local pieces, n, from = {}, 0, 1
	while true do
		local at, to = string.find(text, separator, from, true)
		n = n + 1
		if not at then
			pieces[n] = string.sub(text, from)
			return pieces
		end
		pieces[n] = string.sub(text, from, at - 1)
		from = to + 1
	end
end

-- A format of the game's as a pattern that reads back the text it made, kept by the format: a format code
-- captures, the game's plural code stands for one word, everything else is itself.
local unformats = {}
function R.string.unformat(text, fmt)
	local pattern = unformats[fmt]
	if not pattern then
		local p = string.gsub(fmt, "|4[^;]*;", "\001")
		p = string.gsub(p, "%%%%", "\002")
		p = string.gsub(p, "%%[%d%$]*%.?%d*[sdfgiu]", "\003")
		p = string.gsub(p, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
		p = string.gsub(p, "\003", "(.-)")
		p = string.gsub(p, "\001", "%%S+")
		p = string.gsub(p, "\002", "%%%%")
		pattern = "^" .. p .. "$"
		unformats[fmt] = pattern
	end
	local a, b, c, d = string.match(text, pattern)
	if a == nil then
		return nil
	end
	return { a, b, c, d }
end
local create, resume, yield = coroutine.create, coroutine.resume, coroutine.yield

-- Ownership ----------------------------------------------------------------------------------------------------------
-- Whoever makes something is its owner: the owner keeps it in `$own`, and ending the owner ends it. A thing knows
-- its owner and its place in that list, so ending one thing takes it out of the list without a search.

local function adopt(owner, thing)
	if owner then
		local own = owner["$own"]
		if not own then
			own = {}
			owner["$own"] = own
		end
		local n = #own + 1
		own[n] = thing
		thing["$owner"], thing["$at"] = owner, n
	end
	return thing
end
R.adopt = adopt

-- Take `thing` out of its owner's list: the last one moves into its place.
local function disown(thing)
	local owner = thing["$owner"]
	if owner then
		local own = owner["$own"]
		local at, n = thing["$at"], #own
		local last = own[n]
		own[at], own[n] = last, nil
		last["$at"] = at
		thing["$owner"] = nil
	end
end

-- End everything `owner` made and started, newest first.
local function endOwned(owner)
	local own = owner["$own"]
	if own then
		for i = #own, 1, -1 do
			local thing = own[i]
			own[i] = nil
			thing["$owner"] = nil
			thing["$end"](thing)
		end
	end
end

-- `destroy x`: the class's `$destructor` runs, then what it owns is ended. A class's table has `$end = destroy`.
local function destroy(obj)
	if obj["$dead"] then
		return
	end
	obj["$dead"] = true
	disown(obj)
	local destructor = obj["$destructor"]
	if destructor then
		destructor(obj)
	end
	endOwned(obj)
end
R.destroy = destroy

-- Make `class` a class: instances find its methods through it, and it can be owned and destroyed.
function R.class(class)
	class.__index = class
	class["$end"] = destroy
	class["$is"] = { [class] = true }
	return class
end

-- `class` implements the abstract classes `parents`: the bodies it didn't write itself are copied in once, here, so
-- a call is one lookup. Called after every method of the file is defined, parents before the classes that
-- implement them.
function R.inherit(class, parents)
	local is = class["$is"]
	for i = 1, #parents do
		local parent = parents[i]
		for key, value in pairs(parent) do
			if class[key] == nil and byte(key) ~= 36 then -- not a `$` key: those are each class's own
				class[key] = value
			end
		end
		for ancestor in pairs(parent["$is"]) do
			is[ancestor] = true
		end
	end
end

-- An addon's table: what each of its files declares, by the file's path.
local addons = {}
function R.addon(name)
	local addon = addons[name]
	if not addon then
		addon = {}
		addons[name] = addon
	end
	return addon
end

-- What is kept between sessions: the account's table, or the character's. The client fills them from the last
-- session when LunaType's own files have loaded, before any addon's, and writes them as the session ends.
function R.saved(character)
	local name = character and "LunaTypeCharDB" or "LunaTypeDB"
	local kept = rawget(_G, name)
	if type(kept) ~= "table" then
		kept = {}
		rawset(_G, name, kept)
	end
	return kept
end

-- An addon's root (a class that implements `App`): made once, as its file ends.
R.roots = {}
function R.run(class, addon)
	R.roots[addon] = class.new(nil)
end

-- `new? Class(...)`: a class of another addon, which may not be loaded. Its addon is loaded where the client can
-- load it, and one is made; nil where it can't.
function R.make(addon, file, name, owner, ...)
	local module = addons[addon] and addons[addon][file]
	if not module then
		local namespace = R.client.C_AddOns
		if namespace and namespace.LoadAddOn then
			namespace.LoadAddOn(addon)
		end
		module = addons[addon] and addons[addon][file]
		if not module then
			return nil
		end
	end
	return module[name].new(owner, ...)
end

-- `x implements T`, for a value already known to be a class.
function R.implements(obj, class)
	return obj["$is"][class] == true
end

-- `x is class`
function R.isClass(value)
	return type(value) == "table" and value["$is"] ~= nil
end

-- `x implements T` for a value that may be anything.
function R.isA(value, class)
	if type(value) ~= "table" then
		return false
	end
	local is = value["$is"]
	return is ~= nil and is[class] == true
end

-- The language's own declarations: `Error`, what every error class implements.
local Error = R.class({})
R.lang = { Error = Error, Display = R.class({}) }

function R.isError(value)
	if type(value) ~= "table" then
		return false
	end
	local is = value["$is"]
	return is ~= nil and is[Error] == true
end

-- A class whose constructor refused: what it had made and started is ended, and its destructor doesn't run.
function R.abandon(obj)
	obj["$dead"] = true
	disown(obj)
	endOwned(obj)
end

-- Cells --------------------------------------------------------------------------------------------------------------
-- A cell is { [1] = value, [2] = who read it whole, [3] = who read which key, [4] = who read its shape }. Each of
-- those is a set of observers, made on its first tracked read. A computed cell has more: [5] dirty, [6] its
-- function, [7] the `self` it is called with.
--
-- An observer (a computed cell, a watch, a binding) has `sources`, the sets it stands in, so forgetting what it read
-- is one pass over that array, and `mark`, what a change does to it.
--
-- A change goes out in two strengths. Whoever read the cell that was written is marked for sure. Whoever read a
-- computed cell that was marked is marked to check: before it runs again, the computed cells it read are brought
-- up to date, and it runs only where one of them came out with another value. So a computed cell that works out
-- the same value as before stops the change there. A computed cell counts its values (`v`); an observer keeps the
-- computed cells it read (`from`) with the count each had (`seen`).

local observer = nil -- who is recording its reads now

-- A set of observers is a list with each one's place in it (`set[i] = o`, `set[o] = i`, `set.n` of them): they
-- are told of a change in the order they came to read, the same in every session. (A table walked by its keys
-- gives them in the order of their addresses, which differs from one start of the game to the next.)
local function track(set, o, cell)
	if not set[o] then
		local at = (set.n or 0) + 1
		set.n = at
		set[at], set[o] = o, at
		local n = o.n + 1
		o.n = n
		o.sources[n] = set
		if cell[6] then
			-- A computed cell: which value of it was read.
			local from = o.from
			if not from then
				from = {}
				o.from, o.seen, o.m = from, {}, 0
			end
			local m = o.m + 1
			o.m = m
			from[m], o.seen[m] = cell, cell.v
		end
	end
end

local function forget(o)
	local sources = o.sources
	for i = 1, o.n do
		-- The last one of the set takes its place.
		local set = sources[i]
		local at, last = set[o], set.n
		local moved = set[last]
		set[at], set[moved] = moved, at
		set[last], set[o] = nil, nil
		set.n = last - 1
		sources[i] = nil
	end
	o.n = 0
	local from = o.from
	if from then
		for i = 1, o.m do
			from[i] = nil
		end
		o.m = 0
	end
end

-- `sure`: what they read was written. Otherwise a computed cell they read may have another value: to check.
local function notify(set, sure)
	if set then
		for i = 1, set.n or 0 do
			local o = set[i]
			o.mark(o, sure)
		end
	end
end

local function recompute(cell)
	forget(cell)
	local previous = observer
	observer = cell
	cell[5] = false
	local value = cell[6](cell[7], cell[8], cell[9], cell[10])
	observer = previous
	local v = cell.v
	if value ~= cell[1] or not v then
		cell[1] = value
		cell.v = (v or 0) + 1
	end
end

local refresh

-- Whether a computed cell `o` read has another value now than the one it read.
local function changed(o)
	local from = o.from
	if from then
		local seen = o.seen
		for i = 1, o.m do
			local cell = from[i]
			if cell[5] then
				refresh(cell)
			end
			if cell.v ~= seen[i] then
				return true
			end
		end
	end
	return false
end

-- Bring a marked computed cell up to date: worked out again where what it read was written or came out with
-- another value, left as it is where everything it read came out the same.
function refresh(cell)
	if cell[5] == true or changed(cell) then
		recompute(cell)
	else
		cell[5] = false
	end
end

-- Read a cell's value. Everything that reruns and reads it this way reruns when it is assigned or anything in it
-- changes.
local function get(cell)
	if cell[5] then
		refresh(cell)
	end
	local o = observer
	if o then
		local set = cell[2]
		if not set then
			set = {}
			cell[2] = set
		end
		track(set, o, cell)
	end
	return cell[1]
end
R.get = get

-- Read one entry of the list, map or struct a cell holds: only that entry is depended on.
function R.getKey(cell, key)
	if cell[5] then
		refresh(cell)
	end
	local o = observer
	if o then
		local keys = cell[3]
		if not keys then
			keys = {}
			cell[3] = keys
		end
		local set = keys[key]
		if not set then
			set = {}
			keys[key] = set
		end
		track(set, o, cell)
	end
	return cell[1][key]
end

-- Read the length of the list a cell holds: depended on is its shape, entries added and removed.
function R.len(cell)
	if cell[5] then
		refresh(cell)
	end
	local o = observer
	if o then
		local set = cell[4]
		if not set then
			set = {}
			cell[4] = set
		end
		track(set, o, cell)
	end
	return #cell[1]
end

-- The value now, not depended on.
function R.peek(cell)
	if cell[5] then
		refresh(cell)
	end
	return cell[1]
end

-- Assign a cell: everyone who read it, any entry of it or its shape is marked. A cell that stands for one entry of
-- another (`R.lens`) writes that entry.
function R.set(cell, value)
	local of = cell.of
	if of then
		return R.setKey(of, cell.key, value)
	end
	if cell[1] == value then
		return
	end
	cell[1] = value
	notify(cell[2], true)
	local keys = cell[3]
	if keys then
		for _, set in pairs(keys) do
			notify(set, true)
		end
	end
	notify(cell[4], true)
end

-- Assign one entry of what a cell holds: marked are those who read that entry or the whole, and those who read the
-- shape when an entry comes or goes.
function R.setKey(cell, key, value)
	local of = cell.of
	if of then
		-- An entry of what stands for one entry of another cell (`R.lens`): that entry is written anew, a copy
		-- with this one key changed, so nobody who holds the old one sees it change under them.
		local whole = R.peek(cell)
		if whole[key] == value then
			return
		end
		local changed = {}
		for k, v in pairs(whole) do
			changed[k] = v
		end
		changed[key] = value
		return R.setKey(of, cell.key, changed)
	end
	local t = cell[1]
	local old = t[key]
	if old == value then
		return
	end
	t[key] = value
	notify(cell[2], true)
	local keys = cell[3]
	if keys then
		notify(keys[key], true)
	end
	if old == nil or value == nil then
		notify(cell[4], true)
	end
end

-- An entry of what a cell holds was changed in place (a field of a struct in a list): those who read that entry or
-- the whole are marked.
function R.touchKey(cell, key)
	notify(cell[2], true)
	local keys = cell[3]
	if keys then
		notify(keys[key], true)
	end
end

function R.cell(value)
	return { value }
end

-- Add to the end of the list a cell holds; take its last entry off.
function R.push(cell, value)
	R.setKey(cell, #cell[1] + 1, value)
end

function R.pop(cell)
	local t = cell[1]
	local n = #t
	local value = t[n]
	if n > 0 then
		R.setKey(cell, n, nil)
	end
	return value
end

-- [5] is false while its value stands, 1 while a computed cell it read may have changed, true once something it
-- read was written. Its readers hear of the first of those, to check: its value may come out the same.
local function markComputed(cell, sure)
	local was = cell[5]
	if sure then
		if was == true then
			return
		end
		cell[5] = true
	else
		if was then
			return
		end
		cell[5] = 1
	end
	if not was then
		notify(cell[2], false)
		local keys = cell[3]
		if keys then
			for _, set in pairs(keys) do
				notify(set, false)
			end
		end
		notify(cell[4], false)
	end
end

local function endObserver(o)
	o.dead = true
	forget(o)
end

-- A cell that follows what `fn(self)` reads. It is worked out when first read, and again after something it read
-- changed. `a`, `b` and `c` are a template's variables, for a cell the compiler makes inside one.
function R.computed(owner, fn, self, a, b, c)
	local cell = { nil, nil, nil, nil, true, fn, self, a, b, c, sources = {}, n = 0, mark = markComputed, ["$end"] = endObserver }
	return adopt(owner, cell)
end

-- Write access to one entry of what `cell` holds, handed over as a cell: it reads that entry, follows it, and a
-- write to it writes the entry.
function R.lens(owner, cell, key)
	local lens = R.computed(owner, R.getKey, cell, key)
	lens.of, lens.key = cell, key
	return lens
end

-- The game's side of drawing, set by `R.setHost`: see «Drawing» below.
local host

-- The scheduler ------------------------------------------------------------------------------------------------------
-- A write never runs anything: it marks. What was marked runs in `update`, once a frame, in the order it was marked.

local queue, queued = {}, 0

local function markEffect(effect, sure)
	if sure then
		effect.sure = true
	end
	if not effect.waiting and not effect.dead then
		effect.waiting = true
		queued = queued + 1
		queue[queued] = effect
	end
end

local function runEffect(effect)
	forget(effect)
	local previous = observer
	observer = effect
	effect.fn(effect.self)
	observer = previous
end

-- `fn(self)` runs now, and again whenever what it read has changed.
function R.watch(owner, fn, self)
	local effect = { fn = fn, self = self, sources = {}, n = 0, mark = markEffect, run = runEffect, ["$end"] = endObserver }
	adopt(owner, effect)
	runEffect(effect)
	return effect
end

local MAX_RUNS = 100 -- runs of one effect in one flush: past it, it is writing what it reads
local flushes = 0

-- What a run marks joins the queue and runs in this same flush.
local function flush()
	flushes = flushes + 1
	local i = 1
	while i <= queued do
		local effect = queue[i]
		queue[i] = nil
		i = i + 1
		effect.waiting = false
		if not effect.dead then
			if effect.flush ~= flushes then
				effect.flush, effect.runs = flushes, 0
			end
			effect.runs = effect.runs + 1
			if effect.runs > MAX_RUNS then
				queued = 0
				error("LunaType: a watch keeps re-running itself (it writes what it reads)", 0)
			end
			-- Marked only through computed cells, it runs where one of them has another value now.
			if effect.sure or changed(effect) then
				effect.sure = false
				effect.run(effect)
			end
		end
	end
	queued = 0
end
R.flush = flush

-- Run `fn(...)` with nothing recording: what it reads is not depended on.
function R.untracked(fn, ...)
	local previous = observer
	observer = nil
	local a, b, c = fn(...)
	observer = previous
	return a, b, c
end

-- Events -------------------------------------------------------------------------------------------------------------
-- An event is { n, fns, objs }: its listeners are a method and the object it is called on, side by side. A listener
-- taken away while the event fires leaves `false` behind, cleared when the firing ends.

function R.event()
	return { n = 0, fns = {}, objs = {}, firing = 0 }
end

local function compact(event)
	local fns, objs, j = event.fns, event.objs, 0
	for i = 1, event.n do
		if fns[i] then
			j = j + 1
			fns[j], objs[j] = fns[i], objs[i]
		end
	end
	for i = j + 1, event.n do
		fns[i], objs[i] = nil, nil
	end
	event.n = j
	event.holes = nil
end

local function unlisten(listener)
	local event, fn, obj = listener.event, listener.fn, listener.obj
	local fns, objs = event.fns, event.objs
	for i = event.n, 1, -1 do
		if fns[i] == fn and objs[i] == obj then
			fns[i] = false
			if event.firing == 0 then
				compact(event)
			else
				event.holes = true
			end
			return
		end
	end
end

-- `event.listen(obj.method)`: the listener is `obj`'s, and stops when `obj` is destroyed.
function R.listen(event, obj, fn)
	local n = event.n + 1
	event.n = n
	event.fns[n], event.objs[n] = fn, obj
	return adopt(obj, { event = event, fn = fn, obj = obj, ["$end"] = unlisten })
end

-- `event.emit(...)`: every listener is called with the payload. An event nobody listens to costs one test.
function R.emit(event, ...)
	local n = event.n
	if n == 0 then
		return
	end
	local fns, objs = event.fns, event.objs
	event.firing = event.firing + 1
	for i = 1, n do
		local fn = fns[i]
		if fn then
			fn(objs[i], ...)
		end
	end
	event.firing = event.firing - 1
	if event.firing == 0 and event.holes then
		compact(event)
	end
end

-- Tasks --------------------------------------------------------------------------------------------------------------
-- A task is a coroutine from a pool. It gives the frame back by yielding one of: SLEEP and a time, FRAME, WAIT and
-- another task. `update` resumes what is due.

local SLEEP, FRAME, WAIT, DONE = 1, 2, 3, 4

local pool, pooled = {}, 0
local ready, nReady = {}, 0 -- tasks to resume on the next update
local batch = {} -- the tasks being resumed in this one
local sleeping, nSleeping = {}, 0 -- tasks waiting for a time
local now = 0
-- Cells that follow the host's time: each holds how many of its periods have passed, or the time itself with a
-- period of nought, brought up to date at the start of a frame. Only one that somebody reads keeps the frames
-- coming. A host that stopped calling `update` calls it before it hands anything in.
local tickers, nTickers = {}, 0

function R.ticker(period)
	local cell = R.cell(period > 0 and floor(now / period) or now)
	cell.period = period
	nTickers = nTickers + 1
	tickers[nTickers] = cell
	return cell
end
local current = nil -- the task running now

local function finish(task, ...)
	task.done = true
	task.result = ...
	disown(task)
	local waiters = task.waiters
	if waiters then
		for i = 1, #waiters do
			nReady = nReady + 1
			ready[nReady] = waiters[i]
		end
		task.waiters = nil
	end
end

-- The body of every pooled coroutine: run one task's function, then wait to be handed the next.
local function loop(task, fn, ...)
	finish(task, fn(...))
	return loop(yield(DONE))
end

local function step(task, ...)
	local previous = current
	current = task
	local ok, what, arg = resume(task.co, ...)
	current = previous
	if not ok then
		task.done = true
		disown(task)
		error(what, 0)
	end
	if what == DONE then
		pooled = pooled + 1
		pool[pooled] = task.co
		task.co = nil
	elseif what == SLEEP then
		task.due = now + arg
		nSleeping = nSleeping + 1
		sleeping[nSleeping] = task
	elseif what == FRAME then
		nReady = nReady + 1
		ready[nReady] = task
	elseif what == WAIT then
		local waiters = arg.waiters
		if not waiters then
			waiters = {}
			arg.waiters = waiters
		end
		waiters[#waiters + 1] = task
	end
end

local function cancel(task)
	task.dead = true
end

-- Calling an async function: `fn(...)` starts as a task of `owner` and runs at once, up to its first wait.
function R.spawn(owner, fn, ...)
	local co
	if pooled > 0 then
		co = pool[pooled]
		pool[pooled] = nil
		pooled = pooled - 1
	else
		co = create(loop)
	end
	local task = { co = co, ["$end"] = cancel }
	adopt(owner, task)
	step(task, task, fn, ...)
	return task
end

-- `await task`
function R.await(task)
	if not task.done then
		yield(WAIT, task)
	end
	return task.result
end

-- Wait `seconds` of the host's time; the next frame.
function R.sleep(seconds)
	yield(SLEEP, seconds)
end

function R.frame()
	yield(FRAME)
end

-- One frame: tasks that are due run, then what was marked.
function R.update(time)
	now = time
	for i = 1, nTickers do
		local cell = tickers[i]
		local period = cell.period
		R.set(cell, period > 0 and floor(time / period) or time)
	end
	if nSleeping > 0 then
		local kept = 0
		for i = 1, nSleeping do
			local task = sleeping[i]
			sleeping[i] = nil
			if task.dead then
				-- dropped
			elseif task.due <= time then
				nReady = nReady + 1
				ready[nReady] = task
			else
				kept = kept + 1
				sleeping[kept] = task
			end
		end
		nSleeping = kept
	end
	if nReady > 0 then
		-- what a task makes ready while it runs waits for the next frame
		local n = nReady
		ready, batch, nReady = batch, ready, 0
		for i = 1, n do
			local task = batch[i]
			batch[i] = nil
			if not task.dead and not task.done then
				step(task)
			end
		end
	end
	if queued > 0 then
		flush()
	end
	-- What changed is laid out and placed once, after everything that changed it.
	if host and host.flush then
		host.flush()
	end
end

-- Whether anything waits for a frame: a host may stop calling `update` while nothing does.
function R.idle()
	for i = 1, nTickers do
		local set = tickers[i][2]
		if set and set.n > 0 then
			return false
		end
	end
	return nReady == 0 and nSleeping == 0 and queued == 0
end

-- `"$debug"`: the dev kit. Where the dev addon is loaded (it loads before this file: an optional dependency in
-- the TOC), a line goes to its log; a player doesn't have it, and a dev build's lines go nowhere.
do
	local dev = rawget(_G, "OrdaenCoreDebug")
	local kit = type(dev) == "table" and dev.NewDebug and dev.NewDebug("LunaType")
	R.debug = {
		log = kit and function(format, ...)
			kit:Logf(format, ...)
		end or function() end,
	}
end

-- `"$runtime"`: what the game's side takes from here.
R.runtime = {
	ticker = R.ticker,
	time = function()
		return R.ticker(0)
	end,
	press = function(frame, button)
		local run = R.client.ExecuteFrameScript
		if frame:HasScript("OnMouseDown") and frame:GetScript("OnMouseDown") then
			run(frame, "OnMouseDown", button)
		end
		if frame:HasScript("OnMouseUp") and frame:GetScript("OnMouseUp") then
			run(frame, "OnMouseUp", button)
		end
		if frame.Click and frame:GetScript("OnClick") then
			frame:Click(button)
		end
	end,
	hover = function(frame, on)
		local script = on and "OnEnter" or "OnLeave"
		if frame:GetScript(script) then
			R.client.ExecuteFrameScript(frame, script)
		end
	end,
	picture = function(file)
		return file
	end,
	whenShown = function(path, callback)
		local frame = R.runtime.frame(path)
		if not frame then
			return false
		end
		frame:HookScript("OnShow", function()
			callback()
		end)
		return true
	end,
	screen = function()
		if not R.screenRoot then
			R.screenRoot = R.wow.root(R.client.UIParent)
		end
		return R.screenRoot
	end,
	mount = function(component, on)
		R.mount(component, on)
	end,
	kept = function(character, key, initial)
		local all = R.saved(character)
		if type(all[key]) ~= "table" then
			all[key] = initial
		end
		return all[key]
	end,
	restored = function(character, name, defaults)
		local values = R.runtime.copy(defaults)
		local shelf = R.saved(character).settings
		local was = type(shelf) == "table" and shelf[name]
		if type(was) == "table" then
			for key, value in pairs(was) do
				if type(value) == type(defaults[key]) then
					values[key] = value
				end
			end
		end
		return values
	end,
	store = function(character, name, values)
		local all = R.saved(character)
		if type(all.settings) ~= "table" then
			all.settings = {}
		end
		all.settings[name] = R.runtime.copy(values)
	end,
	copy = function(value)
		local to = {}
		for key, inner in pairs(value) do
			to[key] = inner
		end
		return to
	end,
	differing = function(one, other)
		local n = 0
		for key, value in pairs(one) do
			if other[key] ~= value then
				n = n + 1
			end
		end
		for key in pairs(other) do
			if one[key] == nil then
				n = n + 1
			end
		end
		return n
	end,
	command = function(slash, run)
		local name = slash:gsub("%W", ""):upper()
		rawset(_G, "SLASH_" .. name .. "1", slash)
		R.client.SlashCmdList[name] = function(text)
			run(text or "")
		end
	end,
	text = function(name)
		local value = rawget(_G, name)
		return type(value) == "string" and value or nil
	end,
	publish = function(name, value)
		rawset(_G, name, value)
	end,
	frame = function(path)
		local found = _G
		for key in path:gmatch("[^.]+") do
			if type(found) ~= "table" then
				return nil
			end
			found = found[key]
		end
		return found
	end,
}

-- The client ---------------------------------------------------------------------------------------------------------
-- `"$client"` is the client's own API by its names. `"$events"` is its events: each is made when a file first names
-- it, and heard from the client from `start` on.
R.client = _G

local heard, nHeard = {}, 0
local driver -- the frame the client's events and frames come in through

R.events = setmetatable({}, {
	__index = function(events, name)
		local event = R.event()
		rawset(events, name, event)
		nHeard = nHeard + 1
		heard[nHeard] = name
		if driver then
			driver:RegisterEvent(name)
		end
		return event
	end,
})

-- Start in the client: draw through the game's host, hear the client's events, and run a frame whenever something
-- waits for one. The time is brought up to date once a frame, before the first thing the client hands in.
function R.start()
	local client = R.client
	local getTime = client.GetTime
	local events, emit, update, idle = R.events, R.emit, R.update, R.idle
	local pending = R.wow.pending
	local at = -1
	R.wow.install()
	driver = client.CreateFrame("Frame")
	for i = 1, nHeard do
		driver:RegisterEvent(heard[i])
	end
	driver:SetScript("OnEvent", function(_, name, ...)
		local time = getTime()
		if time ~= at then
			at = time
			update(time)
		end
		emit(events[name], ...)
	end)
	driver:SetScript("OnUpdate", function()
		if pending() or not idle() then
			at = getTime()
			update(at)
		end
	end)
end

-- Tests --------------------------------------------------------------------------------------------------------------
-- A file's tests, as it was loaded: each a name, where it stands in its source, and its function. Whoever runs
-- them loads everything anew for each, so one test leaves nothing to the next.
R.tests = {}

function R.test(name, at, fn)
	R.tests[#R.tests + 1] = { name = name, at = at, fn = fn }
end

-- `$provide`: `obj` is what a declared module is. The module's table gets the object's cells and values by their
-- names, and each of its functions as one that calls the object's method: made once, here.
function R.provide(home, name, path, obj, values, functions)
	local at = home[name]
	if not at then
		at = {}
		home[name] = at
	end
	for i = 1, #path do
		local inner = at[path[i]]
		if not inner then
			inner = {}
			at[path[i]] = inner
		end
		at = inner
	end
	for i = 1, #values do
		at[values[i]] = obj[values[i]]
	end
	for i = 1, #functions do
		local method = obj[functions[i]]
		at[functions[i]] = function(...)
			return method(obj, ...)
		end
	end
end

-- What a test holds to be so: `what` is the file, the line and the condition as written.
function R.expect(held, what)
	if not held then
		error(what, 0)
	end
end

-- Drawing ------------------------------------------------------------------------------------------------------------
-- What a template draws is a tree of nodes. A node is { h = the host's handle } and owns what stands inside it, so
-- ending a node ends its bindings, its children and the components made in it. The host is the game's side of
-- drawing: `create(kind, parentHandle)` gives a handle, `set(handle, name, value)` sets an attribute,
-- `on(handle, event, obj, fn)` listens, `order(handle, index)` places a row, `remove(handle)` takes it away.
--
-- The functions lifted out of a template take `self` and the template's variables, always in three places
-- (a, b, c): a `$for`'s variable stands in the place the compiler gave it.

function R.setHost(h)
	host = h
end

local function endNode(node)
	endOwned(node)
	host.remove(node.h)
end

-- End a node that is still in its owner's list.
local function drop(node)
	disown(node)
	node["$end"](node)
end

local function group(owner)
	return adopt(owner, { h = host.create("group", owner.h), ["$end"] = endNode })
end

-- `<box>`, `<text>`
function R.el(parent, kind)
	return adopt(parent, { h = host.create(kind, parent.h), ["$end"] = endNode })
end

-- An attribute that never changes.
function R.attr(node, name, value)
	host.set(node.h, name, value)
end

local function runBinding(binding)
	forget(binding)
	local previous = observer
	observer = binding
	local value = binding.fn(binding.self, binding.a, binding.b, binding.c)
	observer = previous
	host.set(binding.h, binding.name, value)
end

-- An attribute that follows what `fn` reads.
function R.bind(node, name, fn, self, a, b, c)
	local binding = {
		fn = fn, self = self, a = a, b = b, c = c, h = node.h, name = name,
		sources = {}, n = 0, mark = markEffect, run = runBinding, ["$end"] = endObserver,
	}
	adopt(node, binding)
	runBinding(binding)
end

-- `{expr}` between tags, as text.
function R.text(parent, fn, self, a, b, c)
	R.bind(R.el(parent, "text"), "value", fn, self, a, b, c)
end

-- `<input value={mut cell}>`: the field shows what the cell holds and follows it; what is typed is written to the
-- cell.
function R.input(node, cell)
	R.bind(node, "text", R.get, cell)
	host.on(node.h, "change", cell, R.set)
end

function R.on(node, event, obj, fn)
	host.on(node.h, event, obj, fn)
end

-- `$ltml { }` as a value: the function that draws it and the `self` it draws for.
function R.template(fn, self)
	return { fn, self }
end

-- `{template}` between tags.
function R.place(parent, template)
	template[1](template[2], parent)
end

-- Draw a component made in `parent`: `slots` is what its tag's children fill, by slot name, with the `self` and the
-- variables they are drawn for.
function R.draw(parent, component, slots)
	component["$slots"] = slots
	local template = component:render()
	template[1](template[2], parent)
end

-- `<slot>` in a component's template: what the parent gave for it, or the slot's own children. `values` is the
-- cells the slot passes to what fills it, in the order its class declares them.
function R.slot(parent, component, name, fallback, values, a, b, c)
	local slots = component["$slots"]
	local fn = slots and slots[name]
	if fn then
		fn(slots.self, parent, slots.a, slots.b, slots.c, values)
	elseif fallback then
		fallback(component, parent, a, b, c)
	end
end

local function endBlock(block)
	block.dead = true
	forget(block)
	endOwned(block)
	host.remove(block.h)
end

-- `$if`, `$elseif`, `$else`: `branches` is { test, draw, test, draw, ... }, a test of `false` standing for `$else`.
local function runWhen(block)
	forget(block)
	local previous = observer
	observer = block
	local branches, self, a, b, c = block.branches, block.self, block.a, block.b, block.c
	local chosen = 0
	for i = 1, #branches, 2 do
		local test = branches[i]
		if not test or test(self, a, b, c) then
			chosen = i
			break
		end
	end
	observer = previous
	if chosen ~= block.chosen then
		block.chosen = chosen
		if block.node then
			drop(block.node)
			block.node = nil
		end
		if chosen ~= 0 then
			local node = group(block)
			block.node = node
			branches[chosen + 1](self, node, a, b, c)
		end
	end
end

function R.when(parent, branches, self, a, b, c)
	local block = {
		h = host.create("group", parent.h), branches = branches, self = self, a = a, b = b, c = c, chosen = 0,
		sources = {}, n = 0, mark = markEffect, run = runWhen, ["$end"] = endBlock,
	}
	adopt(parent, block)
	runWhen(block)
end

-- `{template}` where which template it is follows cells: `value(self, a, b, c)` gives the one to draw. When it
-- gives another, what was drawn is ended and the new one drawn in its place.
local function runPlaced(block)
	forget(block)
	local previous = observer
	observer = block
	local template = block.value(block.self, block.a, block.b, block.c)
	observer = previous
	if template ~= block.drawn then
		block.drawn = template
		if block.node then
			drop(block.node)
			block.node = nil
		end
		if template then
			local node = group(block)
			block.node = node
			template[1](template[2], node)
		end
	end
end

function R.placed(parent, value, self, a, b, c)
	local block = {
		h = host.create("group", parent.h), value = value, self = self, a = a, b = b, c = c,
		sources = {}, n = 0, mark = markEffect, run = runPlaced, ["$end"] = endBlock,
	}
	adopt(parent, block)
	runPlaced(block)
end

-- `$for`: one row per item of the list `list(self, a, b, c)` gives. A row is told from another by `key` (its place
-- in the list when there is none): a kept row stays, a new one is drawn, a gone one is ended. `at` is which of the
-- three places the item stands in; `indexAt` the same for the index, or 0. With `cells`, a row's item is a cell
-- that follows its entry.
local probe = {}

local function place(at, value, a, b, c)
	if at == 1 then
		return value, b, c
	elseif at == 2 then
		return a, value, c
	end
	return a, b, value
end

local function runEach(block)
	forget(block)
	local previous = observer
	observer = block
	local self, a, b, c = block.self, block.a, block.b, block.c
	local list = block.list(self, a, b, c)
	observer = previous

	local rows, key, at, indexAt, cells = block.rows, block.key, block.at, block.indexAt, block.cells
	local round = block.round + 1
	block.round = round
	for i = 1, #list do
		local item = list[i]
		local id = i
		if key then
			local seen = item
			if cells then
				probe[1] = item
				seen = probe
			end
			id = key(self, place(at, seen, a, b, c))
		end
		local row = rows[id]
		if row then
			if cells and row.cell[1] ~= item then
				R.set(row.cell, item)
			end
		else
			local node = group(block)
			row = { node = node }
			rows[id] = row
			local value = item
			if cells then
				value = { item }
				row.cell = value
			end
			local ra, rb, rc = place(at, value, a, b, c)
			if indexAt ~= 0 then
				ra, rb, rc = place(indexAt, i, ra, rb, rc)
			end
			block.draw(self, node, ra, rb, rc)
		end
		row.round = round
		if row.index ~= i then
			row.index = i
			host.order(row.node.h, i)
		end
	end
	for id, row in pairs(rows) do
		if row.round ~= round then
			rows[id] = nil
			drop(row.node)
		end
	end
end

function R.each(parent, list, key, draw, at, indexAt, cells, self, a, b, c)
	local block = {
		h = host.create("group", parent.h), list = list, key = key, draw = draw, at = at, indexAt = indexAt,
		cells = cells, self = self, a = a, b = b, c = c, rows = {}, round = 0,
		sources = {}, n = 0, mark = markEffect, run = runEach, ["$end"] = endBlock,
	}
	adopt(parent, block)
	runEach(block)
end

-- Draw `component` into the host's `handle`. The component owns what it drew: destroying it takes it away.
function R.mount(component, handle)
	-- In a group of its own: when the component ends, what it drew goes and what else stands in `handle` stays.
	local node = adopt(component, { h = host.create("group", handle), ["$end"] = endNode })
	R.draw(node, component, nil)
	if host.flush then
		host.flush()
	end
	return node
end

return R
