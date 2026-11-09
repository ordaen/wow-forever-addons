-- The experience bar across the panel's middle: the level's progress, the rested experience beyond it, and the
-- numbers over it. At the level cap it shows nothing (the column stays, empty).
local Define = import("@ordaen/define")

local TRACK = {
	height = 14, border = Define.Theme.panel.barEdge, background = Define.Theme.color.surface,
}
local NUMBERS = { textSize = Define.Theme.text.small, textColor = Define.Theme.color.text, textAlign = "center" }
local format = string.format

local function Fill(game, self)
	local rested, xp, numbers = self.rested, self.xp, self.numbers
	game.ui:Box(rested)
	game.ui:Box(xp)
	game.ui:Text(numbers)
end

return Define.Component({
	Setup = function(game, self)
		-- one call table each, refilled by the render (the widths and the numbers change)
		local track = { attributes = TRACK, slots = { default = Fill } }
		local rested = { attributes = {
			position = "absolute", left = 0, top = 0, bottom = 0, width = "0%", background = Define.Theme.color.xpRested,
		} }
		local xp = { attributes = {
			position = "absolute", left = 0, top = 0, bottom = 0, width = "0%", background = Define.Theme.color.xp,
		} }
		local numbers = { attributes = {
			position = "absolute", left = 0, right = 0, top = 0, bottom = 0, text = "",
			textSize = NUMBERS.textSize, textColor = NUMBERS.textColor, textAlign = NUMBERS.textAlign,
		} }
		return { track = track, rested = rested, xp = xp, numbers = numbers }
	end,

	Render = function(game, self)
		local max = game.Player.xpMax:Get()
		if not max or max <= 0 then
			return -- the level cap: no bar
		end
		local current = game.Player.xp:Get() or 0
		local restedXp = game.Player.rested:Get() or 0
		self.xp.attributes.width = format("%.2f%%", 100 * current / max)
		self.rested.attributes.width = format("%.2f%%", 100 * math.min(current + restedXp, max) / max)
		self.numbers.attributes.text = restedXp > 0
			and format("%d / %d (%.1f%%)  +%d", current, max, 100 * current / max, restedXp)
			or format("%d / %d (%.1f%%)", current, max, 100 * current / max)
		game.ui:Box(self.track)
	end,
})
