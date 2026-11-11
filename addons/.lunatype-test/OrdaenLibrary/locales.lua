-- Made by lunatype from OrdaenLibrary/locales: change the JSON, not this file.
local R = LunaType
local all = {
	enUS = {
		MODULE_NOTES = "The controls and windows every Ordaen module draws. Loaded when a module first needs it.",
		SOON = "in development",
		UNIT_PX = "%d px",
		UNIT_SEC = "%.1f s",
	},
	ruRU = {
		MODULE_NOTES = "Элементы управления и окна, которые рисуют модули Ordaen. Загружается, когда понадобится модулю.",
		SOON = "в разработке",
		UNIT_PX = "%d пикс.",
		UNIT_SEC = "%.1f сек.",
	},
}
R.addon("OrdaenLibrary")["locales"] = all[R.locale] or all.enUS
