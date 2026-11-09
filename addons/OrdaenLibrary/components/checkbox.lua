-- Checkbox (design controls/checkbox): a boolean setting as a dark well with a bronze edge, a gold tick while on; the
-- edge lights up under the cursor. Left-click toggles it. Disabled it draws at 45% and takes no click. 22 px as the
-- design draws it, at the user's scale (a px is 1/1.2 UI units).
--
-- Attributes (state.md «Controls»): `value`, a boolean Setting; `disabled`, a boolean.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local SIZE = 22 * PX

local TICK = { attributes = { position = "absolute", left = 0, top = 0, width = SIZE, height = SIZE,
	background = Define.Theme.ctl.tick } }
local function Tick(game)
	game.ui:Box(TICK)
end
local function Empty() end

return Define.Component({
	Setup = function(_, self)
		local function Toggle()
			local setting = self.attributes.value
			setting:Set(not setting:Peek())
		end
		-- the four looks, made once: [on][disabled]
		local function call(on, disabled)
			return { attributes = {
				width = SIZE, height = SIZE, background = Define.Theme.ctl.check,
				opacity = disabled and 0.45 or nil,
				OnClick = not disabled and Toggle or nil,
			}, slots = { default = on and Tick or Empty } }
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
