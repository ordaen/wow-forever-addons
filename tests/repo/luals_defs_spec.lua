-- scripts/luals_defs.lua: LuaLS definitions from the structured API.
local defs = dofile("scripts/luals_defs.lua")

describe("LuaLS definitions", function()
	local api = {
		widgets = {
			Region = { "GetWidth", "Hide" },
			Frame = { "GetWidth", "Hide", "RegisterEvent", "CreateTexture", "SetScript" },
			Button = { "GetWidth", "Hide", "RegisterEvent", "CreateTexture", "SetScript", "Click" },
			Texture = { "GetWidth", "Hide", "SetTexture" },
			Gone = false,
		},
		functions = {
			["C_Map.GetBestMapForUnit"] = {
				args = { { name = "unit", type = "UnitToken", nilable = false } },
				returns = { { name = "uiMapID", type = "number", nilable = true } },
			},
			GetTime = { args = {}, returns = { { name = "seconds", type = "number", nilable = false } } },
			Defaulted = { args = { { name = "end", type = "cstring", nilable = false, default = true } }, returns = {} },
		},
		namespaces = { C_Map = { GetBestMapForUnit = "function", GetMapInfo = "function" }, Enum = { Kind = "table" } },
		globals = {
			C_Map = "table",
			Enum = "table",
			GetTime = "function",
			Defaulted = "function",
			Undocumented = "function",
			CLOSE = "string",
			Minimap = "widget",
			["bad-name"] = "string",
		},
		objects = {
			Minimap = { ZoomIn = "table", SetZoom = "function", GetWidth = "function", buttonContext = "string" },
			["Minimap.ZoomIn"] = { Click = "function" },
		},
		events = { ZONE_CHANGED = { payload = {} }, PLAYER_LOGIN = { payload = {} } },
	}

	local files
	before_each(function()
		files = defs.Generate(api, "1.0.0-1")
	end)

	it("derives the widget class hierarchy from the method sets", function()
		local parent = defs.WidgetHierarchy(api.widgets)
		assert.equals("Frame", parent.Button)
		assert.equals("Region", parent.Frame)
		assert.equals("Region", parent.Texture)
		assert.is_nil(parent.Region)
	end)

	it("declares each class with only the methods it adds", function()
		local w = files["widgets.lua"]
		local function has(text)
			return w:find(text, 1, true) ~= nil
		end
		assert.is_true(has("---@class Button : Frame\nlocal Button = {}\n---@return any ...\nfunction Button:Click(...) end"))
		assert.falsy(w:find("function Button:GetWidth", 1, true))
		assert.is_true(has("---@param event WowEvent\n---@return boolean registered\n"
			.. "function Frame:RegisterEvent(event, ...) end"))
		assert.truthy(w:find("---@return Texture\nfunction Frame:CreateTexture(...) end", 1, true))
		assert.falsy(w:find("Gone", 1, true))
	end)

	it("types documented functions and leaves the rest open", function()
		local f = files["functions.lua"]
		assert.truthy(f:find("---@param unit UnitToken\n---@return number? uiMapID\n"
			.. "function C_Map.GetBestMapForUnit(unit) end", 1, true))
		assert.truthy(f:find("---@return any ...\nfunction C_Map.GetMapInfo(...) end", 1, true))
		assert.truthy(files["types.lua"]:find("---@alias UnitToken any", 1, true))
		local g = files["globals.lua"]
		assert.truthy(g:find("---@param arg1? string\nfunction Defaulted(arg1) end", 1, true)) -- keyword name, default
		assert.truthy(g:find("---@return any ...\nfunction Undocumented(...) end", 1, true))
		assert.truthy(g:find('CLOSE = ""', 1, true))
		assert.falsy(g:find("bad-name", 1, true))
		assert.falsy(g:find("\nC_Map = ", 1, true)) -- namespaces live in functions.lua
	end)

	it("gives CreateFrame an overload per frame type", function()
		local g = files["globals.lua"]
		assert.truthy(g:find('---@overload fun(frameType: "Button", name?: string, parent?: any, template?: string, '
			.. "id?: integer): Button", 1, true))
		assert.falsy(g:find('frameType: "Texture"', 1, true))
	end)

	it("types the dumped objects, deeper paths as fields", function()
		local o = files["objects.lua"]
		assert.truthy(o:find("---@class MinimapObject\n", 1, true))
		assert.truthy(o:find("---@field ZoomIn Minimap_ZoomInObject", 1, true))
		assert.truthy(o:find("---@field buttonContext string", 1, true))
		assert.truthy(o:find("function MinimapObject:SetZoom(...) end", 1, true))
		assert.truthy(o:find("---@type MinimapObject\nMinimap = MinimapObject", 1, true))
		assert.falsy(files["globals.lua"]:find("\nMinimap = ", 1, true))
	end)

	it("lists the event names", function()
		assert.truthy(files["events.lua"]:find('---@alias WowEvent\n---| "PLAYER_LOGIN"\n---| "ZONE_CHANGED"', 1, true))
	end)
end)
