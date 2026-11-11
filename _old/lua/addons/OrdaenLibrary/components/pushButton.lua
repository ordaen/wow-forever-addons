-- PushButton (design PushButton): our push button, the bronze plate three-sliced from its art (media/button.tga), or
-- the red one with `accent`; the art's hover glow over it under the cursor, its pushed row while pressed (the label
-- 2 px lower). The label in gold, white under the cursor, with a dark drop; disabled, the grey plate and a grey label,
-- and no click. 34 px high as the design draws it (a px is 1/1.2 UI units).
--
-- Attributes: `label` (text), `width` (UI units), `accent` and `disabled` (booleans), `OnClick`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local HEIGHT = 34 * PX
local TEXT = 15 * PX
local LABEL = { default = { 1, 0.82, 0, 1 }, hover = { 1, 1, 1, 1 } } -- #ffd100, white under the cursor
local GREY = { 0.502, 0.502, 0.502, 1 } -- #808080
local SHADOW = { color = { 0, 0, 0, 1 }, x = 1 * PX, y = -1 * PX }
local DOWN = { default = 0, pressed = 2 * PX } -- the label while pressed

local function Art(_, self)
	if self.attributes.disabled == true then
		return Define.Theme.ctl.buttonDisabled
	end
	return self.attributes.accent == true and Define.Theme.ctl.buttonAccent or Define.Theme.ctl.button
end
local function Color(_, self)
	return self.attributes.disabled == true and GREY or LABEL
end
local function Click(_, self)
	return self.attributes.disabled ~= true and self.attributes.OnClick or nil
end

local function Label(game, self)
	game.ui:Text({ attributes = { text = self.attributes.label, textColor = Color(game, self), textSize = TEXT,
		textShadow = SHADOW, wrap = false, stateFrom = "parent" } })
end
local LABEL_BOX = { position = "absolute", left = 0, right = 0, top = DOWN, height = HEIGHT, xAlign = "center",
	yAlign = "center", stateFrom = "parent" }
local function Parts(game)
	game.ui:Box({ attributes = LABEL_BOX, slots = { default = Label } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { width = self.attributes.width, height = HEIGHT, background = Art(game, self),
			OnClick = Click(game, self) }, slots = { default = Parts } })
	end,
})
