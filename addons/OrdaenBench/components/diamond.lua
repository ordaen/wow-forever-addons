-- diamond: one root, 100 computed values from it (root × i) and one sum of them all, watched. Each change of the
-- root must run the watch once and show a consistent sum (root × 5050), never a mix of old and new values.
local Define = import("@ordaen/define")
local counters = import("bench/counters")

local WIDTH = 100
local EXPECTED = WIDTH * (WIDTH + 1) / 2

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ root = { type = "number", default = 1 } })
		local parts = {}
		for i = 1, WIDTH do
			parts[i] = game.Computed(function()
				return self.state.root * i
			end)
		end
		local sum = game.Computed(function()
			local total = 0
			for i = 1, WIDTH do
				total = total + parts[i]:Get()
			end
			return total
		end)
		self:Watch(function()
			counters.runs = counters.runs + 1
			if sum:Get() ~= self.state.root * EXPECTED then
				counters.violations = counters.violations + 1
			end
		end)
		return {
			public = {
				functions = {
					Bump = function()
						self.state.root = Define.Peek(self.state.root) + 1
					end,
				},
			},
		}
	end,
})
