-- A category in the recipes' first column (design ProfessionsWindow .ci): its name in gold, wrapping, and `N (M)` at
-- the right, N its recipes, M how many of them the bags can make now (white when any). A faint rule between rows; the
-- row lights under the cursor, and the chosen one more, with a 2 px gold edge at its left.
--
-- Attributes: `id` (the category's), `first` (no rule above it), `chosen` (a signal: the chosen category's id),
-- `OnClick`.
local Define = import("@ordaen/define")
local S = import("style")

local PAD = { 7 * S.PX, 10 * S.PX, 7 * S.PX, 10 * S.PX }
local COLUMNS = { "1fr", "auto" }
local RULE = { width = 1 * S.PX, sides = { "top" }, color = S.ROW_RULE }
local EDGE = { position = "absolute", left = 0, top = 0, bottom = 0, width = 2 * S.PX, background = S.CHOSEN_EDGE }
local SOME = S.WHITE

local function Chosen(self)
	return self.attributes.chosen:Get() == self.attributes.id
end

local function Counts(game, self)
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
	return n, m
end

local function Name(game, self)
	game.TradeSkill.version:Get()
	local categories = game.TradeSkill.categories
	for i = 1, #categories do
		if categories[i].id == self.attributes.id then
			return categories[i].name
		end
	end
	return ""
end

local function Total(game, self)
	return tostring((Counts(game, self)))
end
local function Makeable(game, self)
	local _, m = Counts(game, self)
	return "(" .. m .. ")"
end
local function MakeableColor(game, self)
	local _, m = Counts(game, self)
	return m > 0 and SOME or S.DIM
end

local function CountParts(game, self)
	game.ui:Text({ attributes = { text = Total(game, self), textSize = S.SMALL, textColor = S.DIM, wrap = false,
		textFamily = Define.Theme.font.numbers } })
	game.ui:Text({ attributes = { text = Makeable(game, self), textSize = S.SMALL, wrap = false,
		textColor = MakeableColor(game, self), textFamily = Define.Theme.font.numbers } })
end

local function Parts(game, self)
	if Chosen(self) then
		game.ui:Box({ attributes = EDGE })
	end
	game.ui:Text({ attributes = { text = Name(game, self), textSize = S.TEXT, textColor = S.GOLD, textShadow = S.SHADOW,
		width = "100%", wrap = true } })
	game.ui:Box({ attributes = { columns = { "auto", "auto" }, gap = 3 * S.PX, yAlign = "center" },
		slots = { default = CountParts } })
end

local function Background(self)
	return Chosen(self) and S.ROW_CHOSEN or { default = nil, hover = S.ROW_HOVER }
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = COLUMNS, gap = 8 * S.PX, padding = PAD, yAlign = "center",
			border = not self.attributes.first and RULE or nil, background = Background(self),
			OnClick = self.attributes.OnClick }, slots = { default = Parts } })
	end,
})
