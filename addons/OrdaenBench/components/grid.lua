-- grid: a window of item buttons (36x36, a background and a count) in 10 columns, on the screen.
-- small: 200 (the bags). large: 1000 (bank, reagents and warband bank together).
-- Written as the build will leave it: constant tables at file level, slot functions lifted (they take game and
-- self), one call table per item, refilled.
local Define = import("@ordaen/define")

local SIZES = { small = 200, large = 1000 }

local GRID = {
	columns = 10, gap = Define.Theme.spacing.xs, padding = Define.Theme.spacing.md,
	background = Define.Theme.color.surface,
}

local function Cells(game, self)
	local counts, calls = self.state.ephemeral.counts, self.calls
	for i = 1, #calls do
		local call = calls[i]
		call.attributes.count = counts:Get(i) or 0
		game.ui:GridItem(call)
	end
end

local GRID_CALL = { attributes = GRID, slots = { default = Cells } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ counts = { type = "map", key = "number", of = { type = "number" }, cap = 2000 } })
		local counts = self.state.ephemeral.counts
		local calls = {}
		for i = 1, SIZES[self.attributes.size:Peek()] do
			calls[i] = { key = i, attributes = { count = 0 } }
		end
		return {
			calls = calls,
			public = {
				functions = {
					SetOne = function(i, value)
						counts:Set(i, value)
					end,
					Count = function()
						return #calls
					end,
				},
			},
		}
	end,

	Render = function(game, self)
		game.ui:Box(GRID_CALL)
	end,
})
