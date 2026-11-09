-- One level of a grow row: a box sized by its content (padding 2) around the next level; the last level is the text.
local Define = import("@ordaen/define")
local Words = import("bench/words")

-- width "auto": each level is its own content's width (a box stretches to its cell otherwise)
local LEVEL = { width = "auto", padding = 2, background = Define.Theme.color.border }

local function Inside(game, self)
	game.ui:GrowLevel(self.child)
end

local LEVEL_CALL = { attributes = LEVEL, slots = { default = Inside } }

return Define.Component({
	Setup = function(game, self)
		local depth = Define.Peek(self.attributes.depth)
		if depth == 0 then
			return { text = { attributes = { text = Words.WORDS[1] } } }
		end
		return { child = { attributes = { depth = depth - 1, row = Define.Peek(self.attributes.row),
			lengths = Define.Peek(self.attributes.lengths) } } }
	end,

	Render = function(game, self)
		if self.attributes.depth == 0 then
			local lengths = self.attributes.lengths -- the row's map itself
			local length = lengths:Get(self.attributes.row) or 1
			self.text.attributes.text = Words.WORDS[length]
			game.ui:Text(self.text)
		else
			game.ui:Box(LEVEL_CALL)
		end
	end,
})
