-- The profession's skill bar (design ProfessionBar): hanging from the window's top line, the experience bar's fill
-- (the theme's XP fill, the same for every profession) in a dark trough with a bronze rim, a notch every 10%, and on
-- it the rank and the skill: «Ученик · 31 / 75».
--
-- Attributes: `skillLine` (the profession's), `fill` (the XP fill's name, the theme's).
local Define = import("@ordaen/define")
local L = import("locales")
local S = import("style")

local HEIGHT = 30 * S.PX
local RIM = 3 * S.PX
local TROUGH = { 11 / 255, 8 / 255, 5 / 255, 1 } -- #0b0805
local RIM_COLOR = { 0.239, 0.153, 0.063, 1 } -- #3d2710
local NOTCH = { 0, 0, 0, 0.75 }
local TEXT = 14 * S.PX
local NOTCHES = 10
local RANKS = { [75] = L.RANK_75, [150] = L.RANK_150, [225] = L.RANK_225, [300] = L.RANK_300 }

local function Profession(game, self)
	game.Professions.version:Get()
	local list = game.Professions.list
	for i = 1, #list do
		if list[i].skillLine == self.attributes.skillLine then
			return list[i]
		end
	end
	return nil
end

local function Share(game, self)
	local p = Profession(game, self)
	return p and p.max > 0 and math.min(1, p.rank / p.max) or 0
end

local function Label(game, self)
	local p = Profession(game, self)
	if not p then
		return ""
	end
	return (RANKS[p.max] and RANKS[p.max] .. " · " or "") .. p.rank .. " / " .. p.max
end

-- the notches: NOTCHES equal cells, each but the last with a 1 px dark right edge
local NOTCH_CELL = { height = "100%", border = { width = 1 * S.PX, sides = { "right" }, color = NOTCH } }
local LAST_CELL = { height = "100%" }
local NOTCH_CALLS = {}
for k = 1, NOTCHES do
	NOTCH_CALLS[k] = { key = k, attributes = k < NOTCHES and NOTCH_CELL or LAST_CELL }
end
local function Notches(game)
	for k = 1, NOTCHES do
		game.ui:Box(NOTCH_CALLS[k])
	end
end

local function LabelText(game, self)
	game.ui:Text({ attributes = { text = Label(game, self), textSize = TEXT, textColor = S.WHITE, textShadow = S.SHADOW,
		textFamily = Define.Theme.font.numbers, wrap = false } })
end

local function Trough(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 0, top = 0, bottom = 0,
		width = Share(game, self) * 100 .. "%",
		background = Define.Theme.panel.xpFill[self.attributes.fill or "brushed"] } })
	game.ui:Box({ attributes = { position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
		columns = NOTCHES }, slots = { default = Notches } })
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, xAlign = "center",
		yAlign = "center" }, slots = { default = LabelText } })
end

local function Inner(game)
	game.ui:Box({ attributes = { height = HEIGHT - RIM, background = TROUGH, overflow = "clip" },
		slots = { default = Trough } })
end

return Define.Component({
	Render = function(game)
		game.ui:Box({ attributes = { height = HEIGHT, padding = { 0, RIM, RIM, RIM }, background = RIM_COLOR, columns = 1 },
			slots = { default = Inner } })
	end,
})
