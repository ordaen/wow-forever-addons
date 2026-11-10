-- Ordaen Minimap (design: wow-dev-tools design/minimap): the square map in the theme's border, the zone in a strip
-- above it, coordinates and the clock in a strip below, buttons on a ring round it (Blizzard's tracking, mail,
-- crafting orders and expansion buttons, the Ordaen button and the drawer button), and the drawer, which holds
-- every other addon's minimap button and the addon compartment's entries. A free part of the placing mode.
-- Blizzard's own buttons stay Blizzard's: each lies invisible under ours, which passes its clicks and hover on.
local Define = import("@ordaen/define")
local L = import("locales")

---@enum OrdaenMinimapHide
local Hide = { Never = "never", Combat = "combat", Transport = "transport" }

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local MAP = 262 * PX -- the map at «Размер карты» 100%
local OUT = 12 * PX -- the border's room round the map (the full-size metal's visible rim)
-- the frame as the design draws it (Minimap.vue): the metal stands 8 out past its line on the left and 3 above, and
-- the frame's box holds it (border-box), so the box starts that far out; its line is 6 narrower to sit even round
-- the map
local ART_L, ART_T, ART_NARROW = 8, 3, 6 * PX -- the reach in UI units, as the game draws the art (Theme.lua)
local STRIP = 30 * PX -- the zone's strip above, the coordinates' and clock's below
local ROOM = 33 * PX -- room round the frame for the ring (16 px out to a button's centre, 17 its radius)
local RING_OUT = 16 * PX -- from the frame's side to a ring button's centre
local BUTTON = 34 * PX
local CELL, CELL_GAP, DRAWER_PAD = 34 * PX, 4 * PX, 6 * PX -- the drawer's cells
local GOLD = { 1, 0.82, 0, 1 } -- the drawer's count, Blizzard's gold
local INK = { 0.953, 0.882, 0.722, 1 } -- the strips' text, #f3e1b8
local PENDING = { 1, 0.604, 0.18, 1 } -- the clock while calendar invites wait, #ff9a2e
local ENGRAVED = { color = { 0, 0, 0, 0.9 }, x = -1, y = 1 } -- dark up-left (the windows' titles)
-- a strip's rule towards the map: a dark 2 px line (design .strip)
local RULE_BELOW = { width = 2 * PX, sides = { "bottom" }, color = { 0.071, 0.047, 0.024, 1 } }
local RULE_ABOVE = { width = 2 * PX, sides = { "top" }, color = { 0.071, 0.047, 0.024, 1 } }
-- the zone's colour by its PvP status (Blizzard's minimap colours)
local ZONE_COLORS = {
	sanctuary = { 0.41, 0.8, 0.94, 1 }, friendly = { 0.1, 1, 0.1, 1 }, hostile = { 1, 0.1, 0.1, 1 },
	contested = { 1, 0.7, 0, 1 }, combat = { 1, 0.1, 0.1, 1 },
}
local ZONE_LABELS = {
	sanctuary = SANCTUARY_TERRITORY, friendly = FACTION_CONTROLLED_TERRITORY, hostile = FACTION_CONTROLLED_TERRITORY,
	contested = CONTESTED_TERRITORY, combat = COMBAT_ZONE,
}

-- The ring's buttons: their default angle (degrees from the top, clockwise), Blizzard's button under ours (if any)
-- and the glyph drawn on ours (the game's own atlas, at most 18 px wide in its own proportions).
local RING = {
	{ id = "tracking", angle = 290, frame = "MinimapTrackingButton", glyph = "ui-hud-minimap-tracking-up",
		w = 16, h = 15 },
	{ id = "ordaen", angle = 250 },
	{ id = "drawer", angle = 225 },
	{ id = "mail", angle = 65, frame = "MinimapMail", glyph = "ui-hud-minimap-mail-up", w = 18, h = 13.5,
		only = "mail" },
	{ id = "craftingOrder", angle = 85, frame = "MinimapCraftingOrder", only = "craftingOrder" },
	{ id = "landing", angle = 120, frame = "ExpansionLandingPageMinimapButton", only = "landing" },
}
local RING_BY_ID = {}
local GLYPH_CALLS = {} -- by id: the glyph's box, made once
for _, b in ipairs(RING) do
	RING_BY_ID[b.id] = b
	if b.glyph then
		GLYPH_CALLS[b.id] = { attributes = { width = b.w * PX, height = b.h * PX, background = { atlas = b.glyph } } }
	end
end

-- a compartment entry's icon, and the hovered one's name
local ENTRY_ICON = CELL - 4 * PX -- a compartment entry's icon in its cell
local function EntryIcon(game, i)
	local entry = game.Minimap.entries:Get()[i]
	return entry and entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function EntryName(game, self)
	local entry = game.Minimap.entries:Get()[tonumber(self.state.tip:sub(6)) or 0]
	return entry and entry.text or ""
end

-- the map's side and the frame's size now
local function Size(self)
	return MAP * self.state.scale
end
local function Top(self)
	return self.state.showZone and STRIP or 0
end
local function Bottom(self)
	return (self.state.showCoords or self.state.showClock) and STRIP or 0
end
local function FrameW(self)
	return Size(self) + 2 * OUT
end
local function FrameH(self)
	return Size(self) + 2 * OUT + Top(self) + Bottom(self)
end

-- a ring button's angle: as dragged now, as the player left it, or its default
local function Angle(self, id)
	if self.state.dragging == id then
		return self.state.dragAngle
	end
	local saved = self.state.angles[id]
	return saved or RING_BY_ID[id].angle
end

-- where a ring button's centre sits, from the frame's centre: along its angle, onto the box RING_OUT round the frame
-- (a square's projection, not a circle's), rounded to hundredths
local function RingOffset(self, id)
	local t = math.rad(Angle(self, id))
	local x, y = math.sin(t), -math.cos(t)
	local hw, hh = FrameW(self) / 2 + RING_OUT, FrameH(self) / 2 + RING_OUT
	local k = math.min(hw / math.max(math.abs(x), 1e-9), hh / math.max(math.abs(y), 1e-9))
	return math.floor(x * k * 100 + 0.5) / 100, math.floor(y * k * 100 + 0.5) / 100
end
local function RingLeft(self, id)
	local x = RingOffset(self, id)
	return ROOM + FrameW(self) / 2 + x - BUTTON / 2
end
local function RingTop(self, id)
	local _, y = RingOffset(self, id)
	return ROOM + FrameH(self) / 2 + y - BUTTON / 2
end

-- whether the ring shows: always, or with «Кнопки при наведении» while the cursor is on the minimap, a button is
-- dragged or the drawer is open
local function RingOpacity(self)
	return (not self.state.buttonsHover or self.state.hovered or self.state.drawerOpen or self.state.dragging ~= "")
		and 1 or 0
end

-- whether a ring button shows: Blizzard's only while theirs would (the mail while there's mail, ...)
local function RingShown(game, id)
	if id == "mail" then
		return game.Frame.MinimapMail:Get() ~= nil and game.Frame.MinimapMail:Get():IsShown()
	elseif id == "craftingOrder" then
		return game.Frame.MinimapCraftingOrder:Get() ~= nil and game.Frame.MinimapCraftingOrder:Get():IsShown()
	elseif id == "landing" then
		return game.Frame.ExpansionLandingPageMinimapButton:Get() ~= nil
			and game.Frame.ExpansionLandingPageMinimapButton:Get():IsShown()
	elseif id == "drawer" then
		-- only while it holds something: another addon's button or a compartment entry
		return #game.Minimap.buttons:Get() + #game.Minimap.entries:Get() > 0
	end
	return true
end

-- the strips ---------------------------------------------------------------------------------------------------------

local function ZoneText(game)
	game.ui:Text({ attributes = {
		text = game.Location.zone:Get(), textColor = ZONE_COLORS[game.Location.pvp:Get() or ""] or GOLD,
		textSize = 15 * PX, textShadow = ENGRAVED, wrap = false,
	} })
end

local function CoordsText(game)
	game.ui:Text({ attributes = {
		text = game.Minimap.coords:Get(), textColor = INK, textSize = 15 * PX, textShadow = ENGRAVED, wrap = false,
		textFamily = Define.Theme.font.numbers,
	} })
end

local function ClockText(game)
	game.ui:Text({ attributes = {
		text = game.Clock.text:Get(), textColor = game.Clock.invites:Get() > 0 and PENDING or INK,
		textSize = 15 * PX, textShadow = ENGRAVED, wrap = false, textFamily = Define.Theme.font.numbers,
	} })
end

local function Foot(game, self)
	if self.state.showCoords and game.Minimap.coords:Get() ~= "" then
		game.ui:Box({ key = "coords", attributes = { OnClick = self.coordsClick, OnEnter = self.tips.coords,
			OnLeave = self.tipOff }, slots = { default = CoordsText } })
	else
		game.ui:Box({ key = "gap", attributes = { width = 1 } })
	end
	if self.state.showClock then
		game.ui:Box({ key = "clock", attributes = { OnClick = self.clockClick, OnEnter = self.tips.clock,
			OnLeave = self.tipOff }, slots = { default = ClockText } })
	end
end

local function Head(game, self)
	game.ui:Box({ attributes = { OnEnter = self.tips.zone, OnLeave = self.tipOff }, slots = { default = ZoneText } })
end

-- the ring ------------------------------------------------------------------------------------------------------------

local function OrdaenIcon(game)
	game.ui:Box({ attributes = { width = 22 * PX, height = 22 * PX, background = game.Ordaen.icon,
		mask = Define.Theme.panel.faceRound } })
end

local function DrawerCount(game, self)
	game.ui:Text({ attributes = {
		text = tostring(#game.Minimap.buttons:Get() + #game.Minimap.entries:Get()), textColor = GOLD,
		textSize = 14 * PX, textFamily = Define.Theme.font.numbers, textShadow = { color = { 0, 0, 0, 1 }, x = 1, y = -1 },
		wrap = false,
	} })
	if self then
		return
	end
end

-- the drawer ----------------------------------------------------------------------------------------------------------

local function DrawerCells(game, self)
	local buttons = game.Minimap.buttons:Get()
	for i = 1, #buttons do
		game.ui:Embed(self:RefOf(buttons[i]), self.drawerButton)
	end
	local entries = game.Minimap.entries:Get()
	for i = 1, #entries do
		game.ui:Box(self:EntryCall(i))
	end
end

return Define.Module({
	title = "Ordaen Minimap",
	icon = Define.Asset("Interface/Icons/INV_Misc_Map_01"),

	-- the free part (Ordaen Core's placing mode moves it): the map with its frame and ring, in the top right corner
	parts = {
		map = { title = L.MINIMAP_TITLE, default = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", left = 0, top = 0 } },
	},

	Setup = function(game, self)
		Define.Persistent({
			-- «Карта»
			scale = { type = "number", default = 1, min = 0.8, max = 1.6, step = 0.05, unit = "percent", setting = true },
			showZone = { type = "boolean", default = true, setting = true },
			showClock = { type = "boolean", default = true, setting = true },
			showCoords = { type = "boolean", default = true, setting = true },
			buttonsHover = { type = "boolean", default = true, setting = true },
			hide = { type = "choice", choices = Hide, default = Hide.Never, setting = true },
			-- «Панель кнопок»
			drawerOn = { type = "boolean", default = true, setting = true },
			drawerColumns = { type = "number", default = 4, min = 2, max = 12, step = 1, setting = true },
			-- the ring buttons' angles as the player left them (degrees from the top, clockwise), by button id
			angles = { type = "map", key = "string", of = { type = "number" }, cap = 16 },
		})
		Define.Ephemeral({
			hovered = { type = "boolean", default = false },
			drawerOpen = { type = "boolean", default = false },
			dragging = { type = "string", default = "" }, -- the ring button being dragged, by id
			dragAngle = { type = "number", default = 0 },
			tip = { type = "string", default = "" }, -- which tooltip shows: zone, coords, clock, a ring button's id
		})
		local out = { tips = {} }
		for _, id in ipairs({ "zone", "coords", "clock", "ordaen", "drawer" }) do
			out.tips[id] = function()
				self.state.tip = id
			end
		end
		function out.tipOff()
			self.state.tip = ""
		end
		function out.enter()
			self.state.hovered = true
		end
		function out.leave()
			self.state.hovered = false
		end
		function out.coordsClick(button)
			if button == "LeftButton" and IsShiftKeyDown() then
				game.Minimap:SendCoords()
			end
		end
		function out.clockClick(button)
			if button == "RightButton" then
				game.Ordaen:ToggleSettings("minimap")
			else
				game.Clock:ToggleCalendar()
			end
		end
		-- a ring button: dragged round the map (its angle from the frame's centre), clicked (ours, or Blizzard's
		-- under it), hovered (its tooltip)
		out.ring = {}
		for _, b in ipairs(RING) do
			local id = b.id
			local ref = b.frame and game.Frame[b.frame]
			local startX, startY
			local ring = {}
			function ring.start()
				startX, startY = RingLeft(self, id), RingTop(self, id)
				self.state.dragAngle = Angle(self, id)
				self.state.dragging = id
				self.state.tip = ""
			end
			function ring.drag(x, y)
				local cx = startX + x - ROOM - FrameW(self) / 2
				local cy = startY + y - ROOM - FrameH(self) / 2
				self.state.dragAngle = math.floor((math.deg(math.atan2(cx, -cy)) + 360) % 360 + 0.5)
			end
			function ring.stop()
				self.state.angles[id] = self.state.dragAngle
				self.state.dragging = ""
			end
			function ring.click(button)
				if id == "ordaen" then
					if button == "RightButton" then
						game.Ordaen:ToggleDev()
					else
						game.Ordaen:ToggleSettings()
					end
				elseif id == "drawer" then
					self.state.drawerOpen = not self.state.drawerOpen
				elseif ref then
					game.Minimap:Press(ref, button)
				end
			end
			function ring.enter()
				if ref then
					game.Minimap:Hover(ref, true)
				else
					self.state.tip = id
				end
			end
			function ring.leave()
				if ref then
					game.Minimap:Hover(ref, false)
				else
					self.state.tip = ""
				end
			end
			out.ring[id] = ring
		end
		-- the drawer's parts: other addons' buttons by frame (a reference each, made once), compartment entries by
		-- index (a cell each, made once)
		local refs = setmetatable({}, { __mode = "k" })
		function out.RefOf(_, frame)
			local ref = refs[frame]
			if not ref then
				ref = { Get = function()
					return frame
				end }
				refs[frame] = ref
			end
			return ref
		end
		out.drawerButton = { attributes = { width = CELL, height = CELL, look = "icon" } }
		local entryCalls = {}
		function out.EntryCall(_, i)
			local call = entryCalls[i]
			if not call then
				-- its icon: the entry's own (entries change rarely: the table is made again when drawn)
				local function icon(game) -- luacheck: ignore 432 (the build reads drawing calls on `game` only: B9)
					game.ui:Box({ key = i, attributes = { width = ENTRY_ICON, height = ENTRY_ICON, background = EntryIcon(game, i) } })
				end
				call = { key = "entry" .. i, attributes = {
					width = CELL, height = CELL, xAlign = "center", yAlign = "center", border = Define.Theme.panel.slotEdge,
					OnClick = function(button)
						local entry = game.Minimap.entries:Peek()[i]
						if entry then
							game.Minimap:RunEntry(entry, button)
						end
					end,
					OnEnter = function()
						self.state.tip = "entry" .. i
					end,
					OnLeave = out.tipOff,
				}, slots = { default = icon } }
				entryCalls[i] = call
			end
			return call
		end
		return out
	end,

	-- the settings page (design minimap/settings): «Карта» and «Панель кнопок»
	Settings = function(game, self)
		game.ui:SettingsTab({ attributes = { title = L.TAB_MAP }, slots = { default = function()
			game.ui:Slider({ attributes = { value = Define.Signal(self.state.scale) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.showZone) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.showClock) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.showCoords) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.buttonsHover) } })
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.hide) } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_DRAWER }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.drawerOn) } })
			game.ui:Slider({ attributes = { value = Define.Signal(self.state.drawerColumns),
				disabled = not self.state.drawerOn } })
		end } })
	end,

	commands = {},

	Render = function(game, self)
		-- Blizzard's minimap furniture: the cluster (its zone text, clock, calendar and compartment buttons) and the map's
		-- round border hidden; the dev addon's own button replaced by the Ordaen button
		game.ui:Frame(game.Frame.MinimapCluster, { attributes = { shown = false } })
		game.ui:Frame(game.Frame.MinimapBackdrop, { attributes = { shown = false } }) -- the round border
		if game.Ordaen.devButton:Get() then
			game.ui:Frame(game.Frame.OrdaenDevButton, { attributes = { shown = false } })
		end
		local hide = self.state.hide
		if hide == Hide.Combat and game.Situation.combat:Get()
			or hide == Hide.Transport and (game.Situation.taxi:Get() or game.Situation.vehicle:Get()) then
			return -- the map goes back into Blizzard's hidden cluster meanwhile
		end
		game.Minimap:Square(true)
		game.Minimap:WheelZoom()
		game.Minimap:TrackCoords(self.state.showCoords)
		game.ui:Placed({ attributes = { part = "map" }, slots = { default = function()
			-- the whole: the frame with the ring's room round it
			game.ui:Box({ attributes = {
				width = FrameW(self) + 2 * ROOM, height = FrameH(self) + 2 * ROOM,
				hoverWithin = true, OnEnter = self.enter, OnLeave = self.leave,
			}, slots = { default = function()
				-- the frame: the metal and its wood, the map inside, the strips
				game.ui:Box({ attributes = {
					position = "absolute", left = ROOM - ART_L, top = ROOM - ART_T, width = FrameW(self) - ART_NARROW,
					height = FrameH(self),
					border = Define.Theme.frame.dialog, background = Define.Theme.window.wood, artOrigin = true,
				}, slots = { default = function()
					game.ui:Embed(game.Frame.Minimap, { attributes = {
						position = "absolute", left = OUT, top = OUT + Top(self), width = Size(self), height = Size(self),
					} })
					if self.state.showZone then
						game.ui:Box({ attributes = {
							position = "absolute", left = OUT, top = OUT, width = Size(self), height = STRIP,
							background = Define.Theme.window.wood, border = RULE_BELOW, xAlign = "center",
							yAlign = "center",
						}, slots = { default = function()
							Head(game, self)
						end } })
					end
					if self.state.showCoords or self.state.showClock then
						game.ui:Box({ attributes = {
							position = "absolute", left = OUT, bottom = OUT, width = Size(self), height = STRIP,
							background = Define.Theme.window.wood, border = RULE_ABOVE, columns = { "1fr", "auto" },
							padding = { 0, 10 * PX, 0, 10 * PX }, yAlign = "center",
						}, slots = { default = function()
							Foot(game, self)
						end } })
					end
				end } })
				-- the ring
				for _, b in ipairs(RING) do
					local id = b.id
					if (id ~= "drawer" or self.state.drawerOn) and RingShown(game, id) then
						local ring = self.ring[id]
						if b.frame then
							-- Blizzard's button, invisible, where ours is: its menu and tooltip anchor here
							game.ui:Embed(game.Frame[b.frame], { key = id, attributes = {
								position = "absolute", left = RingLeft(self, id), top = RingTop(self, id),
								width = BUTTON, height = BUTTON, opacity = 0,
							} })
						end
						game.ui:Box({ key = id, attributes = {
							position = "absolute", left = RingLeft(self, id), top = RingTop(self, id), width = BUTTON,
							height = BUTTON, opacity = RingOpacity(self), xAlign = "center", yAlign = "center",
							background = id == "drawer" and self.state.drawerOpen and Define.Theme.minimap.ringLit
								or Define.Theme.minimap.ring,
							OnClick = ring.click, OnDragStart = ring.start, OnDrag = ring.drag, OnDragStop = ring.stop,
							OnEnter = ring.enter, OnLeave = ring.leave,
						}, slots = { default = function()
							if id == "ordaen" then
								OrdaenIcon(game)
							elseif id == "drawer" then
								DrawerCount(game)
							elseif GLYPH_CALLS[id] then
								game.ui:Box(GLYPH_CALLS[id])
							end
						end } })
					end
				end
				-- the drawer, hanging from its button: its top right under the button's bottom right
				if self.state.drawerOn and self.state.drawerOpen then
					local cols = self.state.drawerColumns
					local n = #game.Minimap.buttons:Get() + #game.Minimap.entries:Get()
					local rows = math.max(1, math.ceil(n / cols))
					local w = cols * CELL + (cols - 1) * CELL_GAP + 2 * DRAWER_PAD
					game.ui:Box({ attributes = {
						position = "absolute", left = RingLeft(self, "drawer") + BUTTON - w,
						top = RingTop(self, "drawer") + BUTTON + 2 * PX, width = w, columns = cols, gap = CELL_GAP,
						padding = DRAWER_PAD, border = Define.Theme.frame.small, background = Define.Theme.window.wood,
						artOrigin = true, zLevel = 20,
						height = rows * CELL + (rows - 1) * CELL_GAP + 2 * DRAWER_PAD,
					}, slots = { default = function()
						DrawerCells(game, self)
					end } })
				elseif self.state.drawerOn then
					-- closed: other addons' buttons stay ours, parked invisible, off the map
					game.ui:Box({ attributes = { position = "absolute", width = 0, height = 0, opacity = 0 },
						slots = { default = function()
							DrawerCells(game, self)
						end } })
				end
				-- the tooltips of our own parts (Blizzard's buttons show their own)
				local tip = self.state.tip
				if tip == "zone" then
					game.ui:Tip({ attributes = { title = game.Location.realZone:Get(),
						text = ZONE_LABELS[game.Location.pvp:Get() or ""] or "", left = ROOM + FrameW(self) + 4 * PX,
						top = ROOM } })
				elseif tip == "coords" then
					game.ui:Tip({ attributes = { title = game.Minimap.coords:Get(), text = L.COORDS_TIP,
						left = ROOM + FrameW(self) + 4 * PX, top = ROOM + FrameH(self) - STRIP } })
				elseif tip == "clock" then
					game.ui:Tip({ attributes = { title = game.Clock.text:Get(), text = L.CLOCK_TIP,
						left = ROOM + FrameW(self) + 4 * PX, top = ROOM + FrameH(self) - STRIP } })
				elseif tip == "ordaen" then
					game.ui:Tip({ attributes = { title = game.Ordaen.title,
						text = game.Ordaen.dev:Get() and L.ORDAEN_TIP_DEV or L.ORDAEN_TIP,
						left = RingLeft(self, "ordaen") + BUTTON, top = RingTop(self, "ordaen") } })
				elseif tip == "drawer" then
					game.ui:Tip({ attributes = { title = L.DRAWER_TITLE, text = L.DRAWER_TIP,
						left = RingLeft(self, "drawer") + BUTTON, top = RingTop(self, "drawer") } })
				elseif tip:find("^entry") then
					game.ui:Tip({ attributes = { title = EntryName(game, self), text = "",
						left = RingLeft(self, "drawer") + BUTTON, top = RingTop(self, "drawer") + BUTTON } })
				end
			end } })
		end } })
	end,
})
