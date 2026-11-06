-- User-facing strings. English is the default; other locales override what they translate.
-- Pure Lua (only GetLocale, when it exists), so specs can load it.
local _, ns = ...

local enUS = {
	SETTINGS_TITLE = "Ordaen Minimap",
	HEADER_BORDER = "Border",
	HEADER_MAP = "Map",
	BORDER_STYLE = "Border style",
	BORDER_STYLE_TOOLTIP = "The frame drawn around the square minimap.",
	BORDER_COLOR = "Border color",
	BORDER_COLOR_TOOLTIP = "Tints the border. \"Natural\" keeps the texture's own colors.",
	MAP_SCALE = "Map size",
	MAP_SCALE_TOOLTIP = "Scales the minimap and everything attached to it.",

	STYLE_GOLD = "Gold (dialog)",
	STYLE_TOOLTIP = "Tooltip",
	STYLE_THIN = "Thin line",
	STYLE_NONE = "None",

	COLOR_NATURAL = "Natural",
	COLOR_BLACK = "Black",
	COLOR_GREY = "Grey",
	COLOR_GOLD = "Gold",
	COLOR_CLASS = "Class color",

	LOADED = "v%s loaded. Type %s to open the settings.",
	HELP_HEADER = "commands:",
	HELP_OPEN = "%s - open the settings",
	HELP_RESET = "%s reset - restore the default settings",
	RESET_DONE = "settings restored to defaults.",
}

local ruRU = {
	SETTINGS_TITLE = "Ordaen Minimap",
	HEADER_BORDER = "Рамка",
	HEADER_MAP = "Карта",
	BORDER_STYLE = "Стиль рамки",
	BORDER_STYLE_TOOLTIP = "Рамка вокруг квадратной миникарты.",
	BORDER_COLOR = "Цвет рамки",
	BORDER_COLOR_TOOLTIP = "Окрашивает рамку. «Естественный» оставляет исходные цвета текстуры.",
	MAP_SCALE = "Размер карты",
	MAP_SCALE_TOOLTIP = "Масштаб миникарты и всего, что к ней прикреплено.",

	STYLE_GOLD = "Золотая (как в диалогах)",
	STYLE_TOOLTIP = "Как у подсказок",
	STYLE_THIN = "Тонкая линия",
	STYLE_NONE = "Без рамки",

	COLOR_NATURAL = "Естественный",
	COLOR_BLACK = "Чёрный",
	COLOR_GREY = "Серый",
	COLOR_GOLD = "Золотой",
	COLOR_CLASS = "Цвет класса",

	LOADED = "v%s загружен. Введите %s, чтобы открыть настройки.",
	HELP_HEADER = "команды:",
	HELP_OPEN = "%s - открыть настройки",
	HELP_RESET = "%s reset - вернуть настройки по умолчанию",
	RESET_DONE = "настройки сброшены.",
}

local translations = { ruRU = ruRU }

--- Build the string table for a locale; missing keys fall back to English, then to the key itself.
---@param locale string|nil
---@return table
function ns.BuildLocale(locale)
	local own = translations[locale] or {}
	return setmetatable({}, {
		__index = function(_, key)
			return own[key] or enUS[key] or key
		end,
	})
end

ns.L = ns.BuildLocale(GetLocale and GetLocale() or "enUS")
