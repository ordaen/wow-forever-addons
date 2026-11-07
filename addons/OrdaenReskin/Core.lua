-- Ordaen Reskin's start: Blizzard's own windows and dialogs in the theme's window art (Ordaen Core's frame.*
-- tokens, drawn by OrdaenCore.UI), so every window looks like every Ordaen surface. Blizzard keeps its windows:
-- only their border and fill are swapped (Skins.lua). Settings come from settings.jsonc.
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	slash = { "/oreskin", "/ordaenreskin" },
	dump = function()
		return ns.Skins.Describe()
	end,
}) --[[@as OrdaenReskinAddon]]
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A

-- One feature per kind of window. Load-on-demand windows appear when Blizzard loads them.
local windows = A:Feature("windows", { setting = "windows" })
windows:On("ADDON_LOADED", function()
	ns.Skins.Watch("window")
end)
windows:OnEnable(function()
	ns.Skins.Enable("window")
end)
windows:OnDisable(function()
	ns.Skins.Disable("window")
end)

local dialogs = A:Feature("dialogs", { setting = "dialogs" })
dialogs:On("ADDON_LOADED", function()
	ns.Skins.Watch("dialog")
end)
dialogs:OnEnable(function()
	ns.Skins.Enable("dialog")
end)
dialogs:OnDisable(function()
	ns.Skins.Disable("dialog")
end)
