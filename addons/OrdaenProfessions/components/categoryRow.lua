-- A category in the recipes' first column: its name and `N (M)`, N its recipes, M how many of them the bags can make
-- now; gold while chosen.
--
-- Attributes: `id` (the category's), `chosen` (a signal: the chosen category's id), `OnClick`.
local Define = import("@ordaen/define")
local S = import("style")

local ROW = { height = S.ROW_H, padding = { 0, 6 * S.PX, 0, 6 * S.PX }, yAlign = "center" }

local function Chosen(self)
	return self.attributes.chosen:Get() == self.attributes.id
end

local function Label(game, self)
	game.TradeSkill.version:Get()
	local recipes, n, m = game.TradeSkill.recipes, 0, 0
	for i = 1, #recipes do
		local r = recipes[i]
		if r.categoryID == self.attributes.id then
			n = n + 1
			if r.craftable > 0 then
				m = m + 1
			end
		end
	end
	local name = ""
	local categories = game.TradeSkill.categories
	for i = 1, #categories do
		if categories[i].id == self.attributes.id then
			name = categories[i].name
		end
	end
	return name .. "  " .. n .. " (" .. m .. ")"
end

local function Text(game, self)
	game.ui:Text({ attributes = { text = Label(game, self), textSize = S.TEXT, wrap = false,
		textColor = Chosen(self) and S.GOLD or S.INK } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { height = ROW.height, padding = ROW.padding, yAlign = ROW.yAlign,
			background = Chosen(self) and S.SHADE or nil, OnClick = self.attributes.OnClick },
			slots = { default = Text } })
	end,
})
