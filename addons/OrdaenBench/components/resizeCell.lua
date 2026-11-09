-- One cell of the resize scenario: a box 24 high, as wide as its column, with its number.
local Define = import("@ordaen/define")

local CELL = { height = 24, xAlign = "center", yAlign = "center", background = Define.Theme.color.border }

local function Label(game, self)
	game.ui:Text(self.text)
end

local CELL_CALL = { attributes = CELL, slots = { default = Label } }

return Define.Component({
	Setup = function(game, self)
		return { text = { attributes = { text = "%d", arguments = { Define.Peek(self.attributes.index) } } } }
	end,

	Render = function(game, self)
		game.ui:Box(CELL_CALL)
	end,
})
