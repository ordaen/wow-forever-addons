-- Ordaen Panel (design: wow-dev-tools design/panel): one panel along the screen's bottom edge, in three equal
-- columns: the player's portrait in the corner and the micro menu at the left, the experience bar centred in the
-- middle, the money and the bags at the right end.
-- The micro menu and the bags are Blizzard's own buttons, embedded in the panel's cells (game.ui:Embed), so their
-- clicks, menus and alerts stay Blizzard's; the character button lies invisible over the portrait.
-- Written as the build leaves it: constant tables at file level (frozen by the build), slot functions at file level
-- taking game and self.
local Define = import("@ordaen/define")
local L = import("locales")

-- The micro menu, left to right (design/micromenu): our cells with our icons on the wood, each with Blizzard's button
-- invisible over it, so the click, menus and alerts stay Blizzard's. While Ordaen Spells and Ordaen Social don't exist,
-- the spellbook and talents keep a button each, the guild's stays, and the social one (friends: Blizzard's button by the
-- chat) comes last.
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
	{ frame = "QuickJoinToastButton", icon = import("assets/micro-social.tga"), friends = true },
}
-- A cell fills the panel below its metal edge (60 - 7 units), 1.075 times as wide: the inside between the cell's side
-- rims is square (design PanelCell). Icons 35 units (42 px at the user's scale).
local CELL_HEIGHT = 53
local CELL_WIDTH = CELL_HEIGHT * 1.075
local ICON_SIDE = 35
-- the cell lights and pushes with Blizzard's button inside it (stateFrom), the icon follows the cell and sits 1 px
-- lower while pushed (design PanelCell)
local CELL = { width = CELL_WIDTH, height = CELL_HEIGHT, background = Define.Theme.panel.cell, stateFrom = "child" }
local ICON_LEFT = (CELL_WIDTH - ICON_SIDE) / 2
local ICON_TOP = { default = (CELL_HEIGHT - ICON_SIDE) / 2, pressed = (CELL_HEIGHT - ICON_SIDE) / 2 + 1 / 1.2 }
local CLICK = { position = "absolute", left = 0, top = 0, width = CELL_WIDTH, height = CELL_HEIGHT, opacity = 0 }
local CLICK_CALL = { attributes = CLICK }
-- the friends online on the social button (design .mbadge): a green pill in the cell's lower right, shown while any are
-- online; Blizzard's own count is on its button, which lies invisible over the cell
local FRIENDS_BADGE = {
	position = "absolute", right = CELL_WIDTH * 0.12, bottom = CELL_HEIGHT * 0.14, height = 16 / 1.2,
	padding = { 0, 4 / 1.2, 0, 4 / 1.2 }, xAlign = "center", yAlign = "center",
	background = { 0.122, 0.435, 0.122, 1 }, border = { width = 1, color = { 0, 0, 0, 1 } },
}
local function FriendsCount(game, self)
	game.ui:Text(self.friends)
end
local FRIENDS_BADGE_CALL = { attributes = FRIENDS_BADGE, slots = { default = FriendsCount } }
-- each button's calls, made once here: its icon, its cell, and Blizzard's button over it
for i = 1, #MICRO do
	local m = MICRO[i]
	local frame = m.frame
	local iconCall = { attributes = {
		position = "absolute", left = ICON_LEFT, top = ICON_TOP, width = ICON_SIDE, height = ICON_SIDE,
		background = m.icon, stateFrom = "parent",
	} }
	local friends = m.friends
	m.call = { key = i, attributes = CELL, slots = { default = function(game, self)
		game.ui:Box(iconCall)
		if friends then
			local online = game.Friends.online:Get()
			if online > 0 then
				self.friends.attributes.text = tostring(online)
				game.ui:Box(FRIENDS_BADGE_CALL)
			end
		end
		game.ui:Embed(game.Frame[frame], CLICK_CALL)
	end } }
end
-- The bags, left to right (design/panel): the backpack, then the four bags. Each is a slot on the wood (design
-- ItemSlot: 38 px, a bronze edge inside it) holding Blizzard's button with only its icon showing (look = "icon"), so
-- its click, drag and tooltip stay Blizzard's.
local BAGS = {
	"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
}
local SLOT_SIDE = 38 / 1.2
local SLOT = { width = SLOT_SIDE, height = SLOT_SIDE, border = Define.Theme.panel.slotEdge }
local SLOT_BUTTON = { attributes = {
	position = "absolute", left = 1, top = 1, width = SLOT_SIDE - 2, height = SLOT_SIDE - 2, look = "icon",
} }
local BAG_CALLS = {}
for i = 1, #BAGS do
	local frame = BAGS[i]
	BAG_CALLS[i] = { key = i, attributes = SLOT, slots = { default = function(game)
		game.ui:Embed(game.Frame[frame], SLOT_BUTTON)
	end } }
end

local PORTRAIT_WIDTH, PORTRAIT_HEIGHT = 128, 124

-- The portrait stands over the panel's left end, flush with the screen's left and bottom edges.
-- Two looks, the player's choice (/ordaen panel portrait face|live): the face as a picture in the corner's shape, or
-- the live 3D head (a model: no mask can cut it, so it stays a rectangle under the rim; it renders every frame).
local PORTRAIT = {
	position = "fixed", left = 0, bottom = 0, width = PORTRAIT_WIDTH, height = PORTRAIT_HEIGHT,
	portrait = "player", mask = Define.Theme.panel.corner,
}
local PORTRAIT_LIVE = {
	position = "fixed", left = 0, bottom = 0, width = PORTRAIT_WIDTH, height = PORTRAIT_HEIGHT,
	portrait = { unit = "player", live = true }, mask = Define.Theme.panel.corner,
}
-- the level, on a badge centred on the portrait's rim at 45° (its centre: 128 - 64 + 57.5 cos 45°, 64 - 57.5 sin 45°)
local BADGE = {
	position = "absolute", left = 86.7, top = 5.3, width = 36, height = 36, background = Define.Theme.panel.badge,
	xAlign = "center", yAlign = "center",
}
local MICRO_ROW = { columns = #MICRO, gap = 0 }
local BAG_ROW = { columns = #BAGS, gap = 6 / 1.2 }

local function MicroButtons(game)
	for i = 1, #MICRO do
		game.ui:Box(MICRO[i].call)
	end
end

local function BagButtons(game)
	for i = 1, #BAGS do
		game.ui:Box(BAG_CALLS[i])
	end
end

-- Blizzard's bag bar, hidden while the panel holds its bag buttons: what stays in it (the reagent bag, which the design
-- leaves out) would sit over the panel's right end
local BAGS_BAR_HIDDEN = { attributes = { shown = false } }

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

local PORTRAIT_CALL = { key = "portrait", attributes = PORTRAIT, slots = { default = Badge } }
local PORTRAIT_LIVE_CALL = { key = "portrait", attributes = PORTRAIT_LIVE, slots = { default = Badge } }
-- the panel's first column, kept free under the portrait (the portrait itself is placed on the screen, out of the grid)
local SPACER = { width = PORTRAIT_WIDTH, height = 1 }
local SPACER_CALL = { attributes = SPACER }

-- The three columns (design/panel): the left one from its start, the right one to its end, the bar filling the middle.
local LEFT = { columns = { PORTRAIT_WIDTH, "auto" }, gap = Define.Theme.spacing.md, xAlign = "start",
	yAlign = "center" }
-- the right column (design .right): the money 16 px before the bags, 10 px from the screen edge
local RIGHT = { columns = { "auto", "auto" }, gap = 16 / 1.2, xAlign = "end", yAlign = "center",
	padding = { 0, 10 / 1.2, 0, 0 } }

local function Left(game, self)
	game.ui:Box(SPACER_CALL)
	game.ui:Box(self.state.livePortrait and PORTRAIT_LIVE_CALL or PORTRAIT_CALL)
	game.ui:Box(MICRO_CALL)
end

local function Right(game, self)
	local money = self.money
	money.attributes.text = game.Money:Format(game.Money.amount:Get())
	game.ui:Text(money)
	game.ui:Box(BAG_CALL)
	game.ui:Frame(game.Frame.BagsBar, BAGS_BAR_HIDDEN)
end

local LEFT_CALL = { key = "left", attributes = LEFT, slots = { default = Left } }

local function Cells(game, self)
	game.ui:Box(LEFT_CALL)
	game.ui:XpBar()
	game.ui:Box(self.right)
end

return Define.Module({
	title = "Ordaen Panel",
	icon = Define.Asset("Interface/Icons/INV_Misc_Bag_08"),

	Setup = function(game, self)
		Define.Persistent({
			height = { type = "number", default = 60, min = 24, max = 96 },
			livePortrait = { type = "boolean", default = false }, -- the 3D head instead of the face's picture
		})
		-- one call table each, refilled by the render: the panel's height and the money's text change
		local panel = {
			attributes = {
				position = "absolute", left = 0, right = 0, bottom = 0, height = 60,
				columns = { "1fr", "1fr", "1fr" }, yAlign = "center",
				background = Define.Theme.panel.wood, border = Define.Theme.panel.edge,
			},
			slots = { default = Cells },
		}
		local money = {
			attributes = { text = "", textColor = Define.Theme.color.text, textSize = Define.Theme.text.body },
		}
		local friends = { attributes = { text = "", textSize = 11 / 1.2, textColor = { 1, 1, 1, 1 } } }
		local level = { attributes = { text = "", textSize = Define.Theme.text.title, textColor = Define.Theme.color.accent } }
		local badge = { attributes = BADGE, slots = { default = Level } }
		local right = { key = "right", attributes = RIGHT, slots = { default = Right } }
		return { panel = panel, money = money, level = level, badge = badge, right = right, friends = friends }
	end,

	commands = {
		-- the portrait's look: face (the picture, in the corner's shape) or live (the 3D head)
		portrait = { help = L.CMD_PORTRAIT, Run = function(game, self, arguments)
			local word = arguments:match("^%s*(%a+)") or ""
			if word == "live" or word == "face" then
				self.state.livePortrait = word == "live"
			else
				print("/ordaen panel portrait face | live")
			end
		end },
	},

	Render = function(game, self)
		local panel = self.panel
		panel.attributes.height = self.state.height
		game.ui:Box(panel)
	end,
})
