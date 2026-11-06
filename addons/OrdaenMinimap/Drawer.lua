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
local AUTO_CLOSE_CHECK = 0.1
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
		items[#items + 1] = entryButtons[i].frame
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
	-- Grow away from the screen edge the main button is closest to. The button is on the minimap,
	-- which has its own scale: compare in UIParent units.
	local bx, by = mainButton:GetCenter()
	local k = (mainButton:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	local growLeft = bx and bx * k > UIParent:GetWidth() / 2
	local growUp = by and by * k < UIParent:GetHeight() / 2
	local offsets, width, height = ns.DrawerGrid(#items, db.drawerColumns, SLOT, GAP, growLeft, growUp)

	local vertical = growUp and "BOTTOM" or "TOP"
	local horizontal = growLeft and "RIGHT" or "LEFT"
	local corner = vertical .. horizontal
	container:ClearAllPoints()
	container:SetPoint(corner, mainButton.frame, (growUp and "TOP" or "BOTTOM") .. horizontal, 0, growUp and 2 or -2)
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
	if collectedSet[button] or (mainButton and button == mainButton.frame) then
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
	-- Our own frames stay where they are, e.g. the Ordaen Dev gear button (OrdaenDevButton), which dev
	-- mode deliberately keeps on the minimap edge.
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
	-- Not confirmed on Forever yet: fall back to the old globals, else no TOC entries.
	local getNum = C_AddOns.GetNumAddOns or _G.GetNumAddOns
	local getInfo = C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
	if type(getNum) ~= "function" or type(getInfo) ~= "function" then
		return list
	end
	for i = 1, getNum() do
		local name = getInfo(i)
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

-- Our tooltips are OrdaenCore.UI tooltip objects, built once; only the entry's title changes on hover.
local UI = OrdaenCore.UI
local LEFT = { side = "left" }
local entryTitle = { text = "", style = "title" }
local entryTooltip = UI.Tooltip({ entryTitle }, LEFT)
local mainTooltip = UI.Tooltip({
	{ text = L.SETTINGS_TITLE, style = "title" },
	{ text = L.DRAWER_TOOLTIP_CLICK, style = "hint" },
	{ text = L.DRAWER_TOOLTIP_RIGHT, style = "hint" },
	{ text = L.DRAWER_TOOLTIP_MOVE, style = "hint" },
}, LEFT)

local entryIndex = setmetatable({}, { __mode = "k" }) -- entry button -> its index in `entries`

-- For entries whose addon has no hover function of its own.
local function plainTooltip(owner, text)
	entryTitle.text = text or "?"
	entryTooltip:Show(owner)
end

-- Entry buttons are OrdaenCore.UI components; the other addons' functions get the WoW frame, as Blizzard's
-- compartment would give them. Clicks go straight to the other addon; its errors are its own.
local function entryOnClick(button, mouseButton)
	local item = entries[entryIndex[button]]
	if not item then
		return
	end
	local frame, e = button.frame, item.entry
	if item.kind == "toc" then
		local fn = _G[e.func]
		if type(fn) == "function" then
			fn(e.addon, mouseButton, frame)
		end
	elseif type(e.func) == "function" then
		e.func(frame, { buttonName = mouseButton }, frame)
	end
end

local function entryOnEnter(button)
	local item = entries[entryIndex[button]]
	if not item then
		return
	end
	local frame, e = button.frame, item.entry
	if item.kind == "toc" then
		local fn = e.onEnter and _G[e.onEnter]
		if type(fn) == "function" then
			fn(e.addon, frame)
			return
		end
		plainTooltip(frame, e.title)
	elseif type(e.funcOnEnter) == "function" then
		e.funcOnEnter(frame, e)
	else
		plainTooltip(frame, e.text)
	end
end

local function entryOnLeave(button)
	local item = entries[entryIndex[button]]
	local frame, e = button.frame, item and item.entry
	if item and item.kind == "toc" and e.onLeave and type(_G[e.onLeave]) == "function" then
		_G[e.onLeave](e.addon, frame)
	elseif item and item.kind == "runtime" and type(e.funcOnLeave) == "function" then
		e.funcOnLeave(frame, e)
	end
	entryTooltip:Hide(frame) -- ours, if we showed one
	GameTooltip:Hide() -- the other addon's own hover code usually draws on GameTooltip
end

local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 } -- trims the border most icons have

local function entryButton(index)
	local button = entryButtons[index]
	if not button then
		button = UI.Button({
			parent = container,
			style = "slot",
			width = SLOT - 4,
			height = SLOT - 4,
			{ image = FALLBACK_ICON, size = ENTRY_ICON, texCoord = ICON_CROP, align = "center" },
			on = { click = entryOnClick, enter = entryOnEnter, leave = entryOnLeave },
		})
		entryButtons[index] = button
	end
	entryIndex[button] = index
	return button
end

local function refreshEntries()
	entries = ns.MergeCompartmentEntries(tocEntries(), runtimeEntries(), shownIconKeys())
	for i, item in ipairs(entries) do
		local button = entryButton(i)
		local e = item.entry
		local atlas = item.kind == "toc" and e.atlas or e.iconAtlas
		local icon = button.block[1]
		icon.atlas = atlas or nil
		icon.image = (not atlas) and (e.icon or FALLBACK_ICON) or nil
		button:Refresh()
		button:Show()
	end
	for i = #entries + 1, #entryButtons do
		entryButtons[i]:Hide()
	end
	debug().Logf("drawer: %d compartment entries", #entries)
end

-- Blizzard's compartment button -----------------------------------------------------------------

-- Blizzard's compartment button (the addon count next to the zone name) is hidden by parenting it to a
-- frame that is never shown: hooking Show alone isn't enough, Blizzard also shows it through SetShown
-- and its layout code. Its entries are in our drawer, so it stays visible while the drawer isn't running.
local hiddenParent
local compartmentParent -- its own parent, to give it back
local placingCompartment = false

local function compartmentHidden()
	return db and db.hideBlizzardCompartment and started
end

local function keepCompartmentHidden(frame)
	if placingCompartment or not compartmentHidden() or frame:GetParent() == hiddenParent then
		return
	end
	placingCompartment = true
	compartmentParent = frame:GetParent()
	frame:SetParent(hiddenParent)
	placingCompartment = false
end

function Drawer.ApplyBlizzardCompartment()
	local frame = _G.AddonCompartmentFrame
	if not frame then
		return
	end
	if not hiddenParent then
		hiddenParent = CreateFrame("Frame")
		hiddenParent:Hide()
	end
	if not blizzardCompartmentHooked then
		blizzardCompartmentHooked = true
		hooksecurefunc(frame, "SetParent", keepCompartmentHidden)
	end
	if compartmentHidden() then
		keepCompartmentHidden(frame)
	elseif frame:GetParent() == hiddenParent then
		placingCompartment = true
		frame:SetParent(compartmentParent or MinimapCluster)
		placingCompartment = false
	end
	debug().Logf("drawer: Blizzard compartment %s", compartmentHidden() and "hidden" or "shown")
end

-- Main button and drawer frame ------------------------------------------------------------------

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
	-- OnUpdate only runs while the drawer is shown (WoW skips it for hidden frames), and the mouse is
	-- checked every AUTO_CLOSE_CHECK seconds, not every frame.
	local away, sinceCheck = 0, 0
	container:SetScript("OnShow", function()
		away, sinceCheck = 0, 0
	end)
	container:SetScript("OnUpdate", function(self, elapsed)
		sinceCheck = sinceCheck + elapsed
		if sinceCheck < AUTO_CLOSE_CHECK then
			return
		end
		-- frame:IsMouseOver(), not the global MouseIsOver(): Forever has no MouseIsOver.
		if self:IsMouseOver() or mainButton:IsMouseOver() then
			away = 0
		else
			away = away + sinceCheck
			if away > AUTO_CLOSE_DELAY then
				self:Hide()
			end
		end
		sinceCheck = 0
	end)

	-- On the ring around the minimap, in the same style as the tracking and Ordaen Dev buttons;
	-- dragging moves it around the map (Buttons.lua).
	mainButton = ns.Buttons.Create("drawer", "OrdaenMinimapDrawerButton", "Interface\\Icons\\INV_Misc_Bag_10")

	if not mainButton then
		return false -- OrdaenCore_UI can't load (the player was told)
	end
	mainButton:On("click", ns.Debug:Wrap(function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.Addon:OpenSettings()
		else
			Drawer.Toggle()
		end
	end))
	mainButton:Tooltip(mainTooltip)
	return true
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
	if not createFrames() then
		return
	end
	started = true
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
		C_Timer.After(delay, ns.Debug:Wrap(collectAll))
	end
	eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventFrame:SetScript("OnEvent", ns.Debug:Wrap(onCombatEnd))
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
		mainButton = mainButton and mainButton.frame or false,
		container = container,
		addon = addonName,
	}
end
