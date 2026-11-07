-- Ordaen Bags' start: declares the addon to the Ordaen Core framework (settings come from settings.jsonc) and runs
-- the takeover of Blizzard's bags (Takeover.lua) as a feature, so it stays off while another bag addon that takes
-- the same frames is loaded (Baganator, Bagnon, AdiBags, ArkInventory): the player keeps that one's bags.
-- The window itself (Window.lua) is made the first time the bags open.
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	slash = { "/ob", "/ordaenbags" },
	dump = function()
		return ns.View and ns.View.Dump()
	end,
	onChange = function(key)
		-- the slots per row, the order, and which tabs show: all change the window's layout
		if ns.View and (key == "columns" or key == "sort" or key == "view" or key == "hideEmpty" or key:find("^tabs%.")) then
			ns.View.Relayout()
		end
	end,
}) --[[@as OrdaenBagsAddon]]
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A
ns.Debug = A.Debug

local Bags = A:Feature("takeover", { conflicts = { "Baganator", "Bagnon", "AdiBags", "ArkInventory" } })
Bags:OnEnable(function()
	ns.Takeover.Start()
end)
Bags:OnDisable(function()
	ns.Takeover.Stop()
end)
