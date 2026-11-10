-- One action bar, Classic mode (design action-bars): Blizzard's 12 buttons of one bar as ours, on Blizzard's own page
-- of slots and key bindings, laid out by the bar's own settings: its buttons per row, the space between them and its
-- scale; each button's key and macro name shown or not.
--
-- Attributes: `bars`, the module's records of the bars' settings; `bar`, this bar's id; `first`, the number before
-- its first button among all bars' (bar k: (k - 1) * 12); `page`, its page of slots; `binding`, its key binding's name
-- without the button's number ("ACTIONBUTTON"); `paging`, a macro condition that picks its page (the main bar's
-- stances), or nil.
local Define = import("@ordaen/define")

local BUTTONS = 12
local BUTTON = 45 / 1.2 -- 45 px buttons (design ActionButton)

local function Field(self, name)
	return self.attributes.bars:Field(self.attributes.bar, name):Get()
end
local function Size(self)
	return BUTTON * Field(self, "scale")
end
local function Gap(self)
	return Field(self, "spacing") / 1.2 * Field(self, "scale")
end
-- button i's slot, and its key binding's name
local function Action(self, i)
	return (self.attributes.page - 1) * BUTTONS + i
end
local function Binding(self, i)
	return self.attributes.binding .. i
end

local function Buttons(game, self)
	local first = self.attributes.first
	for i = 1, BUTTONS do
		game.ui:Embed(game.ActionButtons[first + i], { key = i, attributes = { width = Size(self), height = Size(self),
			index = i, action = Action(self, i), binding = Binding(self, i), paging = self.attributes.paging,
			hotkey = Field(self, "keys"), macroName = Field(self, "macros") } })
	end
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = Field(self, "perRow"), gap = Gap(self) },
			slots = { default = Buttons } })
	end,
})
