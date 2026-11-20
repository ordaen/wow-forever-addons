-- Pawn's API, read for Ordaen Dialogue's rewards (declared in pawn.d.luna). Pawn is called through `pcall`, never
-- copied: an error of its own is no error of the window's.
local name = ...

local pawn = {}

function pawn.present()
	local loaded = C_AddOns.IsAddOnLoaded("Pawn")
	return loaded == true and type(_G.PawnGetItemData) == "function" and type(_G.PawnIsItemAnUpgrade) == "function"
end

function pawn.upgrade(link)
	if not pawn.present() then return nil end
	local ok, item = pcall(_G.PawnGetItemData, link)
	if not ok or item == nil then return nil end
	local fine, upgrades = pcall(_G.PawnIsItemAnUpgrade, item)
	if not fine or type(upgrades) ~= "table" then return nil end
	local best
	for _, scale in ipairs(upgrades) do
		local percent = type(scale) == "table" and scale.PercentUpgrade or nil
		if type(percent) == "number" and (best == nil or percent > best) then best = percent end
	end
	return best
end

LunaType.addon(name)["pawn"] = pawn
