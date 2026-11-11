-- A reagent of the chosen recipe (design ProfessionsWindow .reag): its icon in a slot, its name, have / need (red when
-- short); a faint rule above every row but the first.
--
-- Attributes: `index` (its place in game.TradeSkill.schematic.reagents).
local Define = import("@ordaen/define")
local S = import("style")

local SLOT = 32 * S.PX
local BRONZE = { width = 1 * S.PX, color = { 0.424, 0.333, 0.208, 1 } } -- --o-bronze, an item slot's edge
local RULE = { width = 1 * S.PX, sides = { "top" }, color = S.ROW_RULE }
local COLUMNS = { SLOT, "1fr", "auto" }
local PAD = { 3 * S.PX, 6 * S.PX, 3 * S.PX, 0 }

local function Reagent(game, self)
	game.TradeSkill.version:Get()
	return game.TradeSkill.schematic.reagents[self.attributes.index]
end
local function Icon(game, self)
	local r = Reagent(game, self)
	return r and C_Item.GetItemIconByID(r.itemID) or nil
end
local function Name(game, self)
	local r = Reagent(game, self)
	return r and C_Item.GetItemNameByID(r.itemID) or ""
end
local function HaveNeed(game, self)
	local r = Reagent(game, self)
	return r and r.have .. " / " .. r.need or ""
end
local function Short(game, self)
	local r = Reagent(game, self)
	return r ~= nil and r.have < r.need
end

local function Parts(game, self)
	game.ui:Box({ attributes = { width = SLOT, height = SLOT, border = BRONZE, background = Icon(game, self) } })
	game.ui:Text({ attributes = { text = Name(game, self), textSize = S.RECIPE_TEXT, textColor = S.INK } })
	game.ui:Text({ attributes = { text = HaveNeed(game, self), textSize = S.RECIPE_TEXT, wrap = false,
		textColor = Short(game, self) and S.RED or S.INK, textFamily = Define.Theme.font.numbers } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = COLUMNS, gap = 8 * S.PX, yAlign = "center", padding = PAD,
			border = self.attributes.index > 1 and RULE or nil }, slots = { default = Parts } })
	end,
})
