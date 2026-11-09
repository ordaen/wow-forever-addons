-- deep: a component inside itself 100 times, a text at the bottom showing two numbers: `value`, handed down as an
-- attribute through every level, and `source`, a signal handed down once and read only by the leaf. Changing the
-- source re-runs the leaf alone; changing the value re-runs every level.
local Define = import("@ordaen/define")
local counters = import("bench/counters")

local DEPTH = 100

local LEVEL = { padding = 1 }
local OUTER = { padding = 1, width = 300, height = 300 } -- the outermost level: the hand-written one is 300x300 too

local function Inside(game, self)
	local call = self.child
	call.attributes.value = self.attributes.value:Get()
	game.ui:Deep(call)
end

local LEVEL_CALL = { attributes = LEVEL, slots = { default = Inside } }
local OUTER_CALL = { attributes = OUTER, slots = { default = Inside } }

return Define.Component({
	Setup = function(game, self)
		local depth = self.attributes.depth:Peek()
		if depth == nil then -- the root: owns the two numbers
			Define.Ephemeral({
				value = { type = "number", default = 0 },
				source = { type = "number", default = 0 },
			})
			local value, source = self.state.ephemeral.value, self.state.ephemeral.source
			local child = { attributes = { depth = DEPTH, value = 0, source = source } }
			return {
				child = child,
				rootValue = value,
				public = {
					functions = {
						SetValue = function(v)
							value:Set(v)
						end,
						SetSource = function(v)
							source:Set(v)
						end,
					},
				},
			}
		end
		if depth == 0 then
			local arguments = { 0, 0 }
			return { arguments = arguments, text = { attributes = { text = "%d / %d", arguments = arguments } } }
		end
		local source = self.attributes.source:Peek()
		return { child = { attributes = { depth = depth - 1, value = 0, source = source } } }
	end,

	Render = function(game, self)
		local depth = self.attributes.depth:Get()
		if depth == nil then
			local call = self.child
			call.attributes.value = self.rootValue:Get()
			game.ui:Deep(call)
		elseif depth == 0 then
			counters.renders = counters.renders + 1
			local arguments = self.arguments
			arguments[1], arguments[2] = self.attributes.value:Get(), self.attributes.source:Get():Get()
			counters.leafValue = arguments[1]
			game.ui:Text(self.text)
		else
			game.ui:Box(depth == DEPTH and OUTER_CALL or LEVEL_CALL)
		end
	end,
})
