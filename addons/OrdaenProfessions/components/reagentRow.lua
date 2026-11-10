-- A reagent of the chosen recipe: its icon, its name, and have / need (red when short).
--
-- Attributes: `index` (its place in game.TradeSkill.schematic.reagents).
local Define = import("@ordaen/define")
local S = import("style")

local COLUMNS = { S.ICON, "1fr", "auto" }

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

local function Count(game, self)
	local r = Reagent(game, self)
	return r and r.have .. " / " .. r.need or ""
end

local function Short(game, self)
	local r = Reagent(game, self)
	return r and r.have < r.need
end

local function Parts(game, self)
	game.ui:Box({ attributes = { width = S.ICON, height = S.ICON, background = Icon(game, self) } })
	game.ui:Text({ attributes = { text = Name(game, self), textSize = S.TEXT, textColor = S.INK } })
	game.ui:Text({ attributes = { text = Count(game, self), textSize = S.TEXT, wrap = false,
		textColor = Short(game, self) and S.RED or S.INK } })
end

return Define.Component({
	Render = function(game)
		game.ui:Box({ attributes = { columns = COLUMNS, gap = 8 * S.PX, yAlign = "center" },
			slots = { default = Parts } })
	end,
})
