-- Ordaen Panel (design: wow-dev-tools design/panel): one panel along the screen's bottom edge. From the left: the
-- player's portrait in the corner, the micro menu, the experience bar across the middle, the money and the bags.
-- The micro menu and the bags are Blizzard's own buttons, embedded in the panel's cells (game.ui:Embed), so their
-- clicks, menus and alerts stay Blizzard's; the character button lies invisible over the portrait.
-- Written as the build leaves it: constant tables at file level (frozen by the build), slot functions at file level
-- taking game and self.
local Define = import("@ordaen/define")

-- The micro menu, left to right (design/micromenu): our cells with our icons on the wood, each with Blizzard's button
-- invisible over it, so the click, menus and alerts stay Blizzard's. While Ordaen Spells and Ordaen Social don't exist,
-- the spellbook and talents keep a button each and the guild's stays (the social one comes with its game.Frame).
local MICRO = {
	{ frame = "ProfessionMicroButton", icon = import("assets/micro-professions.tga") },
	{ frame = "SpellbookMicroButton", icon = import("assets/micro-spellbookabilities.tga") },
	{ frame = "TalentMicroButton", icon = import("assets/micro-spectalents.tga") },
	{ frame = "LegacyMicroButton", icon = import("assets/micro-legacy.tga") },
	{ frame = "QuestLogMicroButton", icon = import("assets/micro-questlog.tga") },
	{ frame = "GuildMicroButton", icon = import("assets/micro-guildcommunities.tga") },
	{ frame = "LFDMicroButton", icon = import("assets/micro-groupfinder.tga") },
	{ frame = "CollectionsMicroButton", icon = import("assets/micro-collections.tga") },
	{ frame = "MainMenuMicroButton", icon = import("assets/micro-gamemenu.tga") },
}
-- A cell fills the panel below its metal edge (60 - 7 units), 1.075 times as wide: the inside between the cell's side
-- rims is square (design PanelCell). Icons 35 units (42 px at the user's scale).
local CELL_HEIGHT = 53
local CELL_WIDTH = CELL_HEIGHT * 1.075
local ICON_SIDE = 35
local CELL = {
	width = CELL_WIDTH, height = CELL_HEIGHT, background = Define.Theme.panel.cell, xAlign = "center", yAlign = "center",
}
local CLICK = { position = "absolute", left = 0, top = 0, width = CELL_WIDTH, height = CELL_HEIGHT, opacity = 0 }
local CLICK_CALL = { attributes = CLICK }
-- each button's calls, made once here: its icon, its cell, and Blizzard's button over it
for i = 1, #MICRO do
	local m = MICRO[i]
	local frame = m.frame
	local iconCall = { attributes = { width = ICON_SIDE, height = ICON_SIDE, background = m.icon } }
	m.call = { key = i, attributes = CELL, slots = { default = function(game)
		game.ui:Box(iconCall)
		game.ui:Embed(game.Frame[frame], CLICK_CALL)
	end } }
end
-- The bags, left to right: the four bags, then the backpack, the reagent bag last (Blizzard's order on screen).
local BAGS = {
	"CharacterBag3Slot", "CharacterBag2Slot", "CharacterBag1Slot", "CharacterBag0Slot", "MainMenuBarBackpackButton",
	"CharacterReagentBag0Slot",
}

local PORTRAIT_WIDTH, PORTRAIT_HEIGHT = 128, 124

-- The portrait stands over the panel's left end, flush with the screen's left and bottom edges.
local PORTRAIT = {
	position = "fixed", left = 0, bottom = 0, width = PORTRAIT_WIDTH, height = PORTRAIT_HEIGHT,
	portrait = "player", mask = Define.Theme.panel.corner,
}
-- the level, on a badge centred on the portrait's rim at 45° (its centre: 128 - 64 + 57.5 cos 45°, 64 - 57.5 sin 45°)
local BADGE = {
	position = "absolute", left = 86.7, top = 5.3, width = 36, height = 36, background = Define.Theme.panel.badge,
	xAlign = "center", yAlign = "center",
}
local MICRO_ROW = { columns = #MICRO, gap = 0 }
local BAG_ROW = { columns = #BAGS, gap = 2 }
local BAG_CELL = { width = 36, height = 36 }

local function MicroButtons(game)
	for i = 1, #MICRO do
		game.ui:Box(MICRO[i].call)
	end
end

local function BagButtons(game)
	for i = 1, #BAGS do
		game.ui:Embed(game.Frame[BAGS[i]], { key = i, attributes = BAG_CELL })
	end
end

local MICRO_CALL = { attributes = MICRO_ROW, slots = { default = MicroButtons } }
local BAG_CALL = { attributes = BAG_ROW, slots = { default = BagButtons } }
-- the character button, invisible over the whole portrait: a click on the face opens the character window
local CHARACTER = { position = "absolute", left = 0, top = 0, width = PORTRAIT_WIDTH, height = PORTRAIT_HEIGHT, opacity = 0 }
local CHARACTER_CALL = { attributes = CHARACTER }

local function Badge(game, self)
	game.ui:Embed(game.Frame.CharacterMicroButton, CHARACTER_CALL)
	local level = self.level
	level.attributes.text = tostring(game.Player.level:Get() or "")
	game.ui:Box(self.badge)
end

local function Level(game, self)
	game.ui:Text(self.level)
end

local PORTRAIT_CALL = { attributes = PORTRAIT, slots = { default = Badge } }
-- the panel's first column, kept free under the portrait (the portrait itself is placed on the screen, out of the grid)
local SPACER = { width = PORTRAIT_WIDTH, height = 1 }
local SPACER_CALL = { attributes = SPACER }

local function Cells(game, self)
	game.ui:Box(SPACER_CALL)
	game.ui:Box(PORTRAIT_CALL)
	game.ui:Box(MICRO_CALL)
	game.ui:XpBar()
	local money = self.money
	money.attributes.text = game.Money:Format(game.Money.amount:Get())
	game.ui:Text(money)
	game.ui:Box(BAG_CALL)
end

return Define.Module({
	title = "Ordaen Panel",
	icon = Define.Asset("Interface/Icons/INV_Misc_Bag_08"),

	Setup = function(game, self)
		Define.Persistent({ height = { type = "number", default = 60, min = 24, max = 96 } })
		-- one call table each, refilled by the render: the panel's height and the money's text change
		local panel = {
			attributes = {
				position = "absolute", left = 0, right = 0, bottom = 0, height = 60,
				columns = { PORTRAIT_WIDTH, "auto", "1fr", "auto", "auto" },
				gap = Define.Theme.spacing.md, padding = { 0, 8, 0, 0 }, yAlign = "center",
				background = Define.Theme.panel.wood, border = Define.Theme.panel.edge,
			},
			slots = { default = Cells },
		}
		local money = {
			attributes = { text = "", textColor = Define.Theme.color.text, textSize = Define.Theme.text.body },
		}
		local level = { attributes = { text = "", textSize = Define.Theme.text.title, textColor = Define.Theme.color.accent } }
		local badge = { attributes = BADGE, slots = { default = Level } }
		return { panel = panel, money = money, level = level, badge = badge }
	end,

	Render = function(game, self)
		local panel = self.panel
		panel.attributes.height = self.state.height
		game.ui:Box(panel)
	end,
})
