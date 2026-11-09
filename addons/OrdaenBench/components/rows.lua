-- rows: a list whose number of rows changes (50 to 150) every call: rows come and go at its end and its height
-- follows (a list growing and shrinking: loot, mail, a log).
local Define = import("@ordaen/define")

local MOST = 150

local LIST = {
	columns = 1, padding = Define.Theme.spacing.xs, background = Define.Theme.color.surface,
	position = "absolute", right = 200, width = 120,
}

local function Rows(game, self)
	local calls = self.calls
	for i = 1, self.state.count do
		game.ui:Text(calls[i])
	end
end

local LIST_CALL = { attributes = LIST, slots = { default = Rows } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ count = { type = "number", default = 100 } })
		local calls = {}
		for i = 1, MOST do
			calls[i] = { key = i, attributes = { text = "row %d", arguments = { i } } }
		end
		return {
			calls = calls,
			public = { functions = { SetCount = function(n)
				self.state.count = n
			end } },
		}
	end,

	Render = function(game, self)
		game.ui:Box(LIST_CALL)
	end,
})
