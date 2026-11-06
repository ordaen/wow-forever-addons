-- Ordaen Meter's start: the game's own damage meter (Blizzard_DamageMeter, C_DamageMeter) in the Ordaen look, so
-- no third-party meter is needed. Blizzard keeps drawing the meter: in combat its numbers are secret, so no addon
-- may compute with them, only show Blizzard's text. The "look" feature dresses its windows, texts and bars
-- (Look.lua). Settings come from settings.jsonc.
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	slash = { "/ometer", "/ordaenmeter" },
	dump = function()
		return ns.Look.Describe()
	end,
}) --[[@as OrdaenMeterAddon]]
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A

-- The meter may load after us (Blizzard loads it with the game, or later when it's turned on): the look starts
-- as soon as it's there.
local look = A:Feature("look", { setting = "meterLook" })
look:On("ADDON_LOADED", function(_, name)
	if name == "Blizzard_DamageMeter" then
		ns.Look.Hook()
	end
end)
look:OnEnable(function()
	ns.Look.Enable(A:Get("barTexture"))
end)
look:OnChange(function(key, value)
	if key == "barTexture" then
		ns.Look.SetBarTexture(value)
	end
end)
look:OnDisable(function()
	ns.Look.Disable()
end)
