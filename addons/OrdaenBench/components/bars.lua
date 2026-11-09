-- bars: 20 status bars (200 wide) whose fill changes every frame (health, power, experience, a damage meter).
local Define = import("@ordaen/define")

local BARS = 20

local COLUMN = { columns = 1, gap = Define.Theme.spacing.xs, position = "absolute", left = 40, bottom = 200 }

local function Bars(game, self)
	local calls, fills = self.calls, self.state.ephemeral.fills
	for i = 1, BARS do
		local call = calls[i]
		call.attributes.fill = fills:Get(i) or 50
		game.ui:BarsBar(call)
	end
end

local COLUMN_CALL = { attributes = COLUMN, slots = { default = Bars } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ fills = { type = "map", key = "number", of = { type = "number" }, cap = 100 } })
		local fills = self.state.ephemeral.fills
		local calls = {}
		for i = 1, BARS do
			calls[i] = { key = i, attributes = { fill = 50 } }
		end
		return {
			calls = calls,
			public = { functions = { SetFill = function(i, percent)
				fills:Set(i, percent)
			end } },
		}
	end,

	Render = function(game, self)
		game.ui:Box(COLUMN_CALL)
	end,
})
