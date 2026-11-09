-- drag: a window of 200 cells moved every frame (a window dragged by its title): only its position changes.
local Define = import("@ordaen/define")

local CELLS = 200

local CELL = { width = 36, height = 36, background = Define.Theme.color.border }
local CELL_CALL = { attributes = CELL }

local function Cells(game, self)
	local calls = self.calls
	for i = 1, CELLS do
		game.ui:Box(calls[i])
	end
end

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ x = { type = "number", default = 200 }, y = { type = "number", default = 200 } })
		local window = {
			columns = 10, gap = Define.Theme.spacing.xs, padding = Define.Theme.spacing.md,
			background = Define.Theme.color.surface, position = "absolute", left = 200, top = 200,
		}
		local calls = {}
		for i = 1, CELLS do
			calls[i] = { key = i, attributes = CELL }
		end
		return {
			window = window, calls = calls,
			windowCall = { attributes = window, slots = { default = Cells } },
			public = { functions = { Move = function(left, top)
				self.state.x = left
				self.state.y = top
			end } },
		}
	end,

	Render = function(game, self)
		local window = self.window
		window.left, window.top = self.state.x, self.state.y
		game.ui:Box(self.windowCall)
	end,
})
