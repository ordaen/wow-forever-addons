-- One cell of the columns scenario: 36x36 with its number.
local Define = import("@ordaen/define")

local CELL = { width = 36, height = 36, xAlign = "center", yAlign = "center", background = Define.Theme.color.border }

local function Label(game, self)
	game.ui:Text(self.text)
end

local CELL_CALL = { attributes = CELL, slots = { default = Label } }

return Define.Component({
	Setup = function(game, self)
		return { text = { attributes = { text = "%d", arguments = { self.attributes.index:Peek() } } } }
	end,

	Render = function(game, self)
		game.ui:Box(CELL_CALL)
	end,
})
