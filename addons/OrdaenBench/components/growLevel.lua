-- One level of a grow row: a box sized by its content (padding 2) around the next level; the last level is the text.
local Define = import("@ordaen/define")
local Words = import("bench/words")

local LEVEL = { padding = 2, background = Define.Theme.color.border }

local function Inside(game, self)
	game.ui:GrowLevel(self.child)
end

local LEVEL_CALL = { attributes = LEVEL, slots = { default = Inside } }

return Define.Component({
	Setup = function(game, self)
		local depth = self.attributes.depth:Peek()
		if depth == 0 then
			return { text = { attributes = { text = Words.WORDS[1] } } }
		end
		local a = self.attributes
		return { child = { attributes = { depth = depth - 1, row = a.row:Peek(), lengths = a.lengths:Peek() } } }
	end,

	Render = function(game, self)
		if self.attributes.depth:Get() == 0 then
			local length = self.attributes.lengths:Get():Get(self.attributes.row:Get()) or 1
			self.text.attributes.text = Words.WORDS[length]
			game.ui:Text(self.text)
		else
			game.ui:Box(LEVEL_CALL)
		end
	end,
})
