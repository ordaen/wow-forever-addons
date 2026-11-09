-- cascade: 50 values, each copied into the next by a watch, so one change ripples through 50 effects, one after the
-- other in the same flush. After the flush the last must equal the first.
local Define = import("@ordaen/define")

local LENGTH = 50

return Define.Component({
	Setup = function(game, self)
		-- one list, read and written per entry: each watch depends on its own entry only
		Define.Ephemeral({ values = { type = "list", of = { type = "number" }, cap = LENGTH } })
		for _ = 1, LENGTH do
			table.insert(self.state.values, 0)
		end
		for i = 1, LENGTH - 1 do
			self:Watch(function()
				self.state.values[i + 1] = self.state.values[i]
			end)
		end
		return {
			public = {
				functions = {
					Bump = function()
						self.state.values[1] = Define.Peek(self.state.values[1]) + 1
					end,
					Settled = function()
						return Define.Peek(self.state.values[LENGTH]) == Define.Peek(self.state.values[1])
					end,
				},
			},
		}
	end,
})
