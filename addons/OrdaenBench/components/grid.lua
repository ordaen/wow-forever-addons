-- Grid scenario: a window of 200 item buttons (36x36, a background and a count) in 10 columns, on the screen.
-- Written as the build will leave it: constant tables at file level, the slot function lifted (it takes game and
-- self), one call table per key, refilled.
local Define = import("@ordaen/define")

local COUNT = 200

local GRID = {
	columns = 10, gap = Define.Theme.spacing.xs, padding = Define.Theme.spacing.md,
	background = Define.Theme.color.surface,
}

local function Cells(game, self)
	local counts, calls = self.state.ephemeral.counts, self.calls
	for i = 1, COUNT do
		local call = calls[i]
		call.attributes.count = counts:Get(i) or 0
		game.ui:Item(call)
	end
end

local GRID_CALL = { attributes = GRID, slots = { default = Cells } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ counts = { type = "map", key = "number", of = { type = "number" }, cap = 1000 } })
		local counts = self.state.ephemeral.counts
		local calls = {}
		for i = 1, COUNT do
			calls[i] = { key = i, attributes = { count = 0 } }
		end
		return {
			calls = calls,
			public = {
				functions = {
					SetOne = function(i, value)
						counts:Set(i, value)
					end,
				},
			},
		}
	end,

	Render = function(game, self)
		game.ui:Box(GRID_CALL)
	end,
})
