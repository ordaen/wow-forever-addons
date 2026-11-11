-- Made by lunatype from OrdaenProfessions/style.luna: change the source, not this file.
local R = LunaType
local M = {}
R.addon("OrdaenProfessions")["style"] = M
local WIDTH, HEIGHT, LEFT, CATEGORIES, GAP, TEXT, RECIPE_TEXT, SMALL, NAME, INK, DIM, GOLD, WHITE, RED, OFF, LINE, CLEAR, ROW_CHOSEN, ROW_LIGHT, CHOSEN_EDGE, LISTS_BACK, SHADOW, ROW_RULE, BRONZE, difficultyColor
WIDTH = 883.3333333333334
HEIGHT = 583.3333333333334
LEFT = 441.6666666666667
CATEGORIES = 208.33333333333334
GAP = 10
TEXT = 11.666666666666668
RECIPE_TEXT = 10.833333333333334
SMALL = 10
NAME = 14.166666666666668
INK = { r = 0.910, g = 0.863, b = 0.769, a = 1 }
DIM = { r = 0.639, g = 0.592, b = 0.498, a = 1 }
GOLD = { r = 1, g = 0.820, b = 0, a = 1 }
WHITE = { r = 1, g = 1, b = 1, a = 1 }
RED = { r = 1, g = 0.251, b = 0.251, a = 1 }
OFF = { r = 0.478, g = 0.439, b = 0.376, a = 1 }
LINE = { r = 0.243, g = 0.184, b = 0.114, a = 1 }
CLEAR = { r = 0, g = 0, b = 0, a = 0 }
ROW_CHOSEN = { r = 0.839, g = 0.647, b = 0.420, a = 0.239 }
ROW_LIGHT = { default = CLEAR, hover = { r = 0.839, g = 0.647, b = 0.420, a = 0.122 } }
CHOSEN_EDGE = { r = 0.941, g = 0.784, b = 0.376, a = 1 }
LISTS_BACK = { r = 0, g = 0, b = 0, a = 0.302 }
SHADOW = { color = { r = 0, g = 0, b = 0, a = 1 }, x = 0.8333333333333334, y = -0.8333333333333334 }
ROW_RULE = { width = 0.8333333333333334, color = { r = 0.839, g = 0.647, b = 0.420, a = 0.078 }, sides = { "top" } }
BRONZE = { width = 0.8333333333333334, color = { r = 0.424, g = 0.333, b = 0.208, a = 1 } }

function difficultyColor(difficulty)
	if difficulty == 0 then
		return { r = 1, g = 0.502, b = 0.251, a = 1 }
	elseif difficulty == 1 then
		return { r = 1, g = 0.820, b = 0, a = 1 }
	elseif difficulty == 2 then
		return { r = 0.251, g = 0.753, b = 0.251, a = 1 }
	elseif difficulty == 3 then
		return { r = 0.604, g = 0.604, b = 0.604, a = 1 }
	end
end

M.WIDTH = WIDTH
M.HEIGHT = HEIGHT
M.LEFT = LEFT
M.CATEGORIES = CATEGORIES
M.GAP = GAP
M.TEXT = TEXT
M.RECIPE_TEXT = RECIPE_TEXT
M.SMALL = SMALL
M.NAME = NAME
M.INK = INK
M.DIM = DIM
M.GOLD = GOLD
M.WHITE = WHITE
M.RED = RED
M.OFF = OFF
M.LINE = LINE
M.CLEAR = CLEAR
M.ROW_CHOSEN = ROW_CHOSEN
M.ROW_LIGHT = ROW_LIGHT
M.CHOSEN_EDGE = CHOSEN_EDGE
M.LISTS_BACK = LISTS_BACK
M.SHADOW = SHADOW
M.ROW_RULE = ROW_RULE
M.BRONZE = BRONZE
M.difficultyColor = difficultyColor
