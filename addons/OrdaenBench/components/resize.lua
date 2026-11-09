-- resize: a window of 200 cells in 10 equal columns, its width changed every call: every cell's width and place
-- follow (a window resized by dragging its corner).
local Define = import("@ordaen/define")

local CELLS = 200

local function Cells(game, self)
	local calls = self.calls
	for i = 1, CELLS do
		game.ui:ResizeCell(calls[i])
	end
end

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ width = { type = "number", default = 500 } })
		local window = {
			width = 500, columns = 10, gap = Define.Theme.spacing.xs, padding = Define.Theme.spacing.md,
			background = Define.Theme.color.surface,
		}
		local calls = {}
		for i = 1, CELLS do
			calls[i] = { key = i, attributes = { index = i } }
		end
		return {
			window = window, calls = calls,
			windowCall = { attributes = window, slots = { default = Cells } },
			public = { functions = { SetWidth = function(w)
				self.state.width = w
			end } },
		}
	end,

	Render = function(game, self)
		self.window.width = self.state.width
		game.ui:Box(self.windowCall)
	end,
})
