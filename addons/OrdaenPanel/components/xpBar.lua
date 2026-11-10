-- The status bars (design status-bars, panel XpTube): glass tubes with margins on the wood, back to front the trough,
-- the fill, engraved sections every tenth, the glass shine, the bronze ring, and its text in the middle. Experience:
-- the rested part in pale blue and the player's fill (attribute `fill`); reputation: the watched faction in steel.
-- In the panel one tube: experience, or at the level cap the watched faction (nothing when none is); as a bar of its
-- own (attribute `both`), the faction under the experience.
local Define = import("@ordaen/define")

local TUBE_HEIGHT = 25 -- 30 px at the user's scale: slim at a third of the screen's width (design/panel)
local MARGIN = 32 -- 38 px each side
local INSET = TUBE_HEIGHT * 10 / 64 -- the trough's inside, as the art draws it
local SECTIONS = 10

local OUTER = { width = "100%", padding = { 0, MARGIN, 0, MARGIN }, yAlign = "center", columns = 1, gap = 6 / 1.2 }
local TUBE = { height = TUBE_HEIGHT }
local function layer(background)
	return { attributes = { position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
		background = background } }
end
local TROUGH = layer(Define.Theme.panel.xpTrough)
local SHINE = layer(Define.Theme.panel.xpShine)
local RING = layer(Define.Theme.panel.xpTube)
-- the share done, in the tube's middle: 15 px bold-weight light text with a dark drop and outline (design .label)
local LABEL_COLOR = { 0.953, 0.906, 0.8, 1 } -- #f3e7cc
local LABEL_SHADOW = { color = { 0, 0, 0, 1 }, x = 1, y = -1 }
-- over the whole tube, its text centred both ways
local LABEL = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, xAlign = "center", yAlign = "center" }
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

local function Inner(game, self)
	game.ui:Box({ attributes = {
		position = "absolute", left = 0, top = 0, height = "100%", width = RestedWidth(game),
		background = Define.Theme.color.xpRested,
	} })
	game.ui:Box({ attributes = {
		position = "absolute", left = 0, top = 0, height = "100%", width = FillWidth(game),
		background = Define.Theme.panel.xpFill[self.attributes.fill or "brushed"],
	} })
	game.ui:Box(MARKS_CALL)
end

local function Label(game)
	game.ui:Text({ attributes = {
		text = Percent(game), textSize = 12.5, textColor = LABEL_COLOR, textOutline = "thin", textShadow = LABEL_SHADOW,
		wrap = false,
	} })
end

local function Layers(game)
	game.ui:Box(TROUGH)
	game.ui:Box({ attributes = INNER, slots = { default = Inner } })
	game.ui:Box(SHINE)
	game.ui:Box(RING)
	game.ui:Box({ attributes = LABEL, slots = { default = Label } })
end

-- The reputation tube (design StatusBarsBar): the same glass, the steel fill, the watched faction's name, standing
-- and how far into it ("Stormwind: Honored 40%").
local function RepWidth(game)
	local r = game.Reputation
	local span = r.max:Get() - r.min:Get()
	return span > 0 and format("%.2f%%", 100 * (r.value:Get() - r.min:Get()) / span) or "100%"
end
local function RepLabel(game)
	local r = game.Reputation
	local span = r.max:Get() - r.min:Get()
	local share = span > 0 and floor(100 * (r.value:Get() - r.min:Get()) / span) or 100
	return format("%s: %s %d%%", r.name:Get(), r.standing:Get(), share)
end

local function RepInner(game)
	game.ui:Box({ attributes = {
		position = "absolute", left = 0, top = 0, height = "100%", width = RepWidth(game),
		background = Define.Theme.panel.xpFill.steel,
	} })
	game.ui:Box(MARKS_CALL)
end

local function RepText(game)
	game.ui:Text({ attributes = {
		text = RepLabel(game), textSize = 12.5, textColor = LABEL_COLOR, textOutline = "thin",
		textShadow = LABEL_SHADOW, wrap = false,
	} })
end

local function RepLayers(game)
	game.ui:Box(TROUGH)
	game.ui:Box({ attributes = INNER, slots = { default = RepInner } })
	game.ui:Box(SHINE)
	game.ui:Box(RING)
	game.ui:Box({ attributes = LABEL, slots = { default = RepText } })
end

local XP_TUBE = { key = "xp", attributes = TUBE, slots = { default = Layers } }
local REP_TUBE = { key = "reputation", attributes = TUBE, slots = { default = RepLayers } }

-- what the bar shows: experience below the level cap, and the watched faction under it when `both` (a bar of its own);
-- at the cap, the watched faction alone
local function Tubes(game, self)
	local max = game.Player.xpMax:Get()
	local capped = not max or max <= 0
	local watched = game.Reputation.name:Get() ~= ""
	if not capped then
		game.ui:Box(XP_TUBE)
	end
	if watched and (capped or self.attributes.both) then
		game.ui:Box(REP_TUBE)
	end
end

return Define.Component({
	Render = function(game)
		game.ui:Box({ attributes = OUTER, slots = { default = Tubes } })
	end,
})
