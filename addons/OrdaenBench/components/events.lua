-- events: a burst of 20 bag updates in one frame (looting, selling, sorting), each counted by the bag it names; the
-- 5 bags' counts drawn as texts, once per frame however many updates came.
local Define = import("@ordaen/define")

local BAGS = 5

local COLUMN = { columns = 1, position = "absolute", left = 40, top = 300, width = 120 }

local function Counts(game, self)
	local calls = self.calls
	for bag = 1, BAGS do
		local call = calls[bag]
		call.attributes.arguments[2] = self.state.counts[bag] or 0
		game.ui:Text(call)
	end
end

local COLUMN_CALL = { attributes = COLUMN, slots = { default = Counts } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ counts = { type = "map", key = "number", of = { type = "number" }, cap = 10 } })
		self:On("BAG_UPDATE", function(bag)
			self.state.counts[bag] = (self.state.counts[bag] or 0) + 1
		end)
		local calls = {}
		for bag = 1, BAGS do
			calls[bag] = { key = bag, attributes = { text = "bag %d: %d updates", arguments = { bag, 0 } } }
		end
		return { calls = calls }
	end,

	Render = function(game, self)
		game.ui:Box(COLUMN_CALL)
	end,
})
