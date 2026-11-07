-- Ordaen Reskin's start: Blizzard's own windows and dialogs in the theme's window art (Ordaen Core's frame.*
-- tokens, drawn by OrdaenCore.UI), so every window looks like every Ordaen surface. Blizzard keeps its windows:
-- their frame and control art is swapped (Windows.lua, Kit.lua). Settings come from settings.jsonc.
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	slash = { "/oreskin", "/ordaenreskin" },
	dump = function()
		return ns.Windows.Describe()
	end,
}) --[[@as OrdaenReskinAddon]]
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A

-- One feature per kind of window, skinned at once (the user's choice: eager, like EllesmereUI). Load-on-demand
-- windows are skinned when Blizzard loads them.
local windows = A:Feature("windows", { setting = "windows" })
windows:On("ADDON_LOADED", function()
	ns.Windows.Watch("window")
end)
windows:OnEnable(function()
	ns.Windows.Enable("window")
end)
windows:OnDisable(function()
	ns.Windows.Disable("window")
end)

local dialogs = A:Feature("dialogs", { setting = "dialogs" })
dialogs:On("ADDON_LOADED", function()
	ns.Windows.Watch("dialog")
end)
dialogs:OnEnable(function()
	ns.Windows.Enable("dialog")
end)
dialogs:OnDisable(function()
	ns.Windows.Disable("dialog")
end)
