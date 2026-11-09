-- DropdownItem: one choice in a Dropdown's open menu (design controls/dropdown .mi): its mark 10 px in (gold for the
-- picked choice), its label in white, the light under the cursor. Left-click picks it.
--
-- Attributes: `value`, the choice Setting; `item`, the choice; `OnPick`, called by a click.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WHITE = { 1, 1, 1, 1 }
local TEXT = 15 * PX
local LIGHT = { default = nil, hover = { 214 / 255, 165 / 255, 107 / 255, 0.18 } }

local function Mark(_, self)
	return self.attributes.value:Get() == self.attributes.item and Define.Theme.ctl.radioOn or Define.Theme.ctl.radio
end
local function Label(_, self)
	return self.attributes.value:ChoiceLabel(self.attributes.item)
end

local function Parts(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 10 * PX, top = 9 * PX, width = 11 * PX, height = 11 * PX,
		background = Mark(game, self) } })
	game.ui:Text({ attributes = { text = Label(game, self), textColor = WHITE, textSize = TEXT } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { padding = { 5 * PX, 14 * PX, 5 * PX, 30 * PX }, background = LIGHT,
			OnClick = self.attributes.OnPick }, slots = { default = Parts } })
	end,
})
