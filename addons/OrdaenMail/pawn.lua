-- Pawn's public API, read for Ordaen Mail (declared in pawn.d.luna). Pawn is called from the player's own install
-- through its globals, and nothing of its code is copied here.
local name = ...

local pawn = {}

function pawn.upgrade(link)
	local itemData, isUpgrade = _G.PawnGetItemData, _G.PawnIsItemAnUpgrade
	if type(itemData) ~= "function" or type(isUpgrade) ~= "function" then return nil end
	local item = itemData(link)
	if not item then return nil end
	local upgrades = isUpgrade(item)
	if type(upgrades) ~= "table" then return nil end
	local best = nil
	for _, info in ipairs(upgrades) do
		local share = info.PercentUpgrade
		if type(share) == "number" and share > 0 and (best == nil or share > best) then best = share end
	end
	return best
end

LunaType.addon(name)["pawn"] = pawn
