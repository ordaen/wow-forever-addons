-- sections: 20 sections of a header and 10 rows; every call collapses or expands one section, and every section
-- below it moves (a quest tracker, a settings page).
local Define = import("@ordaen/define")

local SECTIONS, ROWS = 20, 10

local COLUMN = { columns = 1, position = "absolute", right = 40, top = 40, width = 160 }

local function Content(game, self)
	local headers, rows = self.headers, self.rows
	for s = 1, SECTIONS do
		game.ui:Text(headers[s])
		if self.state.open[s] ~= false then
			local list = rows[s]
			for r = 1, ROWS do
				game.ui:Text(list[r])
			end
		end
	end
end

local COLUMN_CALL = { attributes = COLUMN, slots = { default = Content } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ open = { type = "map", key = "number", of = { type = "boolean" }, cap = 100 } })
		local headers, rows = {}, {}
		for s = 1, SECTIONS do
			headers[s] = { key = s * 100, attributes = { text = "Section %d", arguments = { s } } }
			local list = {}
			for r = 1, ROWS do
				list[r] = { key = s * 100 + r, attributes = { text = "  row %d.%d", arguments = { s, r } } }
			end
			rows[s] = list
		end
		return {
			headers = headers, rows = rows,
			public = { functions = { Toggle = function(s)
				self.state.open[s] = self.state.open[s] == false -- nil (never toggled) is open
			end } },
		}
	end,

	Render = function(game, self)
		game.ui:Box(COLUMN_CALL)
	end,
})
