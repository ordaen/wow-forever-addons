-- One child of the units scenario's unchanged row: a 20x20 box with its number. Called again with the same value,
-- it must not render again.
local Define = import("@ordaen/define")

local CELL = { width = 20, height = 20, background = Define.Theme.color.border }

local function Label(game, self)
	game.ui:Text(self.text)
end

local CELL_CALL = { attributes = CELL, slots = { default = Label } }

return Define.Component({
	Setup = function(game, self)
		local arguments = { 0 }
		return { arguments = arguments, text = { attributes = { text = "%d", arguments = arguments } } }
	end,

	Render = function(game, self)
		self.arguments[1] = self.attributes.value:Get()
		game.ui:Box(CELL_CALL)
	end,
})
