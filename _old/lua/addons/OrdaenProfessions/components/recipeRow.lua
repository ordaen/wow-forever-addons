-- A recipe in the recipes' second column (design ProfessionsWindow .rec): its name in its difficulty colour (unlearned
-- ones dim), `[N]` at the right for how many the bags can make now. Ruled, lit and chosen like a category row.
--
-- Attributes: `id` (the recipe's), `first` (no rule above it), `chosen` (a signal: the chosen recipe's id), `OnClick`.
local Define = import("@ordaen/define")
local S = import("style")

local PAD = { 6 * S.PX, 10 * S.PX, 6 * S.PX, 10 * S.PX }
local COLUMNS = { "1fr", "auto" }
local RULE = { width = 1 * S.PX, sides = { "top" }, color = S.ROW_RULE }
local EDGE = { position = "absolute", left = 0, top = 0, bottom = 0, width = 2 * S.PX, background = S.CHOSEN_EDGE }

local function Chosen(self)
	return self.attributes.chosen:Get() == self.attributes.id
end

local function Recipe(game, self)
	game.TradeSkill.version:Get()
	return game.TradeSkill:Recipe(self.attributes.id)
end

local function Name(game, self)
	local r = Recipe(game, self)
	return r and r.name or ""
end

local function Color(game, self)
	local r = Recipe(game, self)
	return r and r.learned and S.DIFFICULTY[r.difficulty] or S.OFF
end

local function Count(game, self)
	local r = Recipe(game, self)
	return r and r.craftable > 0 and "[" .. r.craftable .. "]" or ""
end

local function Parts(game, self)
	if Chosen(self) then
		game.ui:Box({ attributes = EDGE })
	end
	game.ui:Text({ attributes = { text = Name(game, self), textSize = S.RECIPE_TEXT, textColor = Color(game, self),
		textShadow = S.SHADOW, wrap = false } })
	game.ui:Text({ attributes = { text = Count(game, self), textSize = S.SMALL, textColor = S.WHITE, wrap = false,
		textFamily = Define.Theme.font.numbers } })
end

local function Background(self)
	return Chosen(self) and S.ROW_CHOSEN or { default = nil, hover = S.ROW_HOVER }
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = COLUMNS, gap = 8 * S.PX, padding = PAD, yAlign = "center",
			border = not self.attributes.first and RULE or nil, background = Background(self),
			OnClick = self.attributes.OnClick, overflow = "clip" }, slots = { default = Parts } })
	end,
})
