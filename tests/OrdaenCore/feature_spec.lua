-- OrdaenCore framework: features (Feature.lua), the shared ticker (Timer.lua), unit events and migrations
-- (Addon.lua).
local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore features, ticker, unit events, migrations", function()
	local Core, now, timers, reported, loadedAddons, stack, definers

	-- The game's clock and C_Timer.After: timers fire in time order as the clock moves.
	local function advance(seconds)
		local target = now + seconds
		while true do
			table.sort(timers, function(a, b)
				return a.at < b.at
			end)
			local first = timers[1]
			if not first or first.at > target then
				break
			end
			table.remove(timers, 1)
			now = math.max(now, first.at) -- a late timer fires late, the clock never goes back
			first.fn()
		end
		now = target
	end

	-- The framework's shared event frame: the newest frame with an OnEvent script and no unit.
	local function fire(event, ...)
		for i = #helpers.created, 1, -1 do
			local frame = helpers.created[i]
			if frame.scripts.OnEvent and not frame.unit then
				frame.scripts.OnEvent(frame, event, ...)
				return
			end
		end
		error("no event frame yet")
	end

	local function frameFor(unit)
		for i = #helpers.created, 1, -1 do
			if helpers.created[i].unit == unit then
				return helpers.created[i]
			end
		end
	end

	local function start(spec, ns)
		local A = Core.NewAddon("TestAddon", ns or {}, spec or { db = "TestAddonDB", defaults = { on = true } })
		return A
	end

	local function login()
		fire("ADDON_LOADED", "TestAddon")
		fire("PLAYER_LOGIN")
	end

	before_each(function()
		now, timers, reported = 100, {}, {}
		helpers.loggedIn, helpers.inCombat = false, false
		rawset(_G, "TestAddonDB", nil)
		helpers.stubGlobals({
			GetTime = function()
				return now
			end,
			C_Timer = {
				After = function(delay, fn)
					timers[#timers + 1] = { at = now + delay, fn = fn }
				end,
			},
			-- like the game: runs the hook after the original, which stays untouched
			hooksecurefunc = function(target, method, hook)
				if type(target) == "string" then
					target, method, hook = _G, target, method
				end
				local original = target[method]
				target[method] = function(...)
					original(...)
					hook(...)
				end
			end,
			-- like the game: an error is reported and the caller goes on
			securecallfunction = function(fn, ...)
				local ok, err = pcall(fn, ...)
				if not ok then
					reported[#reported + 1] = err
				end
			end,
			geterrorhandler = function()
				return function(err)
					reported[#reported + 1] = err
				end
			end,
			-- the stack below the claims watcher, and who defined each global (like the game's taint tracking)
			debugstack = function()
				return stack
			end,
			issecurevariable = function(name)
				if definers[name] then
					return false, definers[name]
				end
				return true, nil
			end,
		})
		stack, definers = "", {}
		-- record what each frame registers (the shared fakes ignore it)
		local createFrame = _G.CreateFrame
		rawset(_G, "CreateFrame", function(...)
			local f = createFrame(...)
			f.registered = {}
			f.RegisterEvent = function(self, event)
				self.registered[event] = true
			end
			f.RegisterUnitEvent = function(self, event, unit)
				self.registered[event] = true
				self.unit = unit
			end
			f.UnregisterEvent = function(self, event)
				self.registered[event] = nil
			end
			return f
		end)
		loadedAddons = {}
		_G.C_AddOns.IsAddOnLoaded = function(name)
			return loadedAddons[name] == true, loadedAddons[name] == true
		end
		Core = helpers.loadCore()
	end)

	describe("unit events", function()
		it("register on one frame per unit, and only reach that unit's handlers", function()
			local A = start()
			login()
			local seen = {}
			local function onAura(event, unit, extra)
				seen[#seen + 1] = event .. ":" .. unit .. ":" .. tostring(extra)
			end
			A:OnUnit("UNIT_AURA", "player", onAura)
			A:OnUnit("UNIT_AURA", "target", onAura)
			local player, target = frameFor("player"), frameFor("target")
			assert.is_true(player.registered.UNIT_AURA)
			assert.is_true(target.registered.UNIT_AURA)
			assert.are_not.equal(player, target)
			player.scripts.OnEvent(player, "UNIT_AURA", "player", 1)
			assert.same({ "UNIT_AURA:player:1" }, seen)
			A:OffUnit("UNIT_AURA", "player", onAura)
			assert.is_nil(player.registered.UNIT_AURA)
			assert.is_true(target.registered.UNIT_AURA)
		end)
	end)

	describe("ticker", function()
		it("runs every interval on one C_Timer chain, and stops", function()
			local A = start()
			local count = 0
			local ticker = A:Every(1, function()
				count = count + 1
			end)
			assert.equals(1, #timers)
			advance(3.5)
			assert.equals(3, count)
			ticker:Stop()
			advance(5)
			assert.equals(3, count)
			assert.equals(0, #timers, "no chain left when nothing runs")
			ticker:Start()
			advance(1)
			assert.equals(4, count)
		end)

		it("keeps one working chain when a faster ticker starts", function()
			local A = start()
			local slow, fast = 0, 0
			A:Every(1, function()
				slow = slow + 1
			end)
			A:Every(0.1, function()
				fast = fast + 1
			end)
			advance(1.05)
			assert.equals(1, slow)
			assert.equals(10, fast)
			advance(1)
			assert.equals(2, slow)
			assert.equals(20, fast)
			assert.is_true(#timers <= 2)
		end)

		it("doesn't catch up after a long pause, it runs once and keeps its rhythm", function()
			local A = start()
			local count = 0
			A:Every(1, function()
				count = count + 1
			end)
			now = now + 10 -- a loading screen: no timer fired
			advance(0)
			assert.equals(1, count)
			advance(1)
			assert.equals(2, count)
		end)

		it("reports an error in a tick and keeps ticking", function()
			local A = start()
			A:Every(1, function()
				error("tick failed")
			end)
			advance(2)
			assert.equals(2, #reported)
		end)
	end)

	describe("features", function()
		it("start after login, after the addon's OnLogin, and follow their setting", function()
			local A = start({ db = "TestAddonDB", defaults = { drawer = { enabled = true } } })
			local order = {}
			local F = A:Feature("drawer", { setting = "drawer.enabled" })
			F:OnEnable(function(db)
				order[#order + 1] = "on:" .. tostring(db.drawer.enabled)
			end)
			F:OnDisable(function()
				order[#order + 1] = "off"
			end)
			A:OnLogin(function()
				order[#order + 1] = "login"
			end)
			fire("ADDON_LOADED", "TestAddon")
			assert.is_false(F:IsEnabled())
			fire("PLAYER_LOGIN")
			assert.same({ "login", "on:true" }, order)
			A.db.drawer.enabled = false
			A:_SettingChanged("drawer.enabled", false)
			assert.is_false(F:IsEnabled())
			assert.same({ "login", "on:true", "off" }, order)
		end)

		it("hold their events and tickers only while on", function()
			local A = start({ db = "TestAddonDB", defaults = { on = false } })
			local F = A:Feature("bags", { setting = "on" })
			local events, ticks = 0, 0
			local function onBags()
				events = events + 1
			end
			F:On("BAG_UPDATE", onBags)
			F:On("BAG_UPDATE", onBags) -- twice is once
			F:Every(1, function()
				ticks = ticks + 1
			end)
			login()
			fire("BAG_UPDATE")
			advance(2)
			assert.equals(0, events)
			assert.equals(0, ticks)
			A.db.on = true
			A:_SettingChanged("on", true)
			fire("BAG_UPDATE")
			advance(2)
			assert.equals(1, events)
			assert.equals(2, ticks)
			A.db.on = false
			A:_SettingChanged("on", false)
			fire("BAG_UPDATE")
			advance(2)
			assert.equals(1, events)
			assert.equals(2, ticks)
		end)

		it("follow `when`, re-checked by Refresh", function()
			local blocked = true
			local A = start()
			local F = A:Feature("map", {
				when = function()
					return not blocked
				end,
			})
			login()
			assert.is_false(F:IsEnabled())
			blocked = false
			F:Refresh()
			assert.is_true(F:IsEnabled())
		end)

		it("tell the ones that are on about other settings", function()
			local A = start({ db = "TestAddonDB", defaults = { on = true, scale = 1 } })
			local F = A:Feature("map", { setting = "on" })
			local G = A:Feature("off", {
				when = function()
					return false
				end,
			})
			local heard = {}
			F:OnChange(function(key, value)
				heard[#heard + 1] = key .. "=" .. value
			end)
			G:OnChange(function()
				error("an off feature hears nothing")
			end)
			login()
			A:_SettingChanged("scale", 2)
			assert.same({ "scale=2" }, heard)
			assert.same({}, reported)
		end)

		it("start isolated: an error in one is reported and the next still starts", function()
			local A = start()
			local broken = A:Feature("broken")
			broken:OnEnable(function()
				error("boom")
			end)
			local fine = A:Feature("fine")
			local started = false
			fine:OnEnable(function()
				started = true
			end)
			login()
			assert.is_true(started)
			assert.equals(1, #reported)
			assert.truthy(tostring(reported[1]):find("boom"))
		end)

		it("made after login start at once", function()
			local A = start()
			login()
			local F = A:Feature("late")
			assert.is_true(F:IsEnabled())
		end)

		it("follow /x reset, which keeps the migrations done", function()
			rawset(_G, "TestAddonDB", { on = false, _schema = 1 })
			local A = start({
				db = "TestAddonDB",
				defaults = { on = true },
				slash = { "/ta" },
				migrations = {
					function() end,
				},
			})
			local F = A:Feature("x", { setting = "on" })
			login()
			assert.is_false(F:IsEnabled())
			_G.SlashCmdList.TESTADDON("reset")
			assert.is_true(F:IsEnabled())
			assert.equals(1, A.db._schema)
		end)
	end)

	describe("hooks", function()
		it("run after the original, once per function, and a feature's only while it is on", function()
			local obj = { calls = {} }
			function obj:Move(x)
				self.calls[#self.calls + 1] = "move" .. x
			end
			local A = start({ db = "TestAddonDB", defaults = { on = true } })
			local F = A:Feature("f", { setting = "on" })
			local function after(self, x)
				self.calls[#self.calls + 1] = "hook" .. x
			end
			assert.is_true(F:Hook(obj, "Move", after))
			assert.is_true(F:Hook(obj, "Move", after)) -- not hooked twice
			login()
			obj:Move(1)
			assert.same({ "move1", "hook1" }, obj.calls)
			A.db.on = false
			A:_SettingChanged("on", false)
			obj:Move(2)
			assert.same({ "move1", "hook1", "move2" }, obj.calls)
		end)

		it("hook global functions, and refuse missing ones", function()
			local A = start()
			local seen
			rawset(_G, "TestGlobalFn", function() end)
			assert.is_true(A:Hook("TestGlobalFn", function(x)
				seen = x
			end))
			_G.TestGlobalFn(5)
			assert.equals(5, seen)
			assert.is_false(A:Hook({}, "Missing", function() end))
			rawset(_G, "TestGlobalFn", nil)
		end)
	end)

	describe("conflicts", function()
		it("keep a feature off while a declared addon is loaded, recorded once as handled", function()
			loadedAddons.MinimapButtonButton = true
			local A = start()
			local F = A:Feature("drawer", { conflicts = { "MinimapButtonButton" } })
			local G = A:Feature("clock", { conflicts = { "NotInstalled" } })
			login()
			A:_SyncFeatures()
			assert.is_false(F:IsEnabled())
			assert.is_true(G:IsEnabled())
			assert.same({ { other = "MinimapButtonButton", what = "feature drawer off", handled = true } }, A:Conflicts())
		end)

		it("call OnConflict before OnLogin for each declared addon that is loaded", function()
			loadedAddons.SexyMap = true
			local A = start({ db = "TestAddonDB", conflicts = { "SexyMap", "Chinchilla" } })
			local order = {}
			A:OnConflict(function(other)
				order[#order + 1] = "conflict:" .. other
				A:Conflict(other, "map left alone", true)
			end)
			A:OnLogin(function()
				order[#order + 1] = "login"
			end)
			login()
			assert.same({ "conflict:SexyMap", "login" }, order)
			assert.same({ { other = "SexyMap", what = "map left alone", handled = true } }, A:Conflicts())
		end)

		it("record a declared conflict nobody handles as not handled", function()
			loadedAddons.SexyMap = true
			local A = start({ db = "TestAddonDB", conflicts = { "SexyMap" } })
			login()
			assert.same({ { other = "SexyMap", what = "loaded together", handled = false } }, A:Conflicts())
		end)

		it("keep at most 20 records per addon", function()
			local A = start()
			for i = 1, 30 do
				A:Conflict("Other", "thing " .. i, false)
			end
			assert.equals(20, #A:Conflicts())
		end)
	end)

	describe("claims", function()
		local WATCHER = "Interface/AddOns/OrdaenCore/Conflict.lua:120: in function <x>\n"

		local function frame()
			local f = { alphas = {} }
			function f:SetAlpha(a)
				self.alphas[#self.alphas + 1] = a
			end
			return f
		end

		local dialogs
		before_each(function()
			-- the shared confirm dialog (OrdaenCore.UI.Confirm), captured instead of drawn
			dialogs = {}
			Core.UI = {
				Confirm = function(spec)
					function spec.Show(self)
						dialogs[#dialogs + 1] = self
					end
					return spec
				end,
			}
		end)

		after_each(function()
			rawset(_G, "TestFrame", nil)
			rawset(_G, "GetTestShape", nil)
		end)

		it("ask the player once which addon to keep, and turn the other off", function()
			rawset(_G, "TestFrame", frame())
			local disabled
			_G.C_AddOns.DisableAddOn = function(name)
				disabled = name
			end
			helpers.metadata.PrettyTooltip = { Title = "|cff00ff00PrettyTooltip|r" }
			local A = start()
			login()
			stack = WATCHER .. "Interface/AddOns/PrettyTooltip/Hooks.lua:45: in function <x>\n"
			A:Claim(_G.TestFrame, { "SetAlpha" }, "GameTooltip")
			_G.TestFrame:SetAlpha(0)
			assert.equals(0, #dialogs, "a second later")
			advance(1)
			assert.equals(1, #dialogs)
			local d = dialogs[1]
			assert.equals(
				"Test Addon and PrettyTooltip both change the game's tooltips. Keeping one turns the other off and "
					.. "reloads the interface.",
				d.text
			)
			assert.same(
				{ "Keep Test Addon", "Keep PrettyTooltip", "Keep both" },
				{ d.buttons[1].text, d.buttons[2].text, d.buttons[3].text }
			)
			advance(2)
			_G.TestFrame:SetAlpha(0) -- the same addon again: no second dialog this session
			assert.equals(1, #dialogs)
			-- the "keep" buttons reload through their own secure macro; our part only turns the other one off
			assert.same({ "/reload", "/reload" }, { d.buttons[1].macro, d.buttons[2].macro })
			assert.is_nil(d.buttons[3].macro)
			helpers.inCombat = true
			d.buttons[2].onClick()
			assert.equals("TestAddon", disabled)
			helpers.inCombat = false
			d.buttons[1].onClick()
			assert.equals("PrettyTooltip", disabled)
			assert.is_false(helpers.reloaded, "never ReloadUI from addon code: this client blocks it")
			helpers.metadata.PrettyTooltip = nil
		end)

		it("remember Keep both, and then record the pair as handled without asking", function()
			rawset(_G, "TestFrame", frame())
			rawset(_G, "OrdaenCoreDB", {})
			local A = start()
			login()
			stack = WATCHER .. "Interface/AddOns/PrettyTooltip/Hooks.lua:45: in function <x>\n"
			A:Claim(_G.TestFrame, { "SetAlpha" }, "GameTooltip")
			_G.TestFrame:SetAlpha(0)
			advance(1)
			dialogs[1].buttons[3].onClick()
			assert.same({ ["TestAddon:PrettyTooltip"] = true }, _G.OrdaenCoreDB.keptConflicts)
			-- next session (a new Core): no dialog, the conflict is recorded as accepted
			dialogs = {}
			Core = helpers.loadCore()
			Core.UI = { Confirm = function(spec)
				function spec.Show(self)
					dialogs[#dialogs + 1] = self
				end
				return spec
			end }
			local B = start()
			login()
			B:Claim(_G.TestFrame, { "SetAlpha" }, "GameTooltip")
			advance(2)
			_G.TestFrame:SetAlpha(0)
			advance(2)
			assert.equals(0, #dialogs)
			assert.same({ { other = "PrettyTooltip", what = "GameTooltip:SetAlpha", handled = true } }, B:Conflicts())
			rawset(_G, "OrdaenCoreDB", nil)
		end)

		it("don't ask when an OnConflict function handled it", function()
			rawset(_G, "TestFrame", frame())
			local A = start(nil, { CLAIMS = { globals = {}, methods = { { "TestFrame", "SetAlpha" } } } })
			A:OnConflict(function(other)
				A:Conflict(other, "left the tooltips alone", true)
			end)
			login()
			stack = WATCHER .. "Interface/AddOns/PrettyTooltip/Hooks.lua:45: in function <x>\n"
			_G.TestFrame:SetAlpha(0)
			advance(2)
			assert.equals(0, #dialogs)
		end)

		it("report a claimed global another addon defined, before our OnLogin redefines it", function()
			rawset(_G, "GetTestShape", function() end)
			definers.GetTestShape = "SexyMap"
			local A = start(nil, { CLAIMS = { globals = { "GetTestShape" }, methods = {} } })
			local heard
			A:OnConflict(function(other, what)
				heard = other .. " " .. what
			end)
			login()
			assert.equals("SexyMap GetTestShape", heard)
			assert.same({ { other = "SexyMap", what = "GetTestShape", handled = false } }, A:Conflicts())
		end)

		it("report another addon calling a claimed method, once, and never our own calls", function()
			rawset(_G, "TestFrame", frame())
			local A = start(nil, { CLAIMS = { globals = {}, methods = { { "TestFrame", "SetAlpha" } } } })
			A:On("PLAYER_ENTERING_WORLD", function()
				stack = WATCHER .. "Interface/AddOns/PrettyTooltip/Hooks.lua:45: in function <x>\n"
				_G.TestFrame:SetAlpha(0) -- runs as ours (Core._running): no stack check at all
			end)
			login()
			fire("PLAYER_ENTERING_WORLD")
			assert.same({}, A:Conflicts())
			-- from our own raw hook body (not marked as running): the first addon below the watcher is ours
			stack = WATCHER .. "Interface/AddOns/OrdaenTooltips/Takeover.lua:30: in function <x>\n"
				.. "Interface/AddOns/PrettyTooltip/Hooks.lua:45: in function <x>\n"
			_G.TestFrame:SetAlpha(0)
			assert.same({}, A:Conflicts())
			-- Blizzard's code
			advance(2)
			stack = WATCHER .. "Interface/AddOns/Blizzard_SharedXML/Tooltip.lua:9: in function <x>\n"
			_G.TestFrame:SetAlpha(1)
			assert.same({}, A:Conflicts())
			-- another addon, again and again (it re-zeroes in its own hook): one record
			advance(2)
			stack = WATCHER .. "Interface/AddOns/PrettyTooltip/Hooks.lua:45: in function <x>\n"
			for _ = 1, 5 do
				_G.TestFrame:SetAlpha(0)
				advance(2)
			end
			assert.same({ { other = "PrettyTooltip", what = "TestFrame:SetAlpha", handled = false } }, A:Conflicts())
			assert.equals(8, #_G.TestFrame.alphas, "the original method still runs every time")
		end)

		it("check the stack at most once per second per method", function()
			rawset(_G, "TestFrame", frame())
			local checks = 0
			rawset(_G, "debugstack", function()
				checks = checks + 1
				return ""
			end)
			start(nil, { CLAIMS = { globals = {}, methods = { { "TestFrame", "SetAlpha" } } } })
			login()
			for _ = 1, 50 do
				_G.TestFrame:SetAlpha(0)
			end
			assert.equals(1, checks)
		end)

		it("watch frames claimed at runtime with A:Claim", function()
			local f = frame()
			local A = start()
			login()
			A:Claim(f, { "SetAlpha" }, "GameTooltip")
			stack = WATCHER .. "Interface/AddOns/TipTac/Core.lua:1: in function <x>\n"
			f:SetAlpha(0)
			assert.same({ { other = "TipTac", what = "GameTooltip:SetAlpha", handled = false } }, A:Conflicts())
		end)

		it("watch claimed frames that appear when a later addon loads", function()
			local A = start(nil, { CLAIMS = { globals = {}, methods = { { "TestFrame", "SetAlpha" } } } })
			login()
			rawset(_G, "TestFrame", frame())
			fire("ADDON_LOADED", "Blizzard_SomeUI")
			stack = WATCHER .. "Interface/AddOns/Other/x.lua:1: in function <x>\n"
			_G.TestFrame:SetAlpha(0)
			assert.equals("Other", A:Conflicts()[1].other)
		end)
	end)

	describe("migrations", function()
		local function migrations(log)
			return {
				function(db)
					log[#log + 1] = 1
					db.drawerButton = nil
				end,
				function(db)
					log[#log + 1] = 2
					db.scale = (db.scale or 1) * 2
				end,
			}
		end

		it("run the ones old SavedVariables haven't had, once, before the defaults", function()
			rawset(_G, "TestAddonDB", { _schema = 1, scale = 3, drawerButton = { 1, 2 } })
			local log = {}
			local A = start({ db = "TestAddonDB", defaults = { scale = 1, on = true }, migrations = migrations(log) })
			fire("ADDON_LOADED", "TestAddon")
			assert.same({ 2 }, log)
			assert.same({ _schema = 2, scale = 6, drawerButton = { 1, 2 }, on = true }, A.db)
		end)

		it("skip all of them for new SavedVariables", function()
			local log = {}
			local A = start({ db = "TestAddonDB", defaults = { scale = 1 }, migrations = migrations(log) })
			fire("ADDON_LOADED", "TestAddon")
			assert.same({}, log)
			assert.equals(2, A.db._schema)
		end)

		it("stop at one that fails, report it, and retry it next time", function()
			rawset(_G, "TestAddonDB", { scale = 1 })
			local A = start({
				db = "TestAddonDB",
				migrations = {
					function(db)
						db.a = true
					end,
					function()
						error("migration failed")
					end,
					function(db)
						db.c = true
					end,
				},
			})
			fire("ADDON_LOADED", "TestAddon")
			assert.equals(1, A.db._schema)
			assert.is_nil(A.db.c)
			assert.equals(1, #reported)
		end)
	end)
end)
