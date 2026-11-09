-- One bar: a 200x12 track and a fill as wide as its percentage.
local Define = import("@ordaen/define")
local Words = import("bench/words")

local TRACK = { width = 200, height = 12, background = Define.Theme.color.border, xAlign = "start" }

local function Fill(game, self)
	self.fill.attributes.width = Words.PERCENT[self.attributes.fill]
	game.ui:Box(self.fill)
end

local TRACK_CALL = { attributes = TRACK, slots = { default = Fill } }

return Define.Component({
	Setup = function(game, self)
		return { fill = { attributes = { width = "50%", height = 12, background = Define.Theme.color.accent } } }
	end,

	Render = function(game, self)
		game.ui:Box(TRACK_CALL)
	end,
})
