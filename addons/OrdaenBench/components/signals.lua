-- signals: many values, computed sums of three, and watches reading two values and a sum. No view.
-- small: 1000 values, 100 sums, 300 watches. large: 10000 values, 1000 sums, 3000 watches.
local Define = import("@ordaen/define")

local SIZES = {
	small = { values = 1000, sums = 100, watches = 300 },
	large = { values = 10000, sums = 1000, watches = 3000 },
}

-- built here because the bench needs thousands of values; module code declares its state as a literal table
local SPECS = {}
for size, s in pairs(SIZES) do
	local spec = {}
	for i = 1, s.values do
		spec["v" .. i] = { type = "number", default = 0 }
	end
	SPECS[size] = spec
end

return Define.Component({
	Setup = function(game, self)
		local size = self.attributes.size:Peek()
		local s = SIZES[size]
		Define.Ephemeral(SPECS[size])
		local store, values, sums = self.state.ephemeral, {}, {}
		for i = 1, s.values do
			values[i] = store["v" .. i]
		end
		for c = 1, s.sums do
			local a, b, d = values[c], values[c + s.sums], values[c + 2 * s.sums]
			sums[c] = game.Computed(function()
				return a:Get() + b:Get() + d:Get()
			end)
		end
		local out = {} -- each watch's last result: the bench's checksum
		for w = 1, s.watches do
			local a, b, c = values[w], values[(w * 7) % s.values + 1], sums[(w % s.sums) + 1]
			self:Watch(function()
				out[w] = a:Get() + b:Get() + c:Get()
			end)
		end
		return {
			public = {
				functions = {
					Checksum = function()
						local sum = 0
						for w = 1, s.watches do
							sum = sum + (out[w] or 0)
						end
						return sum
					end,
					Write = function(k)
						local value = values[(k - 1) % s.values + 1]
						value:Set(value:Peek() + 1)
					end,
				},
			},
		}
	end,
})
