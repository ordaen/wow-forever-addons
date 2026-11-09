-- The experience bar across the panel's middle (design/panel XpTube): a glass tube with margins on the wood, back to
-- front the trough, the rested part in pale blue and the experience fill (tiled brushed metal), engraved sections every
-- tenth, the glass shine, the bronze ring, and the share of the level done in its middle. At the level cap it shows
-- nothing (the column stays, empty).
local Define = import("@ordaen/define")

local TUBE_HEIGHT = 30 -- 36 px at the user's scale
local MARGIN = 32 -- 38 px each side
local INSET = TUBE_HEIGHT * 10 / 64 -- the trough's inside, as the art draws it
local SECTIONS = 10

local OUTER = { padding = { 0, MARGIN, 0, MARGIN }, yAlign = "center" }
local TUBE = { height = TUBE_HEIGHT }
local function layer(background)
	return { attributes = { position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
		background = background } }
end
local TROUGH = layer(Define.Theme.panel.xpTrough)
local SHINE = layer(Define.Theme.panel.xpShine)
local RING = layer(Define.Theme.panel.xpTube)
local INNER = { position = "absolute", left = INSET, top = INSET, right = INSET, bottom = INSET }
-- the engraved section marks: 1 px dark lines at each tenth
local TICKS = {}
for k = 1, SECTIONS - 1 do
	TICKS[k] = { key = k, attributes = {
		position = "absolute", left = (100 * k / SECTIONS) .. "%", top = 0, width = 1, height = "100%",
		background = { 0, 0, 0, 0.5 },
	} }
end
local LABEL = {
	position = "absolute", left = 0, top = 0, width = "100%", height = "100%", textAlign = "center",
	textSize = 12.5, textColor = { 0.953, 0.906, 0.8, 1 },
}
local format = string.format

local function Inner(game, self)
	game.ui:Box(self.rested)
	game.ui:Box(self.fill)
	for k = 1, #TICKS do
		game.ui:Box(TICKS[k])
	end
end

local function Layers(game, self)
	game.ui:Box(TROUGH)
	game.ui:Box(self.inner)
	game.ui:Box(SHINE)
	game.ui:Box(RING)
	game.ui:Text(self.label)
end

local function Tube(game, self)
	game.ui:Box(self.tube)
end

return Define.Component({
	Setup = function(game, self)
		-- one call table each, refilled by the render (the widths and the label change)
		local rested = { attributes = {
			position = "absolute", left = 0, top = 0, height = "100%", width = "0%", background = Define.Theme.color.xpRested,
		} }
		local fill = { attributes = {
			position = "absolute", left = 0, top = 0, height = "100%", width = "0%", background = Define.Theme.panel.xpFill,
		} }
		local label = { attributes = {
			position = LABEL.position, left = 0, top = 0, width = "100%", height = "100%", text = "",
			textAlign = LABEL.textAlign, textSize = LABEL.textSize, textColor = LABEL.textColor,
		} }
		return {
			outer = { attributes = OUTER, slots = { default = Tube } },
			tube = { attributes = TUBE, slots = { default = Layers } },
			inner = { attributes = INNER, slots = { default = Inner } },
			rested = rested, fill = fill, label = label,
		}
	end,

	Render = function(game, self)
		local max = game.Player.xpMax:Get()
		if not max or max <= 0 then
			return -- the level cap: no bar
		end
		local current = game.Player.xp:Get() or 0
		local restedXp = game.Player.rested:Get() or 0
		self.fill.attributes.width = format("%.2f%%", 100 * current / max)
		self.rested.attributes.width = format("%.2f%%", 100 * math.min(current + restedXp, max) / max)
		self.label.attributes.text = format("%d%%", math.floor(100 * current / max))
		game.ui:Box(self.outer)
	end,
})
