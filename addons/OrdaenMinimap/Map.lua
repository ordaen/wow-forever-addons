-- The square minimap: mask, hiding the round Blizzard pieces, mouse-wheel zoom, border and size.
-- Forever uses the modern minimap code, so frame names differ from classic; every Blizzard piece is
-- looked up by several possible names and skipped when missing (the debug log records what was found).
local _, ns = ...

local Map = {}
ns.Map = Map

local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"

-- Round decorations that make no sense on a square map. Each entry: possible names, first found wins.
local ROUND_PIECES = {
	{ "MinimapBorder" },
	{ "MinimapCompassTexture" },
	{ "MinimapCompassTextureUnderlay" },
	{ "MinimapNorthTag" },
	{ "Minimap.ZoomIn", "MinimapZoomIn" },
	{ "Minimap.ZoomOut", "MinimapZoomOut" },
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
		if object then
			return object, name
		end
	end
	return nil, nil
end

Map.found = {} -- name -> true/false, for /om dump

local hiddenHooked = {}

--- Hide a Blizzard piece and keep it hidden when Blizzard code shows it again.
local function keepHidden(object)
	object:Hide()
	if not hiddenHooked[object] and object.Show then
		hiddenHooked[object] = true
		hooksecurefunc(object, "Show", function(self)
			self:Hide()
		end)
	end
end

local function hideRoundPieces()
	for _, names in ipairs(ROUND_PIECES) do
		local object, name = findFirst(names)
		Map.found[names[1]] = name or false
		if object then
			keepHidden(object)
		end
	end
end

local function applyMask()
	Minimap:SetMaskTexture(SQUARE_MASK)
	-- Quest/archaeology/task areas are drawn with a round ring by default; on a square map the
	-- ring shows as a circle cut by the corners.
	for _, method in ipairs({ "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }) do
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
		zoom = math.max(0, math.min(self:GetZoomLevels() - 1, zoom))
		self:SetZoom(zoom)
	end)
end

local border

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
	if not style.backdrop then
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
	border:SetBackdrop(style.backdrop)
	local rgb = ns.ResolveBorderColor(style, db.borderColor, classRGB())
	if rgb then
		border:SetBackdropBorderColor(rgb[1], rgb[2], rgb[3], 1)
	else
		border:SetBackdropBorderColor(1, 1, 1, 1)
	end
	border:Show()
end

local function applyScale(db)
	Minimap:SetScale(db.scale)
end

-- Called by Blizzard's minimap config code (rotation on/off, layout); undo what it resets.
local function reapplyShape()
	applyMask()
	hideRoundPieces()
end

local setUp = false

--- Make the minimap square and apply the saved look. Safe to call again after a setting changes.
---@param db table OrdaenMinimapDB
function Map.Apply(db)
	ns.Debug.Call(function()
		if not setUp then
			setUp = true
			enableWheelZoom()
			-- Other addons (LibDBIcon and friends) ask this to place buttons on the map's edge.
			function GetMinimapShape()
				return "SQUARE"
			end
			if MinimapCluster and MinimapCluster.UpdateMinimapConfig then
				hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", reapplyShape)
			end
		end
		reapplyShape()
		applyBorder(db)
		applyScale(db)
		ns.Debug.Logf("Map.Apply style=%s color=%s scale=%s", db.borderStyle, db.borderColor, db.scale)
	end)
end

--- What /om dump records about the map.
function Map.Describe()
	return {
		found = Map.found,
		border = border,
		minimap = Minimap,
	}
end
