-- ApiDump: record what the game's Lua API really has, so Claude never has to guess what exists on
-- Forever. Dev mode only, and only on a click ("Dump game API" in the Ordaen Dev window): it walks
-- _G once (a second's hitch), writes OrdaenCoreDebugDB.apiDump and reloads so it reaches the disk.
-- Names and types only, never values (values are locale-dependent noise and would bloat the file).
-- Only Blizzard's API is kept: issecurevariable tells Blizzard-defined names from ones other addons
-- added (LibStub, Details, ...), which must never count as "the game has it".
-- scripts/api-import.sh turns the dump into api/forever/<version>-<build>/ in the repo.
local _, ns = ...

local ApiDump = {}
ns.ApiDump = ApiDump

local MAX_NAMESPACE_KEYS = 5000

local FRAME_TYPES = {
	"Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown",
	"GameTooltip", "MessageFrame", "Model", "PlayerModel", "ColorSelect", "SimpleHTML",
}
local ANIMATION_TYPES = { "Animation", "Alpha", "Translation", "Scale", "Rotation", "Path", "FlipBook" }

-- Blizzard objects whose own fields and methods matter to us (dotted paths from _G).
local OBJECTS = {
	"Minimap", "Minimap.ZoomIn", "Minimap.ZoomOut", "MinimapCluster", "MinimapCluster.Tracking",
	"MinimapCluster.IndicatorFrame", "MinimapCluster.ZoneTextButton", "MinimapCluster.BorderTop",
	"MinimapBackdrop", "AddonCompartmentFrame", "GameTooltip", "UIParent", "SettingsPanel",
	"HybridMinimap", "StaticPopup1", "DEFAULT_CHAT_FRAME",
}

-- WoW widgets are tables with a userdata at index 0.
local function isWidget(value)
	return type(value) == "table" and type(rawget(value, 0)) == "userdata"
end

local function resolve(path)
	local value = _G
	for part in path:gmatch("[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

--- Method names of a widget: the function keys of its metatable's __index table.
local function methodsOf(object)
	local list = {}
	local mt = getmetatable(object)
	local index = mt and mt.__index
	if type(index) == "table" then
		for key, value in pairs(index) do
			if type(key) == "string" and type(value) == "function" then
				list[#list + 1] = key
			end
		end
	end
	table.sort(list)
	return list
end

-- Defined by Blizzard (not by an addon)? issecurevariable(t, k) is false for addon-made keys.
local function blizzard(tbl, key)
	local ok, secure = pcall(issecurevariable, tbl, key)
	return ok and secure
end

--- An object's own string keys plus its metatable methods, as name -> type.
local function membersOf(object)
	local members = {}
	for key, value in pairs(object) do
		if type(key) == "string" and blizzard(object, key) then
			members[key] = type(value)
		end
	end
	for _, method in ipairs(methodsOf(object)) do
		members[method] = members[method] or "function"
	end
	return members
end

local function dumpGlobals(dump)
	local fromAddons = 0
	for name, value in pairs(_G) do
		if type(name) == "string" and not blizzard(_G, name) then
			fromAddons = fromAddons + 1
		elseif type(name) == "string" then
			local kind = type(value)
			dump.globals[name] = isWidget(value) and "widget" or kind
			if kind == "table" and not isWidget(value) and value ~= _G then
				local keys, count = {}, 0
				for key, member in pairs(value) do
					if type(key) == "string" and blizzard(value, key) then
						count = count + 1
						if count > MAX_NAMESPACE_KEYS then
							break
						end
						keys[key] = isWidget(member) and "widget" or type(member)
					end
				end
				if count > MAX_NAMESPACE_KEYS then
					keys = { ["<skipped>"] = tostring(count) .. "+" }
				end
				if next(keys) then
					dump.namespaces[name] = keys
				end
			end
		end
	end
	dump.meta.addonGlobals = fromAddons
end

local function dumpWidgets(dump)
	local parent = CreateFrame("Frame")
	parent:Hide()
	for _, frameType in ipairs(FRAME_TYPES) do
		local ok, frame = pcall(CreateFrame, frameType, nil, parent)
		dump.widgets[frameType] = ok and frame and methodsOf(frame) or false
	end
	local regions = {
		Texture = "CreateTexture",
		MaskTexture = "CreateMaskTexture",
		FontString = "CreateFontString",
		Line = "CreateLine",
		AnimationGroup = "CreateAnimationGroup",
	}
	local groupOk, group
	for regionType, creator in pairs(regions) do
		local ok, region = false, nil
		if type(parent[creator]) == "function" then
			ok, region = pcall(parent[creator], parent)
		end
		dump.widgets[regionType] = ok and region and methodsOf(region) or false
		if regionType == "AnimationGroup" and ok then
			groupOk, group = ok, region
		end
	end
	for _, animationType in ipairs(ANIMATION_TYPES) do
		local ok, animation = false, nil
		if groupOk and group and type(group.CreateAnimation) == "function" then
			ok, animation = pcall(group.CreateAnimation, group, animationType)
		end
		dump.widgets[animationType] = ok and animation and methodsOf(animation) or false
	end
end

local function dumpObjects(dump)
	for _, path in ipairs(OBJECTS) do
		local object = resolve(path)
		if type(object) == "table" then
			dump.objects[path] = membersOf(object)
		end
	end
end

--- Blizzard's generated API documentation (argument/return types), when the client ships it.
local function dumpDocs(dump)
	local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
	if type(load) ~= "function" then
		dump.meta.docs = "no LoadAddOn"
		return
	end
	for _, addon in ipairs({ "Blizzard_APIDocumentationGenerated", "Blizzard_APIDocumentation" }) do
		pcall(load, addon)
	end
	local doc = _G.APIDocumentation
	if type(doc) ~= "table" or type(doc.systems) ~= "table" then
		dump.meta.docs = "missing"
		return
	end
	local function fields(list)
		local out = {}
		for i, field in ipairs(type(list) == "table" and list or {}) do
			out[i] = tostring(field.Name) .. ":" .. tostring(field.Type) .. (field.Nilable and "?" or "")
		end
		return table.concat(out, ", ")
	end
	local docs = { functions = {}, events = {} }
	for _, system in ipairs(doc.systems) do
		local prefix = system.Namespace and (system.Namespace .. ".") or ""
		for _, fn in ipairs(system.Functions or {}) do
			docs.functions[prefix .. tostring(fn.Name)] = "(" .. fields(fn.Arguments) .. ") -> (" .. fields(fn.Returns) .. ")"
		end
		for _, event in ipairs(system.Events or {}) do
			docs.events[tostring(event.LiteralName or event.Name)] = fields(event.Payload)
		end
	end
	dump.docs = docs
	dump.meta.docs = "APIDocumentation"
end

--- Walk the game's API and store the result in OrdaenCoreDebugDB.apiDump.
function ApiDump.Run()
	local version, build, buildDate, interface = GetBuildInfo()
	local dump = {
		meta = {
			version = version,
			build = build,
			date = buildDate,
			interface = interface,
			locale = GetLocale and GetLocale() or "?",
			time = time and time() or nil,
		},
		globals = {},
		namespaces = {},
		widgets = {},
		objects = {},
	}
	-- Docs first: loading the documentation addon adds globals, which belong in the dump too.
	pcall(dumpDocs, dump)
	dumpGlobals(dump)
	dumpWidgets(dump)
	dumpObjects(dump)
	OrdaenCoreDebugDB.apiDump = dump
	return dump
end

function ApiDump.Exists()
	return type(OrdaenCoreDebugDB) == "table" and OrdaenCoreDebugDB.apiDump ~= nil
end

--- Free the dump (a few MB of SavedVariables) once it has been imported into the repo.
function ApiDump.Clear()
	if type(OrdaenCoreDebugDB) == "table" then
		OrdaenCoreDebugDB.apiDump = nil
	end
end
