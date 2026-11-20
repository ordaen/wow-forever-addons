-- Blizzard's `WorldMapFrame`, the frame OpenMap hosts in, read for Ordaen Map (declared in worldMap.d.luna). Nothing is
-- written to Blizzard's map: its scripts are hooked, never replaced, and no size, point or attribute of it is set (a
-- value an addon writes into the panel's code taints closing the map in a fight).
local name = ...

local worldMap = {}
-- The client's globals as the runtime reads them (the game's `_G`).
local client = LunaType.client

local function frame()
	local found = client.WorldMapFrame
	if type(found) == "table" and found.GetCanvas then return found end
	return nil
end

function worldMap.canvas()
	local map = frame()
	return map and map:GetCanvas() or nil
end

function worldMap.shownMap()
	local map = frame()
	if not map or not map:IsShown() then return 0 end
	return map:GetMapID() or 0
end

-- The one listener, and whether the hooks are in place: a hook can't be taken off, so it calls whoever listens now.
local listener = nil
local hooked = false

local function heard()
	if listener then listener() end
end

function worldMap.listen(run)
	listener = run
	local map = frame()
	if map and not hooked then
		hooked = true
		map:HookScript("OnShow", heard)
		map:HookScript("OnHide", heard)
		client.hooksecurefunc(map, "OnMapChanged", heard)
	end
end

function worldMap.forget()
	listener = nil
end

function worldMap.tip(owner, lines)
	client.GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	for i, line in ipairs(lines) do
		if i == 1 then
			client.GameTooltip:AddLine(line, 1, 1, 1)
		else
			client.GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
		end
	end
	client.GameTooltip:Show()
end

function worldMap.untip()
	client.GameTooltip:Hide()
end

LunaType.addon(name)["worldMap"] = worldMap
