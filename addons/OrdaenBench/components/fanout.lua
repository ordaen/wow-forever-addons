-- fanout: one value read by 5000 watches, changed once a frame.
local Define = import("@ordaen/define")

local WATCHES = 5000

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ value = { type = "number", default = 0 } })
		local sum = 0 -- what every run read: the bench's checksum
		for _ = 1, WATCHES do
			self:Watch(function()
				sum = sum + self.state.value
			end)
		end
		return {
			public = {
				functions = {
					-- bench: begin
					Checksum = function()
						return sum
					end,
					-- bench: end
					Bump = function()
						self.state.value = Define.Peek(self.state.value) + 1
					end,
				},
			},
		}
	end,
})
