-- The placing mode («Режим перемещения»; design action-bars/index.md «Moving belongs to Ordaen Core», placement.md):
-- every free Ordaen part (the action bars, the micro menu and status bars off the bottom panel, ...) is drawn with
--   game.ui:Placed(site, nil, { attributes = { title = L.KEY, default = { point, relativePoint, left, top },
--                                             width = n, height = n, resize = "width" | "both" | nil }, slots = ... }, key)
-- at its saved place, or `default` (which may be bound, so a part never moved follows the panel). Its id is the
-- drawing component's path and the call's key (OrdaenPanel.module#statusBars): nobody types it. Saved places are
-- { point, relativePoint, left, top, width?, height? } in UI units (they hold at every scale), account-wide in
-- OrdaenCoreDB.placed; a part never moved stores nothing.
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
	self.on:Set(true)
	return true
end

function Placing:Exit()
	self.on:Set(false)
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

-- A free part: its place, its content, and while placing, the outline over it.
local PlacedPart = {
	name = "placed",
	Setup = function(_, self)
		local owner = self._slotOwner or self._parent
		local declaration = owner and owner._declaration
		local module = owner and owner.module
		local key = self._key
		self.placeId = (module and module.name or "?") .. "." .. (declaration and declaration.name or "?")
			.. (owner and owner._key ~= nil and ("#" .. tostring(owner._key)) or "")
			.. (key ~= nil and ("#" .. tostring(key)) or "")
		self.place = PlaceOf(self.placeId)
		self.moving = ns.NewValue(nil) -- the place while a drag or resize runs; saved on drop
		local start, grabX, grabY
		local function Current()
			local place = self.moving:Peek() or self.place:Peek() or self.attributes.default:Peek()
			return {
				point = place.point, relativePoint = place.relativePoint or place.point, left = place.left or 0,
				top = place.top or 0, width = place.width or self.attributes.width:Peek(),
				height = place.height or self.attributes.height:Peek(),
			}
		end
		local function Begin(x, y)
			start, grabX, grabY = Current(), x, y
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
			place.left = floor(start.left + x - grabX + 0.5)
			place.top = floor(start.top + y - grabY + 0.5)
			self.moving:Set(place)
		end
		self.dragStop = Stop
		self.sizeStart = Begin
		self.size = function(x, y)
			local resize = self.attributes.resize:Peek()
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
		self.click = function(button)
			if button == "RightButton" then
				Save(self.placeId, nil)
			end
		end
	end,
	Render = function(game, self)
		local place = self.moving:Get() or self.place:Get() or self.attributes.default:Get()
		if not place then
			return
		end
		local placing = Placing.on:Get()
		local title = self.attributes.title:Get()
		local resize = self.attributes.resize:Get()
		game.ui:Box(1, { attributes = {
			position = "fixed", anchor = { point = place.point, relativePoint = place.relativePoint or place.point },
			left = place.left or 0, top = place.top or 0,
			width = place.width or self.attributes.width:Get(), height = place.height or self.attributes.height:Get(),
		}, slots = { default = function(g)
			g.ui:Slot(2, "default")
			if placing then
				g.ui:Box(3, { attributes = {
					position = "absolute", left = 0, top = 0, right = 0, bottom = 0, background = SHADE,
					border = OUTLINE, xAlign = "center", yAlign = "center",
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
