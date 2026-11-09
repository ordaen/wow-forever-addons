-- One cell of the grid scenario: a 36x36 box with a background and its count.
local Define = import("@ordaen/define")
local counters = import("bench/counters")

local CELL = { width = 36, height = 36, background = Define.Theme.color.border }

local function Count(game, self)
	game.ui:Text(self.text)
end

local CELL_CALL = { attributes = CELL, slots = { default = Count } }

return Define.Component({
	Setup = function(game, self)
		counters.mounts = counters.mounts + 1
		local arguments = { 0 }
		return { arguments = arguments, text = { attributes = { text = "%d", arguments = arguments } } }
	end,

	Render = function(game, self)
		self.arguments[1] = self.attributes.count:Get()
		game.ui:Box(CELL_CALL)
	end,
})
