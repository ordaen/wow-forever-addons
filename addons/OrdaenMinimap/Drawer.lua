-- Button drawer, WoW side: one small button on the minimap opens a grid with the other addons'
-- minimap buttons (collected the way MinimapButtonButton does) and the addon compartment entries.
-- Many addons place their buttons on a circle with their own math and ignore GetMinimapShape, so
-- on a square map the drawer is also what keeps them tidy.
local addonName, ns = ...

local Drawer = {}
ns.Drawer = Drawer

local L = ns.L
local SLOT, GAP, PAD = 32, 4, 6
local ENTRY_ICON = 22
local AUTO_CLOSE_DELAY = 1
local RESCAN_DELAYS = { 2, 10 }
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local db
local started = false
local mainButton, container
local collected = {} -- list of {frame, name, source}
local collectedSet = {}
local originals = {} -- frame -> its class methods (SetPoint etc.), which our no-ops on the instance hide
local pendingCombat = {}
local entryButtons = {} -- pool of our compartment entry buttons
local entries = {} -- current merged compartment entries
local blizzardCompartmentHooked = false

local function noop() end

local function debug()
	return ns.Debug
end

--- A frame's own class method, from its metatable (skips anything set on the instance).
local function classMethod(frame, name)
	local mt = getmetatable(frame)
	local index = mt and mt.__index
	if type(index) == "table" then
		return index[name]
	end
	return nil
end

-- Layout ---------------------------------------------------------------------------------------

local layoutQueued = false

local function shownItems()
	local items = {}
	for _, c in ipairs(collected) do
		if c.frame:IsShown() then
			items[#items + 1] = c.frame
		end
	end
	for i = 1, #entries do
		items[#items + 1] = entryButtons[i]
	end
	return items
end

local function place(frame, point, relativeTo, relativePoint, x, y)
	local m = originals[frame]
	if m then
		m.ClearAllPoints(frame)
		m.SetPoint(frame, point, relativeTo, relativePoint, x, y)
	else
		frame:ClearAllPoints()
		frame:SetPoint(point, relativeTo, relativePoint, x, y)
	end
end

function Drawer.Layout()
	layoutQueued = false
	if not container then
		return
	end
	local items = shownItems()
	-- Grow away from the screen edge the main button is closest to.
	local bx, by = mainButton:GetCenter()
	local growLeft = bx and bx > UIParent:GetWidth() / 2
	local growUp = by and by < UIParent:GetHeight() / 2
	local offsets, width, height = ns.DrawerGrid(#items, db.drawerColumns, SLOT, GAP, growLeft, growUp)

	local vertical = growUp and "BOTTOM" or "TOP"
	local horizontal = growLeft and "RIGHT" or "LEFT"
	local corner = vertical .. horizontal
	container:ClearAllPoints()
	container:SetPoint(corner, mainButton, (growUp and "TOP" or "BOTTOM") .. horizontal, 0, growUp and 2 or -2)
	container:SetSize(math.max(width, SLOT) + 2 * PAD, math.max(height, SLOT) + 2 * PAD)

	local sx = growLeft and -1 or 1
	local sy = growUp and 1 or -1
	for i, frame in ipairs(items) do
		local o = offsets[i]
		place(frame, "CENTER", container, corner, sx * (PAD + SLOT / 2) + o[1], sy * (PAD + SLOT / 2) + o[2])
	end
end

local function queueLayout()
	if layoutQueued then
		return
	end
	layoutQueued = true
	C_Timer.After(0, Drawer.Layout)
end

-- Collecting minimap buttons --------------------------------------------------------------------

local function collect(button, source)
	if collectedSet[button] or button == mainButton then
		return
	end
	if button.IsProtected and button:IsProtected() and InCombatLockdown() then
		pendingCombat[button] = source
		return
	end
	collectedSet[button] = true
	local methods = {}
	for _, name in ipairs({ "SetParent", "ClearAllPoints", "SetPoint", "SetScale" }) do
		methods[name] = classMethod(button, name) or button[name]
	end
	originals[button] = methods

	methods.SetParent(button, container)
	methods.SetScale(button, 1)
	if button.SetIgnoreParentScale then
		button:SetIgnoreParentScale(false)
	end
	button:SetFrameStrata(container:GetFrameStrata())
	button:SetFrameLevel(container:GetFrameLevel() + 2)
	if button.HasScript and button:HasScript("OnDragStart") then
		button:SetScript("OnDragStart", nil)
		button:SetScript("OnDragStop", nil)
	end
	-- Addons move their buttons back onto the minimap (some on every frame); ignore that.
	button.SetParent = noop
	button.ClearAllPoints = noop
	button.SetPoint = noop
	button.SetScale = noop
	hooksecurefunc(button, "Show", queueLayout)
	hooksecurefunc(button, "Hide", queueLayout)

	local name = button.GetName and button:GetName() or "?"
	collected[#collected + 1] = { frame = button, name = name, source = source }
	table.sort(collected, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	debug().Logf("drawer: collected %s (%s)", name, source)
	queueLayout()
end

local function libDBIcon()
	return LibStub and LibStub("LibDBIcon-1.0", true)
end

local function isCollectable(frame)
	if type(frame) ~= "table" or not frame.GetName or collectedSet[frame] then
		return false
	end
	local name = frame:GetName()
	if not ns.IsMinimapButtonName(name) then
		return false
	end
	-- Blizzard's own minimap frames are secure globals.
	if issecurevariable(_G, name) then
		return false
	end
	return not name:find("^Ordaen")
end

local function collectAll()
	local icon = libDBIcon()
	if icon and icon.GetButtonList then
		for _, name in ipairs(icon:GetButtonList()) do
			local button = icon:GetMinimapButton(name)
			if button then
				collect(button, "LibDBIcon")
			end
		end
	end
	for _, child in ipairs({ Minimap:GetChildren() }) do
		if isCollectable(child) then
			collect(child, "Minimap child")
		end
	end
end

-- Addon compartment entries ---------------------------------------------------------------------

local function tocEntries()
	local list = {}
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		local func = name and C_AddOns.IsAddOnLoaded(name) and C_AddOns.GetAddOnMetadata(name, "AddonCompartmentFunc")
		if func then
			list[#list + 1] = {
				addon = name,
				title = C_AddOns.GetAddOnMetadata(name, "Title") or name,
				icon = C_AddOns.GetAddOnMetadata(name, "IconTexture"),
				atlas = C_AddOns.GetAddOnMetadata(name, "IconAtlas"),
				func = func,
				onEnter = C_AddOns.GetAddOnMetadata(name, "AddonCompartmentFuncOnEnter"),
				onLeave = C_AddOns.GetAddOnMetadata(name, "AddonCompartmentFuncOnLeave"),
			}
		end
	end
	return list
end

local function runtimeEntries()
	local frame = _G.AddonCompartmentFrame
	return frame and frame.registeredAddons or {}
end

local function shownIconKeys()
	local keys = {}
	for _, c in ipairs(collected) do
		local object = ns.LibDBIconObjectName(c.name)
		if object and c.frame:IsShown() then
			keys[ns.CompartmentKey(object)] = true
		end
	end
	return keys
end

local function plainTooltip(owner, text)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:SetText(text or "?")
	GameTooltip:Show()
end

-- Clicks go straight to the other addon; its errors are its own (not wrapped in our debug kit).
local function entryOnClick(self, mouseButton)
	local item = entries[self.index]
	if not item then
		return
	end
	local e = item.entry
	if item.kind == "toc" then
		local fn = _G[e.func]
		if type(fn) == "function" then
			fn(e.addon, mouseButton, self)
		end
	elseif type(e.func) == "function" then
		e.func(self, { buttonName = mouseButton }, self)
	end
end

local function entryOnEnter(self)
	local item = entries[self.index]
	if not item then
		return
	end
	local e = item.entry
	if item.kind == "toc" then
		local fn = e.onEnter and _G[e.onEnter]
		if type(fn) == "function" then
			fn(e.addon, self)
			return
		end
		plainTooltip(self, e.title)
	elseif type(e.funcOnEnter) == "function" then
		e.funcOnEnter(self, e)
	else
		plainTooltip(self, e.text)
	end
end

local function entryOnLeave(self)
	local item = entries[self.index]
	local e = item and item.entry
	if item and item.kind == "toc" and e.onLeave and type(_G[e.onLeave]) == "function" then
		_G[e.onLeave](e.addon, self)
	elseif item and item.kind == "runtime" and type(e.funcOnLeave) == "function" then
		e.funcOnLeave(self, e)
	end
	GameTooltip:Hide()
end

local function entryButton(index)
	local button = entryButtons[index]
	if not button then
		button = CreateFrame("Button", nil, container)
		button:SetSize(SLOT - 4, SLOT - 4)
		button:RegisterForClicks("AnyUp")
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetSize(ENTRY_ICON, ENTRY_ICON)
		button.icon:SetPoint("CENTER")
		button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:SetScript("OnClick", entryOnClick)
		button:SetScript("OnEnter", entryOnEnter)
		button:SetScript("OnLeave", entryOnLeave)
		entryButtons[index] = button
	end
	button.index = index
	return button
end

local function refreshEntries()
	entries = ns.MergeCompartmentEntries(tocEntries(), runtimeEntries(), shownIconKeys())
	for i, item in ipairs(entries) do
		local button = entryButton(i)
		local e = item.entry
		local atlas = item.kind == "toc" and e.atlas or e.iconAtlas
		if atlas and button.icon.SetAtlas then
			button.icon:SetAtlas(atlas)
		else
			button.icon:SetTexture(e.icon or FALLBACK_ICON)
		end
		button:Show()
	end
	for i = #entries + 1, #entryButtons do
		entryButtons[i]:Hide()
	end
	debug().Logf("drawer: %d compartment entries", #entries)
end

-- Blizzard's compartment button -----------------------------------------------------------------

function Drawer.ApplyBlizzardCompartment()
	local frame = _G.AddonCompartmentFrame
	if not frame then
		return
	end
	if not blizzardCompartmentHooked then
		blizzardCompartmentHooked = true
		hooksecurefunc(frame, "Show", function(self)
			if db and db.hideBlizzardCompartment and started then
				self:Hide()
			end
		end)
	end
	if db.hideBlizzardCompartment and started then
		frame:Hide()
	else
		frame:Show()
	end
end

-- Main button and drawer frame ------------------------------------------------------------------

local function savePosition()
	local bx, by = mainButton:GetCenter()
	local mx, my = Minimap:GetCenter()
	if not (bx and mx) then
		return
	end
	local bs, ms = mainButton:GetEffectiveScale(), Minimap:GetEffectiveScale()
	db.drawerButton = { x = (bx * bs - mx * ms) / bs, y = (by * bs - my * ms) / bs }
end

function Drawer.PlaceMainButton()
	if not mainButton then
		return
	end
	mainButton:ClearAllPoints()
	local pos = db.drawerButton
	if pos then
		mainButton:SetPoint("CENTER", Minimap, "CENTER", pos.x, pos.y)
	else
		mainButton:SetPoint("CENTER", Minimap, "BOTTOMLEFT", 12, 12)
	end
end

function Drawer.Toggle()
	if not container then
		return
	end
	if container:IsShown() then
		container:Hide()
		return
	end
	collectAll()
	refreshEntries()
	Drawer.Layout()
	container:Show()
end

local function createFrames()
	container = CreateFrame("Frame", "OrdaenMinimapDrawer", UIParent, "BackdropTemplate")
	container:SetFrameStrata("MEDIUM")
	container:SetFrameLevel(20)
	container:SetClampedToScreen(true)
	container:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	container:SetBackdropColor(0, 0, 0, 0.85)
	container:Hide()
	table.insert(UISpecialFrames, "OrdaenMinimapDrawer") -- Escape closes it

	-- Close after the mouse has been away from the drawer and its button for a moment.
	local away = 0
	container:SetScript("OnShow", function()
		away = 0
	end)
	container:SetScript("OnUpdate", function(self, elapsed)
		if MouseIsOver(self) or MouseIsOver(mainButton) then
			away = 0
		else
			away = away + elapsed
			if away > AUTO_CLOSE_DELAY then
				self:Hide()
			end
		end
	end)

	mainButton = CreateFrame("Button", "OrdaenMinimapDrawerButton", UIParent)
	mainButton:SetSize(20, 20)
	mainButton:SetFrameStrata("MEDIUM")
	mainButton:SetFrameLevel(25)
	mainButton:SetClampedToScreen(true)
	mainButton:SetMovable(true)
	mainButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mainButton:RegisterForDrag("LeftButton")
	local icon = mainButton:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	mainButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

	mainButton:SetScript("OnClick", ns.Debug.Wrap(function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.Options.Open()
		else
			Drawer.Toggle()
		end
	end))
	mainButton:SetScript("OnDragStart", function(self)
		if IsShiftKeyDown() then
			self:StartMoving()
		end
	end)
	mainButton:SetScript("OnDragStop", ns.Debug.Wrap(function(self)
		self:StopMovingOrSizing()
		savePosition()
		Drawer.PlaceMainButton()
		Drawer.Layout()
	end))
	mainButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(L.SETTINGS_TITLE)
		GameTooltip:AddLine(L.DRAWER_TOOLTIP_CLICK, 1, 1, 1)
		GameTooltip:AddLine(L.DRAWER_TOOLTIP_RIGHT, 1, 1, 1)
		GameTooltip:AddLine(L.DRAWER_TOOLTIP_MOVE, 1, 1, 1)
		GameTooltip:Show()
	end)
	mainButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Drawer.PlaceMainButton()
end

-- Start / settings ------------------------------------------------------------------------------

local eventFrame

local function onCombatEnd()
	for button, source in pairs(pendingCombat) do
		pendingCombat[button] = nil
		collect(button, source)
	end
end

--- Start the drawer (once). Skipped while MinimapButtonButton is loaded: both would grab the buttons.
---@param savedDb table OrdaenMinimapDB
function Drawer.Start(savedDb)
	db = savedDb
	if started or not db.drawerEnabled then
		Drawer.ApplyBlizzardCompartment()
		return
	end
	if C_AddOns.IsAddOnLoaded("MinimapButtonButton") then
		ns.Print(L.DRAWER_MBB_WARNING)
		debug().Log("drawer: skipped, MinimapButtonButton is loaded")
		return
	end
	started = true
	createFrames()
	Drawer.ApplyBlizzardCompartment()
	collectAll()

	local icon = libDBIcon()
	if icon and icon.RegisterCallback then
		icon.RegisterCallback(Drawer, "LibDBIcon_IconCreated", function(_, button)
			collect(button, "LibDBIcon")
		end)
	end
	-- Addons create buttons late (after login, after loading data); look again a few times.
	for _, delay in ipairs(RESCAN_DELAYS) do
		C_Timer.After(delay, ns.Debug.Wrap(collectAll))
	end
	eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventFrame:SetScript("OnEvent", ns.Debug.Wrap(onCombatEnd))
end

--- Apply changed drawer settings. Turning the drawer off needs a reload to give buttons back.
---@param savedDb table OrdaenMinimapDB
function Drawer.Apply(savedDb)
	db = savedDb
	if db.drawerEnabled and not started then
		Drawer.Start(db)
	elseif not db.drawerEnabled and started then
		mainButton:Hide()
		container:Hide()
		ns.Print(L.DRAWER_RELOAD_HINT)
	elseif started then
		mainButton:Show()
		Drawer.PlaceMainButton()
		Drawer.Layout()
	end
	Drawer.ApplyBlizzardCompartment()
end

--- What the dev-mode dump records about the drawer.
function Drawer.Describe()
	local names = {}
	for _, c in ipairs(collected) do
		names[#names + 1] = c.name .. " (" .. c.source .. (c.frame:IsShown() and "" or ", hidden") .. ")"
	end
	local entryTitles = {}
	for _, item in ipairs(entries) do
		entryTitles[#entryTitles + 1] = item.kind .. ": " .. tostring(item.entry.title or item.entry.text)
	end
	return {
		started = started,
		collected = names,
		entries = entryTitles,
		mainButton = mainButton,
		container = container,
		addon = addonName,
	}
end
