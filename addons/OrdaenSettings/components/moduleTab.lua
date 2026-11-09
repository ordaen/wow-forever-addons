-- moduleTab: a module's entry in the settings window's list: its icon, its name, its switch; dimmed while it's off.
--
-- Attributes: `module`, an entry of game.Modules; `shown`, the page the window shows (a signal of a folder); `OnClick`.
local Define = import("@ordaen/define")

-- its name in the list: its title without "Ordaen " (Ordaen Panel: Panel)
local function Name(_, self)
	return (self.attributes.module.title:gsub("^Ordaen ", ""))
end
local function Selected(_, self)
	return self.attributes.shown:Get() == self.attributes.module.folder
end
local function Off(_, self)
	return not self.attributes.module.on:Get()
end

local function Switch(game, self)
	game.ui:ModuleSwitch({ attributes = { module = self.attributes.module } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:ListTab({ attributes = { label = Name(game, self), icon = self.attributes.module.icon,
			selected = Selected(game, self), off = Off(game, self), OnClick = self.attributes.OnClick },
			slots = { default = Switch } })
	end,
})
