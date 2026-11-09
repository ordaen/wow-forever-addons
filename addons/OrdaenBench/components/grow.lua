-- grow: 50 rows, each a text inside 5 nested boxes sized by their content; every call gives each text a new length
-- (1 to 30 characters), so each change climbs through its 5 boxes (a tracker line, a panel item).
local Define = import("@ordaen/define")

local ROWS, DEPTH = 50, 5

local COLUMN = { columns = 1, gap = 2, position = "absolute", left = 40, top = 40 }

local function Rows(game, self)
	local calls = self.calls
	for r = 1, ROWS do
		game.ui:GrowLevel(calls[r])
	end
end

local COLUMN_CALL = { attributes = COLUMN, slots = { default = Rows } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ lengths = { type = "map", key = "number", of = { type = "number" }, cap = 100 } })
		local lengths = self.state.ephemeral.lengths
		local calls = {}
		for r = 1, ROWS do
			calls[r] = { key = r, attributes = { depth = DEPTH, row = r, lengths = lengths } }
		end
		return {
			calls = calls,
			public = { functions = { SetLength = function(r, n)
				lengths:Set(r, n)
			end } },
		}
	end,

	Render = function(game, self)
		game.ui:Box(COLUMN_CALL)
	end,
})
