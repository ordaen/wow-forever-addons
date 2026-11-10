-- The chosen recipe, beside the lists (design ProfessionsWindow .detail): on the game's dark marble with its own rim,
-- the icon in a slot and the name in white with what it does for the skill in its difficulty colour («Обычно повышает
-- навык», or «Не изучен» while unlearned); the made item's description; what the work needs (red while missing); the
-- reagents, one ruled row each: icon, name, have / need (red when short); and at the bottom the make row: the count
-- with − and +, and «Создать».
--
-- Attributes: `recipe` (a signal: the chosen recipe's id), `count` (a signal: how many to make), `OnLess`, `OnMore`
-- (the count's − and +), `OnCreate` (the button's click: crafting must start in it).
local Define = import("@ordaen/define")
local L = import("locales")
local S = import("style")

local MARBLE = { file = "Interface\\FrameGeneral\\UI-Background-Marble", repeatSize = 256 * S.PX }
-- the head, the description, the needs, the reagents (scrolling in what's left) and the make row at the bottom: in the
-- flow, so the make row's buttons count in the window's smallest size
local PANEL = { rows = { "auto", "auto", "auto", "1fr", "auto" }, gap = 8 * S.PX, padding = 12 * S.PX,
	border = { width = 1 * S.PX, color = S.LINE }, background = MARBLE, overflow = "clip" }
local REAGENTS = { rows = "auto", overflow = "scroll" }
local BRONZE = { width = 1 * S.PX, color = { 0.424, 0.333, 0.208, 1 } } -- --o-bronze, an item slot's edge
local HEAD = { columns = { 52 * S.PX, "1fr" }, gap = 10 * S.PX, yAlign = "center" }
local SLOT = 52 * S.PX
local MAKE = { columns = { "auto", "auto", "auto", "1fr", "auto" }, gap = 8 * S.PX, yAlign = "center" }
local STEP = 30 * S.PX
local MAX_REAGENTS = 8

local function Recipe(game, self)
	game.TradeSkill.version:Get()
	return game.TradeSkill:Recipe(self.attributes.recipe:Get())
end

local function Icon(game, self)
	local r = Recipe(game, self)
	return r and r.icon or nil
end
local function Name(game, self)
	local r = Recipe(game, self)
	return r and r.name or ""
end
local function Skill(game, self)
	local r = Recipe(game, self)
	if not r then
		return ""
	end
	return r.learned and L["DIFFICULTY_" .. r.difficulty] or L.NOT_LEARNED
end
local function SkillColor(game, self)
	local r = Recipe(game, self)
	return r and r.learned and S.DIFFICULTY[r.difficulty] or S.RED
end
local function Description(game, self)
	local r = Recipe(game, self)
	return r and game.TradeSkill:Description(r.id) or ""
end
-- what the work needs, one line each, red while missing: «Нужно: Кузнечный молот»
local function Needs(game, self)
	local r = Recipe(game, self)
	local needs = r and game.TradeSkill:Requirements(r.id)
	if not needs or #needs == 0 then
		return ""
	end
	local lines = {}
	for i = 1, #needs do
		local line = L.TOOLS .. ": " .. needs[i].name
		lines[i] = needs[i].met and line or "|cffff4040" .. line .. "|r"
	end
	return table.concat(lines, "\n")
end

-- a row per reagent slot, made once
local REAGENT_CALLS = {}
for i = 1, MAX_REAGENTS do
	REAGENT_CALLS[i] = { key = i, attributes = { index = i } }
end
local function Reagents(game, self)
	local r = Recipe(game, self)
	if not r then
		return
	end
	local schematic = game.TradeSkill:Schematic(r.id)
	for i = 1, math.min(#schematic.reagents, MAX_REAGENTS) do
		game.ui:ReagentRow(REAGENT_CALLS[i])
	end
end

local function HeadText(game, self)
	game.ui:Text({ attributes = { text = Name(game, self), textSize = S.NAME, textColor = S.WHITE,
		textShadow = S.SHADOW } })
	game.ui:Text({ attributes = { text = Skill(game, self), textSize = S.SMALL, textColor = SkillColor(game, self) } })
end
local function Head(game, self)
	game.ui:Box({ attributes = { width = SLOT, height = SLOT, border = BRONZE, background = Icon(game, self) } })
	game.ui:Box({ attributes = { rows = "auto", gap = 2 * S.PX }, slots = { default = HeadText } })
end

local function Make(game, self)
	game.ui:PushButton({ attributes = { label = "−", width = STEP, OnClick = self.attributes.OnLess } })
	game.ui:Text({ attributes = { text = tostring(self.attributes.count:Get()), textSize = S.TEXT, textColor = S.WHITE,
		textFamily = Define.Theme.font.numbers, wrap = false } })
	game.ui:PushButton({ attributes = { label = "+", width = STEP, OnClick = self.attributes.OnMore } })
	game.ui:Box({ attributes = { height = 1 } })
	game.ui:PushButton({ attributes = { label = L.CREATE, width = 140 * S.PX, OnClick = self.attributes.OnCreate,
		disabled = (Recipe(game, self) and Recipe(game, self).craftable or 0) < 1 } })
end

local function Panel(game, self)
	if not Recipe(game, self) then
		return
	end
	game.ui:Box({ attributes = HEAD, slots = { default = Head } })
	game.ui:Text({ attributes = { text = Description(game, self), textSize = S.RECIPE_TEXT, textColor = S.INK } })
	game.ui:Text({ attributes = { text = Needs(game, self), textSize = S.RECIPE_TEXT, textColor = S.DIM } })
	game.ui:Box({ attributes = REAGENTS, slots = { default = Reagents } })
	game.ui:Box({ attributes = MAKE, slots = { default = Make } })
end

return Define.Component({
	Render = function(game)
		game.ui:Box({ attributes = PANEL, slots = { default = Panel } })
	end,
})
