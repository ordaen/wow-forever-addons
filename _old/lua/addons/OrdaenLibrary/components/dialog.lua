-- Dialog (design Window kind="dialog", the settings window's questions): a question over a window, the screen dimmed
-- behind it. The small metal frame round the window's wood, its title in gold at the top, the content under it (24 px
-- in, 44 px from the top with a title), and its buttons at the bottom right, 8 px apart. A click on the dimmed screen
-- does nothing (the question needs an answer).
--
-- Attributes: `title` (text), `width` (UI units). Slots: `default`, the question; `buttons`, its PushButtons (up to
-- three).
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local TITLE = { 1, 0.82, 0, 1 } -- #ffd100
local TITLE_SIZE = 15 * PX
local SHADOW = { color = { 0, 0, 0, 0.7 }, x = 1 * PX, y = -1 * PX }
local CENTER = { point = "CENTER", relativePoint = "CENTER" }

-- the screen behind it: dimmed, and taking the clicks meant for what's under it
local SHADE = { attributes = { position = "fixed", left = 0, right = 0, top = 0, bottom = 0,
	background = { 0, 0, 0, 0.55 }, OnClick = function() end } }
local TITLE_BOX = { position = "absolute", left = 0, right = 0, top = 14 * PX, xAlign = "center" }
local BUTTONS = { columns = { "1fr", "auto" } }
local ROW = { columns = { "auto", "auto", "auto" }, gap = 8 * PX } -- up to three buttons

local function Title(game, self)
	game.ui:Text({ attributes = { text = self.attributes.title, textColor = TITLE, textSize = TITLE_SIZE,
		textShadow = SHADOW, wrap = false } })
end
local function Row(game)
	game.ui:Slot("buttons")
end
local function Buttons(game)
	game.ui:Box({ attributes = {} })
	game.ui:Box({ attributes = ROW, slots = { default = Row } })
end
local function Body(game, self)
	game.ui:Slot("default")
	game.ui:Box({ attributes = BUTTONS, slots = { default = Buttons } })
	if self.attributes.title then
		game.ui:Box({ attributes = TITLE_BOX, slots = { default = Title } })
	end
end
local function Parts(game, self)
	game.ui:Box(SHADE)
	game.ui:Box({ attributes = { position = "fixed", anchor = CENTER, left = 0, top = 0, width = self.attributes.width,
		border = Define.Theme.frame.small, background = Define.Theme.window.wood, artOrigin = true, columns = 1,
		gap = 14 * PX, padding = { (self.attributes.title and 44 or 24) * PX, 24 * PX, 24 * PX, 24 * PX } },
		slots = { default = Body } })
end

return Define.Component({
	Render = function(game)
		game.ui:Box({ attributes = { position = "fixed", left = 0, right = 0, top = 0, bottom = 0, zLevel = 100 },
			slots = { default = Parts } })
	end,
})
