-- windowCheck: the library's Window as the settings window draws it (design settings/: "Ordaen", a 1160 x 700 px
-- body), with two rows of settings controls bound to test values of its own, to compare the game's rendering with the
-- design page. Dev only (the bench); `/ordaen bench window` shows and hides it. Not part of a round.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale
local LABEL = { 0.796, 0.725, 0.58, 1 } -- --o-label #cbb994
-- a setting's row (design controls/row): the label in a 280 px column, the control beside it, 18 px apart
local ROW = { columns = { 280 * PX, "1fr" }, gap = 18 * PX, yAlign = "center" }
local ROWS = { columns = 1, gap = 14 * PX }

local function SwitchRow(game, self)
	game.ui:Text({ attributes = { text = "Switch", textColor = LABEL } })
	game.ui:Switch({ attributes = { value = Define.Signal(self.state.on) } })
end

local function SliderRow(game, self)
	game.ui:Text({ attributes = { text = "Slider", textColor = LABEL } })
	game.ui:Slider({ attributes = { value = Define.Signal(self.state.height) } })
end

local function Rows(game)
	game.ui:Box({ attributes = ROW, slots = { default = SwitchRow } })
	game.ui:Box({ attributes = ROW, slots = { default = SliderRow } })
end

local function Body(game)
	game.ui:Box({ attributes = ROWS, slots = { default = Rows } })
end

return Define.Component({
	Setup = function()
		Define.Ephemeral({
			on = { type = "boolean", default = true },
			height = { type = "number", default = 60, min = 24, max = 96, step = 1, unit = "px" },
		})
	end,

	Render = function(game)
		game.ui:Window({ attributes = { title = "Ordaen", width = 1160 * PX, height = 700 * PX },
			slots = { default = Body } })
	end,
})
