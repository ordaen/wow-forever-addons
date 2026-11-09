-- Dropdown (design controls/dropdown): a choice setting as the bronze plate showing the picked choice in gold with an
-- arrow; Left-click opens the menu under it, each choice with its mark (the picked one gold), the light under the
-- cursor. Left-click on a choice picks it and closes the menu; a click anywhere else closes it. Disabled it draws at
-- 45% and doesn't open. 240 x 34 px as the design draws it on a settings row (a px is 1/1.2 UI units).
--
-- Attributes (state.md «Controls»): `value`, a choice Setting (its choices in declaration order, `setting:Choices()`,
-- each shown as `setting:ChoiceLabel(value)`); `disabled`, a boolean.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WIDTH, HEIGHT = 240 * PX, 34 * PX
local GOLD = { 0.941, 0.784, 0.376, 1 } -- #f0c860
local TEXT = 15 * PX
local BOLD = { color = GOLD, x = 1 * PX, y = 0 } -- the design's 700: the same colour one pixel right

local FACE = { position = "absolute", left = 0, top = 0, width = WIDTH, height = HEIGHT,
	padding = { 0, 12 * PX, 0, 18 * PX }, columns = { "1fr", 16 * PX }, gap = 10 * PX, yAlign = "center" }
local ARROW = { attributes = { width = 16 * PX, height = 16 * PX, background = Define.Theme.ctl.dropdownArrow } }
-- the menu: under the plate (38 px down), over the rows below it, as wide as the plate and 20 px more
local MENU = { position = "absolute", left = 0, top = 38 * PX, width = WIDTH + 20 * PX, zLevel = 50,
	background = { 10 / 255, 8 / 255, 6 / 255, 0.97 }, border = { width = 1 * PX, color = { 0.424, 0.333, 0.208, 1 } },
	padding = { 6 * PX, 0, 6 * PX, 0 }, columns = 1 }

local function Face(game, self)
	game.ui:Text({ attributes = { text = self.attributes.value:ChoiceLabel(self.attributes.value:Get()),
		textColor = GOLD, textSize = TEXT, textShadow = BOLD, wrap = false } })
	game.ui:Box(ARROW)
end

local function Items(game, self)
	local choices = self.attributes.value:Choices()
	for i = 1, #choices do
		local item = choices[i]
		game.ui:DropdownItem({ key = item, attributes = { value = self.attributes.value, item = item,
			OnPick = self.picks[item] } })
	end
end

local function Parts(game, self)
	game.ui:Box({ attributes = { position = FACE.position, left = 0, top = 0, width = WIDTH, height = HEIGHT,
		padding = FACE.padding, columns = FACE.columns, gap = FACE.gap, yAlign = FACE.yAlign,
		background = Define.Theme.ctl.button, OnClick = self.toggle }, slots = { default = Face } })
	if self.state.open then
		-- the screen under the menu: a click there closes it
		game.ui:Box({ attributes = { position = "fixed", left = 0, right = 0, top = 0, bottom = 0, zLevel = 49,
			OnClick = self.close } })
		game.ui:Box({ attributes = { position = MENU.position, left = 0, top = MENU.top, width = MENU.width,
			zLevel = MENU.zLevel, background = MENU.background, border = MENU.border, padding = MENU.padding,
			columns = 1 }, slots = { default = Items } })
	end
end

local WIDGET = { attributes = { width = WIDTH, height = HEIGHT }, slots = { default = Parts } }
local function Widget(game)
	game.ui:Box(WIDGET)
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({ open = { type = "boolean", default = false } })
		-- a handler per choice, made once: picks it and closes the menu
		local picks = setmetatable({}, { __index = function(t, item)
			local function Pick()
				self.attributes.value:Set(item)
				self.state.open = false
			end
			t[item] = Pick
			return Pick
		end })
		return {
			picks = picks,
			toggle = function()
				if self.attributes.disabled == true then
					return
				end
				self.state.open = not Define.Peek(self.state.open)
			end,
			close = function()
				self.state.open = false
			end,
		}
	end,

	Render = function(game, self)
		game.ui:SettingRow({ attributes = { value = self.attributes.value, disabled = self.attributes.disabled },
			slots = { default = Widget } })
	end,
})
