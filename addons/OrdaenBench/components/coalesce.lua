-- coalesce: one value written 1000 times in a frame, read by 100 watches. The scheduler should run each watch once
-- per frame, whatever the number of writes.
local Define = import("@ordaen/define")
local counters = import("bench/counters")

local WATCHES = 100

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ value = { type = "number", default = 0 } })
		local value = self.state.ephemeral.value
		local sink = 0
		for _ = 1, WATCHES do
			self:Watch(function()
				counters.runs = counters.runs + 1
				sink = value:Get()
			end)
		end
		return {
			public = {
				functions = {
					WriteMany = function(times)
						for _ = 1, times do
							value:Set(value:Peek() + 1)
						end
					end,
				},
			},
		}
	end,
})
