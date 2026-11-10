-- Ordaen Panel (design: wow-dev-tools design/panel): one panel along an edge of the screen (the bottom by default),
-- in three zones: at its start, centred and at its end. Each item (the micro menu, friends and guild, the experience
-- bar, the zone name, the time, the money, the bags) sits in the zone its setting names, or not on the panel; the
-- player's portrait stands in the screen's bottom-left corner while the micro menu is at the bottom panel's start.
-- The micro menu and the bags are Blizzard's own buttons, embedded in the panel's cells (game.ui:Embed), so their
-- clicks, menus and alerts stay Blizzard's; the character button lies invisible over the portrait.
-- Drawing calls with literal data are compiled by the build (development/framework/structure, «Bindings»): their
-- constant attributes become one frozen table per call, and each value that reads the game or state is bound, so a
-- change sets that one field without drawing the panel again. Slot functions live at file level, taking game and self.
local Define = import("@ordaen/define")
local L = import("locales")

-- The character button (setting charButton, design: panel): the portrait in the screen's corner with the level, or a
-- micro menu cell with the face, first in the row.
---@enum OrdaenPanelCharButton
local CharButton = { Portrait = "portrait", Button = "button" }
-- The micro menu's icon set (setting microIcons, design MicroIcon): our icons as they are, or the same in one gold.
---@enum OrdaenPanelMicroIcons
local MicroIcons = { Upscaled = "upscaled", Gold = "gold" }
-- Where an item sits (design settings, «Элементы»): one of the panel's zones, or not on the panel.
---@enum OrdaenPanelZone
local Zone = { Left = "left", Center = "center", Right = "right", Off = "off" }
---@enum OrdaenPanelEdge
local Edge = { Bottom = "bottom", Top = "top", Left = "left", Right = "right" }
-- The panel's length: the whole edge, or as long as its items, centred.
---@enum OrdaenPanelFit
local Fit = { Full = "full", Center = "center" }
---@enum OrdaenPanelOutline
local Outline = { None = "none", Thin = "thin", Thick = "thick" }
-- When the panel shows (design settings, «Видимость»).
---@enum OrdaenPanelShow
local Show = { Always = "always", Mouseover = "mouseover", Never = "never" }
---@enum OrdaenPanelCombat
local Combat = { Any = "any", Hide = "hide", Only = "only" }

-- The micro menu, left to right (design/micromenu): our cells with our icons on the wood, each with Blizzard's button
-- invisible over it, so the click, menus and alerts stay Blizzard's. While Ordaen Spells and Ordaen Social don't exist,
-- the spellbook and talents keep a button each and the guild's stays; the social one (friends: Blizzard's button by
-- the chat) comes before the game menu, which is always last.
local MICRO = {
	{ frame = "ProfessionMicroButton", icon = import("assets/micro-professions.tga") },
	{ frame = "SpellbookMicroButton", icon = import("assets/micro-spellbookabilities.tga") },
	{ frame = "TalentMicroButton", icon = import("assets/micro-spectalents.tga") },
	{ frame = "LegacyMicroButton", icon = import("assets/micro-legacy.tga") },
	{ frame = "QuestLogMicroButton", icon = import("assets/micro-questlog.tga") },
	{ frame = "LFDMicroButton", icon = import("assets/micro-groupfinder.tga") },
	{ frame = "CollectionsMicroButton", icon = import("assets/micro-collections.tga") },
	{ frame = "MainMenuMicroButton", icon = import("assets/micro-gamemenu.tga") },
}
-- Friends and guild (design settings, item «Друзья и гильдия»): their own item, wherever the player puts it.
local SOCIAL = {
	{ frame = "QuickJoinToastButton", icon = import("assets/micro-social.tga"), friends = true },
	{ frame = "GuildMicroButton", icon = import("assets/micro-guildcommunities.tga") },
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
-- online; Blizzard's own count is on its button, which lies invisible over the cell. 16 px high and at least as wide:
-- one digit is a circle, more grow the pill
local BADGE_SIDE = 16 / 1.2
local FRIENDS_BADGE = {
	position = "absolute", right = CELL_WIDTH * 0.12, bottom = CELL_HEIGHT * 0.14, height = BADGE_SIDE,
	padding = { 0, 4 / 1.2, 0, 4 / 1.2 }, xAlign = "center", yAlign = "center", background = Define.Theme.panel.countBadge,
}
local FRIENDS_BADGE_ONE = {
	position = "absolute", right = CELL_WIDTH * 0.12, bottom = CELL_HEIGHT * 0.14, width = BADGE_SIDE, height = BADGE_SIDE,
	xAlign = "center", yAlign = "center", background = Define.Theme.panel.countBadge,
}
local function FriendsCount(game)
	game.ui:Text({ attributes = {
		text = tostring(game.Friends.online:Get()), textSize = 11 / 1.2, textColor = { 1, 1, 1, 1 },
		-- the design's bold number: its number font, a white shadow one pixel right (a browser's synthetic bold)
		textFamily = Define.Theme.font.numbers, textShadow = { color = { 1, 1, 1, 1 }, x = 1, y = 0 },
	} })
end
local FRIENDS_BADGE_CALL = { attributes = FRIENDS_BADGE, slots = { default = FriendsCount } }
local FRIENDS_BADGE_ONE_CALL = { attributes = FRIENDS_BADGE_ONE, slots = { default = FriendsCount } }
-- each button's calls, made once here: its icon, its cell, and Blizzard's button over it
local CELLS = {}
for i = 1, #MICRO do
	CELLS[#CELLS + 1] = MICRO[i]
end
for i = 1, #SOCIAL do
	CELLS[#CELLS + 1] = SOCIAL[i]
end
for i = 1, #CELLS do
	local m = CELLS[i]
	local frame = m.frame
	local iconCall = { attributes = {
		position = "absolute", left = ICON_LEFT, top = ICON_TOP, width = ICON_SIDE, height = ICON_SIDE,
		background = m.icon, stateFrom = "parent",
	} }
	local goldCall = { attributes = {
		position = "absolute", left = ICON_LEFT, top = ICON_TOP, width = ICON_SIDE, height = ICON_SIDE,
		background = m.icon, stateFrom = "parent", desaturate = true, tint = Define.Theme.color.microGold,
	} }
	local friends = m.friends
	m.call = { key = m.frame, attributes = CELL, slots = { default = function(game, self)
		game.ui:Box(self.state.microIcons == MicroIcons.Gold and goldCall or iconCall)
		if friends then
			local online = game.Friends.online:Get()
			if online > 0 then
				game.ui:Box(online < 10 and FRIENDS_BADGE_ONE_CALL or FRIENDS_BADGE_CALL)
			end
		end
		game.ui:Embed(game.Frame[frame], CLICK_CALL)
	end } }
end
-- Blizzard's frames the panel replaces, hidden while it's on: the bag bar (what stays in it, the reagent bag the design
-- leaves out, would sit over the panel's right end), the XP and reputation bars (design status-bars/: ours are drawn
-- instead)
local HIDDEN = { attributes = { shown = false } }
-- the micro menu's box, emptied by the panel: invisible, not hidden, since Blizzard's MicroMenu:Layout reads its
-- buttons' positions (GetEdgeButton), which a hidden box doesn't have
local INVISIBLE = { attributes = { opacity = 0 } }
-- the micro buttons the design leaves out (shop, help): taken out of Blizzard's MicroMenu into a box of no size,
-- invisible. Hidden there instead, they'd have no position, and MicroMenu:Layout reads every child's (GetEdgeButton).
local PARKED_BUTTON = { attributes = { width = 0, height = 0, opacity = 0 } }
local function Parked(game)
	game.ui:Embed(game.Frame.StoreMicroButton, PARKED_BUTTON)
	game.ui:Embed(game.Frame.HelpMicroButton, PARKED_BUTTON)
end
local PARKED_CALL = { key = "parked", attributes = { position = "absolute", left = 0, top = 0, width = 0, height = 0 },
	slots = { default = Parked } }

-- The bags, left to right (design/panel): the backpack, then the four bags. Each is a cell like the micro menu's (its
-- side rims on the wood) with Blizzard's button in it showing only its icon (look = "icon"), square, the cell's full
-- height, so its click, drag and tooltip stay Blizzard's.
local BAGS = {
	"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
}
local BAG_ICON = { attributes = {
	position = "absolute", left = (CELL_WIDTH - CELL_HEIGHT) / 2, top = 0, width = CELL_HEIGHT, height = CELL_HEIGHT,
	look = "icon",
} }
-- the backpack's free slots in the slot's lower right (design ItemSlot .n: 14 px bold numbers, white, outlined), over
-- Blizzard's button; Blizzard's own count, "(23)" under the icon, is hidden
local function Free(game)
	if game.Bags.free:Get() then
		game.ui:Text({ attributes = {
			text = tostring(game.Bags.free:Get()), position = "absolute", right = (CELL_WIDTH - CELL_HEIGHT) / 2 + 3 / 1.2,
			bottom = 1 / 1.2, textSize = 14 / 1.2,
			textColor = { 1, 1, 1, 1 }, textFamily = Define.Theme.font.numbers,
			textOutline = "thin", zLevel = 1,
		} })
	end
	game.ui:Frame(game.Frame.BackpackFreeSlots, HIDDEN)
end
local BAG_CALLS = {}
for i = 1, #BAGS do
	local frame = BAGS[i]
	BAG_CALLS[i] = { key = i, attributes = CELL, slots = { default = function(game)
		game.ui:Embed(game.Frame[frame], BAG_ICON)
		if i == 1 then
			Free(game)
		end
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
local function MicroButtons(game)
	for i = 1, #MICRO do
		game.ui:Box(MICRO[i].call)
	end
end

local function SocialButtons(game)
	for i = 1, #SOCIAL do
		game.ui:Box(SOCIAL[i].call)
	end
end

local function BagButtons(game)
	for i = 1, #BAGS do
		game.ui:Box(BAG_CALLS[i])
	end
end

-- a row of an item's buttons along a horizontal panel, a column down a vertical one
local function Line(count, gap, slot, key)
	return {
		[false] = { key = key, attributes = { columns = count, gap = gap }, slots = { default = slot } },
		[true] = { key = key, attributes = { rows = count, gap = gap }, slots = { default = slot } },
	}
end

local MICRO_LINE = Line(#MICRO, 0, MicroButtons, "micro")
local SOCIAL_LINE = Line(#SOCIAL, 0, SocialButtons, "social")
local BAG_LINE = Line(#BAGS, 0, BagButtons, "bags")
-- the character button as a cell: the face, round with a thin dark rim (design .face, 40 px), with Blizzard's button
-- invisible over the cell like the others
local FACE_SIDE = 40 / 1.2
local FACE = {
	position = "absolute", left = (CELL_WIDTH - FACE_SIDE) / 2, top = (CELL_HEIGHT - FACE_SIDE) / 2, width = FACE_SIDE,
	height = FACE_SIDE, portrait = "player", mask = Define.Theme.panel.faceRound,
}
local FACE_CALL = { attributes = FACE }
local function FaceCell(game)
	game.ui:Box(FACE_CALL)
	game.ui:Embed(game.Frame.CharacterMicroButton, CLICK_CALL)
end
local FACE_CELL_CALL = { key = "face", attributes = CELL, slots = { default = FaceCell } }
local function FaceAndMicroButtons(game)
	game.ui:Box(FACE_CELL_CALL)
	MicroButtons(game)
end
local MICRO_FACE_LINE = Line(#MICRO + 1, 0, FaceAndMicroButtons, "micro")
-- the character button, invisible over the whole portrait: a click on the face opens the character window
local CHARACTER = { position = "absolute", left = 0, top = 0, width = PORTRAIT_WIDTH, height = PORTRAIT_HEIGHT, opacity = 0 }
local CHARACTER_CALL = { attributes = CHARACTER }

local function Level(game)
	game.ui:Text({ attributes = {
		text = tostring(game.Player.level:Get() or ""), textSize = Define.Theme.text.title,
		textColor = Define.Theme.color.accent,
	} })
end

local function Badge(game)
	game.ui:Embed(game.Frame.CharacterMicroButton, CHARACTER_CALL)
	game.ui:Box({ attributes = BADGE, slots = { default = Level } })
end

local PORTRAIT_CALL = { key = "portrait", attributes = PORTRAIT, slots = { default = Badge } }
local PORTRAIT_LIVE_CALL = { key = "portrait", attributes = PORTRAIT_LIVE, slots = { default = Badge } }
-- the room kept free under the portrait at the bottom panel's start (the portrait itself is placed on the screen)
local SPACER_CALL = { key = "spacer", attributes = { width = PORTRAIT_WIDTH, height = 1 } }

-- the panel's text (the money, the time, the zone): its outline and shadow are the panel's own settings (design
-- settings: text drawn on the world)
local OUTLINE = { none = nil, thin = "thin", thick = "thick" }
local TEXT_SHADOW = { color = { 0, 0, 0, 1 }, x = 1, y = -1 }
local PENDING = { 1, 0.6, 0.2, 1 } -- the time while calendar invites wait: orange (design .clock.pending)

local function Money(game, self)
	game.ui:Text({ attributes = {
		text = game.Money:Format(game.Money.amount:Get()), textColor = Define.Theme.color.text,
		textSize = Define.Theme.text.body, textOutline = OUTLINE[self.state.outline],
		textShadow = self.state.shadow and TEXT_SHADOW or nil, wrap = false,
	} })
	if game.Money.tracked:Get() ~= "" then
		game.ui:Text({ attributes = {
			text = game.Money.tracked:Get(), textColor = Define.Theme.color.text, textSize = Define.Theme.text.body,
			textOutline = OUTLINE[self.state.outline], textShadow = self.state.shadow and TEXT_SHADOW or nil, wrap = false,
		} })
	end
end
local MONEY_LINE = {
	[false] = { key = "money", attributes = { columns = { "auto", "auto" }, gap = 12 / 1.2, yAlign = "center" },
		slots = { default = Money } },
	[true] = { key = "money", attributes = { rows = { "auto", "auto" }, gap = 4 / 1.2, xAlign = "center" },
		slots = { default = Money } },
}

local function ZoneName(game, self)
	game.ui:Text({ key = "zone", attributes = {
		text = game.Location.zone:Get(), textColor = Define.Theme.color.text, textSize = Define.Theme.text.body,
		textOutline = OUTLINE[self.state.outline], textShadow = self.state.shadow and TEXT_SHADOW or nil, wrap = false,
	} })
end

local function TimeText(game, self)
	game.ui:Text({ attributes = {
		text = game.Clock.text:Get(),
		textColor = game.Clock.invites:Get() > 0 and PENDING or Define.Theme.color.text,
		textSize = Define.Theme.text.body, textOutline = OUTLINE[self.state.outline],
		textShadow = self.state.shadow and TEXT_SHADOW or nil, wrap = false,
	} })
end

local function Time(game, self)
	game.ui:Box({ key = "clock", attributes = { OnClick = self.toggleCalendar }, slots = { default = TimeText } })
end

-- the micro menu with the portrait: one box (one track of its zone), the room under the portrait first
local function MicroWithPortrait(game, self)
	game.ui:Box(SPACER_CALL)
	game.ui:Box(self.state.livePortrait and PORTRAIT_LIVE_CALL or PORTRAIT_CALL)
	game.ui:Box(MICRO_LINE[false])
end
local MICRO_PORTRAIT_CALL = { key = "micromenu", attributes = { columns = { PORTRAIT_WIDTH, "auto" },
	gap = Define.Theme.spacing.md, yAlign = "center" }, slots = { default = MicroWithPortrait } }

-- whether the portrait stands in the corner: asked for, and the micro menu at the start of a bottom panel
local function PortraitShown(self)
	return self.state.charButton == CharButton.Portrait and self.state.edge == Edge.Bottom
		and self.state.micromenu == Zone.Left
end

-- One item, drawn in its zone. `vertical`: the panel runs down a side of the screen.
local function Item(game, self, item, vertical)
	if item == "micromenu" then
		if not self.state.microOn then
			return
		end
		if PortraitShown(self) then
			game.ui:Box(MICRO_PORTRAIT_CALL)
		else
			game.ui:Box(MICRO_FACE_LINE[vertical])
		end
	elseif item == "social" then
		if self.state.microOn then
			game.ui:Box(SOCIAL_LINE[vertical])
		end
	elseif item == "experience" then
		if self.state.statusOn and not vertical then
			game.ui:XpBar({ key = "xp" })
		end
	elseif item == "zone" then
		ZoneName(game, self)
	elseif item == "clock" then
		Time(game, self)
	elseif item == "currencies" then
		game.ui:Box(MONEY_LINE[vertical])
	elseif item == "bags" then
		game.ui:Box(BAG_LINE[vertical])
	end
end

-- the items in the order they line up in a zone (design settings, «Элементы»)
local ITEMS = { "micromenu", "social", "experience", "zone", "clock", "currencies", "bags" }

-- the zone an item's setting names
local function ZoneOf(self, item)
	if item == "micromenu" then
		return self.state.micromenu
	elseif item == "social" then
		return self.state.social
	elseif item == "experience" then
		return self.state.experience
	elseif item == "zone" then
		return self.state.zone
	elseif item == "clock" then
		return self.state.clock
	elseif item == "currencies" then
		return self.state.currencies
	end
	return self.state.bags
end

-- a zone's box: its items along the panel, from the zone's start, centred or to its end
local ALIGN = { left = "start", center = "center", right = "end" }
-- each zone's box, made once per zone and direction: its items along the panel, from the zone's start, centred or to
-- its end (a grid of one track per item, "auto" each)
local function Vertical(self)
	return self.state.edge == Edge.Left or self.state.edge == Edge.Right
end
-- A zone's tracks, one per item in it in ITEMS order: the experience bar takes what's left ("1fr"), the rest their
-- content's size. Made on first use per set of items (a bit per item): the player uses a few sets.
local function TracksOf(mask)
	local tracks = {}
	for i = 1, #ITEMS do
		if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then
			tracks[#tracks + 1] = ITEMS[i] == "experience" and "1fr" or "auto"
		end
	end
	return tracks
end

-- each zone's slot: its items in order
local ZONE_SLOTS = {}
for _, zone in ipairs({ Zone.Left, Zone.Center, Zone.Right }) do
	ZONE_SLOTS[zone] = function(game, self)
		local vertical = Vertical(self)
		for i = 1, #ITEMS do
			if ZoneOf(self, ITEMS[i]) == zone then
				Item(game, self, ITEMS[i], vertical)
			end
		end
	end
end

-- a zone's box per direction and set of items, made on first use: its items along the panel, from the zone's start,
-- centred or to its end
local ZONE_CALLS = { [false] = {}, [true] = {} }
local function ZoneCall(zone, vertical, mask)
	local key = zone .. mask
	local call = ZONE_CALLS[vertical][key]
	if not call then
		local tracks, gap = mask > 0 and TracksOf(mask) or nil, Define.Theme.spacing.md
		local attributes = vertical
			and { rows = tracks, gap = gap, yAlign = ALIGN[zone], xAlign = "center" }
			or { columns = tracks, gap = gap, xAlign = ALIGN[zone], yAlign = "center" }
		call = { key = zone, attributes = attributes, slots = { default = ZONE_SLOTS[zone] } }
		ZONE_CALLS[vertical][key] = call
	end
	return call
end

-- the set of items in a zone, a bit per item
local function Mask(self, zone)
	local mask = 0
	for i = 1, #ITEMS do
		if ZoneOf(self, ITEMS[i]) == zone then
			mask = mask + 2 ^ (i - 1)
		end
	end
	return mask
end

local function ZoneBox(game, self, zone)
	game.ui:Box(ZoneCall(zone, Vertical(self), Mask(self, zone)))
end

local function Zones(game, self)
	ZoneBox(game, self, Zone.Left)
	ZoneBox(game, self, Zone.Center)
	ZoneBox(game, self, Zone.Right)
end

-- What the panel replaces of Blizzard's, for as long as it's on: its micro menu's box (invisible, not hidden: see
-- INVISIBLE) and the buttons the design leaves out; Blizzard's XP and reputation bars while ours are on.
local function Replaced(game, self)
	if self.state.microOn then
		game.ui:Frame(game.Frame.MicroMenuContainer, INVISIBLE)
		game.ui:Box(PARKED_CALL)
	end
	if self.state.statusOn then
		game.ui:Frame(game.Frame.MainStatusTrackingBarContainer, HIDDEN)
		game.ui:Frame(game.Frame.SecondaryStatusTrackingBarContainer, HIDDEN)
	end
	game.ui:Frame(game.Frame.BagsBar, HIDDEN)
end

-- Whether the panel is hidden now (design settings, «Видимость»): never shown, or only while the cursor is on it,
-- or by combat, a vehicle, a pet battle or resting.
local function Hidden(game, self)
	local show = self.state.show
	if show == Show.Never then
		return true
	end
	local combat, situation = self.state.combat, game.Situation
	if combat == Combat.Hide and situation.combat:Get() or combat == Combat.Only and not situation.combat:Get() then
		return true
	end
	if self.state.vehicle and situation.vehicle:Get() or self.state.petBattle and situation.petBattle:Get()
		or self.state.resting and situation.resting:Get() then
		return true
	end
	return show == Show.Mouseover and not self.state.hovered
end

local MOUSEOVER_MIN = 1 / 255 -- a panel shown on mouseover, hidden: invisible, yet under the cursor

-- the panel box along its edge: the whole edge, or its items' length centred on it
local function PanelAttributes(self)
	local edge, size, full = self.state.edge, self.state.height, self.state.fit == Fit.Full
	local vertical = edge == Edge.Left or edge == Edge.Right
	local a = {
		position = "fixed", background = Define.Theme.panel.wood, border = Define.Theme.panel.edge,
		hoverWithin = true, OnEnter = self.enter, OnLeave = self.leave,
	}
	if vertical then
		a.width, a.top, a.bottom = size, full and 0 or nil, full and 0 or nil
		a.rows = full and { "1fr", "1fr", "1fr" } or { "auto", "auto", "auto" }
		a.xAlign = "center"
		a[edge] = 0
		if not full then
			local point = edge == Edge.Left and "LEFT" or "RIGHT"
			a.anchor = { point = point, relativePoint = point }
		end
	else
		a.height, a.left, a.right = size, full and 0 or nil, full and 0 or nil
		a.columns = full and { "1fr", "1fr", "1fr" } or { "auto", "auto", "auto" }
		a.yAlign = "center"
		a[edge] = 0
		if not full then
			local point = edge == Edge.Bottom and "BOTTOM" or "TOP"
			a.anchor = { point = point, relativePoint = point }
		end
	end
	return a
end

return Define.Module({
	title = "Ordaen Panel",
	icon = Define.Asset("Interface/Icons/INV_Misc_Bag_08"),

	Setup = function(game, self)
		Define.Persistent({
			-- the parts, each on or off («Общее»)
			microOn = { type = "boolean", default = true, setting = true },
			statusOn = { type = "boolean", default = true, setting = true },
			bottomOn = { type = "boolean", default = true, setting = true },
			-- the micro menu
			microIcons = { type = "choice", choices = MicroIcons, default = MicroIcons.Upscaled, setting = true },
			charButton = { type = "choice", choices = CharButton, default = CharButton.Portrait, setting = true },
			livePortrait = { type = "boolean", default = false }, -- the 3D head instead of the face's picture
			-- the panel's text
			outline = { type = "choice", choices = Outline, default = Outline.None, setting = true },
			shadow = { type = "boolean", default = true, setting = true },
			-- the bottom panel: where, how long, how high, what sits in which zone, when it shows
			edge = { type = "choice", choices = Edge, default = Edge.Bottom, setting = true },
			fit = { type = "choice", choices = Fit, default = Fit.Full, setting = true },
			height = { type = "number", default = 60, min = 24, max = 96, step = 1, unit = "px", setting = true },
			micromenu = { type = "choice", choices = Zone, default = Zone.Left, setting = true },
			social = { type = "choice", choices = Zone, default = Zone.Left, setting = true },
			experience = { type = "choice", choices = Zone, default = Zone.Center, setting = true },
			zone = { type = "choice", choices = Zone, default = Zone.Off, setting = true },
			clock = { type = "choice", choices = Zone, default = Zone.Off, setting = true },
			currencies = { type = "choice", choices = Zone, default = Zone.Right, setting = true },
			bags = { type = "choice", choices = Zone, default = Zone.Right, setting = true },
			show = { type = "choice", choices = Show, default = Show.Always, setting = true },
			combat = { type = "choice", choices = Combat, default = Combat.Any, setting = true },
			vehicle = { type = "boolean", default = true, setting = true },
			petBattle = { type = "boolean", default = true, setting = true },
			resting = { type = "boolean", default = false, setting = true },
			fadedAlpha = { type = "number", default = 0, min = 0, max = 1, step = 0.05, unit = "percent", setting = true },
			condition = { type = "string", default = "", maxLength = 255, setting = true },
		})
		Define.Ephemeral({ hovered = { type = "boolean", default = false } })
		return {
			enter = function()
				self.state.hovered = true
			end,
			leave = function()
				self.state.hovered = false
			end,
			toggleCalendar = function()
				game.Clock:ToggleCalendar()
			end,
		}
	end,

	-- the settings page (design settings/, Ordaen Panel): «Общее» switches each part on or off; each part's tab shows
	-- while it's on
	Settings = function(game, self)
		game.ui:SettingsTab({ attributes = { title = L.TAB_GENERAL }, slots = { default = function()
			game.ui:Section({ attributes = { title = L.SECTION_MICROMENU }, slots = { default = function()
				game.ui:Switch({ attributes = { value = Define.Signal(self.state.microOn) } })
			end } })
			game.ui:Section({ attributes = { title = L.SECTION_STATUS }, slots = { default = function()
				game.ui:Switch({ attributes = { value = Define.Signal(self.state.statusOn) } })
			end } })
			game.ui:Section({ attributes = { title = L.SECTION_BOTTOM }, slots = { default = function()
				game.ui:Switch({ attributes = { value = Define.Signal(self.state.bottomOn) } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_MICROMENU, shown = self.state.microOn },
			slots = { default = function()
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.microIcons) } })
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.charButton) } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_STATUS, shown = self.state.statusOn },
			slots = { default = function()
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.outline) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.shadow) } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_BOTTOM, shown = self.state.bottomOn },
			slots = { default = function()
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.edge) } })
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.fit) } })
			game.ui:Slider({ attributes = { value = Define.Signal(self.state.height) } })
			game.ui:Section({ attributes = { title = L.SECTION_ITEMS }, slots = { default = function()
				game.ui:Zones({ attributes = { title = L.SECTION_ITEMS, items = {
					Define.Signal(self.state.micromenu), Define.Signal(self.state.social),
					Define.Signal(self.state.experience), Define.Signal(self.state.zone), Define.Signal(self.state.clock),
					Define.Signal(self.state.currencies), Define.Signal(self.state.bags),
				} } })
			end } })
			game.ui:Section({ attributes = { title = L.SECTION_VISIBILITY }, slots = { default = function()
				game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.show) } })
				game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.combat) } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.vehicle) } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.petBattle) } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.resting) } })
				game.ui:Slider({ attributes = { value = Define.Signal(self.state.fadedAlpha) } })
				game.ui:Input({ attributes = { value = Define.Signal(self.state.condition) } })
			end } })
		end } })
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
		Replaced(game, self)
		if not self.state.bottomOn then
			return
		end
		-- hidden: faded to its opacity, or not drawn at all at none. Shown on mouseover, a hidden panel stays drawn
		-- at the least opacity the cursor still finds (a box at opacity 0 takes no mouse).
		local hidden = Hidden(game, self)
		local faded = self.state.fadedAlpha
		if hidden and faded <= 0 and self.state.show ~= Show.Mouseover then
			-- its buttons go back to Blizzard's frames, which the panel keeps hidden or invisible; the friends
			-- button's home is by the chat, so it's hidden while the panel is
			if self.state.microOn then
				game.ui:Frame(game.Frame.QuickJoinToastButton, HIDDEN)
			end
			return
		end
		local a = PanelAttributes(self)
		a.opacity = not hidden and 1 or self.state.show == Show.Mouseover and math.max(faded, MOUSEOVER_MIN) or faded
		game.ui:Box({ attributes = a, slots = { default = Zones } })
	end,
})
