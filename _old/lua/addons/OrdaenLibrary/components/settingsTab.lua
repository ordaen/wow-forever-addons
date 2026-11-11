-- SettingsTab: one tab of a module's settings page (state.md «Settings»): its rows, sections and editors, one under
-- another, 14 px apart (design controls/page). The tab strip is the settings window's (from the page description); the
-- window draws one tab at a time (game.ui:ModuleSettings). `shown` false hides it while its part is off.
--
-- Attributes: `title` (the tab's name: read by the build and the window, not drawn here), `shown`. Slot `default`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local ROWS = { columns = 1, gap = 14 * PX }

local function Content(game)
	game.ui:Slot("default")
end
local CALL = { attributes = ROWS, slots = { default = Content } }

return Define.Component({
	Render = function(game, self)
		if self.attributes.shown ~= false then
			game.ui:Box(CALL)
		end
	end,
})
