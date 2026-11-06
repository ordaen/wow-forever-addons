-- Shared test setup for OrdaenCore: stub the WoW API it touches and load its files the way WoW does.
local M = {}

-- metadata[addon][field]; "*" applies to every addon.
M.metadata = {}

--- A stand-in for any WoW frame/texture/font string: unknown methods are no-ops returning nil.
--- Keeps scripts, text, shown state and points so UI code can be driven from tests.
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
		__index = function(_, method)
			return methods[method] or function() end
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
	M.forwarded = {}
	M.errorHandler = function(err) -- stands in for BugGrabber/Blizzard: remembers what reached it
		table.insert(M.forwarded, err)
	end
	rawset(_G, "BugGrabber", nil)
	rawset(_G, "OrdaenCoreDebugDB", nil)
	for name, value in pairs(overrides or {}) do
		stubs[name] = value
	end
	-- rawset keeps luacheck quiet about defining globals in tests.
	for name, value in pairs(stubs) do
		rawset(_G, name, value)
	end
end

--- Load OrdaenCore the way WoW does; returns the Core table.
---@param withDebugModule boolean|nil also load the optional OrdaenCore_Debug addon (dev mode)
function M.loadCore(withDebugModule)
	local ns = {}
	assert(loadfile("addons/OrdaenCore/Core.lua"))("OrdaenCore", ns)
	if withDebugModule then
		M.debugNs = {}
		local dir = "addons/OrdaenCore/OrdaenCore_Debug/"
		local toc = assert(io.open(dir .. "OrdaenCore_Debug.toc")):read("*a")
		for file in toc:gmatch("[^\r\n]+") do
			if file:match("%.lua$") then
				assert(loadfile(dir .. file))("OrdaenCore_Debug", M.debugNs)
			end
		end
	end
	return ns.Core
end

return M
