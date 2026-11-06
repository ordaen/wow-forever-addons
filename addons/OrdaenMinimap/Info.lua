-- Text around the minimap, outside the border: the zone name above it, coordinates and the clock below.
-- They replace Blizzard's zone text, clock and calendar button (hidden in Map.lua). A click on the clock
-- opens the calendar, a right-click the clock settings, a click on the zone name the world map.
-- All three are OrdaenCore.UI components; their tooltips are UI tooltip objects.
--
-- Cost: nothing runs per frame. The zone updates on zone events. Coordinates and the clock tick once a second on
-- the Core's shared ticker; while the player moves, coordinates also tick every 0.1 s. Both stop with the feature.
-- Coordinates come from UnitPosition (numbers only) and the map's world rectangle (read once per zone), and
-- are drawn as format + args (WoW's SetFormattedText), so ticking creates no tables or strings; the components
-- are redrawn only when the shown value changes.
local _, ns = ...

local Info = {}
ns.Info = Info

local L = ns.L
local UI = OrdaenCore.UI
local SLOW, FAST = 1, 0.1
local TEXT_GAP = 2

local PVP_COLORS = {
	sanctuary = { 0.41, 0.8, 0.94 },
	arena = { 1, 0.1, 0.1 },
	combat = { 1, 0.1, 0.1 },
	hostile = { 1, 0.1, 0.1 },
	friendly = { 0.1, 1, 0.1 },
	contested = { 1, 0.7, 0 },
}
local INVITES_COLOR = { 1, 0.5, 0.1 }

local db
local zone, coords, clock -- OrdaenCore.UI components, made on the first Apply
local active = false

-- Blocks and tooltips: built once; only fields change. ------------------------------------------

local zoneLabel = { text = "", style = "normal" }
-- Tooltips beside what they describe have no title (CLAUDE.md, "Tooltips"). The zone tooltip says the zone
-- (in its PvP colour) and the subzone: the label on the map often shows only one of them.
local zoneName = { text = "", style = "value" }
local subzoneName = { text = "", style = "label" }
local zoneTooltip = UI.Tooltip({
	zoneName,
	subzoneName,
	{ text = L.ZONE_TOOLTIP_MAP, style = "hint" },
}, { side = "below" })

local coordValue = { format = "%.1f, %.1f", args = { 0, 0 }, style = "small", hidden = true }

local CLOCK_24, CLOCK_12 = "%02d:%02d", "%d:%02d %s"
local clockValue = { format = CLOCK_24, args = { 0, 0, "" }, style = "small" }
-- The clock tooltip: local and realm time side by side (Blizzard's own translated labels), invites, hints.
local localTime = { format = CLOCK_24, args = { 0, 0, "" }, style = "value", align = "right" }
local realmTime = { format = CLOCK_24, args = { 0, 0, "" }, style = "value", align = "right" }
local invitesLine = { text = L.CALENDAR_PENDING, color = INVITES_COLOR, colSpan = 2, hidden = true }
local clockTooltip = UI.Tooltip({
	{
		columns = { "auto", "1fr" },
		gap = { "lg", "xs" },
		{ text = TIMEMANAGER_TOOLTIP_LOCALTIME, style = "label" },
		localTime,
		{ text = TIMEMANAGER_TOOLTIP_REALMTIME, style = "label" },
		realmTime,
		invitesLine,
	},
	{ separator = "rule" },
	{ text = L.TIME_TOOLTIP_CALENDAR, style = "hint" },
	{ text = L.TIME_TOOLTIP_CLOCK, style = "hint" },
}, { side = "below" })

-- Zone -----------------------------------------------------------------------------------------

local function updateZone()
	zoneLabel.text = GetMinimapZoneText() or ""
	local pvp = C_PvP.GetZonePVPInfo()
	local color = pvp and PVP_COLORS[pvp] or nil
	zoneLabel.color = color -- nil: the "normal" style's colour
	zone:Refresh()
	-- The tooltip's lines change with the zone, not on hover.
	zoneName.text = GetRealZoneText() or ""
	zoneName.color = color -- nil: the value style's colour
	subzoneName.text = GetSubZoneText() or ""
	subzoneName.hidden = subzoneName.text == "" or subzoneName.text == zoneName.text
	zoneTooltip:Refresh()
end

-- Coordinates ----------------------------------------------------------------------------------

local mapLeft, mapTop, mapWidth, mapHeight -- world rectangle of the player's map, nil when unknown
local lastWorldX, lastWorldY
local shownX, shownY

local function updateMapRect()
	mapLeft = nil
	lastWorldX = nil
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then
		return
	end
	-- Like HereBeDragons: the corner (0, 0) and the center, doubled (some maps clamp at 1).
	local _, corner = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
	local _, center = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0.5, 0.5))
	if not (corner and center) then
		return
	end
	local top, left = corner:GetXY()
	local midTop, midLeft = center:GetXY()
	local width, height = (left - midLeft) * 2, (top - midTop) * 2
	if width ~= 0 and height ~= 0 then
		mapLeft, mapTop, mapWidth, mapHeight = left, top, width, height
	end
	if ns.Debug:IsEnabled() then
		-- Check our math against Blizzard's once per zone (dev mode only).
		local pos = C_Map.GetPlayerMapPosition(mapID, "player")
		local wx, wy = UnitPosition("player")
		if pos and wx and mapLeft then
			ns.Debug:Logf("coords: map %d ours %.3f, %.3f blizzard %.3f, %.3f", mapID,
				(mapLeft - wy) / mapWidth, (mapTop - wx) / mapHeight, pos.x, pos.y)
		end
	end
end

local function showCoords(x, y)
	if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
		x, y = math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5) -- tenths of a percent
		if x ~= shownX or y ~= shownY then
			shownX, shownY = x, y
			coordValue.args[1], coordValue.args[2] = x / 10, y / 10
			coordValue.hidden = false
			coords:Refresh()
		end
	elseif shownX then
		shownX, shownY = nil, nil
		coordValue.hidden = true
		coords:Refresh()
	end
end

local function updateCoords()
	-- UnitPosition gives world X (north) then Y (west); nil in instances, where there are no coordinates.
	local wx, wy = UnitPosition("player")
	if not (wx and mapLeft) then
		lastWorldX = nil
		showCoords(nil)
		return
	end
	if wx == lastWorldX and wy == lastWorldY then
		return
	end
	lastWorldX, lastWorldY = wx, wy
	showCoords((mapLeft - wy) / mapWidth, (mapTop - wx) / mapHeight)
end

-- Clock ----------------------------------------------------------------------------------------

local shownLocal, shownRealm -- minutes shown, to redraw only when one changes
local cvarBool = C_CVar.GetCVarBool

-- Put hour:minute into a time element, 24-hour or AM/PM as Blizzard's clock settings say.
local function setTime(value, hour, minute, military)
	local args = value.args
	if military then
		value.format = CLOCK_24
		args[1], args[2], args[3] = hour, minute, ""
	else
		local h12 = hour % 12
		value.format = CLOCK_12
		args[1], args[2], args[3] = h12 == 0 and 12 or h12, minute, hour >= 12 and TIMEMANAGER_PM or TIMEMANAGER_AM
	end
end

local function updateClock()
	local now = time()
	local localKey = math.floor(now / 60)
	local realmHour, realmMinute = GetGameTime()
	local realmKey = realmHour * 60 + realmMinute
	if localKey == shownLocal and realmKey == shownRealm then
		return
	end
	shownLocal, shownRealm = localKey, realmKey
	local localHour, localMinute = tonumber(date("%H", now)), tonumber(date("%M", now))
	local military = cvarBool("timeMgrUseMilitaryTime") ~= false
	setTime(localTime, localHour, localMinute, military)
	setTime(realmTime, realmHour, realmMinute, military)
	-- The clock on the map shows the time Blizzard's clock settings pick: local or realm.
	if cvarBool("timeMgrUseLocalTime") then
		setTime(clockValue, localHour, localMinute, military)
	else
		setTime(clockValue, realmHour, realmMinute, military)
	end
	clock:Refresh() -- also redraws its tooltip, if shown
end

local function updateInvites()
	local pending = C_Calendar.GetNumPendingInvites() > 0
	clockValue.color = pending and INVITES_COLOR or nil
	invitesLine.hidden = not pending
	clock:Refresh() -- also redraws its tooltip, if shown
end

-- Ticking and events: on the "info" feature (Core.lua), so they run only while it is on. -------------

local moving = false
local fast -- ticker: coordinates every 0.1 s, only between PLAYER_STARTED_MOVING and PLAYER_STOPPED_MOVING

local function slowTick()
	updateCoords()
	updateClock()
end

local function onStartMoving()
	moving = true
	fast:Start()
end

local function onStopMoving()
	moving = false
	fast:Stop()
	updateCoords()
end

local function onZone()
	updateZone()
	updateMapRect()
	updateCoords()
end

local function onClockClick(_, mouseButton)
	if mouseButton == "RightButton" then
		TimeManager_Toggle()
	else
		ToggleCalendar()
	end
end

local function onZoneClick()
	ToggleWorldMap()
end

-- Once, on the feature's first start. All confirmed in api/forever/<CURRENT>/api.json; written out literally so
-- forever-lint checks them. The feature registers them while it is on and releases them when it goes off.
local function listen(feature)
	feature:On("ZONE_CHANGED", onZone)
	feature:On("ZONE_CHANGED_INDOORS", onZone)
	feature:On("ZONE_CHANGED_NEW_AREA", onZone)
	feature:On("PLAYER_ENTERING_WORLD", onZone)
	feature:On("PLAYER_STARTED_MOVING", onStartMoving)
	feature:On("PLAYER_STOPPED_MOVING", onStopMoving)
	feature:On("CALENDAR_UPDATE_PENDING_INVITES", updateInvites)
	feature:Every(SLOW, slowTick)
	fast = feature:Every(FAST, updateCoords)
	fast:Stop()
end

-- Components -----------------------------------------------------------------------------------

local function createComponents()
	local level = (Minimap:GetFrameLevel() or 1) + 6
	zone = UI.Button({ name = "OrdaenMinimapZone", parent = Minimap, level = level, tooltip = zoneTooltip, zoneLabel })
	coords = UI.Block({ name = "OrdaenMinimapCoords", parent = Minimap, level = level, coordValue })
	clock = UI.Button({ name = "OrdaenMinimapClock", parent = Minimap, level = level, tooltip = clockTooltip,
		clockValue })
	if not (zone and coords and clock) then
		return false -- OrdaenCore_UI can't load; the player was told
	end
	zone:On("click", onZoneClick)
	clock:On("click", onClockClick)
	return true
end

local function layout()
	local style = ns.GetBorderStyle(db.borderStyle)
	local outset = (style.backdrop or style.frame) and style.outset or 0
	local gap = outset + TEXT_GAP
	zone:ClearAllPoints()
	zone:SetPoint("BOTTOM", Minimap, "TOP", 0, gap)
	coords:ClearAllPoints()
	coords:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 2, -gap)
	clock:ClearAllPoints()
	clock:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", -2, -gap)
end

--- Start the texts: the "info" feature's OnEnable (creates them the first time).
---@param feature OrdaenFeature
---@param savedDb table OrdaenMinimapDB
function Info.Enable(feature, savedDb)
	db = savedDb
	if not zone then
		if not createComponents() then
			return
		end
		listen(feature)
	end
	active = true
	shownLocal, shownRealm = nil, nil
	Info.Apply(savedDb)
	updateZone()
	updateMapRect()
	updateInvites()
	slowTick()
end

--- Place the texts for the current settings (a setting changed: the border's size moves them).
---@param savedDb table OrdaenMinimapDB
function Info.Apply(savedDb)
	db = savedDb
	if not zone then
		return
	end
	layout()
	zone:Show()
	coords:Show()
	clock:Show()
end

--- Remove the texts: the feature's OnDisable (another minimap addon owns the map). Its events and tickers stop
--- with the feature.
function Info.Hide()
	if not zone then
		return
	end
	active = false
	moving = false
	zone:Hide()
	coords:Hide()
	clock:Hide()
end

--- What the dev-mode dump records.
function Info.Describe()
	return {
		active = active,
		moving = moving,
		mapRect = mapLeft and { mapLeft, mapTop, mapWidth, mapHeight } or false,
		zone = zone and zone.frame or false,
		clock = clock and clock.frame or false,
	}
end
