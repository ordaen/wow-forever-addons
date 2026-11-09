-- The experience bar in the panel's middle third (design/panel XpTube): a glass tube with margins on the wood, back to
-- front the trough, the rested part in pale blue and the experience fill (tiled brushed metal), engraved sections every
-- tenth, the glass shine, the bronze ring, and the share of the level done in its middle. At the level cap it shows
-- nothing (the column stays, empty).
local Define = import("@ordaen/define")

local TUBE_HEIGHT = 25 -- 30 px at the user's scale: slim at a third of the screen's width (design/panel)
local MARGIN = 32 -- 38 px each side
local INSET = TUBE_HEIGHT * 10 / 64 -- the trough's inside, as the art draws it
local SECTIONS = 10

local OUTER = { padding = { 0, MARGIN, 0, MARGIN }, yAlign = "center" }
local TUBE = { height = TUBE_HEIGHT }
-- zLevel: the shine and the ring draw over the fill and the marks, which sit a level deeper inside the trough
local function layer(background, z)
	return { attributes = { position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
		background = background, zLevel = z } }
end
local TROUGH = layer(Define.Theme.panel.xpTrough)
local SHINE = layer(Define.Theme.panel.xpShine, 2)
local RING = layer(Define.Theme.panel.xpTube, 3)
-- the share done, in the tube's middle: 15 px bold-weight light text with a dark drop and outline (design .label)
local LABEL_COLOR = { 0.953, 0.906, 0.8, 1 } -- #f3e7cc
local LABEL_SHADOW = { color = { 0, 0, 0, 1 }, x = 1, y = -1 }
local INNER = { position = "absolute", left = INSET, top = INSET, right = INSET, bottom = INSET }
-- the engraved section marks: a row of SECTIONS equal cells over the inside, each but the last with a 1 px dark right
-- edge (offsets take units, not shares, so the marks come from the grid)
local MARKS = { position = "absolute", left = 0, top = 0, width = "100%", height = "100%", columns = SECTIONS }
local MARK = { height = "100%", border = { width = 1, sides = { "right" }, color = { 0, 0, 0, 0.5 } } }
local LAST_MARK = { height = "100%" }
local SECTION_CALLS = {}
for k = 1, SECTIONS do
	SECTION_CALLS[k] = { key = k, attributes = k < SECTIONS and MARK or LAST_MARK }
end
local function Sections(game)
	for k = 1, SECTIONS do
		game.ui:Box(SECTION_CALLS[k])
	end
end
local MARKS_CALL = { attributes = MARKS, slots = { default = Sections } }
local format, floor, min = string.format, math.floor, math.min

-- the level's share as the bar shows it, each bound to its one field: the fill's width, the rested part's, the label
local function FillWidth(game)
	local max = game.Player.xpMax:Get() or 0
	return max > 0 and format("%.2f%%", 100 * (game.Player.xp:Get() or 0) / max) or "0%"
end
local function RestedWidth(game)
	local max = game.Player.xpMax:Get() or 0
	local current = (game.Player.xp:Get() or 0) + (game.Player.rested:Get() or 0)
	return max > 0 and format("%.2f%%", 100 * min(current, max) / max) or "0%"
end
local function Percent(game)
	local max = game.Player.xpMax:Get() or 0
	return max > 0 and format("%d%%", floor(100 * (game.Player.xp:Get() or 0) / max)) or ""
end

local function Inner(game)
	game.ui:Box({ attributes = {
		position = "absolute", left = 0, top = 0, height = "100%", width = RestedWidth(game),
		background = Define.Theme.color.xpRested,
	} })
	game.ui:Box({ attributes = {
		position = "absolute", left = 0, top = 0, height = "100%", width = FillWidth(game),
		background = Define.Theme.panel.xpFill.brushed,
	} })
	game.ui:Box(MARKS_CALL)
end

local function Layers(game)
	game.ui:Box(TROUGH)
	game.ui:Box({ attributes = INNER, slots = { default = Inner } })
	game.ui:Box(SHINE)
	game.ui:Box(RING)
	game.ui:Text({ attributes = {
		position = "absolute", left = 0, right = 0, top = 0, bottom = 0, text = Percent(game), textAlign = "center",
		textYAlign = "center", textSize = 12.5, textColor = LABEL_COLOR, textOutline = "thin", textShadow = LABEL_SHADOW,
	} })
end

local function Tube(game)
	game.ui:Box({ attributes = TUBE, slots = { default = Layers } })
end

return Define.Component({
	Render = function(game)
		local max = game.Player.xpMax:Get()
		if not max or max <= 0 then
			return -- the level cap: no bar
		end
		game.ui:Box({ attributes = OUTER, slots = { default = Tube } })
	end,
})
