-- filter: 500 keyed items of which a filter shows about two thirds; every call shifts the filter, so a third of the
-- items leave and others come back (a bag search, a list filter).
local Define = import("@ordaen/define")

local ITEMS = 500

local LIST = { columns = 1, position = "absolute", left = 300, width = 120 }

local function Items(game, self)
	local calls, shift = self.calls, self.state.ephemeral.shift:Get()
	for id = 1, ITEMS do
		if (id + shift) % 3 ~= 0 then
			game.ui:Text(calls[id])
		end
	end
end

local LIST_CALL = { attributes = LIST, slots = { default = Items } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ shift = { type = "number", default = 0 } })
		local shift = self.state.ephemeral.shift
		local calls = {}
		for id = 1, ITEMS do
			calls[id] = { key = id, attributes = { text = "item %d", arguments = { id } } }
		end
		return {
			calls = calls,
			public = { functions = { SetShift = function(s)
				shift:Set(s)
			end } },
		}
	end,

	Render = function(game, self)
		game.ui:Box(LIST_CALL)
	end,
})
