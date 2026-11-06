-- Shared test setup for OrdaenCore: stub the WoW API it touches and load its files the way WoW does.
local M = {}

-- metadata[addon][field]; "*" applies to every addon.
M.metadata = {}

-- Method names any widget on Forever has (from the API dump), or nil before a dump is imported.
local foreverMethods = require("tests.repo.forever_api").Methods()

--- Whether a missing key on a stub object should act as a do-nothing method: a method name (CamelCase)
--- that a real Forever widget has. Anything else reads as nil, like an unset field on a real frame, so a
--- test can't pass because a fake made up a method or a field.
function M.isStubMethod(key)
	if type(key) ~= "string" or not key:match("^%u") then
		return false
	end
	return foreverMethods == nil or foreverMethods[key] == true
end

local function noop() end

--- A stand-in for any WoW frame/texture/font string: unknown widget methods are no-ops returning nil,
--- unknown fields are nil (see M.isStubMethod). Keeps scripts, text, shown state and points so UI code
--- can be driven from tests.
function M.stubObject(name)
	local obj = { name = name, scripts = {}, shown = true, text = "" }
	local methods = {
		SetScript = function(self, script, fn)
			self.scripts[script] = fn
		end,
		GetScript = function(self, script)
			return self.scripts[script]
		end,
		Show = function(self)
			if not self.shown then
				self.shown = true
				if self.scripts.OnShow then
					self.scripts.OnShow(self)
				end
			end
		end,
		Hide = function(self)
			self.shown = false
		end,
		IsShown = function(self)
			return self.shown
		end,
		SetShown = function(self, shown)
			if shown then
				self:Show()
			else
				self:Hide()
			end
		end,
		SetText = function(self, text)
			self.text = text
		end,
		GetText = function(self)
			return self.text
		end,
		GetName = function(self)
			return self.name
		end,
		GetPoint = function()
			return "CENTER", nil, "CENTER", 10, 20
		end,
		CreateFontString = function()
			return M.stubObject()
		end,
		CreateTexture = function()
			return M.stubObject()
		end,
	}
	return setmetatable(obj, {
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			return M.isStubMethod(key) and noop or nil
		end,
	})
end

function M.stubGlobals(overrides)
	M.metadata = {
		["*"] = { Version = "1.2.3" },
		TestAddon = { Title = "Test Addon" },
	}
	local stubs = {
		date = os.date,
		GetTime = function()
			return 12.5
		end,
		GetBuildInfo = function()
			return "1.16.0", "60000", "Oct 1 2026", 16001
		end,
		GetLocale = function()
			return "enUS"
		end,
		C_AddOns = {
			GetAddOnMetadata = function(addon, field)
				local own = M.metadata[addon]
				if own and own[field] ~= nil then
					return own[field]
				end
				return M.metadata["*"][field]
			end,
		},
		debugstack = function()
			return "Interface/AddOns/TestAddon/Core.lua:10: in function <fake>"
		end,
		debuglocals = function()
			return "x = 1"
		end,
		geterrorhandler = function()
			return M.errorHandler
		end,
		DEFAULT_CHAT_FRAME = { AddMessage = function() end },
		-- frames and UI globals (the debug module builds frames at load)
		CreateFrame = function(_, name)
			local f = M.stubObject(name)
			table.insert(M.created, f)
			if name then
				rawset(_G, name, f)
			end
			return f
		end,
		UIParent = M.stubObject("UIParent"),
		UISpecialFrames = {},
		SlashCmdList = {},
		GameTooltip = M.stubObject("GameTooltip"),
		ChatFontNormal = {},
		BackdropTemplateMixin = {},
		InCombatLockdown = function()
			return false
		end,
		ReloadUI = function()
			M.reloaded = true
		end,
		seterrorhandler = function(fn)
			M.errorHandler = fn
		end,
	}
	M.reloaded = false
	M.created = {} -- every frame CreateFrame made, in order
	M.forwarded = {}
	M.errorHandler = function(err) -- stands in for BugGrabber/Blizzard: remembers what reached it
		table.insert(M.forwarded, err)
	end
	rawset(_G, "BugGrabber", nil)
	rawset(_G, "C_Timer", nil)
	rawset(_G, "OrdaenCoreDebugDB", nil)
	for name, value in pairs(overrides or {}) do
		stubs[name] = value
	end
	-- Never fake an API Forever doesn't have (checked against the in-game dump once imported).
	local names = {}
	for name in pairs(stubs) do
		names[#names + 1] = name
	end
	require("tests.repo.forever_api").CheckStubs(names)
	-- rawset keeps luacheck quiet about defining globals in tests.
	for name, value in pairs(stubs) do
		rawset(_G, name, value)
	end
end

--- Load OrdaenCore the way WoW does; returns the Core table. (The dev-mode addon OrdaenCore_Debug
--- and its specs live in the private wow-dev-tools repo, which has its own copy of these helpers.)
function M.loadCore()
	local ns = {}
	assert(loadfile("addons/OrdaenCore/Core.lua"))("OrdaenCore", ns)
	return ns.Core
end

return M
