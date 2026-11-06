-- Border styles for the square minimap, and the saved-settings defaults.
-- Data plus pure functions only (no WoW API at load time), so specs can load it.
--
-- A style is drawn with a BackdropTemplate frame around the map:
--   id        saved in OrdaenMinimapDB.borderStyle
--   label     key in ns.L
--   backdrop  table passed to frame:SetBackdrop (nil = no border)
--   outset    how far (px) the frame extends past the map edge, so the visible line hugs the map
--   natural   border color used for the "natural" color choice ({r, g, b}; nil = untinted)
--
-- To add art of our own, add a style whose edgeFile points at a texture in this addon's media/
-- folder, e.g. "Interface\\AddOns\\OrdaenMinimap\\media\\gold-filigree" (backdrop edge files are
-- 8 slices side by side: left, right, top, bottom, then the four corners).
local _, ns = ...

ns.BORDER_STYLES = {
	{
		id = "gold",
		label = "STYLE_GOLD",
		backdrop = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24 },
		outset = 7,
	},
	{
		id = "tooltip",
		label = "STYLE_TOOLTIP",
		backdrop = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 },
		outset = 4,
	},
	{
		id = "thin",
		label = "STYLE_THIN",
		backdrop = { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 },
		outset = 2,
		natural = { 0, 0, 0 },
	},
	{
		id = "none",
		label = "STYLE_NONE",
	},
}

-- "class" is resolved at runtime from the player's class color.
ns.BORDER_COLORS = {
	{ id = "natural", label = "COLOR_NATURAL" },
	{ id = "black", label = "COLOR_BLACK", rgb = { 0, 0, 0 } },
	{ id = "grey", label = "COLOR_GREY", rgb = { 0.5, 0.5, 0.5 } },
	{ id = "gold", label = "COLOR_GOLD", rgb = { 1, 0.82, 0 } },
	{ id = "class", label = "COLOR_CLASS" },
}

ns.DEFAULTS = {
	borderStyle = "gold",
	borderColor = "natural",
	scale = 1,
	drawerEnabled = true,
	hideBlizzardCompartment = true,
	drawerColumns = 6,
}

ns.SCALE_MIN, ns.SCALE_MAX, ns.SCALE_STEP = 0.8, 1.6, 0.05
ns.DRAWER_COLUMNS_MIN, ns.DRAWER_COLUMNS_MAX = 2, 12

local function byId(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

--- The style with this id, or the default style for unknown ids (e.g. a removed style).
---@param id string|nil
---@return table
function ns.GetBorderStyle(id)
	return byId(ns.BORDER_STYLES, id) or byId(ns.BORDER_STYLES, ns.DEFAULTS.borderStyle)
end

--- The {r, g, b} to tint a style with, or nil to leave the texture untinted.
---@param style table a ns.BORDER_STYLES entry
---@param colorId string|nil
---@param classRGB table|nil {r, g, b} of the player's class, for "class"
---@return table|nil
function ns.ResolveBorderColor(style, colorId, classRGB)
	if colorId == "class" and classRGB then
		return classRGB
	end
	local color = byId(ns.BORDER_COLORS, colorId)
	if color and color.rgb then
		return color.rgb
	end
	return style.natural
end

--- Fill in missing settings and repair invalid ones, in place. Unknown keys are kept
--- (other modules, such as the debug kit, store their data in the same table).
---@param db table
---@return table db
function ns.ApplyDefaults(db)
	if not byId(ns.BORDER_STYLES, db.borderStyle) then
		db.borderStyle = ns.DEFAULTS.borderStyle
	end
	if not byId(ns.BORDER_COLORS, db.borderColor) then
		db.borderColor = ns.DEFAULTS.borderColor
	end
	local scale = tonumber(db.scale)
	if not scale then
		db.scale = ns.DEFAULTS.scale
	else
		db.scale = math.min(ns.SCALE_MAX, math.max(ns.SCALE_MIN, scale))
	end
	for _, flag in ipairs({ "drawerEnabled", "hideBlizzardCompartment" }) do
		if type(db[flag]) ~= "boolean" then
			db[flag] = ns.DEFAULTS[flag]
		end
	end
	local columns = tonumber(db.drawerColumns)
	if not columns then
		db.drawerColumns = ns.DEFAULTS.drawerColumns
	else
		db.drawerColumns = math.min(ns.DRAWER_COLUMNS_MAX, math.max(ns.DRAWER_COLUMNS_MIN, math.floor(columns + 0.5)))
	end
	return db
end
