-- The «Панели команд» page (design action-bars/configuration): the bars listed with their switches, the picked one
-- marked; beside the list the picked bar's settings, one section under another: «Кнопки», «Вид», «Видимость» with a tab
-- per state (out of combat, in combat, on transport), each with its own copy of the settings.
--
-- Attributes: `bars`, the module's records of the bars' settings (`Define.Signal(self.state.bars)`); `ids`, the bars'
-- ids in the list's order; `titles`, each id's name.
local Define = import("@ordaen/define")
local L = import("locales")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local PAGE = { columns = { 180 * PX, "1fr" }, gap = 16 * PX }
local LIST = { columns = 1 }
local SETTINGS = { columns = 1, gap = 10 * PX }
local VIS_TABS = { L.PANEL_VIS_OOC, L.PANEL_VIS_COMBAT, L.PANEL_VIS_TRANSPORT }
-- each state's fields, by the «Видимость» tab's index
local VIS_SUFFIX = { "Ooc", "Combat", "Transport" }

-- the picked bar's field (a stored value with the setting API, what a control binds)
local function Field(self, name)
	return self.attributes.bars:Field(self.state.bar, name)
end
local function VisField(self, name)
	return self.attributes.bars:Field(self.state.bar, name .. VIS_SUFFIX[self.state.visTab])
end

local function Entry(game, self)
	local ids = self.attributes.ids
	for i = 1, #ids do
		local id = ids[i]
		game.ui:ListTab({ key = id, attributes = { label = self.attributes.titles[id], selected = self.state.bar == id,
			off = not self.attributes.bars:Field(id, "on"):Get(), OnClick = self.picks[id],
			value = self.attributes.bars:Field(id, "on") } })
	end
end

local function Buttons(game, self)
	game.ui:Slider({ attributes = { value = Field(self, "perRow") } })
end
local function Look(game, self)
	game.ui:Slider({ attributes = { value = Field(self, "spacing") } })
	game.ui:Slider({ attributes = { value = Field(self, "scale") } })
	game.ui:Switch({ attributes = { value = Field(self, "keys") } })
	game.ui:Switch({ attributes = { value = Field(self, "macros") } })
	game.ui:Switch({ attributes = { value = Field(self, "empty") } })
end
local function Visibility(game, self)
	game.ui:Tabs({ attributes = { tabs = VIS_TABS, selected = self.state.visTab, OnSelect = self.pickTab } })
	game.ui:Switch({ attributes = { value = VisField(self, "show") } })
	game.ui:Slider({ attributes = { value = VisField(self, "fade") } })
	game.ui:Slider({ attributes = { value = VisField(self, "delay") } })
	game.ui:Switch({ attributes = { value = VisField(self, "through") } })
end
local function Settings(game, self)
	game.ui:Section({ attributes = { title = L.SECTION_BUTTONS }, slots = { default = Buttons } })
	game.ui:Section({ attributes = { title = L.SECTION_LOOK }, slots = { default = Look } })
	game.ui:Section({ attributes = { title = L.SECTION_VISIBILITY }, slots = { default = Visibility } })
end
local function Parts(game, self)
	game.ui:Box({ attributes = LIST, slots = { default = Entry } })
	game.ui:Box({ attributes = SETTINGS, slots = { default = Settings } })
end

return Define.Component({
	Setup = function(_, self)
		local ids = Define.Peek(self.attributes.ids)
		Define.Ephemeral({
			bar = { type = "string", default = ids[1] }, -- the picked bar's id
			visTab = { type = "number", default = 1 }, -- «Видимость»: the state shown
		})
		-- per bar, made once: a click picks it
		local picks = {}
		for i = 1, #ids do
			local id = ids[i]
			picks[id] = function()
				self.state.bar = id
			end
		end
		return {
			picks = picks,
			pickTab = function(i)
				self.state.visTab = i
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = PAGE, slots = { default = Parts } })
	end,
})
