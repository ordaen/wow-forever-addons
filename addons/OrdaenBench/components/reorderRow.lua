-- One row of the reorder scenario: its id as text.
local Define = import("@ordaen/define")

return Define.Component({
	Setup = function(game, self)
		local arguments = { 0 }
		return { arguments = arguments, text = { attributes = { text = "row %d", arguments = arguments } } }
	end,

	Render = function(game, self)
		self.arguments[1] = self.attributes.id
		game.ui:Text(self.text)
	end,
})
