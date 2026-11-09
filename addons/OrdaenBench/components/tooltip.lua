-- tooltip: a box of 10 lines shown with new content each time (lines of varying width; the box sized by them),
-- then hidden: what hovering over items does all the time.
local Define = import("@ordaen/define")
local Words = import("bench/words")

local LINES = 10

local TIP = {
	columns = 1, gap = 1, padding = Define.Theme.spacing.md, background = Define.Theme.color.surface,
	position = "absolute", left = 600, top = 200,
}

local function Lines(game, self)
	local calls, content, pool = self.calls, self.state.content, Words.LINES
	for i = 1, LINES do
		local call = calls[i]
		call.attributes.text = pool[(content + i * 7) % #pool + 1]
		game.ui:Text(call)
	end
end

local TIP_CALL = { attributes = TIP, slots = { default = Lines } }

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({
			shown = { type = "boolean", default = false },
			content = { type = "number", default = 1 },
		})
		local calls = {}
		for i = 1, LINES do
			calls[i] = { key = i, attributes = { text = "" } }
		end
		return {
			calls = calls,
			public = { functions = {
				ShowWith = function(n)
					self.state.content = n
					self.state.shown = true
				end,
				Hide = function()
					self.state.shown = false
				end,
			} },
		}
	end,

	Render = function(game, self)
		if self.state.shown then
			game.ui:Box(TIP_CALL)
		end
	end,
})
