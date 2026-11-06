-- Shared test setup for OrdaenCore: stub the WoW API it touches and load its files the way WoW does.
local M = {}

-- metadata[addon][field]; "*" applies to every addon.
M.metadata = {}

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
			return function() end
		end,
		DEFAULT_CHAT_FRAME = { AddMessage = function() end },
	}
	for name, value in pairs(overrides or {}) do
		stubs[name] = value
	end
	-- rawset keeps luacheck quiet about defining globals in tests.
	for name, value in pairs(stubs) do
		rawset(_G, name, value)
	end
end

--- Load OrdaenCore's files in TOC order; returns the Core table.
function M.loadCore()
	local ns = {}
	for _, file in ipairs({ "Core.lua", "Debug.lua" }) do
		assert(loadfile("addons/OrdaenCore/" .. file))("OrdaenCore", ns)
	end
	return ns.Core
end

return M
