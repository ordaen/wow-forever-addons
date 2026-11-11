-- The professions window's look, shared by its parts (design professions/, ProfessionsWindow): sizes at the user's
-- scale (a px is 1/1.2 UI units) and colours.
local PX = 1 / 1.2

local function rgb(hex, a)
	return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255,
		a or 1 }
end

return {
	PX = PX,
	WIDTH = 1060 * PX, -- the body
	HEIGHT = 700 * PX,
	LEFT = 530 * PX, -- the recipes' side: the search and the lists
	CATEGORIES = 250 * PX,
	GAP = 12 * PX,
	TEXT = 14 * PX, -- a category's name
	RECIPE_TEXT = 13 * PX,
	SMALL = 12 * PX,
	NAME = 17 * PX, -- the chosen recipe's
	INK = rgb("e8dcc4"), -- --o-ink
	DIM = rgb("a3977f"), -- --o-dim
	GOLD = rgb("ffd100"),
	WHITE = { 1, 1, 1, 1 },
	RED = rgb("ff4040"),
	OFF = rgb("7a7060"), -- an unlearned recipe
	LINE = rgb("3e2f1d"), -- the lists' frame and the column rule
	ROW_RULE = rgb("d6a56b", 0.08), -- between rows
	ROW_HOVER = rgb("d6a56b", 0.12),
	ROW_CHOSEN = rgb("d6a56b", 0.24),
	CHOSEN_EDGE = rgb("f0c860"), -- the chosen row's 2 px at its left
	LISTS_BG = { 0, 0, 0, 0.3 },
	SHADOW = { color = { 0, 0, 0, 1 }, x = 1 * PX, y = -1 * PX },
	-- a recipe's name in its difficulty colour and what that means, by the game's relative difficulty
	-- (game.TradeSkill.Difficulty: 0 orange, 1 yellow, 2 green, 3 grey)
	DIFFICULTY = { [0] = rgb("ff8040"), [1] = rgb("ffd100"), [2] = rgb("40c040"), [3] = rgb("9a9a9a") },
}
