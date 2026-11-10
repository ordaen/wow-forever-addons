-- DropdownItem: one choice in a Dropdown's open menu (design controls/dropdown .mi): its mark 10 px in (gold for the
-- picked choice), its label in white, the light under the cursor. Left-click picks it. A choice not built yet (the
-- setting's `soon`) is listed dimmed with «в разработке» after its name, and takes no click.
--
-- Attributes: `value`, the choice Setting; `item`, the choice; `OnPick`, called by a click.
local Define = import("@ordaen/define")
local L = import("locales")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WHITE = { 1, 1, 1, 1 }
local TEXT = 15 * PX
local LIGHT = { default = nil, hover = { 214 / 255, 165 / 255, 107 / 255, 0.18 } }

local function Mark(_, self)
	return self.attributes.value:Get() == self.attributes.item and Define.Theme.ctl.radioOn or Define.Theme.ctl.radio
end
local DIM = { 1, 1, 1, 0.45 }
local function Label(_, self)
	local value, item = self.attributes.value, self.attributes.item
	if value:Soon(item) then
		return value:ChoiceLabel(item) .. " — " .. L.SOON
	end
	return value:ChoiceLabel(item)
end
local function LabelColor(_, self)
	return self.attributes.value:Soon(self.attributes.item) and DIM or WHITE
end
local function Pick(_, self)
	return not self.attributes.value:Soon(self.attributes.item) and self.attributes.OnPick or nil
end
local function Light(_, self)
	return not self.attributes.value:Soon(self.attributes.item) and LIGHT or nil
end

local function Parts(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 10 * PX, top = 9 * PX, width = 11 * PX, height = 11 * PX,
		background = Mark(game, self) } })
	game.ui:Text({ attributes = { text = Label(game, self), textColor = LabelColor(game, self), textSize = TEXT } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { padding = { 5 * PX, 14 * PX, 5 * PX, 30 * PX }, background = Light(game, self),
			OnClick = Pick(game, self) }, slots = { default = Parts } })
	end,
})
