-- reorder: a keyed list of 500 rows changing order: reversed, rotated by one, a row inserted at the front, one
-- removed from the middle, shuffled. Keys keep each row's node; only the order moves.
local Define = import("@ordaen/define")

local ROWS = 500

local LIST = { columns = 1, position = "absolute", right = 40, width = 120 }

local function Rows(game, self)
	local calls = self.calls
	for _, id in self.state.ephemeral.order:Ipairs() do
		local call = calls[id]
		if not call then -- a new row: its call table, made once
			call = { key = id, attributes = { id = id } }
			calls[id] = call
		end
		game.ui:ReorderRow(call)
	end
end

local LIST_CALL = { attributes = LIST, slots = { default = Rows } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ order = { type = "list", of = { type = "number" }, cap = 5000 } })
		local order = self.state.ephemeral.order
		local ids, nextId = {}, ROWS + 1
		for i = 1, ROWS do
			ids[i] = i
			order:Insert(i)
		end
		local function Store()
			order:Reset()
			for i = 1, #ids do
				order:Insert(ids[i])
			end
		end
		local seed = 1
		return {
			calls = {},
			public = {
				functions = {
					Reverse = function()
						local n = #ids
						for i = 1, math.floor(n / 2) do
							ids[i], ids[n - i + 1] = ids[n - i + 1], ids[i]
						end
						Store()
					end,
					Rotate = function()
						local id = table.remove(ids, 1)
						ids[#ids + 1] = id
						order:Remove(1)
						order:Insert(id)
					end,
					InsertFront = function()
						table.insert(ids, 1, nextId)
						nextId = nextId + 1
						Store()
					end,
					RemoveMiddle = function()
						local middle = math.floor(#ids / 2)
						table.remove(ids, middle)
						order:Remove(middle)
					end,
					-- bench: begin
					Ids = function()
						return ids
					end,
					-- bench: end
					Shuffle = function()
						for i = #ids, 2, -1 do
							seed = (seed * 1103515245 + 12345) % 2147483648
							local j = seed % i + 1
							ids[i], ids[j] = ids[j], ids[i]
						end
						Store()
					end,
				},
			},
		}
	end,

	Render = function(game, self)
		game.ui:Box(LIST_CALL)
	end,
})
