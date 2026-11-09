-- ticker: texts with two numbers each (like coordinates), all changed every frame. small: 50. large: 500.
local Define = import("@ordaen/define")

local SIZES = { small = 50, large = 500 }

local COLUMN = { position = "absolute", left = 40, width = 200 }

local function Lines(game, self)
	local tick, calls = self.state.ephemeral.tick:Get(), self.calls
	-- bench: begin
	if self.naive then -- as code reads without the build's hoisting: new tables every call
		for i = 1, #calls do
			game.ui:Text({ key = i, attributes = { text = "%.1f, %.1f", arguments = { tick * 0.1 + i, tick * 0.2 - i } } })
		end
		return
	end
	-- bench: end
	for i = 1, #calls do
		local call = calls[i]
		local arguments = call.attributes.arguments
		arguments[1], arguments[2] = tick * 0.1 + i, tick * 0.2 - i
		game.ui:Text(call)
	end
end

local COLUMN_CALL = { attributes = COLUMN, slots = { default = Lines } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ tick = { type = "number", default = 0 } })
		local tick = self.state.ephemeral.tick
		local calls = {}
		for i = 1, SIZES[self.attributes.size:Peek()] do
			calls[i] = { key = i, attributes = { text = "%.1f, %.1f", arguments = { 0, 0 } } }
		end
		return {
			calls = calls,
			-- bench: begin
			naive = self.attributes.naive:Peek() or false,
			-- bench: end
			public = {
				functions = {
					Tick = function()
						tick:Set(tick:Peek() + 1)
					end,
				},
			},
		}
	end,

	Render = function(game, self)
		game.ui:Box(COLUMN_CALL)
	end,
})
