-- The settings window's «Темы» page (design settings/, «Themes»): a tab per theme (the active one marked ●), and in
-- the tab: the theme's look at a glance drawn with its own fonts and accent, its name (the player's own themes: a
-- field to rename it), «Использовать» (through the window's draft: it applies on «Сохранить»), «Копировать» (the
-- player's own copy; greyed at the cap), «Сбросить» on a built-in theme (back to how it ships) or «Удалить» on an own
-- one; then its values: fonts, textures, animations, the accent and the palette, the class colours. Every value edits
-- through the draft (game.Themes, Core's Themes.lua). Copy, reset, rename and delete apply at once (actions).
--
-- Attributes: `draft` (the window's game.Settings:Draft()).
local Define = import("@ordaen/define")
local L = import("locales")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local DIM = { 0.639, 0.592, 0.498, 1 } -- --o-dim
local INK = { 0.91, 0.863, 0.769, 1 } -- --o-ink
local GREEN = { 0.651, 0.89, 0.604, 1 } -- .inuse #a6e39a
local WHITE = { 1, 1, 1, 1 }
local MAX_OWN = 10
local PALETTE = { "red", "orange", "yellow", "green", "cyan", "blue", "violet", "pink", "tan", "white", "grey" }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CHIPS = {} -- a palette colour's name, on its bar tone
for i = 1, #PALETTE do
	CHIPS[i] = L["THEME_PALETTECOLOR_" .. PALETTE[i]:upper()]
end
local SECTIONS = {
	{ L.THEMES_FONTS, { "font", "fontHeader", "fontNumbers" } },
	{ L.THEMES_TEXTURES, { "barTexture", "xpFill", "barFrame" } },
	{ L.THEMES_ANIMATION, { "anim" } },
}

-- the themes shown, in order: built-ins first, then the player's own
local function Themes(game)
	return game.Themes:List()
end

local function Picked(game, self)
	local list = Themes(game)
	return list[self.state.tab] or list[1]
end

-- a theme's name as shown: a built-in's from the locales, an own one's as the player wrote it
local function NameOf(theme)
	if theme.builtin then
		return L["THEME_NAME_" .. theme.id:upper()] or theme.id
	end
	return theme:Name()
end

local function TabNames(game, self)
	local active = self.attributes.draft.Settings.theme:Get()
	-- a new table: the draw compares by identity, and this runs only when the active theme or the list changes
	local names = {}
	local list = Themes(game)
	for i = 1, #list do
		names[i] = (list[i].id == active and "● " or "") .. NameOf(list[i])
	end
	return names
end

-- a value of the picked theme as the draft holds it
local function ValueOf(game, self, key)
	return self.attributes.draft:Of(Picked(game, self).values[key]):Get()
end

-- the look at a glance: a heading, a sentence and numbers, each in the theme's font for it, the accent under them
local function Preview(game, self)
	game.ui:Text({ attributes = { text = L.THEMES_PREVIEW_TITLE, textColor = INK, textSize = 20 * PX,
		textFamily = game.Themes.FontFile(ValueOf(game, self, "fontHeader"), true), wrap = false } })
	game.ui:Text({ attributes = { text = L.THEMES_PREVIEW_TEXT, textColor = INK, textSize = 15 * PX,
		textFamily = game.Themes.FontFile(ValueOf(game, self, "font")) } })
	game.ui:Text({ attributes = { text = L.THEMES_PREVIEW_NUMBERS, textColor = INK, textSize = 15 * PX,
		textFamily = game.Themes.FontFile(ValueOf(game, self, "fontNumbers")), wrap = false } })
	game.ui:Box({ attributes = { height = 4 * PX, background = self.colorOf(ValueOf(game, self, "accent")) } })
end

local function InUse(game, self)
	return self.attributes.draft.Settings.theme:Get() == Picked(game, self).id
end

local function Buttons(game, self)
	if InUse(game, self) then
		game.ui:Text({ attributes = { text = L.THEMES_IN_USE, textColor = GREEN, textSize = 13 * PX, wrap = false } })
	else
		game.ui:PushButton({ attributes = { label = L.THEMES_USE, width = 150 * PX, accent = true, OnClick = self.use } })
	end
	game.ui:PushButton({ attributes = { label = L.THEMES_COPY, width = 140 * PX, OnClick = self.copy,
		disabled = #Themes(game) - 3 >= MAX_OWN } })
	if Picked(game, self).builtin then
		game.ui:PushButton({ attributes = { label = L.THEMES_RESET, width = 120 * PX, OnClick = self.reset } })
	else
		game.ui:PushButton({ attributes = { label = L.THEMES_DELETE, width = 110 * PX, accent = true,
			OnClick = self.delete } })
	end
end

local function AboutOf(game, self)
	return L["THEME_ABOUT_" .. Picked(game, self).id:upper()] or ""
end

local function About(game, self)
	if Picked(game, self).builtin then
		game.ui:Text({ attributes = { text = NameOf(Picked(game, self)), textColor = WHITE, textSize = 18 * PX,
			wrap = false } })
		game.ui:Text({ attributes = { text = AboutOf(game, self), textColor = DIM, textSize = 13 * PX } })
	else
		game.ui:Input({ attributes = { value = self.names(Picked(game, self)) } })
	end
	game.ui:Box({ attributes = { columns = { "auto", "auto", "auto" }, gap = 8 * PX, yAlign = "center" },
		slots = { default = Buttons } })
end

local function Head(game)
	game.ui:Box({ attributes = { columns = 1, gap = 6 * PX, padding = 12 * PX, background = { 0, 0, 0, 0.3 } },
		slots = { default = Preview } })
	game.ui:Box({ attributes = { columns = 1, gap = 10 * PX }, slots = { default = About } })
end

-- a section of the theme's values: a row per value, its control by its type
local function Values(game, self, keys)
	local theme = Picked(game, self)
	local draft = self.attributes.draft
	for i = 1, #keys do
		local value = draft:Of(theme.values[keys[i]])
		local kind = value.spec.type
		if kind == "boolean" then
			game.ui:Checkbox(nil, { attributes = { value = value } }, keys[i])
		elseif kind == "color" then
			game.ui:ColorPicker(nil, { attributes = { value = value } }, keys[i])
		else
			game.ui:Dropdown(nil, { attributes = { value = value } }, keys[i])
		end
	end
end

local function Fonts(game, self)
	Values(game, self, SECTIONS[1][2])
end
local function Textures(game, self)
	Values(game, self, SECTIONS[2][2])
end
local function Animation(game, self)
	Values(game, self, SECTIONS[3][2])
end
-- the palette every module colours with: per colour its bar tone (its name in white on it) and its text tone
local function Swatches(game, self)
	for i = 1, #PALETTE do
		game.ui:Box({ key = i, attributes = { height = 22 * PX, padding = { 0, 6 * PX, 0, 6 * PX }, text = CHIPS[i],
			textColor = WHITE, textSize = 12 * PX, background = self.colorOf(ValueOf(game, self, "palette." .. PALETTE[i])) } })
		game.ui:Text({ key = i, attributes = { text = L.THEMES_TEXT, textSize = 13 * PX, wrap = false,
			textColor = self.colorOf(ValueOf(game, self, "palette." .. PALETTE[i] .. "Text")) } })
	end
end
local function Colors(game, self)
	Values(game, self, self.colorKeys)
	game.ui:Box({ attributes = { columns = { "auto", "auto", "auto", "auto", "auto", "auto" }, gap = 6 * PX,
		yAlign = "center" }, slots = { default = Swatches } })
end
local function ClassColors(game, self)
	Values(game, self, self.classKeys)
end

local function Panel(game, self)
	game.ui:Box({ attributes = { columns = { 280 * PX, "1fr" }, gap = 18 * PX }, slots = { default = Head } })
	game.ui:Section({ attributes = { title = SECTIONS[1][1] }, slots = { default = Fonts } })
	game.ui:Section({ attributes = { title = SECTIONS[2][1] }, slots = { default = Textures } })
	game.ui:Section({ attributes = { title = SECTIONS[3][1] }, slots = { default = Animation } })
	game.ui:Section({ attributes = { title = L.THEMES_COLORS }, slots = { default = Colors } })
	game.ui:Section({ attributes = { title = L.THEMES_CLASS_COLORS }, slots = { default = ClassColors } })
end

return Define.Component({
	Setup = function(game, self)
		Define.Ephemeral({ tab = { type = "number", default = 1 } })
		-- the keys of the colour and class sections: the accent; the switch for class-coloured names and a palette
		-- colour per class
		local colorKeys = { "accent" }
		local classKeys = { "classNames" }
		for i = 1, #CLASSES do
			classKeys[#classKeys + 1] = "class." .. CLASSES[i]
		end
		-- an own theme's name as a text setting for the Input: renamed at once (an action, not drafted)
		local names = setmetatable({}, { __mode = "k" })
		local NAME_SPEC = { type = "string", maxLength = 24 }
		local function NameSetting(theme)
			local setting = names[theme]
			if not setting then
				setting = {
					spec = NAME_SPEC, name = "name",
					Get = function()
						return theme:Name()
					end,
					Peek = function()
						return theme.name:Peek()
					end,
					Set = function(_, text)
						theme:Rename(text)
					end,
					Valid = function()
						return true
					end,
					MaxLength = function()
						return NAME_SPEC.maxLength
					end,
					Label = function()
						return L.THEMES_NAME
					end,
					Tip = function()
						return L.THEMES_NAME_TIP
					end,
				}
				names[theme] = setting
			end
			return setting
		end
		local colors = setmetatable({}, { __mode = "k" })
		local current = 1 -- the tab shown, as the callbacks read it (the state is the render's)
		local function show(i)
			current = i
			self.state.tab = i
		end
		local function picked()
			local list = game.Themes:List()
			return list[current] or list[1]
		end
		return {
			colorKeys = colorKeys,
			classKeys = classKeys,
			names = NameSetting,
			colorOf = function(c)
				local s = colors[c]
				if not s then
					s = { c[1], c[2], c[3], 1 }
					colors[c] = s
				end
				return s
			end,
			pickTab = show,
			use = function()
				self.attributes.draft.Settings.theme:Set(picked().id)
			end,
			copy = function()
				local copy = picked():Copy()
				if copy then
					local list = game.Themes:List()
					for i = 1, #list do
						if list[i] == copy then
							show(i)
						end
					end
				end
			end,
			reset = function()
				picked():ResetAll()
			end,
			delete = function()
				picked():Delete()
				show(1)
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Tabs({ attributes = { tabs = TabNames(game, self), selected = self.state.tab, OnSelect = self.pickTab } })
		game.ui:Box({ attributes = { columns = 1, gap = 14 * PX }, slots = { default = Panel } })
	end,
})
