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
		GetEffectiveScale = function() -- a real frame always has one; the UI renderer sizes pixels with it
			return 1
		end,
		-- A real frame always has a size (0 until set); layout code does arithmetic with it.
		SetWidth = function(self, w)
			self.width = w
		end,
		SetHeight = function(self, h)
			self.height = h
		end,
		SetSize = function(self, w, h)
			self.width, self.height = w, h
		end,
		GetWidth = function(self)
			return self.width or 0
		end,
		GetHeight = function(self)
			return self.height or 0
		end,
		GetSize = function(self)
			return self.width or 0, self.height or 0
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
		-- Events a frame registered (like the game: M.fire delivers only to frames registered for the event).
		RegisterEvent = function(self, event)
			rawset(self, "registered", rawget(self, "registered") or {})
			self.registered[event] = true
		end,
		RegisterUnitEvent = function(self, event, unit)
			rawset(self, "registered", rawget(self, "registered") or {})
			self.registered[event] = true
			rawset(self, "unit", unit)
		end,
		UnregisterEvent = function(self, event)
			local registered = rawget(self, "registered")
			if registered then
				registered[event] = nil
			end
		end,
		IsEventRegistered = function(self, event)
			local registered = rawget(self, "registered")
			return registered ~= nil and registered[event] == true
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

-- Whether a fake frame registered an event: its `registered` map (stubObject), or the RegisterEvent /
-- RegisterUnitEvent / UnregisterEvent calls a spec's own stub recorded in `calls`.
local function registeredFor(frame, event)
	local registered = rawget(frame, "registered")
	if registered then
		return registered[event] == true
	end
	local calls = rawget(frame, "calls")
	if not calls then
		return false
	end
	local n = 0
	for _, method in ipairs({ "RegisterEvent", "RegisterUnitEvent" }) do
		for _, args in ipairs(rawget(calls, method) or {}) do
			n = n + (args[1] == event and 1 or 0)
		end
	end
	for _, args in ipairs(rawget(calls, "UnregisterEvent") or {}) do
		n = n - (args[1] == event and 1 or 0)
	end
	return n > 0
end

--- Deliver a game event the way WoW does: to every frame of `frames` (in creation order) that registered it and has
--- an OnEvent script. Ordaen addons each have their own event frame (Addon.lua), so a spec can't pick one frame.
---@param frames table[]
---@param event string
function M.fireOn(frames, event, ...)
	for _, frame in ipairs(frames) do
		local script = frame.scripts and frame.scripts.OnEvent
		if script and registeredFor(frame, event) then
			script(frame, event, ...)
		end
	end
end

--- M.fireOn for the frames made through the shared CreateFrame (M.created).
---@param event string
function M.fire(event, ...)
	M.fireOn(M.created, event, ...)
end

-- What C_Texture.GetAtlasInfo answers for any atlas.
M.atlasInfo = { width = 200, height = 100, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }

-- The pieces Blizzard's NineSliceUtil puts on a frame.
M.NINE_SLICE_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
	"BottomEdge", "LeftEdge", "RightEdge", "Center" }

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
		-- what the UI renderer draws with (OrdaenCore_UI/Render.lua)
		CreateColor = function(r, g, b, a)
			local c = { r = r, g = g, b = b, a = a }
			function c:SetRGBA(nr, ng, nb, na)
				self.r, self.g, self.b, self.a = nr, ng, nb, na
			end
			function c:GetRGBA()
				return self.r, self.g, self.b, self.a
			end
			return c
		end,
		PixelUtil = { GetPixelToUIUnitFactor = function()
			return 1
		end },
		-- Forever's secret values: none in a spec unless it says so (ui_spec overrides this).
		issecretvalue = function()
			return false
		end,
		-- Atlas sizes (cover-fit backgrounds): every atlas is M.atlasInfo, a 2:1 one over its whole texture by default.
		C_Texture = { GetAtlasInfo = function()
			return M.atlasInfo
		end },
		-- Blizzard's NineSlice layouts (window art): puts the named layout's pieces on the frame as its own textures
		-- (fields named as Blizzard's), records the layout and that sharpening is off.
		NineSliceUtil = {
			ApplyLayoutByName = function(frame, name)
				rawset(frame, "layout", name)
				for _, piece in ipairs(M.NINE_SLICE_PIECES) do
					if rawget(frame, piece) == nil then
						rawset(frame, piece, frame:CreateTexture(nil, "BORDER"))
					end
				end
			end,
			DisableSharpening = function(frame)
				rawset(frame, "unsharpened", true)
			end,
			ShowLayout = function(frame)
				for _, piece in ipairs(M.NINE_SLICE_PIECES) do
					rawget(frame, piece):Show()
				end
			end,
			HideLayout = function(frame)
				rawset(frame, "layout", nil)
				for _, piece in ipairs(M.NINE_SLICE_PIECES) do
					rawget(frame, piece):Hide()
				end
			end,
		},
		IsShiftKeyDown = function()
			return M.shiftDown == true
		end,
		STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF",
		IsLoggedIn = function()
			return M.loggedIn == true
		end,
		InCombatLockdown = function()
			return M.inCombat == true
		end,
		ReloadUI = function()
			M.reloaded = true
		end,
		seterrorhandler = function(fn)
			M.errorHandler = fn
		end,
	}
	M.reloaded = false
	M.shiftDown = false
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

--- The built addons, as the game loads them: `ordaen build` writes the TOCs (file order derived from the code)
--- and the locale files there. `ordaen test` and `ordaen check` build before running the specs.
M.DIST = "dist/"

--- The Lua files of a built addon's TOC, in load order, as paths from the repo root.
---@param path string the addon's folder inside dist/, e.g. "OrdaenCore" or "OrdaenCore/OrdaenCore_UI"
---@return string[]
function M.tocFiles(path)
	local name = path:match("([^/]+)$")
	local tocPath = M.DIST .. path .. "/" .. name .. ".toc"
	local handle = assert(io.open(tocPath), "no " .. tocPath .. ": run `ordaen build` first (ordaen test does)")
	local files = {}
	for line in handle:read("*a"):gmatch("[^\r\n]+") do
		if line:sub(1, 1) ~= "#" and line:match("%.lua$") then
			files[#files + 1] = M.DIST .. path .. "/" .. line:gsub("\\", "/")
		end
	end
	handle:close()
	return files
end

--- Load a built addon the way WoW does: every Lua file of its TOC, in order, with one shared namespace.
---@param path string the addon's folder inside dist/
---@param ns table|nil the namespace (a new one if nil)
---@return table ns
function M.loadAddon(path, ns)
	ns = ns or {}
	local name = path:match("([^/]+)$")
	for _, file in ipairs(M.tocFiles(path)) do
		assert(loadfile(file))(name, ns)
	end
	return ns
end

--- A strict debug kit around the Core's stand-in, for specs: a method called with `.` (wrong self) or a method the
--- kit doesn't have fails the spec instead of passing quietly. Lenient fakes once hid exactly that bug.
---@param standIn table the kit to check calls against (Core.NewDebug's)
---@return table kit
function M.strictDebug(standIn)
	local kit = {}
	return setmetatable(kit, {
		__index = function(_, key)
			local method = standIn[key]
			if type(method) ~= "function" then
				error("the debug kit has no method " .. tostring(key), 2)
			end
			return function(self, ...)
				if self ~= kit then
					error("debug kit method " .. key .. " called with '.' (use ':')", 2)
				end
				return method(standIn, ...)
			end
		end,
	})
end

--- Load OrdaenCore the way WoW does; returns the Core table. Its debug kit is the strict one (M.strictDebug),
--- shared by every addon like the real stand-in. (The dev-mode addon OrdaenCore_Debug and its specs live in the
--- private wow-dev-tools repo, which has its own copy of these helpers.)
function M.loadCore()
	local Core = M.loadAddon("OrdaenCore").Core
	local kit = M.strictDebug(Core.NewDebug("OrdaenCore"))
	Core.NewDebug = function()
		return kit
	end
	return Core
end

return M
