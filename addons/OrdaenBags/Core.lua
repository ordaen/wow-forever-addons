-- Ordaen Bags' start: declares the addon to the Ordaen Core framework. The window (category tabs on the left,
-- sections of slots, search, sort, money) comes in the next steps; slots wait for the API dump to know ItemButton.
--
-- Conflicts: the bag addons that replace Blizzard's bags the same way (Baganator, Bagnon, AdiBags, ArkInventory):
-- both would take the bag key and the bag frames, so the player is asked at login (Core's dialog).
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenBagsDB",
	defaults = {},
	conflicts = { "Baganator", "Bagnon", "AdiBags", "ArkInventory" },
})
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A
ns.Debug = A.Debug
