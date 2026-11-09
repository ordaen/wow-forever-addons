-- moduleSwitch: a module's on/off in the settings window's list (design settings/: the Switch beside each module):
-- the switch's art (ctl.switchOn/Off, the knob); Left-click turns the module on (it loads at once) or off (after a
-- /reload).
--
-- Attributes: `module`, an entry of game.Modules.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WIDTH, HEIGHT = 38 * PX, 20 * PX
local KNOB, KNOB_TOP = 26 * PX, (3 - 6) * PX

local function Track(_, self)
	return self.attributes.module.on:Get() and Define.Theme.ctl.switchOn or Define.Theme.ctl.switchOff
end
local function KnobLeft(_, self)
	return (self.attributes.module.on:Get() and 21 - 6 or 3 - 6) * PX
end
local function Knob(_, self)
	return self.attributes.module.on:Get() and Define.Theme.ctl.knobOn or Define.Theme.ctl.knobOff
end

local function Parts(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = KnobLeft(game, self), top = KNOB_TOP, width = KNOB,
		height = KNOB, background = Knob(game, self) } })
end

return Define.Component({
	Setup = function(_, self)
		return {
			toggle = function()
				local module = self.attributes.module
				module:Enable(not module.on:Peek())
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { width = WIDTH, height = HEIGHT, background = Track(game, self),
			OnClick = self.toggle }, slots = { default = Parts } })
	end,
})
