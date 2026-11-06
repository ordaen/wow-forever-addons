-- Text around the minimap, outside the border: the zone name above it, coordinates and the clock below.
-- They replace Blizzard's zone text, clock and calendar button (hidden in Map.lua). A click on the clock
-- opens the calendar, a right-click the clock settings, a click on the zone name the world map.
--
-- Cost: nothing runs per frame. The zone updates on zone events. Coordinates and the clock share one
-- 1-second timer chain; while the player moves, a second chain refreshes coordinates every 0.1 s.
-- Coordinates come from UnitPosition (numbers only) and the map's world rectangle (read once per zone),
-- so ticking creates no tables; the text is set with SetFormattedText and only when it changes.
local _, ns = ...

local Info = {}
ns.Info = Info

local L = ns.L
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
local NORMAL = { 1, 0.82, 0 }

local db
local zoneButton, zoneText, coordText, timeButton, timeText
local events
local active = false

-- Zone -----------------------------------------------------------------------------------------

local function updateZone()
	local text = GetMinimapZoneText and GetMinimapZoneText() or GetZoneText()
	zoneText:SetText(text or "")
	local pvp = GetZonePVPInfo and GetZonePVPInfo()
	local c = pvp and PVP_COLORS[pvp] or NORMAL
	zoneText:SetTextColor(c[1], c[2], c[3])
end

-- Coordinates ----------------------------------------------------------------------------------

local mapLeft, mapTop, mapWidth, mapHeight -- world rectangle of the player's map, nil when unknown
local useFallback = false -- no world rectangle API: ask C_Map every tick (creates a table each time)
local lastWorldX, lastWorldY
local shownX, shownY

local function updateMapRect()
	mapLeft = nil
	lastWorldX = nil
	local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not mapID then
		return
	end
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then
		useFallback = C_Map.GetPlayerMapPosition ~= nil
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
	if ns.Debug.IsEnabled() and C_Map.GetPlayerMapPosition then
		-- Check our math against Blizzard's once per zone (dev mode only).
		local pos = C_Map.GetPlayerMapPosition(mapID, "player")
		local wx, wy = UnitPosition("player")
		if pos and wx and mapLeft then
			ns.Debug.Logf("coords: map %d ours %.3f, %.3f blizzard %.3f, %.3f", mapID,
				(mapLeft - wy) / mapWidth, (mapTop - wx) / mapHeight, pos.x, pos.y)
		end
	end
end

local function showCoords(x, y)
	if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
		x, y = math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5) -- tenths of a percent
		if x ~= shownX or y ~= shownY then
			shownX, shownY = x, y
			coordText:SetFormattedText("%.1f, %.1f", x / 10, y / 10)
		end
	elseif shownX then
		shownX, shownY = nil, nil
		coordText:SetText("")
	end
end

local function updateCoords()
	if useFallback then
		local mapID = C_Map.GetBestMapForUnit("player")
		local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
		showCoords(pos and pos.x, pos and pos.y)
		return
	end
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

local shownMinute
local pendingInvites = false

local function cvarBool(name)
	if C_CVar and C_CVar.GetCVarBool then
		return C_CVar.GetCVarBool(name)
	elseif GetCVarBool then
		return GetCVarBool(name)
	end
	return nil
end

local function updateClock()
	-- Blizzard's clock settings: local or realm time, 24-hour or AM/PM.
	local hour, minute
	if cvarBool("timeMgrUseLocalTime") or not GetGameTime then
		local now = time()
		local key = math.floor(now / 60)
		if key == shownMinute then
			return
		end
		shownMinute = key
		hour, minute = tonumber(date("%H", now)), tonumber(date("%M", now))
	else
		hour, minute = GetGameTime()
		local key = hour * 60 + minute
		if key == shownMinute then
			return
		end
		shownMinute = key
	end
	if cvarBool("timeMgrUseMilitaryTime") == false then
		local suffix = hour >= 12 and (TIMEMANAGER_PM or "PM") or (TIMEMANAGER_AM or "AM")
		local h12 = hour % 12
		timeText:SetFormattedText("%d:%02d %s", h12 == 0 and 12 or h12, minute, suffix)
	else
		timeText:SetFormattedText("%02d:%02d", hour, minute)
	end
end

local function updateInvites()
	pendingInvites = C_Calendar and C_Calendar.GetNumPendingInvites
		and C_Calendar.GetNumPendingInvites() > 0 or false
	if pendingInvites then
		timeText:SetTextColor(1, 0.5, 0.1)
	else
		timeText:SetTextColor(1, 1, 1)
	end
end

-- Ticking --------------------------------------------------------------------------------------

local moving = false
local fastRunning = false
local slowRunning = false

local function slowTick()
	if not active then
		slowRunning = false
		return
	end
	updateCoords()
	updateClock()
	C_Timer.After(SLOW, slowTick)
end

local function fastTick()
	if not (active and moving) then
		fastRunning = false
		return
	end
	updateCoords()
	C_Timer.After(FAST, fastTick)
end

local function startFast()
	moving = true
	if not fastRunning then
		fastRunning = true
		fastTick()
	end
end

-- Events ---------------------------------------------------------------------------------------

local function onEvent(_, event)
	if event == "PLAYER_STARTED_MOVING" then
		startFast()
	elseif event == "PLAYER_STOPPED_MOVING" then
		moving = false
		updateCoords()
	elseif event == "CALENDAR_UPDATE_PENDING_INVITES" then
		updateInvites()
	else -- zone changes, loading screens
		updateZone()
		updateMapRect()
		updateCoords()
	end
end

local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }
local OPTIONAL_EVENTS = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "CALENDAR_UPDATE_PENDING_INVITES" }

local function registerEvents()
	for _, event in ipairs(ZONE_EVENTS) do
		events:RegisterEvent(event)
	end
	local movingEvents = true
	for _, event in ipairs(OPTIONAL_EVENTS) do
		-- RegisterEvent errors on events a client doesn't have.
		local ok = pcall(events.RegisterEvent, events, event)
		if not ok and event ~= "CALENDAR_UPDATE_PENDING_INVITES" then
			movingEvents = false
		end
	end
	if not movingEvents then
		-- No movement events: refresh coordinates fast all the time (still a timer, not per frame).
		ns.Debug.Log("info: no movement events, coordinates tick every 0.1 s")
		startFast()
	end
end

local function unregisterEvents()
	events:UnregisterAllEvents()
end

-- Frames ---------------------------------------------------------------------------------------

local function tooltip(owner, ...)
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
	for i = 1, select("#", ...) do
		local line = select(i, ...)
		if line then
			GameTooltip:AddLine(line, 1, 1, 1)
		end
	end
	GameTooltip:Show()
end

local function hideTooltip()
	GameTooltip:Hide()
end

local function openCalendar()
	if ToggleCalendar then
		ToggleCalendar()
	elseif GameTimeFrame then
		GameTimeFrame:Click()
	end
end

local function createFrames()
	local level = (Minimap:GetFrameLevel() or 1) + 6

	zoneButton = CreateFrame("Button", "OrdaenMinimapZone", Minimap)
	zoneButton:SetFrameLevel(level)
	zoneButton:SetHeight(16)
	zoneText = zoneButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	zoneText:SetAllPoints()
	zoneText:SetWordWrap(false)
	zoneButton:SetScript("OnClick", function()
		if ToggleWorldMap then
			ToggleWorldMap()
		end
	end)
	zoneButton:SetScript("OnEnter", function(self)
		tooltip(self, GetRealZoneText and GetRealZoneText(), L.ZONE_TOOLTIP_MAP)
	end)
	zoneButton:SetScript("OnLeave", hideTooltip)

	coordText = Minimap:CreateFontString("OrdaenMinimapCoords", "OVERLAY", "GameFontHighlightSmall")
	coordText:SetJustifyH("LEFT")

	timeButton = CreateFrame("Button", "OrdaenMinimapClock", Minimap)
	timeButton:SetFrameLevel(level)
	timeButton:SetSize(60, 14)
	timeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	timeText = timeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	timeText:SetPoint("RIGHT")
	timeText:SetJustifyH("RIGHT")
	timeButton:SetScript("OnClick", ns.Debug.Wrap(function(_, mouseButton)
		if mouseButton == "RightButton" then
			if TimeManager_Toggle then
				TimeManager_Toggle()
			end
		else
			openCalendar()
		end
	end))
	timeButton:SetScript("OnEnter", function(self)
		tooltip(self, pendingInvites and L.CALENDAR_PENDING or nil, L.TIME_TOOLTIP_CALENDAR,
			TimeManager_Toggle and L.TIME_TOOLTIP_CLOCK or nil)
	end)
	timeButton:SetScript("OnLeave", hideTooltip)

	events = CreateFrame("Frame")
	events:SetScript("OnEvent", ns.Debug.Wrap(onEvent))
end

local function layout()
	local style = ns.GetBorderStyle(db.borderStyle)
	local outset = (style.backdrop or style.frame) and style.outset or 0
	local gap = outset + TEXT_GAP
	zoneButton:ClearAllPoints()
	zoneButton:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, gap)
	zoneButton:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, gap)
	coordText:ClearAllPoints()
	coordText:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 2, -gap)
	timeButton:ClearAllPoints()
	timeButton:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", -2, -gap)
end

--- Show the texts for the current settings (creates them the first time).
---@param savedDb table OrdaenMinimapDB
function Info.Apply(savedDb)
	db = savedDb
	if not zoneButton then
		createFrames()
	end
	layout()
	zoneButton:Show()
	coordText:Show()
	timeButton:Show()
	if not active then
		active = true
		registerEvents()
		shownMinute = nil
		updateZone()
		updateMapRect()
		updateInvites()
		if not slowRunning then
			slowRunning = true
			slowTick()
		end
	end
end

--- Remove the texts (another minimap addon owns the map).
function Info.Hide()
	if not zoneButton then
		return
	end
	active = false
	unregisterEvents()
	zoneButton:Hide()
	coordText:Hide()
	timeButton:Hide()
end

--- What the dev-mode dump records.
function Info.Describe()
	return {
		active = active,
		moving = moving,
		fallbackCoords = useFallback,
		mapRect = mapLeft and { mapLeft, mapTop, mapWidth, mapHeight } or false,
		zone = zoneButton,
		clock = timeButton,
	}
end
