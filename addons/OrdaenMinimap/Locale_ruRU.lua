-- Russian strings. Returns immediately on other clients, so they never keep this table in memory.
local _, ns = ...
if ns.LOCALE ~= "ruRU" then
	return
end

ns.ApplyTranslation({
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
	DRAWER_TOOLTIP_MOVE = "Перетаскивание: переместить вокруг миникарты",
	DRAWER_MBB_WARNING = "Загружен MinimapButtonButton, поэтому панель кнопок выключена (обе собирают одни и те же "
		.. "кнопки). Выключите одну из них.",
	DRAWER_RELOAD_HINT = "панель кнопок выключена. Введите /reload, чтобы вернуть кнопки на миникарту.",
	STYLE_BRONZE_RIM = "Бронзовый обод",
	CONFLICT_DISABLE_MANUALLY = "выключите %s в списке модификаций (на экране выбора персонажа) и перезапустите игру.",
	ZONE_TOOLTIP_MAP = "Щелчок: карта мира",
	TIME_TOOLTIP_CALENDAR = "Щелчок: календарь",
	TIME_TOOLTIP_CLOCK = "Правый щелчок: настройки часов",
	CALENDAR_PENDING = "У вас новые приглашения в календаре",
})
