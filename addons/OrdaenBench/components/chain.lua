-- chain: 150 computed values, each the one before plus one, and a watch on the last that checks it equals the root
-- plus 150 every time it runs (a stale read in between would break it).
local Define = import("@ordaen/define")
local counters = import("bench/counters")

local LENGTH = 150 -- below the ~195 levels where nested recomputes overflow the C stack (a framework limit to fix)

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ root = { type = "number", default = 0 } })
		local previous = game.Computed(function()
			return self.state.root
		end)
		for _ = 1, LENGTH do
			local before = previous
			previous = game.Computed(function()
				return before:Get() + 1
			end)
		end
		local last = previous
		self:Watch(function()
			counters.runs = counters.runs + 1
			if last:Get() ~= self.state.root + LENGTH then
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
