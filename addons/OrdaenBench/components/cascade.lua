-- cascade: 50 values, each copied into the next by a watch, so one change ripples through 50 effects, one after the
-- other in the same flush. After the flush the last must equal the first.
local Define = import("@ordaen/define")

local LENGTH = 50

local SPEC = {}
for i = 1, LENGTH do
	SPEC["v" .. i] = { type = "number", default = 0 }
end

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral(SPEC)
		local store, values = self.state.ephemeral, {}
		for i = 1, LENGTH do
			values[i] = store["v" .. i]
		end
		for i = 1, LENGTH - 1 do
			local from, to = values[i], values[i + 1]
			self:Watch(function()
				to:Set(from:Get())
			end)
		end
		return {
			public = {
				functions = {
					Bump = function()
						values[1]:Set(values[1]:Peek() + 1)
					end,
					Settled = function()
						return values[LENGTH]:Peek() == values[1]:Peek()
					end,
				},
			},
		}
	end,
})
