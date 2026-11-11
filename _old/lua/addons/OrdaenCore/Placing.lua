-- The placing mode («Режим перемещения»; design action-bars/index.md «Moving belongs to Ordaen Core», placement.md):
-- every free Ordaen part (the action bars, the micro menu and status bars off the bottom panel, the minimap, ...) is
-- declared by its module (design development/framework/module, «Parts»):
--   Define.Module({ parts = { bar1 = { title = L.KEY, default = { point, relativePoint, left, top },
--                                      width = n, height = n, resize = "width" | "both" | nil }, ... } })
-- so Ordaen Core knows every part of every module that's on, drawn or not, under the id <Module>.<part>
-- (OrdaenPanel.bar1). The module draws it with game.ui:Placed({ attributes = { part = "bar1", default = ... },
-- slots = ... }): at its saved place, else the call's `default` (bound: a part never moved follows the panel), else
-- the declared one. Saved places are { point, relativePoint, left, top, width?, height? } in UI units (they hold at
-- every scale), account-wide in OrdaenCoreDB.placed; a part never moved stores nothing.
-- While the mode is on, a left-click selects a part (gold): the position window («Положение», one of our windows,
-- moved by its own tab) shows its X and Y to type or nudge, «По умолчанию» and «Привязка». With «Привязка» (Blizzard's
-- own Edit Mode snap setting, the one source) a dragged part's edges and middle snap to the screen's edges and middle
-- and to the other parts' edges within SNAP units.
-- game.Placing.on (a value signal), :Enter(), :Exit(), :Toggle(): opens and closes with Blizzard's Edit Mode and with
-- `/ordaen move`, never in combat (secure parts can't move then). While it's on, each part shows an outline with its
-- title over its content: dragged to move it, right-clicked to put it back at its default, and a grip to resize it
-- when it's resizable. The place is saved on drop.
local _, ns = ...

local Engine, Game = ns.Engine, ns.Game
local floor, max, next = math.floor, math.max, next

---@class OrdaenPlacing
---@field on OrdaenValueSignal boolean: the placing mode is on
local Placing = {}
ns.Placing = Placing

local places = {} -- id -> value signal of its saved place (nil: its default)
local rects = {} -- id -> { left, top, width, height } on the screen while the mode is on (the outline's OnRect)
local SNAP = 8 -- UI units: how near an edge snaps
local declared = {} -- id -> its declaration (title, default, width, height, resize), from the module's `parts`

--- A module's parts (its declaration's `parts`), when it mounts: known from then on, drawn or not.
---@param module string the module's folder ("OrdaenPanel")
---@param parts table<string, table>
function Placing.Declare(module, parts)
	for name, part in pairs(parts) do
		declared[module .. "." .. name] = part
	end
end

--- A module reset (App.ResetModule): its parts no longer declared (their saved places stay, for its next mount).
---@param module string the module's folder
function Placing.Forget(module)
	local prefix = module .. "."
	for id in pairs(declared) do
		if id:sub(1, #prefix) == prefix then
			declared[id] = nil
		end
	end
end

--- Every declared part, by id (the placing mode's list).
function Placing.Parts()
	return declared
end

-- a saved place's signal, read from OrdaenCoreDB.placed once
local function PlaceOf(id)
	local place = places[id]
	if not place then
		local db = ns.Globals.store.db
		place = ns.NewValue(db.placed and db.placed[id] or nil)
		places[id] = place
	end
	return place
end

local function Save(id, value)
	local db = ns.Globals.store.db
	if value then
		db.placed = db.placed or {}
		db.placed[id] = value
	elseif db.placed then
		db.placed[id] = nil
		if next(db.placed) == nil then
			db.placed = nil
		end
	end
	PlaceOf(id):Set(value)
end

--- Turn the mode on (refused in combat: returns false).
function Placing:Enter()
	if InCombatLockdown() then
		return false
	end
	Placing.MountWindow()
	self.on:Set(true)
	return true
end

-- «Привязка»: Blizzard's own Edit Mode snap setting (C_EditMode's account setting), read and written there
local function SnapSetting()
	return Enum.EditModeAccountSetting and Enum.EditModeAccountSetting.EnableSnap
end
function Placing.SnapOn()
	local setting = SnapSetting()
	if not setting then
		return false
	end
	for _, s in ipairs(C_EditMode.GetAccountSettings() or {}) do
		if s.setting == setting then
			return s.value == 1
		end
	end
	return false
end
function Placing.SetSnap(on)
	local setting = SnapSetting()
	if setting then
		C_EditMode.SetAccountSetting(setting, on and 1 or 0)
	end
end

-- a dragged part's move (dx, dy from where it was, UI units) snapped: its left, middle and right to the screen's edges
-- and middle and to the other parts' edges and middles, nearest within SNAP; the same for top, middle and bottom
local function Snap(id, dx, dy)
	local r = rects[id]
	if not r or not Placing.SnapOn() then
		return dx, dy
	end
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
	local function best(pos, size, lines, d)
		local bestD, bestGap = d, SNAP + 1
		for _, edge in ipairs({ 0, size / 2, size }) do
			local at = pos + d + edge
			for i = 1, #lines do
				local gap = math.abs(lines[i] - at)
				if gap < bestGap then
					bestGap, bestD = gap, lines[i] - pos - edge
				end
			end
		end
		return bestD
	end
	local xs, ys = { 0, screenW / 2, screenW }, { 0, screenH / 2, screenH }
	for other, o in pairs(rects) do
		if other ~= id then
			xs[#xs + 1], xs[#xs + 2], xs[#xs + 3] = o[1], o[1] + o[3] / 2, o[1] + o[3]
			ys[#ys + 1], ys[#ys + 2], ys[#ys + 3] = o[2], o[2] + o[4] / 2, o[2] + o[4]
		end
	end
	return best(r[1], r[3], xs, dx), best(r[2], r[4], ys, dy)
end

function Placing:Exit()
	self.on:Set(false)
	self.selected:Set(nil)
end

function Placing:Toggle()
	if self.on:Peek() then
		self:Exit()
	else
		self:Enter()
	end
end

--- Put a part back at its default place and size.
---@param id string
function Placing.Reset(id)
	Save(id, nil)
end

--- At Ordaen's ADDON_LOADED: the mode's signal, and following Edit Mode and combat.
function Placing.Load()
	Placing.on = ns.NewValue(false)
	Placing.selected = ns.NewValue(nil) -- the selected part's id, while the mode is on
	-- places saved under the ids parts had before they were declared (OrdaenPanel.module#bar1): moved over once
	local db = ns.Globals.store.db
	if db.placed then
		local moved = {}
		for id, place in pairs(db.placed) do
			local new = id:match("^(Ordaen%w+)%.module#([%w_]+)$")
			if new then
				moved[id] = new .. "." .. id:match("#([%w_]+)$")
			end
		end
		for old, new in pairs(moved) do
			if db.placed[new] == nil then
				db.placed[new] = db.placed[old]
			end
			db.placed[old] = nil
		end
	end
	local registry = EventRegistry
	if registry and registry.RegisterCallback then
		registry:RegisterCallback("EditMode.Enter", function()
			Engine:Handle(Placing.Enter, Placing)
		end, Placing)
		registry:RegisterCallback("EditMode.Exit", function()
			Engine:Handle(Placing.Exit, Placing)
		end, Placing)
	end
	Game.RawEvent("PLAYER_REGEN_DISABLED"):Subscribe(function()
		Placing:Exit()
	end, false)
end

-- How much of a size change moves the anchored point's offset, so the top-left corner stays put: none for a point on
-- the left (top), half for one in the middle, all of it for one on the right (bottom).
local SHARE_X = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1,
	RIGHT = 1, BOTTOMRIGHT = 1 }
local SHARE_Y = { TOPLEFT = 0, TOP = 0, TOPRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 1,
	BOTTOM = 1, BOTTOMRIGHT = 1 }

local OUTLINE = { width = 1, color = { 1, 0.82, 0, 0.9 } }
local SHADE = { 0, 0, 0, 0.45 }
-- the selected part: a brighter, wider edge over a gold shade
local OUTLINE_SELECTED = { width = 2, color = { 1, 0.86, 0.3, 1 } }
local SHADE_SELECTED = { 0.45, 0.33, 0.05, 0.45 }
local live = {} -- id -> the drawn part (its place for the position window), while it's drawn

-- A free part: its place, its content, and while placing, the outline over it.
local PlacedPart = {
	name = "placed",
	Setup = function(_, self)
		local module = self.module
		local name = self.attributes.part:Peek()
		self.placeId = (module and module.name or "?") .. "." .. tostring(name)
		local part = declared[self.placeId]
		if not part then
			error("Ordaen: " .. self.placeId .. " is no part its module declares (parts = { " .. tostring(name)
				.. " = ... })", 0)
		end
		self.part = part
		self.place = PlaceOf(self.placeId)
		self.moving = ns.NewValue(nil) -- the place while a drag or resize runs; saved on drop
		local start, grabX, grabY
		local function Current()
			local place = self.moving:Peek() or self.place:Peek() or self.attributes.default:Peek() or part.default
			return {
				point = place.point, relativePoint = place.relativePoint or place.point, left = place.left or 0,
				top = place.top or 0, width = place.width or part.width, height = place.height or part.height,
			}
		end
		local function Begin(x, y)
			start, grabX, grabY = Current(), x, y
			Placing.selected:Set(self.placeId)
		end
		local function Stop()
			local place = self.moving:Peek()
			if place then
				Save(self.placeId, place)
				self.moving:Set(nil)
			end
		end
		self.dragStart = Begin
		self.drag = function(x, y)
			local place = Current()
			local dx, dy = Snap(self.placeId, x - grabX, y - grabY)
			place.left = floor(start.left + dx + 0.5)
			place.top = floor(start.top + dy + 0.5)
			self.moving:Set(place)
		end
		self.dragStop = Stop
		self.sizeStart = Begin
		self.size = function(x, y)
			local resize = part.resize
			local place = Current()
			if start.width and (resize == "width" or resize == "both") then
				place.width = max(8, floor(start.width + x - grabX + 0.5))
				place.left = start.left + (place.width - start.width) * (SHARE_X[place.point] or 0)
			end
			if start.height and resize == "both" then
				place.height = max(8, floor(start.height + y - grabY + 0.5))
				place.top = start.top + (place.height - start.height) * (SHARE_Y[place.point] or 0)
			end
			self.moving:Set(place)
		end
		self.sizeStop = Stop
		self.current = Current -- its place as it is now (the position window moves it)
		-- its place, followed: the position window's fields read it in their render
		self.followed = function()
			return self.moving:Get() or self.place:Get() or self.attributes.default:Get() or part.default
		end
		self.save = function(place)
			Save(self.placeId, place)
		end
		live[self.placeId] = self
		self.click = function(button)
			if button == "RightButton" then
				Save(self.placeId, nil)
			else
				Placing.selected:Set(self.placeId)
			end
		end
		-- its outline's place on the screen, for the others' snapping
		local id = self.placeId
		self.rect = function(l, t, w, h)
			local r = rects[id]
			if not r then
				r = {}
				rects[id] = r
			end
			r[1], r[2], r[3], r[4] = l, t, w, h
		end
	end,
	Render = function(game, self)
		local part = self.part
		local place = self.moving:Get() or self.place:Get() or self.attributes.default:Get() or part.default
		if not place then
			return
		end
		local placing = Placing.on:Get()
		local title = part.title
		local resize = part.resize
		local selected = placing and Placing.selected:Get() == self.placeId
		game.ui:Box(1, { attributes = {
			position = "fixed", anchor = { point = place.point, relativePoint = place.relativePoint or place.point },
			left = place.left or 0, top = place.top or 0,
			width = place.width or part.width, height = place.height or part.height,
		}, slots = { default = function(g)
			g.ui:Slot(2, "default")
			if placing then
				g.ui:Box(3, { attributes = {
					position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
					background = selected and SHADE_SELECTED or SHADE, border = selected and OUTLINE_SELECTED or OUTLINE,
					xAlign = "center", yAlign = "center", OnRect = self.rect,
					OnDragStart = self.dragStart, OnDrag = self.drag, OnDragStop = self.dragStop, OnClick = self.click,
				}, slots = { default = function(g2)
					g2.ui:Text(4, { attributes = { text = title or "", textColor = OUTLINE.color } })
					if resize then
						g2.ui:Box(5, { attributes = {
							position = "absolute", right = 0, bottom = 0, width = 16, height = 16,
							background = ns.Define.Theme.ctl.grip,
							OnDragStart = self.sizeStart, OnDrag = self.size, OnDragStop = self.sizeStop,
						} })
					end
				end } })
			end
		end } })
	end,
}

Placing.Part = PlacedPart -- drawn by game.ui:Placed (Draw.lua)

-- The position window («Положение»): the selected part's X and Y (its offsets from its anchor, UI units), typed or
-- nudged a unit at a time, «По умолчанию» and «Привязка». One of our windows (the library's Window: moved by its own
-- tab, where it's left kept in OrdaenCoreDB), on the dialog layer, mounted the first time the mode opens.

-- a value with the setting API the library's controls take (Get, Set, Valid, MaxLength, Label, Tip)
local function NumberField(axis, label, tip)
	local field = {}
	function field.Get()
		local part = live[Placing.selected:Get() or ""]
		local place = part and part.followed()
		return place and tostring(place[axis] or 0) or ""
	end
	function field.Peek()
		return field.Get()
	end
	function field.Set(_, text)
		local part = live[Placing.selected:Peek() or ""]
		local n = tonumber(text)
		if part and n then
			local place = part.current()
			place[axis] = floor(n + 0.5)
			part.save(place)
		end
	end
	function field.Valid(_, text)
		return tonumber(text) ~= nil
	end
	function field.MaxLength()
		return 6
	end
	function field.Label()
		return label
	end
	function field.Tip()
		return tip
	end
	return field
end

local function Nudge(axis, by)
	return function()
		local part = live[Placing.selected:Peek() or ""]
		if part then
			local place = part.current()
			place[axis] = place[axis] + by
			part.save(place)
		end
	end
end

local PositionWindow = {
	name = "placingWindow",
	Setup = function(_, self)
		local L = ns.L
		self.x = NumberField("left", L.PLACING_X, L.PLACING_X_TIP)
		self.y = NumberField("top", L.PLACING_Y, L.PLACING_Y_TIP)
		self.snap = {
			Get = function()
				return Placing.SnapOn()
			end,
			Peek = function()
				return Placing.SnapOn()
			end,
			Set = function(_, on)
				Placing.SetSnap(on)
			end,
			Label = function()
				return L.PLACING_SNAP
			end,
			Tip = function()
				return L.PLACING_SNAP_TIP
			end,
		}
		self.xLess, self.xMore = Nudge("left", -1), Nudge("left", 1)
		self.yLess, self.yMore = Nudge("top", -1), Nudge("top", 1)
		self.reset = function()
			local id = Placing.selected:Peek()
			if id then
				Save(id, nil)
			end
		end
		self.close = function()
			Placing.selected:Set(nil)
		end
		self.window = Placing.window
	end,
	Render = function(game, self)
		local id = Placing.on:Get() and Placing.selected:Get()
		local part = id and declared[id]
		if not part then
			return
		end
		local L = ns.L
		game.ui:Window(1, { attributes = { title = part.title, window = self.window, minWidth = 300, minHeight = 150,
			OnClose = self.close }, slots = { default = function(g)
			g.ui:Box(2, { attributes = { columns = { "1fr", "auto", "auto" }, gap = 6, yAlign = "center" },
				slots = { default = function(g2)
				g2.ui:Input(3, { attributes = { value = self.x } })
				g2.ui:PushButton(4, { attributes = { label = "−", width = 30, OnClick = self.xLess } })
				g2.ui:PushButton(5, { attributes = { label = "+", width = 30, OnClick = self.xMore } })
				g2.ui:Input(6, { attributes = { value = self.y } })
				g2.ui:PushButton(7, { attributes = { label = "−", width = 30, OnClick = self.yLess } })
				g2.ui:PushButton(8, { attributes = { label = "+", width = 30, OnClick = self.yMore } })
			end } })
			g.ui:Checkbox(9, { attributes = { value = self.snap } })
			g.ui:PushButton(10, { attributes = { label = L.PLACING_RESET, width = 160, OnClick = self.reset } })
		end } })
	end,
}

-- the module the position window draws in: Ordaen Core's own, its components from the library
local mounted = false
function Placing.MountWindow()
	if mounted or not ns.App.Library() then -- its controls are the library's
		return
	end
	mounted = true
	local store = ns.Globals.store
	Placing.window = ns.NewWindow(store, "placing", { width = 380, height = 170 })
	-- its close button (and Escape) closes through the window: the selection goes with it
	Placing.window:Guard(function()
		Placing.selected:Set(nil)
		return true
	end)
	local module = { name = "OrdaenCore", ns = {}, db = store.db, charDb = store.charDb, Import = function()
		return nil
	end }
	ns.Engine:Mount(nil, PositionWindow, 0, {}, Game.Layer.Dialog, module, Game.ForModule(module))
end
