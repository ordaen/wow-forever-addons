-- OpenMap's public API (`OpenMapAPI`, docs/api.md) and Blizzard's `WorldMapFrame`, read for Ordaen Map (declared in
-- openMap.d.luna). Nothing is written to Blizzard's map: its scripts are hooked, never replaced, and no size, point
-- or attribute of it is set (a value an addon writes into the panel's code taints closing the map in a fight).
local name = ...

local openMap = {}

local function api()
	local found = _G.OpenMapAPI
	if type(found) == "table" and found.major == 1 and type(found.version) == "number" and found.version >= 4 then
		return found
	end
	return nil
end

function openMap.present()
	return api() ~= nil
end

local function worldMap()
	local frame = _G.WorldMapFrame
	if type(frame) == "table" and frame.GetCanvas then return frame end
	return nil
end

function openMap.canvas()
	local map = worldMap()
	return map and map:GetCanvas() or nil
end

function openMap.shownMap()
	local map = worldMap()
	if not map or not map:IsShown() then return 0 end
	return map:GetMapID() or 0
end

function openMap.stitched()
	local found = api()
	return found ~= nil and found.IsStitched() == true
end

function openMap.canvasOf(map, x, y)
	local found = api()
	local shown = openMap.shownMap()
	if not found or shown == 0 then return nil, nil end
	local u, v = found.WorldFromMap(map, x, y)
	if not u or not v then return nil, nil end
	return found.MapFromWorld(shown, u, v)
end

function openMap.artTop()
	local found = api()
	return found and found.ArtTopLevel() or 0
end

-- The one listener, and whether the hooks are in place: a hook can't be taken off, so it calls whoever listens now.
local listener = nil
local hooked = false
local owner = {}

local function heard()
	if listener then listener() end
end

function openMap.listen(run)
	listener = run
	local map = worldMap()
	if map and not hooked then
		hooked = true
		map:HookScript("OnShow", heard)
		map:HookScript("OnHide", heard)
		hooksecurefunc(map, "OnMapChanged", heard)
	end
	local found = api()
	if found then
		found.RegisterCallback(owner, "OpenMap_ViewChanged", heard)
		found.RegisterCallback(owner, "OpenMap_StitchedChanged", heard)
	end
end

function openMap.forget()
	listener = nil
	local found = api()
	if found then found.UnregisterAllCallbacks(owner) end
end

function openMap.menuToggle(id, label, get, set)
	local found = api()
	if not found then return end
	found.RegisterMenuToggle(name, { id = id, label = label, get = get, set = set, tab = "show", section = "Ordaen" })
end

function openMap.tip(owner, lines)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	for i, line in ipairs(lines) do
		if i == 1 then
			GameTooltip:AddLine(line, 1, 1, 1)
		else
			GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
		end
	end
	GameTooltip:Show()
end

function openMap.untip()
	GameTooltip:Hide()
end

LunaType.addon(name)["openMap"] = openMap
