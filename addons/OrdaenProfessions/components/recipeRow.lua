-- A recipe in the recipes' second column: its name in its difficulty colour, `[N]` for how many the bags can make now;
-- unlearned ones dim; the chosen one on a shade.
--
-- Attributes: `id` (the recipe's), `chosen` (a signal: the chosen recipe's id), `OnClick`.
local Define = import("@ordaen/define")
local S = import("style")

local function Chosen(self)
	return self.attributes.chosen:Get() == self.attributes.id
end

local function Recipe(game, self)
	game.TradeSkill.version:Get()
	return game.TradeSkill:Recipe(self.attributes.id)
end

local function Label(game, self)
	local r = Recipe(game, self)
	if not r then
		return ""
	end
	return r.craftable > 0 and r.name .. "  [" .. r.craftable .. "]" or r.name
end

local function Color(game, self)
	local r = Recipe(game, self)
	return r and r.learned and S.DIFFICULTY[r.difficulty] or S.DIM
end

local function Text(game, self)
	game.ui:Text({ attributes = { text = Label(game, self), textSize = S.TEXT, wrap = false,
		textColor = Color(game, self) } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { height = S.ROW_H, padding = { 0, 6 * S.PX, 0, 6 * S.PX }, yAlign = "center",
			background = Chosen(self) and S.SHADE or nil, OnClick = self.attributes.OnClick },
			slots = { default = Text } })
	end,
})
