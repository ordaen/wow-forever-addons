-- One cell of the grid scenario: a 36x36 box with a background and its count, handed down (`count`) or read by
-- the item itself from the grid's map (`counts`, `index`).
local Define = import("@ordaen/define")
local counters = import("bench/counters")

local CELL = { width = 36, height = 36, xAlign = "center", yAlign = "center", background = Define.Theme.color.border }

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
		-- bench: begin
		if self.attributes.naive then -- new tables and a new function every render
			local count = self.attributes.count
			game.ui:Box({ attributes = { width = 36, height = 36, xAlign = "center", yAlign = "center",
				background = Define.Theme.color.border }, slots = { default = function()
				game.ui:Text({ attributes = { text = "%d", arguments = { count } } })
			end } })
			return
		end
		-- bench: end
		local counts = self.attributes.counts -- the grid's map itself, in the items-read variant
		if counts then
			self.arguments[1] = counts:Get(self.attributes.index) or 0
		else
			self.arguments[1] = self.attributes.count
		end
		game.ui:Box(CELL_CALL)
	end,
})
