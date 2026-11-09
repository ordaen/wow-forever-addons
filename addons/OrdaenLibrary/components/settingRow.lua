-- SettingRow (design controls/row): one setting's row on a settings page: its label (the setting's own, in the label
-- colour; its hint in a Tip while the cursor is on it) in a 280 px column, its control beside it, 18 px apart,
-- both centred on the row. A disabled row draws at 45%. Every settings control (Switch, Checkbox, Slider, Dropdown) draws its row with it, so
-- the rows line up.
--
-- Attributes: `value`, the Setting (its label: `setting:Label()`); `disabled`, a boolean. Slot `default`: the control.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local LABEL = { 0.796, 0.725, 0.58, 1 } -- --o-label #cbb994
local TEXT = 15 * PX

local function Label(game, self)
	game.ui:Text({ attributes = { text = self.attributes.value:Label(), textColor = LABEL, textSize = TEXT } })
end
local function Tip(_, self)
	return self.attributes.value:Tip()
end

local function Parts(game, self)
	-- the label's box, as wide as its column: the cursor on it shows the hint
	game.ui:Box({ attributes = { columns = 1, OnEnter = self.enter, OnLeave = self.leave },
		slots = { default = Label } })
	game.ui:Slot("default")
	-- the hint in our tooltip beside the label, over the control (settings hints are never inline)
	if self.state.tip then
		local tip = Tip(game, self)
		if tip and tip ~= "" then
			game.ui:Tip({ attributes = { title = self.attributes.value:Label(), text = Tip(game, self),
				left = 280 * PX, top = 0 } })
		end
	end
end

local function Opacity(_, self)
	return self.attributes.disabled == true and 0.45 or 1
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({ tip = { type = "boolean", default = false } })
		return {
			enter = function()
				self.state.tip = true
			end,
			leave = function()
				self.state.tip = false
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { columns = { 280 * PX, "1fr" }, gap = 18 * PX, yAlign = "center",
			opacity = Opacity(game, self) }, slots = { default = Parts } })
	end,
})
