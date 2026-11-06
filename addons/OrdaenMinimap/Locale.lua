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
	RESET_DONE = "settings restored to defaults (including conflict choices).",

	UNKNOWN_ADDON = "another addon",
	CONFLICT_TEXT = "%s also changes the minimap. Both at once will fight over it.\n\nWhich one do you want to keep?",
	CONFLICT_TEXT_UNKNOWN = "Another addon changes the minimap too. Both at once will fight over it.\n\n"
		.. "Keep Ordaen Minimap, or turn it off?",
	CONFLICT_KEEP_OURS = "Keep Ordaen Minimap",
	CONFLICT_KEEP_OTHER = "Keep %s",
	CONFLICT_DISABLE_OURS = "Turn off Ordaen Minimap",
	CONFLICT_LATER = "Decide later",
	CONFLICT_OVERRIDE_HINT = "keeping Ordaen Minimap. If %s has its own minimap options (shape, border), "
		.. "turn them off there.",
	CONFLICT_LATER_HINT = "Ordaen Minimap stays off until the next login, where it asks again.",

	HEADER_DRAWER = "Button drawer",
	DRAWER_ENABLED = "Button drawer",
	DRAWER_ENABLED_TOOLTIP = "Collects other addons' minimap buttons and addon compartment entries behind one "
		.. "small button. Turning it off needs a /reload to put the buttons back on the map.",
	HIDE_BLIZZARD_COMPARTMENT = "Hide Blizzard's addon button",
	HIDE_BLIZZARD_COMPARTMENT_TOOLTIP = "Hides Blizzard's addon compartment button; its entries are in the drawer.",
	DRAWER_COLUMNS = "Columns",
	DRAWER_COLUMNS_TOOLTIP = "How many buttons per row in the drawer.",
	DRAWER_TOOLTIP_CLICK = "Click: open or close the drawer",
	DRAWER_TOOLTIP_RIGHT = "Right-click: settings",
	DRAWER_TOOLTIP_MOVE = "Shift-drag: move this button",
	DRAWER_MBB_WARNING = "MinimapButtonButton is loaded, so the button drawer stays off (both would grab the same "
		.. "buttons). Disable one of them.",
	DRAWER_RELOAD_HINT = "button drawer off. Type /reload to put the buttons back on the minimap.",
	STYLE_BRONZE_RIM = "Bronze rim",
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
	RESET_DONE = "настройки сброшены (включая выбор при конфликтах).",

	UNKNOWN_ADDON = "другая модификация",
	CONFLICT_TEXT = "%s тоже меняет миникарту. Вместе они будут мешать друг другу.\n\nКакую модификацию оставить?",
	CONFLICT_TEXT_UNKNOWN = "Другая модификация тоже меняет миникарту. Вместе они будут мешать друг другу.\n\n"
		.. "Оставить Ordaen Minimap или выключить её?",
	CONFLICT_KEEP_OURS = "Оставить Ordaen Minimap",
	CONFLICT_KEEP_OTHER = "Оставить %s",
	CONFLICT_DISABLE_OURS = "Выключить Ordaen Minimap",
	CONFLICT_LATER = "Решить позже",
	CONFLICT_OVERRIDE_HINT = "Ordaen Minimap остаётся. Если у %s есть свои настройки миникарты (форма, рамка), "
		.. "выключите их там.",
	CONFLICT_LATER_HINT = "Ordaen Minimap выключен до следующего входа в игру, тогда вопрос появится снова.",

	HEADER_DRAWER = "Панель кнопок",
	DRAWER_ENABLED = "Панель кнопок",
	DRAWER_ENABLED_TOOLTIP = "Собирает кнопки модификаций с миникарты и пункты меню модификаций за одной маленькой "
		.. "кнопкой. Чтобы вернуть кнопки на карту после выключения, нужен /reload.",
	HIDE_BLIZZARD_COMPARTMENT = "Скрыть кнопку модификаций Blizzard",
	HIDE_BLIZZARD_COMPARTMENT_TOOLTIP = "Скрывает кнопку меню модификаций Blizzard; её пункты есть в панели.",
	DRAWER_COLUMNS = "Столбцы",
	DRAWER_COLUMNS_TOOLTIP = "Сколько кнопок в одном ряду панели.",
	DRAWER_TOOLTIP_CLICK = "Щелчок: открыть или закрыть панель",
	DRAWER_TOOLTIP_RIGHT = "Правый щелчок: настройки",
	DRAWER_TOOLTIP_MOVE = "Shift + перетаскивание: переместить кнопку",
	DRAWER_MBB_WARNING = "Загружен MinimapButtonButton, поэтому панель кнопок выключена (обе собирают одни и те же "
		.. "кнопки). Выключите одну из них.",
	DRAWER_RELOAD_HINT = "панель кнопок выключена. Введите /reload, чтобы вернуть кнопки на миникарту.",
	STYLE_BRONZE_RIM = "Бронзовый обод",
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
