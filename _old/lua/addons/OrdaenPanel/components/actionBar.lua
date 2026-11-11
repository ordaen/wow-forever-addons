-- One action bar, Classic mode (design action-bars): Blizzard's 12 buttons of one bar as ours, on Blizzard's own page
-- of slots and key bindings, laid out by the bar's own settings: its buttons per row, the space between them and its
-- scale; each button's key and macro name shown or not. Per state (out of combat, in combat, on transport) it shows
-- or not (a secure macro condition: it holds in combat), and while shown it fades to its opacity once the mouse has
-- been off it for its delay. Clicks going through it are a setting not drawn yet (secure buttons can't change their
-- mouse in combat; it needs a secure handler).
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

-- the state the bar's visibility follows: on transport (a vehicle, a flight path), in combat, or out of combat
local function State(game)
	if game.Situation.vehicle:Get() or game.Situation.taxi:Get() then
		return "Transport"
	end
	return game.Situation.combat:Get() and "Combat" or "Ooc"
end
-- whether it shows, as a macro condition the game runs: a vehicle first, then combat (the bar's own three switches);
-- the eight conditions made once, by [transport][combat][out of combat]
local SHOW_WHEN = {}
for _, t in ipairs({ true, false }) do
	SHOW_WHEN[t] = {}
	for _, c in ipairs({ true, false }) do
		SHOW_WHEN[t][c] = {}
		for _, o in ipairs({ true, false }) do
			local function word(on)
				return on and "show" or "hide"
			end
			SHOW_WHEN[t][c][o] = "[vehicleui][possessbar][overridebar] " .. word(t) .. "; [combat] " .. word(c) .. "; "
				.. word(o)
		end
	end
end
local function ShowWhen(self)
	return SHOW_WHEN[Field(self, "showTransport")][Field(self, "showCombat")][Field(self, "showOoc")]
end
-- full under the mouse (and for its delay after), else the state's opacity
local FADE = { Ooc = "fadeOoc", Combat = "fadeCombat", Transport = "fadeTransport" }
local DELAY = { Ooc = "delayOoc", Combat = "delayCombat", Transport = "delayTransport" }
local function Opacity(game, self)
	if self.state.hovered or self.state.held then
		return 1
	end
	return Field(self, FADE[State(game)])
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
	Setup = function(game, self)
		Define.Ephemeral({
			hovered = { type = "boolean", default = false }, -- the mouse is over the bar
			held = { type = "boolean", default = false }, -- the mouse left less than its delay ago
		})
		local timer
		return {
			enter = function()
				if timer then
					timer:Cancel()
					timer = nil
				end
				self.state.hovered = true
			end,
			leave = function()
				self.state.hovered = false
				local delay = self.attributes.bars:Field(self.attributes.bar, DELAY[State(game)]):Peek()
				if delay > 0 then
					self.state.held = true
					timer = game.Timer:After(delay, function()
						timer = nil
						self.state.held = false
					end)
				end
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { columns = Field(self, "perRow"), gap = Gap(self), visibleWhen = ShowWhen(self),
			opacity = Opacity(game, self), hoverWithin = true, OnEnter = self.enter, OnLeave = self.leave },
			slots = { default = Buttons } })
	end,
})
