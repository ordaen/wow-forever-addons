-- The professions window's look, shared by its parts (design professions/): sizes at the user's scale (a px is 1/1.2
-- UI units) and colours.
local PX = 1 / 1.2

return {
	PX = PX,
	ROW_H = 22 * PX,
	TEXT = 14 * PX,
	TITLE = 17 * PX,
	ICON = 28 * PX,
	INK = { 0.910, 0.863, 0.769, 1 }, -- --o-ink #e8dcc4
	DIM = { 0.639, 0.592, 0.498, 1 }, -- --o-dim #a3977f
	GOLD = { 1, 0.82, 0, 1 },
	RED = { 1, 0.25, 0.25, 1 },
	SHADE = { 0, 0, 0, 0.25 }, -- the chosen row
	-- a recipe's name in its difficulty colour, as the game draws it (orange, yellow, green, grey), by the game's
	-- relative difficulty (game.TradeSkill.Difficulty)
	DIFFICULTY = { [0] = { 1, 0.5, 0.25, 1 }, [1] = { 1, 1, 0, 1 }, [2] = { 0.25, 0.75, 0.25, 1 },
		[3] = { 0.5, 0.5, 0.5, 1 } },
}
