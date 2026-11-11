-- Slider (design controls/slider): a number setting between its declaration's min and max. A dark groove, the bronze
-- fill up to the value, a bronze knob; the value beside it in the declaration's unit (70%, 48 px, 3). Left-click or
-- drag anywhere along it sets the value, in the declaration's steps. Disabled it draws at 45% and takes no input.
-- 240 px long as the design draws it (a px is 1/1.2 UI units at the user's scale).
--
-- Attributes (state.md «Controls»): `value`, a number Setting with min and max; `disabled`, a boolean.
local Define = import("@ordaen/define")
local L = import("locales")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local LENGTH = 240 * PX
local BAND = 20 * PX -- the knob's height: the band that takes the mouse, the groove centred in it
local GROOVE = 8 * PX -- with its 1 px edge
local EDGE = 1 * PX
local GROOVE_TOP = (BAND - GROOVE) / 2
-- the knob's art: a 16 x 32 px square, the 14 x 20 px knob 1 px in and 2 px down, centred on the value
local KNOB_W, KNOB_H = 16 * PX, 32 * PX
-- the knob's soft drop shadow, drawn by its box (the art has none)
local KNOB_SHADOW = { size = 3 * PX, y = 2 * PX, color = { 0, 0, 0, 0.55 } }
local floor, max, min, format = math.floor, math.max, math.min, string.format

-- the value as the slider shows it, by the declaration's unit
-- a value's text by its unit (the client's language: «4 пикс.», «0,5 сек.»)
local FORMATS = { percent = "%d%%", px = L.UNIT_PX, sec = L.UNIT_SEC }

local ROW = { columns = { LENGTH, "auto" }, gap = 12 * PX, yAlign = "center" }
local GROOVE_BOX = { position = "absolute", left = 0, top = GROOVE_TOP, width = LENGTH, height = GROOVE,
	background = Define.Theme.ctl.groove }

-- where the value sits along the range, 0 to 1
local function Fraction(self)
	local setting = self.attributes.value
	local spec = setting.spec
	local v = setting:Get() or spec.min
	return spec.max > spec.min and (v - spec.min) / (spec.max - spec.min) or 0
end
local function FillWidth(_, self)
	return Fraction(self) * (LENGTH - 2 * EDGE)
end
local function KnobLeft(_, self)
	return Fraction(self) * LENGTH - KNOB_W / 2
end
local function Label(_, self)
	local setting = self.attributes.value
	local unit, v = setting.spec.unit, setting:Get() or 0
	return format(FORMATS[unit] or "%s", unit == "percent" and floor(v * 100 + 0.5) or v)
end
local function Parts(game, self)
	game.ui:Box({ attributes = GROOVE_BOX })
	game.ui:Box({ attributes = { position = "absolute", left = EDGE, top = GROOVE_TOP + EDGE, height = GROOVE - 2 * EDGE,
		width = FillWidth(game, self), background = Define.Theme.ctl.sliderFill } })
	game.ui:Box({ attributes = { position = "absolute", left = KnobLeft(game, self), top = -2 * PX, width = KNOB_W,
		height = KNOB_H, background = Define.Theme.ctl.sliderKnob, shadow = KNOB_SHADOW } })
end

local function Row(game, self)
	game.ui:Box({ attributes = { width = LENGTH, height = BAND, OnClick = self.click, OnDragStart = self.setAt,
		OnDrag = self.setAt }, slots = { default = Parts } })
	game.ui:Text({ attributes = { text = Label(game, self), textColor = { 1, 1, 1, 1 } } })
end

local WIDGET = { attributes = ROW, slots = { default = Row } }
local function Widget(game)
	game.ui:Box(WIDGET)
end

return Define.Component({
	Setup = function(_, self)
		-- the value at `x` UI units along the groove, held to the range and its steps
		local function SetAt(x)
			local setting = self.attributes.value
			if self.attributes.disabled == true then
				return
			end
			local spec = setting.spec
			local lo, hi, step = spec.min, spec.max, spec.step or 1
			local t = max(0, min(1, x / LENGTH))
			setting:Set(min(hi, lo + floor(t * (hi - lo) / step + 0.5) * step))
		end
		return {
			setAt = SetAt,
			click = function(_, x)
				SetAt(x)
			end,
		}
	end,

	Render = function(game, self)
		game.ui:SettingRow({ attributes = { value = self.attributes.value, disabled = self.attributes.disabled },
			slots = { default = Widget } })
	end,
})
