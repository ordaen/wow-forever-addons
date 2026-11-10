-- ColorPicker (design controls/color-swatch): a colour setting's row (SettingRow: its label; the row greyed while
-- disabled) with a swatch of the colour in a fine bronze edge; left-click opens the game's colour picker on it, and
-- each colour picked there is written to the setting (through the settings window's draft, so nothing applies
-- before «Сохранить»); its Cancel puts the colour back. Disabled, it takes no click. 44 x 22 px as the design draws
-- it (a px is 1/1.2 UI units).
--
-- Attributes (state.md «Controls»): `value`, a colour Setting ({ r, g, b } from 0 to 1); `disabled`, a boolean.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local EDGE = { width = 1 * PX, color = { 0.424, 0.333, 0.208, 1 } } -- the controls' bronze edge

local function Swatch(_, self)
	return self.swatch(self.attributes.value:Get())
end

local function Widget(game, self)
	game.ui:Box({ attributes = { width = 44 * PX, height = 22 * PX, border = EDGE, background = Swatch(game, self),
		OnClick = self.open } })
end

return Define.Component({
	Setup = function(_, self)
		-- the swatch's colour as the draw takes it: one table per colour (a colour picked is a new one)
		local swatches = setmetatable({}, { __mode = "k" })
		local function swatch(c)
			if type(c) ~= "table" then
				return { 0, 0, 0, 1 }
			end
			local s = swatches[c]
			if not s then
				s = { c[1], c[2], c[3], 1 }
				swatches[c] = s
			end
			return s
		end
		local before -- the colour when the picker opened: its Cancel puts it back
		local function Picked()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			self.attributes.value:Set({ r, g, b })
		end
		local function Cancelled()
			if before then
				self.attributes.value:Set(before)
			end
		end
		return {
			swatch = swatch,
			open = function()
				if self.attributes.disabled == true then
					return
				end
				local c = self.attributes.value:Peek()
				before = c
				ColorPickerFrame:SetupColorPickerAndShow({ r = c[1], g = c[2], b = c[3], hasOpacity = false,
					swatchFunc = Picked, cancelFunc = Cancelled })
			end,
		}
	end,

	Render = function(game, self)
		game.ui:SettingRow({ attributes = { value = self.attributes.value, disabled = self.attributes.disabled },
			slots = { default = Widget } })
	end,
})
