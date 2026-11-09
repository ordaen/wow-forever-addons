-- grid: a window of item buttons (36x36, a background and a count) in 10 columns, on the screen.
-- small: 200 (the bags). large: 1000 (bank, reagents and warband bank together).
-- A naive variant (attribute `naive`) writes its calls as code reads without the build: a new table every call.
-- Two ways to hand the counts down (attribute `itemsRead`): the grid reads every count and passes each as an
-- attribute (one change re-runs the grid's render), or the grid passes the map once and each item reads its own
-- count (one change re-runs what read the map: with whole-map tracking, every item).
-- Written as the build will leave it: constant tables at file level, slot functions lifted (they take game and
-- self), one call table per item, refilled.
local Define = import("@ordaen/define")

local SIZES = { small = 200, large = 1000 }

local GRID = {
	columns = 10, gap = Define.Theme.spacing.xs, padding = Define.Theme.spacing.md,
	background = Define.Theme.color.surface,
}

local function Cells(game, self)
	local calls = self.calls
	-- bench: begin
	if self.naive then -- as code reads without the build's hoisting: new tables every call
		local counts = self.state.ephemeral.counts
		for i = 1, #calls do
			-- ordaen: ignore B13 the naive variant reads a render local on purpose: it measures code the build can't lift
			game.ui:GridItem({ key = i, attributes = { count = counts:Get(i) or 0, naive = true } })
		end
		return
	end
	-- bench: end
	-- bench: begin
	if self.itemsRead then
		for i = 1, #calls do
			game.ui:GridItem(calls[i])
		end
		return
	end
	-- bench: end
	local counts = self.state.ephemeral.counts
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
		-- bench: begin
		local itemsRead = self.attributes.itemsRead:Peek() or false
		-- bench: end
		local calls = {}
		for i = 1, SIZES[self.attributes.size:Peek()] do
			calls[i] = { key = i, attributes = itemsRead and { counts = counts, index = i } or { count = 0 } }
		end
		return {
			calls = calls,
			-- bench: begin
			itemsRead = itemsRead,
			-- bench: end
			-- bench: begin
			naive = self.attributes.naive:Peek() or false,
			-- bench: end
			public = {
				functions = {
					SetOne = function(i, value)
						counts:Set(i, value)
					end,
					-- bench: begin
					Count = function()
						return #calls
					end,
					-- bench: end
				},
			},
		}
	end,

	Render = function(game, self)
		game.ui:Box(GRID_CALL)
	end,
})
