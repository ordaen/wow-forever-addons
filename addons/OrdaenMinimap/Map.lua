-- The square minimap: mask, hiding the round Blizzard pieces, mouse-wheel zoom, border and size.
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

--- Called from our hooks: someone changed `what` outside our own code.
local function foreignChange(what)
	if applying or not Map.active then
		return
	end
	if Map.onForeignChange then
		Map.onForeignChange(what, debugstack(3))
	end
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

local function hideRoundPieces()
	for _, names in ipairs(ROUND_PIECES) do
		local object, name = findFirst(names)
		Map.found[names[1]] = name or false
		if object then
			hiddenPieces[#hiddenPieces + 1] = object
			object:Hide()
			-- Blizzard re-shows some of these (hover, config updates); keep them hidden.
			guard(object, "Show", "show " .. name, function(self)
				withApplying(function()
					self:Hide()
				end)
			end)
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

local function ourShape()
	return "SQUARE"
end
Map.ShapeFunction = ourShape

local currentDb
local setUp = false

local function reapplyShape()
	if not Map.active then
		return
	end
	withApplying(function()
		applyMask()
		for _, piece in ipairs(hiddenPieces) do
			piece:Hide()
		end
	end)
end

local function setUpOnce()
	if setUp then
		return
	end
	setUp = true
	enableWheelZoom()
	hideRoundPieces()
	-- Blizzard's minimap config code (rotation on/off, layout) resets the mask and sizes.
	if MinimapCluster and MinimapCluster.UpdateMinimapConfig then
		hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", reapplyShape)
	end
	-- Anyone else setting these is either Blizzard (re-apply) or a conflicting addon (Guard decides).
	guard(Minimap, "SetMaskTexture", "mask", function()
		reapplyShape()
	end)
	guard(Minimap, "SetScale", "scale", function()
		withApplying(function()
			Minimap:SetScale(currentDb.scale)
		end)
	end)
end

--- Make the minimap square and apply the saved look. Safe to call again after a setting changes.
---@param db table OrdaenMinimapDB
function Map.Apply(db)
	currentDb = db
	ns.Debug.Call(function()
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
		ns.Debug.Logf("Map.Apply style=%s color=%s scale=%s", db.borderStyle, db.borderColor, db.scale)
	end)
end

--- Stop owning the minimap (a conflict the user hasn't resolved). Our border goes away; the rest
--- (mask, hidden pieces) is left to the other addon, and a /reload restores Blizzard's look.
function Map.StepAside()
	Map.active = false
	if border then
		border:Hide()
	end
	if GetMinimapShape == ourShape then
		GetMinimapShape = nil
	end
	ns.Debug.Log("Map.StepAside")
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
