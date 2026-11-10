-- The chosen recipe, beside the lists: its icon and name, «Не изучен» while unlearned, what the work needs (red when
-- missing), its reagents, and the make row: a count and «Создать».
--
-- Attributes: `recipe` (a signal: the chosen recipe's id), `count` (a signal: how many to make), `OnCount(text)` (the
-- count typed), `OnCreate` (the button's click: crafting must start in it).
local Define = import("@ordaen/define")
local L = import("locales")
local S = import("style")

local HEAD = { columns = { 40 * S.PX, "1fr" }, gap = 10 * S.PX, yAlign = "center" }
local ICON = 40 * S.PX
local MAKE = { columns = { 80 * S.PX, "auto" }, gap = 10 * S.PX, yAlign = "center" }
local FIELD_BG = { 0, 0, 0, 0.5 }
local MAX_REAGENTS = 8
-- a row per reagent slot, made once
local REAGENT_CALLS = {}
for i = 1, MAX_REAGENTS do
	REAGENT_CALLS[i] = { key = i, attributes = { index = i } }
end

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

-- what the work needs, one line each: «Нужно: Кузнечный молот»
local function Needs(game, self)
	local r = Recipe(game, self)
	local needs = r and game.TradeSkill:Requirements(r.id)
	if not needs or #needs == 0 then
		return ""
	end
	local lines = {}
	for i = 1, #needs do
		lines[i] = (needs[i].met and "" or "|cffff4040") .. L.NEEDS .. ": " .. needs[i].name .. (needs[i].met and "" or "|r")
	end
	return table.concat(lines, "\n")
end

local function Head(game, self)
	game.ui:Box({ attributes = { width = ICON, height = ICON, background = Icon(game, self) } })
	game.ui:Text({ attributes = { text = Name(game, self), textSize = S.TITLE, textColor = S.GOLD } })
end

local function Make(game, self)
	game.ui:Box({ attributes = { kind = "input", text = tostring(self.attributes.count:Get()), width = 80 * S.PX,
		height = 30 * S.PX, padding = { 0, 8 * S.PX, 0, 8 * S.PX }, textSize = S.TEXT, textColor = S.INK,
		background = FIELD_BG, maxLength = 3, OnChange = self.attributes.OnCount } })
	game.ui:PushButton({ attributes = { label = L.CREATE, OnClick = self.attributes.OnCreate,
		disabled = (Recipe(game, self) and Recipe(game, self).craftable or 0) < 1 } })
end

return Define.Component({
	Render = function(game, self)
		local r = Recipe(game, self)
		if not r then
			return
		end
		local schematic = game.TradeSkill:Schematic(r.id)
		game.ui:Box({ attributes = HEAD, slots = { default = Head } })
		if not r.learned then
			game.ui:Text({ attributes = { text = L.NOT_LEARNED, textSize = S.TEXT, textColor = S.DIM } })
		end
		game.ui:Text({ attributes = { text = Needs(game, self), textSize = S.TEXT, textColor = S.INK } })
		game.ui:Text({ attributes = { text = L.REAGENTS, textSize = S.TEXT, textColor = S.GOLD } })
		for i = 1, math.min(#schematic.reagents, MAX_REAGENTS) do
			game.ui:ReagentRow(REAGENT_CALLS[i])
		end
		if r.learned then
			game.ui:Box({ attributes = MAKE, slots = { default = Make } })
		end
	end,
})
