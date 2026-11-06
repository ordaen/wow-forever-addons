-- Ordaen Tooltips' start: declares the addon to the Ordaen Core framework and starts the takeover of the native
-- tooltips as a feature (its own protected call after login; its hooks run only while it is on).
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenTooltipsDB",
	defaults = { anchorToButtons = true },
	slash = { "/otips", "/ordaentooltips" },
	settings = {
		title = "SETTINGS_TITLE",
		{ key = "anchorToButtons", label = "BESIDE_BUTTONS", tooltip = "BESIDE_BUTTONS_TOOLTIP" },
	},
	dump = function()
		return { takeover = ns.Takeover.Describe() }
	end,
})
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A
ns.Debug = A.Debug

local takeover = A:Feature("takeover")
takeover:OnEnable(function()
	ns.Takeover.Enable(takeover)
end)
takeover:OnDisable(function()
	ns.Takeover.Disable()
end)
