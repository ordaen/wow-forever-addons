-- Signals scenario: 1000 values, 100 computed sums of three, 300 watches reading two values and a sum. No view.
local Define = import("@ordaen/define")

local N, SUMS, WATCHES = 1000, 100, 300

-- built here because the bench needs 1000 values; module code declares its state as a literal table
local SPEC = {}
for i = 1, N do
	SPEC["v" .. i] = { type = "number", default = 0 }
end

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral(SPEC)
		local store = self.state.ephemeral
		local values = {}
		for i = 1, N do
			values[i] = store["v" .. i]
		end
		local sums = {}
		for c = 1, SUMS do
			local a, b, d = values[c], values[c + 100], values[c + 200]
			sums[c] = game.Computed(function()
				return a:Get() + b:Get() + d:Get()
			end)
		end
		local sink = 0
		for w = 1, WATCHES do
			local a, b, c = values[w], values[(w * 7) % N + 1], sums[(w % SUMS) + 1]
			self:Watch(function()
				sink = a:Get() + b:Get() + c:Get()
			end)
		end
		return {
			public = {
				functions = {
					Write = function(k)
						local value = values[k]
						value:Set(value:Peek() + 1)
					end,
				},
			},
		}
	end,
})
