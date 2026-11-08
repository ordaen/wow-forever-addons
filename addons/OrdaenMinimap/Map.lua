-- The square minimap: mask, hiding Blizzard's round pieces (and the ones Info.lua replaces),
-- mouse-wheel zoom, border and size.
-- Forever uses the modern minimap code, so frame names differ from classic; every Blizzard piece is
-- looked up by several possible names and skipped when missing (the debug log records what was found).
--
-- Ownership guard: everything we change is changed inside `withApplying`. Hooks on those methods
-- report any change made outside it to Map.onForeignChange(what, stack), which Guard.lua uses to
-- find conflicting addons. Blizzard's own changes (rotation toggle etc.) are simply re-applied.
local addonName, ns = ...

local Map = {}
ns.Map = Map

local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"

-- Blizzard pieces we hide, by their names on Forever (checked against the API dump in api/forever/).
-- Each entry: possible names, first found wins. Some load later (the clock comes with
-- Blizzard_TimeManager), so missing ones are looked for again when a Blizzard addon loads.
local HIDDEN_PIECES = {
	-- Round decorations that make no sense on a square map.
	{ "MinimapCompassTexture" },
	{ "MinimapCompassTextureUnderlay" },
	{ "Minimap.ZoomIn" },
	{ "Minimap.ZoomOut" },
	-- Shown by Info.lua instead: zone text, clock, calendar button (our clock opens it), day/night icon, and
	-- Blizzard's own coordinates (MinimapPlayerCoordsMixin exists; the frame is deeper than the dump goes).
	{ "MinimapCluster.ZoneTextButton" },
	{ "TimeManagerClockButton" },
	{ "GameTimeFrame" },
	{ "MinimapCluster.DielFrame" },
	{ "MinimapCluster.MinimapContainer.PlayerCoords" },
}

--- Resolve "A.B.C" through _G; nil when any part is missing.
local function resolve(path)
	local value = _G
	for part in path:gmatch("[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

local function findFirst(names)
	for _, name in ipairs(names) do
		local object = resolve(name)
		if type(object) == "table" then -- frames are tables; anything else is not what we look for
			return object, name
		end
	end
	return nil, nil
end
ns.FindFirst = findFirst

Map.found = {} -- name -> found name or false, for the dev-mode dump
Map.active = false -- true while we own the minimap's look (false = stepped aside for a conflict)
Map.onForeignChange = nil -- function(what, stack), set by Guard.lua

local applying = false

local function withApplying(fn)
	local was = applying
	applying = true
	local ok, err = pcall(fn)
	applying = was
	if not ok then
		error(err, 0)
	end
end

-- debugstack() is expensive, and some foreign calls repeat (Blizzard re-shows the zoom buttons on every
-- hover; an addon we override may re-set the mask every frame). Attribute each kind of change at most
-- once per second; the re-apply after the hook still runs every time.
local ATTRIBUTION_INTERVAL = 1
local lastAttribution = {}

--- Called from our hooks: someone changed `what` outside our own code.
local function foreignChange(what)
	if applying or not Map.active or not Map.onForeignChange then
		return
	end
	local now = GetTime()
	local last = lastAttribution[what]
	if last and now - last < ATTRIBUTION_INTERVAL then
		return
	end
	lastAttribution[what] = now
	Map.onForeignChange(what, debugstack(3))
end

local hooked = {}

--- Watch object:method; report calls that aren't ours. `after` runs on every foreign call.
local function guard(object, method, what, after)
	local key = tostring(object) .. method
	if hooked[key] or not object[method] then
		return
	end
	hooked[key] = true
	hooksecurefunc(object, method, function(self)
		if applying or not Map.active then
			return
		end
		foreignChange(what)
		if after and Map.active then
			after(self)
		end
	end)
end

local hiddenPieces = {}

-- Hook bodies run on every foreign call (some on every hover), so they are plain functions that
-- create no closures or tables.
local function rehide(self)
	applying = true
	self:Hide()
	applying = false
end

local hiddenDone = {} -- entry -> true once found and hidden

local function hidePieces()
	for _, names in ipairs(HIDDEN_PIECES) do
		local object, name
		if not hiddenDone[names] then
			object, name = findFirst(names)
			Map.found[names[1]] = name or false
		end
		if object then
			hiddenDone[names] = true
			hiddenPieces[#hiddenPieces + 1] = object
			object:Hide()
			-- Blizzard re-shows some of these (hover, config updates); keep them hidden.
			guard(object, "Show", "show " .. name, rehide)
		end
	end
end

-- Quest/archaeology/task areas are drawn with a round ring by default; on a square map the ring
-- shows as a circle cut by the corners.
local BLOB_RING_METHODS = { "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }

local function applyMask()
	Minimap:SetMaskTexture(SQUARE_MASK)
	for _, method in ipairs(BLOB_RING_METHODS) do
		if Minimap[method] then
			Minimap[method](Minimap, 0)
		end
	end
	local hybrid = _G.HybridMinimap
	if hybrid and hybrid.MapCanvas and hybrid.CircleMask then
		hybrid.MapCanvas:SetUseMaskTexture(false)
		hybrid.CircleMask:SetTexture(SQUARE_MASK)
		hybrid.MapCanvas:SetUseMaskTexture(true)
	end
end

local function enableWheelZoom()
	-- Newer Blizzard minimaps zoom with the wheel already; only add it when missing.
	if Minimap:GetScript("OnMouseWheel") then
		Map.found.wheelZoom = "blizzard"
		return
	end
	Map.found.wheelZoom = "ours"
	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", function(self, delta)
		local zoom = self:GetZoom() + (delta > 0 and 1 or -1)
		local levels = self.GetZoomLevels and self:GetZoomLevels() or 6
		zoom = math.max(0, math.min(levels - 1, zoom))
		self:SetZoom(zoom)
	end)
end

local border
local frameTexture -- for styles drawn as one texture over the whole border frame

local function classRGB()
	local _, class = UnitClass("player")
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if color then
		return { color.r, color.g, color.b }
	end
	return nil
end

local function applyBorder(db)
	local style = ns.GetBorderStyle(db.borderStyle)
	if not style.backdrop and not style.frame then
		if border then
			border:Hide()
		end
		return
	end
	if not border then
		border = CreateFrame("Frame", "OrdaenMinimapBorder", Minimap, "BackdropTemplate")
		border:SetFrameLevel(Minimap:GetFrameLevel() + 5)
		border:EnableMouse(false)
	end
	local outset = style.outset or 0
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -outset, outset)
	border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", outset, -outset)
	local rgb = ns.ResolveBorderColor(style, db.borderColor, classRGB())
	local r, g, b = 1, 1, 1
	if rgb then
		r, g, b = rgb[1], rgb[2], rgb[3]
	end
	if style.frame then
		-- One texture stretched over the whole frame: details (chips, scratches) don't repeat.
		border:SetBackdrop(nil)
		if not frameTexture then
			frameTexture = border:CreateTexture(nil, "OVERLAY")
			frameTexture:SetAllPoints(border)
		end
		frameTexture:SetTexture(style.frame.file)
		frameTexture:SetVertexColor(r, g, b, 1)
		frameTexture:Show()
	else
		if frameTexture then
			frameTexture:Hide()
		end
		border:SetBackdrop(style.backdrop)
		border:SetBackdropBorderColor(r, g, b, 1)
	end
	border:Show()
end

local function ourShape()
	return "SQUARE"
end
Map.ShapeFunction = ourShape

local currentDb
local setUp = false

local function applyShapeNow()
	applyMask()
	for _, piece in ipairs(hiddenPieces) do
		piece:Hide()
	end
end

local function reapplyShape()
	if not Map.active then
		return
	end
	withApplying(applyShapeNow)
end

local function rescale()
	applying = true
	Minimap:SetScale(currentDb.scale)
	applying = false
end

local function setUpOnce()
	if setUp then
		return
	end
	setUp = true
	enableWheelZoom()
	hidePieces()
	-- Blizzard's minimap config code (rotation on/off, layout) resets the mask and sizes.
	if MinimapCluster and MinimapCluster.UpdateMinimapConfig then
		hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", reapplyShape)
	end
	-- Anyone else setting these is either Blizzard (re-apply) or a conflicting addon (Guard decides).
	guard(Minimap, "SetMaskTexture", "mask", reapplyShape)
	guard(Minimap, "SetScale", "scale", rescale)
end

--- Make the minimap square and apply the saved look. Safe to call again after a setting changes.
---@param db table OrdaenMinimapDB
function Map.Apply(db)
	currentDb = db
	ns.Debug:Call(function()
		Map.active = true
		withApplying(function()
			setUpOnce()
			-- Other addons (LibDBIcon and friends) ask this to place buttons on the map's edge.
			GetMinimapShape = ourShape
			applyMask()
			for _, piece in ipairs(hiddenPieces) do
				piece:Hide()
			end
			applyBorder(db)
			Minimap:SetScale(db.scale)
		end)
		ns.Debug:Logf("Map.Apply style=%s color=%s scale=%s", db.borderStyle, db.borderColor, db.scale)
	end)
end

--- Look again for Blizzard pieces that weren't there yet (call when a Blizzard addon loads).
function Map.RetryHidden()
	if setUp and Map.active then
		withApplying(hidePieces)
	end
end

--- Stop owning the minimap (a conflict the user hasn't resolved). Our border goes away; the rest
--- (mask, hidden pieces) is left to the other addon, and a /reload restores Blizzard's look.
function Map.StepAside()
	Map.active = false
	if border then
		border:Hide()
	end
	if GetMinimapShape == ourShape then
		-- Blizzard leaves it undefined; other addons check for nil (the API dump typed it as a function).
		---@diagnostic disable-next-line: assign-type-mismatch
		GetMinimapShape = nil
	end
	ns.Debug:Log("Map.StepAside")
end

--- Differences between what we applied and what the minimap shows now (for the delayed check).
---@return table list of short descriptions, empty when everything is as we left it
function Map.Verify()
	local problems = {}
	if not Map.active or not currentDb then
		return problems
	end
	if GetMinimapShape ~= ourShape then
		problems[#problems + 1] = "GetMinimapShape"
	end
	local scale = Minimap:GetScale()
	if scale and math.abs(scale - currentDb.scale) > 0.001 then
		problems[#problems + 1] = "scale"
	end
	for _, piece in ipairs(hiddenPieces) do
		if piece:IsShown() then
			problems[#problems + 1] = "shown " .. (piece.GetName and piece:GetName() or "?")
		end
	end
	return problems
end

--- What the dev-mode dump records about the map.
function Map.Describe()
	return {
		active = Map.active,
		found = Map.found,
		border = border,
		minimap = Minimap,
		addon = addonName,
	}
end
