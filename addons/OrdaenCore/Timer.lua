-- Ordaen Core: a clock per Ordaen addon. `A:Every(seconds, fn)` (or a feature's `F:Every`) makes a ticker; an
-- addon's running tickers share one C_Timer.After chain, always set for the next one due, so nothing runs per frame
-- and idle tickers cost nothing. Each addon's chain is its own, its callback made by NewAddon while the addon's file
-- runs. UNVERIFIED: whether the profiler bills the ticks to the addon. Billing follows the frame a handler runs on
-- (EllesmereUI's probe; Addon.lua, event frames), and a C_Timer callback has none; not probed in game yet.
--
--   local clock = A:Every(1, updateClock)      -- runs every second from now on
--   local fast = F:Every(0.1, updateCoords)     -- runs while the feature is on (Feature.lua)
--   fast:Stop() ... fast:Start()               -- e.g. only while the player moves
--
-- Ticks are as precise as C_Timer (a frame at most late); a ticker that fell behind (loading screen) runs once and
-- keeps its rhythm from then on, it doesn't catch up. Cost: no tables or closures per tick or per Start/Stop.
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core
---@class OrdaenAddon
local Addon = ns.AddonClass

local huge = math.huge
local EARLY = 0.001 -- C_Timer may fire this much before the time asked for

--- A repeating timer (A:Every / F:Every). Methods are called with `:`.
---@class OrdaenTicker
---@field interval number seconds
---@field fn function the owner's function (wrapped by its debug kit)
---@field due number GetTime() of the next run
---@field wanted boolean started (Start) and not stopped (Stop)
---@field running boolean in the clock's list and running
---@field listed boolean in the clock's list (stopped ones leave it at the next tick)
---@field feature OrdaenFeature|nil runs only while this feature is on
---@field owner OrdaenAddon
local Ticker = {}
Ticker.__index = Ticker

--- One addon's clock: its tickers and its C_Timer chain.
---@class OrdaenClock
---@field list OrdaenTicker[] running tickers, plus stopped ones until the next tick removes them
---@field pendingAt number when the scheduled C_Timer.After fires (huge: none scheduled)
---@field tick fun() the chain's callback (made in the addon's context)

local function schedule(clock, at)
	if at < clock.pendingAt then
		clock.pendingAt = at
		local delay = at - GetTime()
		C_Timer.After(delay > 0 and delay or 0, clock.tick)
	end
end

-- An earlier-due ticker schedules another C_Timer.After; the older one then fires before pendingAt and is
-- ignored, so there is never more than one chain doing work.
local function tick(clock)
	local now = GetTime()
	if now < clock.pendingAt - EARLY then
		return
	end
	clock.pendingAt = huge
	local list = clock.list
	local n = #list
	for i = 1, n do
		local t = list[i]
		if t.running and t.due <= now + EARLY then
			local due = t.due + t.interval
			t.due = due > now and due or now + t.interval
			Core._RunAs(t.owner, t.fn)
		end
	end
	-- drop stopped tickers (in place: no new table) and find the next one due
	local nextAt, j = huge, 0
	for i = 1, #list do
		local t = list[i]
		if t.running then
			j = j + 1
			list[j] = t
			if t.due < nextAt then
				nextAt = t.due
			end
		else
			t.listed = false
		end
	end
	for i = #list, j + 1, -1 do
		list[i] = nil
	end
	if nextAt < huge then
		schedule(clock, nextAt)
	end
end

-- A clock's C_Timer callback (made by NewAddon in the addon's context) calls this.
Core._Tick = tick

-- Whether the ticker should run now: started, and its feature (if any) is on.
local function sync(t)
	local run = t.wanted and (t.feature == nil or t.feature.enabled)
	if run == t.running then
		return
	end
	t.running = run
	if run then
		t.due = GetTime() + t.interval
		local clock = t.owner._clock
		if not t.listed then
			t.listed = true
			clock.list[#clock.list + 1] = t
		end
		schedule(clock, t.due)
	end
end
Core._SyncTicker = sync

--- Run every `interval` seconds from now (again after Stop).
function Ticker:Start()
	self.wanted = true
	sync(self)
end

--- Stop running until Start.
function Ticker:Stop()
	self.wanted = false
	sync(self)
end

---@return boolean
function Ticker:IsRunning()
	return self.running
end

---@param owner OrdaenAddon
---@param interval number
---@param fn fun()
---@param feature OrdaenFeature|nil
---@return OrdaenTicker
function Core._NewTicker(owner, interval, fn, feature)
	local t = setmetatable({
		interval = interval,
		fn = owner.Debug:Wrap(fn),
		due = huge,
		wanted = true,
		running = false,
		listed = false,
		feature = feature,
		owner = owner,
	}, Ticker)
	sync(t)
	return t
end

--- Run `fn()` every `interval` seconds, starting `interval` from now, until `:Stop()`. Make tickers once (at load
--- or when a feature starts) and Start/Stop them; don't make one per event.
---@param interval number seconds
---@param fn fun()
---@return OrdaenTicker
function Addon:Every(interval, fn)
	return Core._NewTicker(self, interval, fn, nil)
end
