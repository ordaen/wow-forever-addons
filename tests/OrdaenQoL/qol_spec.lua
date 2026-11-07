-- Ordaen QoL: at a vendor, sells the junk (Blizzard's own "sell all junk") and repairs with your own gold, each
-- while its setting is on.
local helpers = require("tests.OrdaenCore.helpers")

local function stub(name)
	local obj = { name = name, calls = {}, scripts = {}, shown = true }
	setmetatable(obj, { __index = function(self, method)
		if not helpers.isStubMethod(method) then
			return nil
		end
		local fn = function(_, ...)
			self.calls[method] = self.calls[method] or {}
			table.insert(self.calls[method], { ... })
		end
		rawset(self, method, fn)
		return fn
	end })
	function obj:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function obj:HookScript(script, fn)
		local before = self.scripts[script]
		self.scripts[script] = before and function(...)
			before(...)
			fn(...)
		end or fn
	end
	function obj:GetName()
		return self.name
	end
	return obj
end

describe("Ordaen QoL", function()
	local ns, frames, chat, vendor

	local function fire(event, ...)
		helpers.fireOn(frames, event, ...)
	end

	local function login()
		fire("ADDON_LOADED", "OrdaenQoL")
		fire("PLAYER_LOGIN")
	end

	before_each(function()
		frames, chat = {}, {}
		-- The vendor and the player's purse: what the game answers.
		vendor = { junk = 3, sellAll = true, sold = 0, canRepair = true, cost = 2500, needsRepair = true,
			money = 10000, repaired = 0 }
		rawset(_G, "OrdaenQoLDB", nil) -- a new character
		helpers.stubGlobals({
			CreateFrame = function(_, name)
				local f = stub(name or "anon")
				table.insert(frames, f)
				return f
			end,
			DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg)
				table.insert(chat, msg)
			end },
			C_MerchantFrame = {
				GetNumJunkItems = function()
					return vendor.junk
				end,
				IsSellAllJunkEnabled = function()
					return vendor.sellAll
				end,
				SellAllJunkItems = function()
					vendor.sold = vendor.sold + vendor.junk
					vendor.junk = 0
				end,
			},
			CanMerchantRepair = function()
				return vendor.canRepair
			end,
			GetRepairAllCost = function()
				return vendor.needsRepair and vendor.cost or 0, vendor.needsRepair
			end,
			RepairAllItems = function(guildBank)
				assert.is_nil(guildBank, "own gold only")
				vendor.repaired = vendor.repaired + 1
				vendor.money = vendor.money - vendor.cost
				vendor.needsRepair = false
			end,
			GetMoney = function()
				return vendor.money
			end,
			GetMoneyString = function(copper)
				return copper .. "c"
			end,
		})
		helpers.loadCore()
		ns = {}
		helpers.loadAddon("OrdaenQoL", ns)
	end)

	after_each(function()
		assert.same({}, helpers.forwarded) -- no error was caught and reported on the way
	end)

	local function said(text)
		for _, line in ipairs(chat) do
			if line:find(text, 1, true) then
				return true
			end
		end
		return false
	end

	it("sells the junk and repairs when a vendor opens, and says so", function()
		login()
		fire("MERCHANT_SHOW")
		assert.equals(3, vendor.sold)
		assert.equals(1, vendor.repaired)
		assert.is_true(said("junk sold: 3 items."))
		assert.is_true(said("gear repaired for 2500c."))
	end)

	it("does nothing when both settings are off", function()
		login()
		for _, key in ipairs({ "autoSellJunk", "autoRepair" }) do
			ns.Addon.db[key] = false
			ns.Addon:_SettingChanged(key, false)
		end
		fire("MERCHANT_SHOW")
		assert.equals(0, vendor.sold)
		assert.equals(0, vendor.repaired)
	end)

	it("sells nothing when there is no junk or Blizzard doesn't allow selling it all", function()
		vendor.junk = 0
		login()
		fire("MERCHANT_SHOW")
		assert.equals(0, vendor.sold)
		assert.is_false(said("junk sold"))
		vendor.junk, vendor.sellAll = 2, false
		fire("MERCHANT_SHOW")
		assert.equals(0, vendor.sold)
	end)

	it("says so instead of repairing when the gold isn't enough", function()
		vendor.money = 100
		login()
		fire("MERCHANT_SHOW")
		assert.equals(0, vendor.repaired)
		assert.is_true(said("not enough gold to repair your gear (2500c)."))
	end)

	it("doesn't repair at a vendor that can't repair, or when nothing is damaged", function()
		vendor.canRepair = false
		login()
		fire("MERCHANT_SHOW")
		assert.equals(0, vendor.repaired)
		vendor.canRepair, vendor.needsRepair = true, false
		fire("MERCHANT_SHOW")
		assert.equals(0, vendor.repaired)
		assert.is_false(said("repaired"))
	end)
end)
