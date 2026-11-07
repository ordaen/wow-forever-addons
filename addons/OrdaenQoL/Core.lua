-- Ordaen QoL's start: declares the addon to the Ordaen Core framework (SavedVariables, settings page, slash) and its
-- two features, each switched by its own setting: sell junk and repair at a vendor (Merchant.lua).
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenQoLDB",
	defaults = { autoSellJunk = true, autoRepair = true },
	slash = { "/oqol", "/ordaenqol" },
	settings = {
		title = "SETTINGS_TITLE",
		{ key = "autoSellJunk", label = "AUTO_SELL_JUNK", tooltip = "AUTO_SELL_JUNK_TOOLTIP" },
		{ key = "autoRepair", label = "AUTO_REPAIR", tooltip = "AUTO_REPAIR_TOOLTIP" },
	},
})
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A
ns.Debug = A.Debug
function ns.Print(...)
	A:Print(...)
end

-- Each listens to MERCHANT_SHOW only while its setting is on.
local sellJunk = A:Feature("sellJunk", { setting = "autoSellJunk" })
sellJunk:OnEnable(function()
	sellJunk:On("MERCHANT_SHOW", ns.Merchant.SellJunk)
end)

local repair = A:Feature("repair", { setting = "autoRepair" })
repair:OnEnable(function()
	repair:On("MERCHANT_SHOW", ns.Merchant.Repair)
end)
