-- Input (design controls/input): a text setting's row (SettingRow: its label; the row greyed while disabled) with a
-- text field sunk into the page: dark, with a fine bronze edge. Typing writes the setting (through the settings
-- window's draft, so nothing applies before «Сохранить»); Enter or Escape leaves the field. Disabled, it takes no
-- typing. 300 x 30 px as the design draws it, at the user's scale (a px is 1/1.2 UI units).
--
-- Attributes (state.md «Controls»): `value`, a string Setting (its `maxLength` from the declaration); `disabled`, a
-- boolean.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WIDTH, HEIGHT = 300 * PX, 30 * PX
local INK = { 0.910, 0.863, 0.769, 1 } -- --o-ink #e8dcc4
local TEXT = 14 * PX
-- the field: #080605 at the top to #120e0a, a 1 px #4a3a24 edge (design .o-input)
local FILL = { from = { 8 / 255, 6 / 255, 5 / 255, 1 }, to = { 18 / 255, 14 / 255, 10 / 255, 1 },
	direction = "vertical" }
local EDGE = { width = 1 * PX, color = { 74 / 255, 58 / 255, 36 / 255, 1 } }

local function Field(game, self)
	game.ui:Box({ attributes = {
		kind = self.attributes.disabled == true and nil or "input", text = self.attributes.value:Get() or "",
		width = WIDTH, height = HEIGHT, padding = { 0, 10 * PX, 0, 10 * PX }, background = FILL, border = EDGE,
		textColor = INK, textSize = TEXT, maxLength = self.attributes.value:MaxLength(), OnChange = self.typed,
	} })
end

return Define.Component({
	Setup = function(_, self)
		return {
			-- written while it's a value the setting takes (a macro condition the game parses); the field keeps what
			-- was typed either way, and the setting its last valid value
			typed = function(text)
				local setting = self.attributes.value
				if not setting.Valid or setting:Valid(text) then
					setting:Set(text)
				end
			end,
		}
	end,

	Render = function(game, self)
		game.ui:SettingRow({ attributes = { value = self.attributes.value, disabled = self.attributes.disabled },
			slots = { default = Field } })
	end,
})
