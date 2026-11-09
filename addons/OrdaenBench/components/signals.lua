-- signals: many values, computed sums of three, and watches reading two values and a sum. No view.
-- small: 1000 values, 100 sums, 300 watches. large: 10000 values, 1000 sums, 3000 watches.
local Define = import("@ordaen/define")

local SIZES = {
	small = { values = 1000, sums = 100, watches = 300 },
	large = { values = 10000, sums = 1000, watches = 3000 },
}


return Define.Component({
	Setup = function(game, self)
		local s = SIZES[Define.Peek(self.attributes.size)]
		-- the values: one list, read and written per entry (each reader depends on its entries only)
		Define.Ephemeral({ values = { type = "list", of = { type = "number" }, cap = 10000 } })
		for _ = 1, s.values do
			table.insert(self.state.values, 0)
		end
		local sums = {}
		for c = 1, s.sums do
			local a, b, d = c, c + s.sums, c + 2 * s.sums
			sums[c] = game.Computed(function()
				return self.state.values[a] + self.state.values[b] + self.state.values[d]
			end)
		end
		local out = {} -- each watch's last result: the bench's checksum
		for w = 1, s.watches do
			local a, b, c = w, (w * 7) % s.values + 1, sums[(w % s.sums) + 1]
			self:Watch(function()
				out[w] = self.state.values[a] + self.state.values[b] + c:Get()
			end)
		end
		return {
			public = {
				functions = {
					-- bench: begin
					Checksum = function()
						local sum = 0
						for w = 1, s.watches do
							sum = sum + (out[w] or 0)
						end
						return sum
					end,
					-- bench: end
					Write = function(k)
						local i = (k - 1) % s.values + 1
						self.state.values[i] = Define.Peek(self.state.values[i]) + 1
					end,
				},
			},
		}
	end,
})
