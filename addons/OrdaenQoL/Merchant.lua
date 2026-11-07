-- Ordaen QoL at a vendor: sells the junk (Blizzard's own "sell all junk") and repairs everything with your own gold,
-- each when its setting is on. One chat line says what happened.
-- Cost: one MERCHANT_SHOW handler per feature, registered only while the feature is on (Core.lua); nothing else.
local _, ns = ...

local Merchant = {}
ns.Merchant = Merchant

local L = ns.L

--- A vendor opened: sell the junk if there is any and Blizzard allows it.
function Merchant.SellJunk()
	local count = C_MerchantFrame.GetNumJunkItems()
	if not count or count <= 0 or not C_MerchantFrame.IsSellAllJunkEnabled() then
		return
	end
	C_MerchantFrame.SellAllJunkItems()
	ns.Print(L.JUNK_SOLD:format(count))
	ns.Debug:Logf("merchant: sold %d junk items", count)
end

--- A vendor opened: repair everything with your own gold if it can repair and you can pay.
function Merchant.Repair()
	if not CanMerchantRepair() then
		return
	end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or not cost or cost <= 0 then
		return
	end
	if GetMoney() < cost then
		ns.Print(L.REPAIR_NO_MONEY:format(GetMoneyString(cost)))
		return
	end
	RepairAllItems()
	ns.Print(L.REPAIRED:format(GetMoneyString(cost)))
	ns.Debug:Logf("merchant: repaired for %d copper", cost)
end
