-- columns: 200 cells of 36x36 whose column count changes (6 to 14): every cell moves and the window's size follows
-- its content (a bag window's columns setting).
local Define = import("@ordaen/define")

local CELLS = 200

local function Cells(game, self)
	local calls = self.calls
	for i = 1, CELLS do
		game.ui:ColumnsCell(calls[i])
	end
end

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ columns = { type = "number", default = 10 } })
		local columns = self.state.ephemeral.columns
		local window = {
			columns = 10, gap = Define.Theme.spacing.xs, padding = Define.Theme.spacing.md,
			background = Define.Theme.color.surface,
		}
		local calls = {}
		for i = 1, CELLS do
			calls[i] = { key = i, attributes = { index = i } }
		end
		return {
			window = window, calls = calls,
			windowCall = { attributes = window, slots = { default = Cells } },
			public = { functions = { SetColumns = function(n)
				columns:Set(n)
			end } },
		}
	end,

	Render = function(game, self)
		self.window.columns = self.state.ephemeral.columns:Get()
		game.ui:Box(self.windowCall)
	end,
})
