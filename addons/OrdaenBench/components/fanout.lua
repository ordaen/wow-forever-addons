-- fanout: one value read by 5000 watches, changed once a frame.
local Define = import("@ordaen/define")

local WATCHES = 5000

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ value = { type = "number", default = 0 } })
		local value = self.state.ephemeral.value
		local sum = 0 -- what every run read: the bench's checksum
		for _ = 1, WATCHES do
			self:Watch(function()
				sum = sum + value:Get()
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
						value:Set(value:Peek() + 1)
					end,
				},
			},
		}
	end,
})
