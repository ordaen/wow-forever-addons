-- hover: 100 item cells (10 x 10, a bag or an action bar). Each lights up while hovered (a per-state background: the
-- backend restyles it without the engine) and names the hovered item in a line above (its OnEnter writes a value).
-- The bench moves the "cursor" by calling the cells' frames' OnLeave and OnEnter scripts: hit testing (WoW finding
-- the frame under the cursor) isn't measured.
local Define = import("@ordaen/define")

local CELLS = 100

local BACKGROUND = { default = Define.Theme.color.surface, hover = Define.Theme.color.surfaceHover }
local GRID = { columns = 10, gap = 2 }
local WINDOW = { columns = 1, gap = Define.Theme.spacing.xs, position = "absolute", left = 300, top = 300 }

local function Cells(game, self)
	local calls = self.calls
	for i = 1, CELLS do
		game.ui:Box(calls[i])
	end
end

local function Window(game, self)
	local hovered = self.state.hovered
	if hovered ~= 0 then
		self.arguments[1] = hovered
		game.ui:Text(self.label)
	end
	game.ui:Box(self.grid)
end

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ hovered = { type = "number", default = 0 } })
		local function Leave()
			self.state.hovered = 0
		end
		local calls = {}
		for i = 1, CELLS do
			calls[i] = { key = i, attributes = {
				width = 30, height = 30, background = BACKGROUND,
				OnEnter = function()
					self.state.hovered = i
				end,
				OnLeave = Leave,
			} }
		end
		local arguments = { 0 }
		return {
			calls = calls,
			arguments = arguments,
			label = { key = "label", attributes = { text = "Item %d", arguments = arguments } },
			grid = { key = "grid", attributes = GRID, slots = { default = Cells } },
			window = { attributes = WINDOW, slots = { default = Window } },
		}
	end,

	Render = function(game, self)
		game.ui:Box(self.window)
	end,
})
