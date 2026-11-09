-- Switch (design controls/switch): an on/off switch for a boolean setting. A bronze-edged pill, its knob left and grey
-- while off, right, gold and glowing while on; the edge lights up under the cursor. Left-click flips it. Disabled it
-- draws at 45% and takes no click. 38 x 20 px as the design draws it, at the user's scale (a px is 1/1.2 UI units).
--
-- Attributes (state.md «Controls»): `value`, a boolean Setting; `disabled`, a boolean.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WIDTH, HEIGHT = 38 * PX, 20 * PX
-- the knob's art is a 26 px square: the 14 px knob 6 px in from each side (room for the on knob's glow); the knob
-- sits 3 px in from the track's left (off) or 21 px (on), 3 px down
local KNOB, KNOB_TOP = 26 * PX, (3 - 6) * PX

local function knob(left, background)
	local call = { attributes = { position = "absolute", left = left, top = KNOB_TOP, width = KNOB, height = KNOB,
		background = background } }
	return function(game)
		game.ui:Box(call)
	end
end
local KNOB_OFF = knob((3 - 6) * PX, Define.Theme.ctl.knobOff)
local KNOB_ON = knob((21 - 6) * PX, Define.Theme.ctl.knobOn)

return Define.Component({
	Setup = function(_, self)
		local function Toggle()
			local setting = self.attributes.value
			setting:Set(not setting:Peek())
		end
		-- the four looks, made once: [on][disabled]
		local function call(on, disabled)
			return { attributes = {
				width = WIDTH, height = HEIGHT,
				background = on and Define.Theme.ctl.switchOn or Define.Theme.ctl.switchOff,
				opacity = disabled and 0.45 or nil,
				OnClick = not disabled and Toggle or nil,
			}, slots = { default = on and KNOB_ON or KNOB_OFF } }
		end
		return {
			looks = {
				[true] = { [true] = call(true, true), [false] = call(true, false) },
				[false] = { [true] = call(false, true), [false] = call(false, false) },
			},
		}
	end,

	Render = function(game, self)
		local setting = self.attributes.value -- the attribute's value: the Setting (a bare read, tracked by the build)
		local on = setting:Get() == true
		game.ui:Box(self.looks[on][self.attributes.disabled == true])
	end,
})
