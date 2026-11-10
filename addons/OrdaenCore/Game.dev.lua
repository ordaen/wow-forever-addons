-- Dev-only: `game.Dev`, the dev addon (OrdaenCore_Debug, never in players' installs) for the Ordaen Dev window
-- (OrdaenDev, design development/debug/panel). Release builds leave out *.dev.lua, so players never get it; without
-- the dev addon it is nil. The switches stay the dev addon's own: each is read from it and written through it, the
-- value here only tells the window it changed.
local _, ns = ...

local NewValue = ns.NewValue

---@class OrdaenDevSwitch
---@field name string "<group>:<key>" (the dev addon's Api.lua)
---@field value OrdaenValueSignal boolean
local Switch = {}
local SwitchMeta = { __index = Switch }

function Switch:Get()
	return self.value:Get()
end

function Switch:Peek()
	return self.value:Peek()
end

---@param on boolean
function Switch:Set(on)
	local api = _G.OrdaenCoreDebug
	api:Set(self.name, on == true)
	self.value:Set(api:Get(self.name))
end

function Switch:Label()
	return (_G.OrdaenCoreDebug:Describe(self.name))
end

function Switch:Tip()
	return select(2, _G.OrdaenCoreDebug:Describe(self.name))
end

---@class OrdaenDev
---@field switches table<string, OrdaenDevSwitch> made once each, by name
---@field status OrdaenValueSignal { queued, errors }, read again by Refresh
---@field addons OrdaenValueSignal string[]: the Ordaen addons with a debug kit
---@field hasDump OrdaenValueSignal boolean
---@field tasks OrdaenValueSignal OrdaenDevTask[]: the event loop's live tasks (Core._Tasks, Loop.dev.lua)
---@field cancels table<table, fun()> each task's cancel, made once (weak: a task that ended goes)
local Dev = {}
local DevMeta = { __index = Dev }

--- The switch by its name, made once.
---@param name string
---@return OrdaenDevSwitch
function Dev:Switch(name)
	local s = self.switches[name]
	if not s then
		s = setmetatable({ name = name, value = NewValue(_G.OrdaenCoreDebug:Get(name)) }, SwitchMeta)
		self.switches[name] = s
	end
	return s
end

---@class OrdaenDevTask
---@field owner string module and component
---@field site string where it was spawned (file:line)
---@field waits string what it waits for now
---@field cpu string the CPU it used, "41.2 ms"
---@field Cancel fun() cancels it

-- the live tasks as rows: their text, and a cancel made once per task
local function ReadTasks(dev)
	local read = ns.Core._Tasks
	local out = {}
	if not read then
		return out
	end
	for i, t in ipairs(read()) do
		local task = t.task
		local cancel = dev.cancels[task]
		if not cancel then
			cancel = function()
				task:Cancel()
			end
			dev.cancels[task] = cancel
		end
		out[i] = { owner = tostring(t.owner or t.state), site = tostring(t.site), waits = tostring(t.wait),
			cpu = string.format("%.1f ms", t.cpu or 0), Cancel = cancel }
	end
	return out
end

--- Read everything again: the status, the addons, the dump and every switch (the window does it once a second while
--- it's open: another switch, «All» say, may have changed the others).
function Dev:Refresh()
	local api = _G.OrdaenCoreDebug
	local queued, errors = api:Status()
	local status = self.status:Peek()
	if status.queued ~= queued or status.errors ~= errors then
		self.status:Set({ queued = queued, errors = errors })
	end
	local addons = api:Addons()
	if #addons ~= #self.addons:Peek() then
		self.addons:Set(addons)
	end
	self.hasDump:Set(api:HasDump())
	self.tasks:Set(ReadTasks(self))
	for name, s in pairs(self.switches) do
		s.value:Set(api:Get(name))
	end
end

--- The recorder's channel switches' names, in order.
---@return string[]
function Dev:RecorderChannels() -- luacheck: ignore 212
	return _G.OrdaenCoreDebug:RecorderChannels()
end

---@param code string
function Dev:Run(code) -- luacheck: ignore 212
	_G.OrdaenCoreDebug:Run(code)
end

function Dev:SendState() -- luacheck: ignore 212
	_G.OrdaenCoreDebug:SendState()
end

function Dev:Benchmark() -- luacheck: ignore 212
	_G.OrdaenCoreDebug:Benchmark()
end

--- The game API dump; true when it ran (then the player reloads).
---@return boolean
function Dev:DumpApi()
	local ran = _G.OrdaenCoreDebug:DumpApi()
	self.hasDump:Set(_G.OrdaenCoreDebug:HasDump())
	return ran
end

function Dev:ClearDump()
	_G.OrdaenCoreDebug:ClearDump()
	self.hasDump:Set(false)
end

--- The window opened: the dev addon's gear button drops its error alert.
function Dev:Opened() -- luacheck: ignore 212
	_G.OrdaenCoreDebug:Opened()
end

function Dev:ToggleArtPreview() -- luacheck: ignore 212
	_G.OrdaenCoreDebug:ToggleArtPreview()
end

function ns.GameDomains.Dev()
	local api = _G.OrdaenCoreDebug
	if type(api) ~= "table" then
		return nil
	end
	local queued, errors = api:Status()
	local dev = setmetatable({ switches = {}, status = NewValue({ queued = queued, errors = errors }),
		addons = NewValue(api:Addons()), hasDump = NewValue(api:HasDump()), tasks = NewValue({}),
		cancels = setmetatable({}, { __mode = "k" }) }, DevMeta)
	dev.tasks:Set(ReadTasks(dev))
	return dev
end

--- The Ordaen Dev window toggled (the dev addon's gear button and its key): OrdaenDev loaded at its first use.
---@return boolean
function ns.Core._ToggleDev()
	return ns.Commands.RunOnDemand("OrdaenDev", "toggle", "")
end
