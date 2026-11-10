-- game (design: development/framework/game): everything a module touches at runtime, handed to Setup and Render.
-- One shared table of domains; each module's `game` adds its own `ui` on top. Domains are made on first use, and a
-- game event is registered only while something subscribes to it.
local _, ns = ...

local NewEvent, NewValue, NewComputed = ns.NewEvent, ns.NewValue, ns.NewComputed
local setmetatable, select = setmetatable, select

---@class OrdaenGame
local Game = {}
ns.Game = Game

-- Raw game events, one shared frame --------------------------------------------------------------------------------

local events = {} -- name -> OrdaenEvent
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, name, ...)
	local event = events[name]
	if event then
		event:Fire(...)
	end
end)

local function Register(event)
	frame:RegisterEvent(event.name)
end

local function Unregister(event)
	frame:UnregisterEvent(event.name)
end

--- The event signal for a game event (registered with Blizzard while it has subscribers).
---@param name string
---@return OrdaenEvent
function Game.RawEvent(name)
	local event = events[name]
	if not event then
		event = NewEvent(Register, Unregister)
		event.name = name
		events[name] = event
	end
	return event
end
local RawEvent = Game.RawEvent

-- A unit event for the player only (RegisterUnitEvent: other units' events never reach us), on a frame of its own.
local playerEvents = {} -- name -> OrdaenEvent
local playerFrame = CreateFrame("Frame")
playerFrame:SetScript("OnEvent", function(_, name, ...)
	local event = playerEvents[name]
	if event then
		event:Fire(...)
	end
end)
local function RegisterPlayer(event)
	playerFrame:RegisterUnitEvent(event.name, "player")
end
local function UnregisterPlayer(event)
	playerFrame:UnregisterEvent(event.name)
end
local function PlayerEvent(name)
	local event = playerEvents[name]
	if not event then
		event = NewEvent(RegisterPlayer, UnregisterPlayer)
		event.name = name
		playerEvents[name] = event
	end
	return event
end

--- A derived value: `game.Computed(function() ... end)`.
Game.Computed = NewComputed

Game.Stage = ns.Stage

---@param name string
function Game:UseModule(name) -- luacheck: ignore 212
	return ns.App.Handle(name)
end

-- Domains, made on first use ---------------------------------------------------------------------------------------

local LAYERS = { Screen = "screen", Dialog = "dialog", Tooltip = "tooltip" }

local DOMAINS = {}

function DOMAINS.Layer()
	return setmetatable({}, {
		__index = function(layers, key)
			local name = LAYERS[key]
			if not name then
				return nil
			end
			local place = ns.Draw:NewPlace(name)
			layers[key] = place
			return place
		end,
	})
end

--- Blizzard's frames by reference: `game.Frame.CombinedBags:Get()`.
local FRAME_NAMES = { CombinedBags = "ContainerFrameCombinedBags", Minimap = "Minimap", Merchant = "MerchantFrame",
	Professions = "ProfessionsFrame" }
-- the micro menu, the bag bar, the XP and reputation bars and the social button by the chat, under their own names
-- (every one in the dump of 70862)
for _, name in ipairs({
	"CharacterMicroButton", "PlayerSpellsMicroButton", "SpellbookMicroButton", "TalentMicroButton",
	"ProfessionMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton",
	"CollectionsMicroButton", "EJMicroButton", "HousingMicroButton", "LegacyMicroButton", "MainMenuMicroButton",
	"HelpMicroButton", "StoreMicroButton", "MicroMenu", "MicroMenuContainer",
	"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
	"CharacterReagentBag0Slot", "BagBarExpandToggle", "BagsBar",
	"MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "QuickJoinToastButton",
	"MinimapCluster", "MinimapCompassTexture", "MinimapBackdrop", "TimeManagerClockButton", "GameTimeFrame",
	"AddonCompartmentFrame", "ExpansionLandingPageMinimapButton", "OrdaenDevButton",
	"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5",
	"MultiBar6", "MultiBar7",
}) do
	FRAME_NAMES[name] = name
end
-- regions without a global name, as their frame's parentKey: { global, key }
local FRAME_KEYS = {
	-- the backpack's free slots, "(23)" under its icon (seen in game: the dev addon's "bag button" probe)
	BackpackFreeSlots = { "MainMenuBarBackpackButton", "FreeSlots" },
	-- the minimap's own parts (MinimapCluster's children in the dump of 70862; Ordaen Minimap takes them)
	MinimapTracking = { "MinimapCluster", "Tracking" },
	MinimapTrackingButton = { "MinimapCluster", "Tracking", "Button" },
	MinimapMail = { "MinimapCluster", "IndicatorFrame", "MailFrame" },
	MinimapCraftingOrder = { "MinimapCluster", "IndicatorFrame", "CraftingOrderFrame" },
	MinimapZoneText = { "MinimapCluster", "ZoneTextButton" },
	MinimapDiel = { "MinimapCluster", "DielFrame" },
	MinimapCoords = { "MinimapCluster", "MinimapContainer", "PlayerCoords" },
	MinimapZoomIn = { "Minimap", "ZoomIn" },
	MinimapZoomOut = { "Minimap", "ZoomOut" },
}
local FrameRef = {}
local FrameRefMeta = { __index = FrameRef }
function FrameRef:Get()
	local found = _G[self.global]
	local path = self.path
	if path then
		for i = 2, #path do
			if type(found) ~= "table" then
				return nil
			end
			found = found[path[i]]
		end
	end
	return found
end

function DOMAINS.Frame()
	return setmetatable({}, {
		__index = function(frames, key)
			local global = FRAME_NAMES[key]
			local path = FRAME_KEYS[key]
			if path then
				global = path[1]
			end
			if not global then
				return nil
			end
			local ref = setmetatable({ global = global, path = path }, FrameRefMeta)
			frames[key] = ref
			return ref
		end,
	})
end

--- Ordaen's action buttons by index, as frame references for game.ui:Embed: `game.ActionButtons[1]` (made by the
--- backend on first use, out of combat; Backend.lua «Action buttons»).
function DOMAINS.ActionButtons()
	return setmetatable({}, {
		__index = function(refs, index)
			local ref = { Get = function()
				return ns.Backend:ActionButton(index)
			end }
			refs[index] = ref
			return ref
		end,
	})
end

--- Ordaen's global settings as values: `game.Settings.scale:Get()` (development/framework/game).
function DOMAINS.Settings()
	return ns.Globals.ByName
end

--- Ordaen's modules, for the settings window's list: `game.Modules[i]` (folder, title, on, loaded, reason, pending,
--- :Enable(on)), in AddOns order (App.lua).
function DOMAINS.Modules()
	return ns.App.modules
end

--- Ordaen itself, as the settings window shows it beside its own pages: `game.Ordaen.title`, `game.Ordaen.icon`
--- (OrdaenCore's toc).
-- Read now if the character is in the world, and again at each login.
local function AtLogin(fn)
	Game.Stage.Login:Subscribe(fn, false)
	if Game.Stage.Login.fired then
		fn()
	end
end

function DOMAINS.Ordaen()
	local _, title = C_AddOns.GetAddOnInfo("OrdaenCore")
	local Ordaen = { title = title, icon = C_AddOns.GetAddOnMetadata("OrdaenCore", "IconTexture"),
		dev = NewValue(false), devButton = NewValue(_G.OrdaenDevButton) }
	-- the dev addon's own minimap button, for a module that takes its place: there now, or when the dev addon makes it
	-- (it announces it: rule 8, handovers on an event)
	EventRegistry:RegisterCallback("OrdaenDevButton.Created", function(_, button)
		Ordaen.devButton:Set(button)
	end)
	--- Ordaen's settings window, as /ordaen opens it; `page`: a module's word (/ordaen minimap) for its page.
	function Ordaen:OpenSettings(page) -- luacheck: ignore 212
		ns.Commands.OpenSettings(page)
	end
	-- the dev addon (OrdaenCore_Debug, never in players' installs): its window's toggle, while it's loaded
	local function ReadDev()
		Ordaen.dev:Set(type(_G.OrdaenCoreDebug_Toggle) == "function")
	end
	--- Open or close the Ordaen Dev window (nothing without the dev addon).
	function Ordaen:ToggleDev() -- luacheck: ignore 212
		local toggle = _G.OrdaenCoreDebug_Toggle
		if type(toggle) == "function" then
			toggle()
		end
	end
	ReadDev()
	AtLogin(ReadDev)
	return Ordaen
end

--- The themes: `game.Themes:Active()`, `:List()`, `:Get(id)`, `.ClassColor(class)` (Themes.lua).
function DOMAINS.Themes()
	return ns.Themes
end

--- The placing mode: `game.Placing.on`, `:Enter()`, `:Exit()`, `:Toggle()` (Placing.lua).
function DOMAINS.Placing()
	return ns.Placing
end

--- Blizzard's tooltips as the game fills them, for a module that draws its own: `game.Tooltip.GameTooltip`
--- (Tooltip.lua).
function DOMAINS.Tooltip()
	return ns.NewTooltips()
end

--- Numbers formatted by the global settings: `game.Numbers:Format(n)` (Numbers.lua).
function DOMAINS.Numbers()
	return ns.Numbers
end


function DOMAINS.Money()
	local Money = { amount = NewValue(GetMoney()) }
	RawEvent("PLAYER_MONEY"):Subscribe(function()
		Money.amount:Set(GetMoney())
	end, false)
	function Money:Get() -- luacheck: ignore 212
		return GetMoney()
	end
	function Money:Format(copper) -- luacheck: ignore 212
		return C_CurrencyInfo.GetCoinTextureString(copper)
	end
	-- value signal: the currencies the player marked to show on the backpack (the Currency tab), as one text of
	-- "<count> <icon>" each, "" with none; read at login and when a currency changes
	Money.tracked = NewValue("")
	local parts = {}
	local function ReadTracked()
		local n = 0
		for i = 1, 3 do -- the backpack shows at most three
			local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
			if not info then
				break
			end
			n = n + 1
			parts[n] = BreakUpLargeNumbers(info.quantity) .. " |T" .. info.iconFileID .. ":0|t"
		end
		for i = n + 1, #parts do
			parts[i] = nil
		end
		Money.tracked:Set(table.concat(parts, "  "))
	end
	AtLogin(ReadTracked)
	RawEvent("CURRENCY_DISPLAY_UPDATE"):Subscribe(ReadTracked, false)
	return Money
end

-- what changes the number of friends online: the friend list, and Battle.net friends coming and going
local FRIEND_EVENTS = {
	"FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_FRIEND_INFO_CHANGED", "BN_CONNECTED",
	"BN_DISCONNECTED",
}

function DOMAINS.Friends()
	-- value signal: friends online, the character friend list and Battle.net friends together (what Blizzard's social
	-- button counts)
	local Friends = { online = NewValue(0) }
	local function Read()
		local _, bnetOnline = BNGetNumFriends()
		Friends.online:Set((C_FriendList.GetNumOnlineFriends() or 0) + (bnetOnline or 0))
	end
	for i = 1, #FRIEND_EVENTS do
		RawEvent(FRIEND_EVENTS[i]):Subscribe(Read, false)
	end
	Game.Stage.Login:Subscribe(Read, false)
	if Game.Stage.Login.fired then
		Read()
	end
	return Friends
end

function DOMAINS.Player()
	-- value signals, read once the character is in the world and kept current by the events that change them
	local Player = {
		name = NewValue(nil), class = NewValue(nil), level = NewValue(nil), xp = NewValue(nil),
		xpMax = NewValue(nil), rested = NewValue(nil),
	}
	local key
	local function ReadXp()
		Player.level:Set(UnitLevel("player"))
		Player.xp:Set(UnitXP("player"))
		Player.xpMax:Set(UnitXPMax("player"))
		Player.rested:Set(GetXPExhaustion()) -- nil when there's none
	end
	local function ReadAll()
		Player.name:Set(UnitName("player"))
		Player.class:Set((select(2, UnitClass("player")))) -- the file name: "WARRIOR"
		ReadXp()
	end
	Game.Stage.Login:Subscribe(ReadAll, false)
	if Game.Stage.Login.fired then
		ReadAll()
	end
	RawEvent("PLAYER_ENTERING_WORLD"):Subscribe(ReadAll, false)
	RawEvent("PLAYER_XP_UPDATE"):Subscribe(ReadXp, false)
	RawEvent("PLAYER_LEVEL_UP"):Subscribe(function(level) -- UnitLevel can still say the old level here
		ReadXp()
		Player.level:Set(level)
	end, false)
	RawEvent("UPDATE_EXHAUSTION"):Subscribe(ReadXp, false)
	--- "Name-Realm": the character's key in account-wide data.
	function Player:Key() -- luacheck: ignore 212
		if not key then
			key = UnitName("player") .. "-" .. GetRealmName()
		end
		return key
	end
	return Player
end

function DOMAINS.Reputation()
	-- value signals of the faction the player watches (the reputation bar's): its name, standing's label, and how far
	-- into the standing (value from min to max); name "" while none is watched
	local Reputation = { name = NewValue(""), standing = NewValue(""), min = NewValue(0), max = NewValue(0),
		value = NewValue(0) }
	local function Read()
		local data = C_Reputation.GetWatchedFactionData()
		if not data or not data.name or data.name == "" then
			Reputation.name:Set("")
			return
		end
		Reputation.name:Set(data.name)
		Reputation.standing:Set(_G["FACTION_STANDING_LABEL" .. (data.reaction or 4)] or "")
		Reputation.min:Set(data.currentReactionThreshold or 0)
		Reputation.max:Set(data.nextReactionThreshold or 0)
		Reputation.value:Set(data.currentStanding or 0)
	end
	AtLogin(Read)
	RawEvent("UPDATE_FACTION"):Subscribe(Read, false)
	return Reputation
end

-- the round minimap's mask, put back when the square one goes
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local SHAPE_GLOBAL = "GetMinimapShape"
local function SquareShape()
	return "SQUARE"
end
local BLOB_RINGS = { "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }
-- other addons' minimap buttons: children of the minimap (or its cluster) that aren't Blizzard's or ours, by their
-- names (LibDBIcon's LibDBIcon10_<name>, and the usual "...MinimapButton" names)
local BLIZZARD_MINIMAP = {
	MinimapBackdrop = true, MinimapCompassTexture = true, MiniMapMailFrame = true, MinimapZoomIn = true,
	MinimapZoomOut = true, GameTimeFrame = true, TimeManagerClockButton = true, ExpansionLandingPageMinimapButton = true,
	AddonCompartmentFrame = true, OrdaenDevButton = true, HybridMinimap = true,
}
local function IsAddonButton(child)
	if type(child) ~= "table" or not child.GetName or not child.IsObjectType then
		return false
	end
	local name = child:GetName()
	if not name or BLIZZARD_MINIMAP[name] or name:find("^Ordaen") then
		return false
	end
	if not (child:IsObjectType("Button") or child:IsObjectType("Frame")) then
		return false
	end
	return name:find("^LibDBIcon10_") ~= nil or name:lower():find("minimap") ~= nil and name:lower():find("button") ~= nil
end

function DOMAINS.Minimap()
	-- value signals: the player's coordinates as text ("" where the game gives none: instances), the other addons'
	-- minimap buttons (a list, new when it changes) and the addon compartment's entries (Blizzard's
	-- AddonCompartmentFrame.registeredAddons). No pings: Forever's client refuses MINIMAP_PING.
	local Minimap = { coords = NewValue(""), buttons = NewValue({}), entries = NewValue({}) }
	local map = _G.Minimap

	--- The square map (on) or Blizzard's round one: its mask, and GetMinimapShape for other addons' buttons.
	function Minimap:Square(on) -- luacheck: ignore 212
		map:SetMaskTexture(on and SQUARE_MASK or ROUND_MASK)
		for _, method in ipairs(BLOB_RINGS) do
			if map[method] then
				map[method](map, on and 0 or 1)
			end
		end
		-- what other addons ask to place their buttons round it (LibDBIcon and the like)
		rawset(_G, SHAPE_GLOBAL, on and SquareShape or nil)
	end

	--- Zoom in (delta > 0) or out, clamped to the game's levels.
	function Minimap:Zoom(delta) -- luacheck: ignore 212
		local zoom = map:GetZoom() + (delta > 0 and 1 or -1)
		if zoom >= 0 and zoom < map:GetZoomLevels() then
			map:SetZoom(zoom)
		end
	end

	-- the coordinates, read twice a second while asked for (the game has no event for moving)
	local ticker
	local format = string.format
	local function ReadCoords()
		local id = C_Map.GetBestMapForUnit("player")
		local pos = id and C_Map.GetPlayerMapPosition(id, "player")
		Minimap.coords:Set(pos and format("%.1f, %.1f", pos.x * 100, pos.y * 100) or "")
	end
	--- Keep the coordinates current (on) or stop.
	function Minimap:TrackCoords(on) -- luacheck: ignore 212
		if on and not ticker then
			ReadCoords()
			ticker = C_Timer.NewTicker(0.5, ReadCoords)
		elseif not on and ticker then
			ticker:Cancel()
			ticker = nil
		end
	end

	-- other addons' buttons: looked for at login, when an addon loads (after its own setup ran) and a while later
	local seen = {}
	local function Scan()
		local list, changed = {}, false
		for _, parent in ipairs({ map, _G.MinimapCluster }) do
			for _, child in ipairs({ parent:GetChildren() }) do
				if not seen[child] and IsAddonButton(child) then
					seen[child] = true
					changed = true
				end
			end
		end
		if not changed then
			return
		end
		for button in pairs(seen) do
			list[#list + 1] = button
		end
		table.sort(list, function(a, b)
			return a:GetName() < b:GetName()
		end)
		Minimap.buttons:Set(list)
	end
	local function ScanSoon()
		C_Timer.After(0, Scan)
	end
	AtLogin(function()
		Scan()
		C_Timer.After(2, Scan)
		C_Timer.After(10, Scan)
	end)
	RawEvent("ADDON_LOADED"):Subscribe(ScanSoon, false)

	-- the compartment's entries, read again when an addon registers one
	local compartment = _G.AddonCompartmentFrame
	local function ReadEntries()
		local list = {}
		for i, entry in ipairs(compartment and compartment.registeredAddons or {}) do
			list[i] = entry
		end
		Minimap.entries:Set(list)
	end
	if compartment and compartment.RegisterAddon then
		hooksecurefunc(compartment, "RegisterAddon", ReadEntries)
	end
	AtLogin(ReadEntries)
	--- Blizzard's own button behind one of ours (a ring button): press it with `mouse` ("LeftButton", ...) as a click
	--- of the player's would (its mouse-down opens a menu, its click the rest).
	function Minimap:Press(ref, mouse) -- luacheck: ignore 212
		local button = ref:Get()
		if not button then
			return
		end
		if button:HasScript("OnMouseDown") and button:GetScript("OnMouseDown") then
			ExecuteFrameScript(button, "OnMouseDown", mouse)
		end
		if button:HasScript("OnMouseUp") and button:GetScript("OnMouseUp") then
			ExecuteFrameScript(button, "OnMouseUp", mouse)
		end
		if button.Click and button:GetScript("OnClick") then
			button:Click(mouse)
		end
	end
	--- Its tooltip shown (on) or hidden, as the cursor over it would.
	function Minimap:Hover(ref, on) -- luacheck: ignore 212
		local button = ref:Get()
		local script = on and "OnEnter" or "OnLeave"
		if button and button:GetScript(script) then
			ExecuteFrameScript(button, script)
		end
	end
	--- The mouse wheel zooms the map (unless Blizzard already handles it).
	function Minimap:WheelZoom() -- luacheck: ignore 212
		if not map:GetScript("OnMouseWheel") then
			map:EnableMouseWheel(true)
			map:SetScript("OnMouseWheel", function(_, delta)
				Minimap:Zoom(delta)
			end)
		end
	end
	--- The subzone and coordinates into the chat's input («Аллея Героев (71.8, 87.1)»), opening it when closed.
	function Minimap:SendCoords() -- luacheck: ignore 212
		local coords = Minimap.coords:Peek()
		if coords == "" then
			return
		end
		local text = format("%s (%s)", GetMinimapZoneText() or "", coords)
		if not ChatFrameUtil.InsertLink(text) then
			ChatFrameUtil.OpenChat(text)
		end
	end

	--- Run a compartment entry's click, as Blizzard's menu does.
	function Minimap:RunEntry(entry, button) -- luacheck: ignore 212
		local func = entry.func
		if type(func) == "function" then
			func(entry.text, button)
		elseif type(func) == "string" and type(_G[func]) == "function" then
			_G[func](entry.text, button)
		end
	end
	return Minimap
end

function DOMAINS.Situation()
	-- value signals of what the player is doing, for what shows or hides by it (Ordaen Panel's visibility)
	local Situation = { combat = NewValue(false), resting = NewValue(false), vehicle = NewValue(false),
		petBattle = NewValue(false), taxi = NewValue(false) }
	local function ReadTaxi()
		Situation.taxi:Set(UnitOnTaxi("player") == true)
	end
	local function ReadCombat()
		Situation.combat:Set(UnitAffectingCombat("player") == true)
	end
	local function ReadResting()
		Situation.resting:Set(IsResting() == true)
	end
	local function ReadVehicle()
		Situation.vehicle:Set(UnitInVehicle("player") == true)
	end
	local function ReadPetBattle()
		Situation.petBattle:Set(C_PetBattles.IsInBattle() == true)
	end
	AtLogin(function()
		ReadCombat()
		ReadResting()
		ReadVehicle()
		ReadPetBattle()
		ReadTaxi()
	end)
	RawEvent("PLAYER_CONTROL_LOST"):Subscribe(ReadTaxi, false)
	RawEvent("PLAYER_CONTROL_GAINED"):Subscribe(ReadTaxi, false)
	RawEvent("PLAYER_REGEN_DISABLED"):Subscribe(function()
		Situation.combat:Set(true)
	end, false)
	RawEvent("PLAYER_REGEN_ENABLED"):Subscribe(function()
		Situation.combat:Set(false)
	end, false)
	RawEvent("PLAYER_UPDATE_RESTING"):Subscribe(ReadResting, false)
	PlayerEvent("UNIT_ENTERED_VEHICLE"):Subscribe(ReadVehicle, false)
	PlayerEvent("UNIT_EXITED_VEHICLE"):Subscribe(ReadVehicle, false)
	RawEvent("PET_BATTLE_OPENING_START"):Subscribe(ReadPetBattle, false)
	RawEvent("PET_BATTLE_CLOSE"):Subscribe(ReadPetBattle, false)
	return Situation
end

function DOMAINS.Location()
	-- value signal: the zone's name as the minimap shows it (the subzone where there is one)
	local Location = { zone = NewValue(""), pvp = NewValue(nil), realZone = NewValue("") }
	local function Read()
		Location.zone:Set(GetMinimapZoneText() or "")
		Location.realZone:Set(GetRealZoneText() or "")
		Location.pvp:Set((C_PvP.GetZonePVPInfo())) -- "sanctuary", "friendly", "hostile", "contested", ... or nil
	end
	AtLogin(Read)
	RawEvent("ZONE_CHANGED"):Subscribe(Read, false)
	RawEvent("ZONE_CHANGED_INDOORS"):Subscribe(Read, false)
	RawEvent("ZONE_CHANGED_NEW_AREA"):Subscribe(Read, false)
	return Location
end

function DOMAINS.Clock()
	-- value signals: the time as the game's clock shows it (the minimap's: realm or local time, 24 or 12 hours by
	-- Blizzard's own options) and the calendar invites waiting for an answer. The time changes once a minute: one
	-- timer to the next minute's start, then one a minute.
	local Clock = { text = NewValue(""), invites = NewValue(0) }
	local floor, format = math.floor, string.format
	local function Text()
		local hour, minute
		if GetCVarBool("timeMgrUseLocalTime") then
			local now = C_DateAndTime.GetCurrentCalendarTime()
			hour, minute = now.hour, now.minute
		else
			hour, minute = GetGameTime()
		end
		if GetCVarBool("timeMgrUseMilitaryTime") then
			return format("%02d:%02d", hour, minute)
		end
		return format("%d:%02d %s", (hour - 1) % 12 + 1, minute, hour < 12 and "AM" or "PM")
	end
	local function Tick()
		Clock.text:Set(Text())
		C_Timer.After(60 - floor(GetServerTime() % 60), Tick)
	end
	local function ReadInvites()
		Clock.invites:Set(C_Calendar.GetNumPendingInvites() or 0)
	end
	AtLogin(function()
		ReadInvites()
		Tick()
	end)
	RawEvent("CALENDAR_UPDATE_PENDING_INVITES"):Subscribe(ReadInvites, false)
	--- Open or close Blizzard's calendar (a click on the clock).
	function Clock:ToggleCalendar() -- luacheck: ignore 212
		ToggleCalendar()
	end
	return Clock
end

function DOMAINS.Merchant()
	local Merchant = { Signal = { Opened = RawEvent("MERCHANT_SHOW"), Closed = RawEvent("MERCHANT_CLOSED") } }
	local open = false
	Merchant.Signal.Opened:Subscribe(function()
		open = true
	end, false)
	Merchant.Signal.Closed:Subscribe(function()
		open = false
	end, false)
	--- Sell one bag slot (only while a merchant is open).
	function Merchant:Sell(bag, slot) -- luacheck: ignore 212
		if open then
			C_Container.UseContainerItem(bag, slot)
		end
	end
	--- What repairing everything costs now (0 when this merchant can't repair).
	function Merchant:RepairCost() -- luacheck: ignore 212
		if not CanMerchantRepair() then
			return 0
		end
		local cost, canRepair = GetRepairAllCost()
		return canRepair and cost or 0
	end
	---@param guildFunds boolean
	function Merchant:RepairAll(guildFunds) -- luacheck: ignore 212
		if open and CanMerchantRepair() then
			RepairAllItems(guildFunds and CanGuildBankRepair() or false)
		end
	end
	return Merchant
end

local LAST_BAG = 4 -- backpack 0 and bags 1-4

function DOMAINS.Bags()
	local toggled = NewEvent(function(event)
		if not event.hooked then
			event.hooked = true
			hooksecurefunc("ToggleAllBags", function()
				event:Fire()
			end)
		end
	end)
	local changed = RawEvent("BAG_UPDATE_DELAYED")
	-- value signal: the free slots in the backpack and bags (what Blizzard's backpack button counts), read at login and
	-- after each burst of bag changes
	local Bags = { Signal = { Toggled = toggled, Changed = changed }, free = NewValue(nil) }
	local function ReadFree()
		Bags.free:Set(C_Container.CalculateTotalNumberOfFreeBagSlots())
	end
	changed:Subscribe(ReadFree, false)
	Game.Stage.Login:Subscribe(ReadFree, false)
	if Game.Stage.Login.fired then
		ReadFree()
	end
	--- `fn(item, bag, slot)` for every filled slot; item is Blizzard's ContainerItemInfo.
	function Bags:Each(fn) -- luacheck: ignore 212
		local GetInfo = C_Container.GetContainerItemInfo
		for bag = 0, LAST_BAG do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				local item = GetInfo(bag, slot)
				if item then
					fn(item, bag, slot)
				end
			end
		end
	end
	return Bags
end

function DOMAINS.Items()
	local Items = {}
	function Items:SellPrice(itemID) -- luacheck: ignore 212
		return (select(11, C_Item.GetItemInfo(itemID)))
	end
	return Items
end

function DOMAINS.ItemQuality()
	return Enum.ItemQuality
end

-- Professions -------------------------------------------------------------------------------------------------------

-- A profession's kind (design professions/: crafting, gathering, secondary).
---@enum OrdaenProfessionKind
local ProfessionKind = { Crafting = "crafting", Gathering = "gathering", Secondary = "secondary" }
-- the gathering professions by skill line: herbalism, mining, skinning
local GATHERING = { [182] = true, [186] = true, [393] = true }

---@class OrdaenProfession
---@field skillLine integer
---@field name string
---@field icon integer
---@field rank integer
---@field max integer
---@field kind OrdaenProfessionKind

function DOMAINS.Professions()
	-- list: the character's professions in the game's order (main ones first), one kept record each; version: a value
	-- signal that changes whenever the records are refilled
	local Professions = { Kind = ProfessionKind, list = {}, version = NewValue(0) }
	local list = Professions.list
	local function Read()
		local n = 0
		local indexes = { GetProfessions() } -- luacheck: ignore (once per skill change, not per frame)
		for slot = 1, 6 do
			local index = indexes[slot]
			if index then
				local name, icon, rank, max, _, _, skillLine = GetProfessionInfo(index)
				if skillLine then
					n = n + 1
					local p = list[n] or {}
					list[n] = p
					p.skillLine, p.name, p.icon, p.rank, p.max = skillLine, name, icon, rank, max
					p.kind = GATHERING[skillLine] and ProfessionKind.Gathering
						or slot <= 2 and ProfessionKind.Crafting or ProfessionKind.Secondary
				end
			end
		end
		for i = n + 1, #list do
			list[i] = nil
		end
		Professions.version:Set(Professions.version:Peek() + 1)
	end
	AtLogin(Read)
	RawEvent("SKILL_LINES_CHANGED"):Subscribe(Read, false)
	return Professions
end

-- A recipe's difficulty for the player now (the game's Enum.TradeskillRelativeDifficulty).
---@enum OrdaenRecipeDifficulty
local RecipeDifficulty = { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 }

---@class OrdaenRecipe
---@field id integer
---@field name string
---@field icon integer
---@field categoryID integer
---@field difficulty OrdaenRecipeDifficulty
---@field learned boolean
---@field favorite boolean
---@field craftable integer how many the bags have reagents for now
---@field grey integer the skill at which it stops raising the skill

---@class OrdaenTradeSkillCategory
---@field id integer
---@field name string
---@field parentID integer|nil nil for a header

---@class OrdaenReagent
---@field itemID integer
---@field need integer
---@field have integer

function DOMAINS.TradeSkill()
	local TS = C_TradeSkillUI
	-- open: the open profession's skill line, nil while none is; recipes and categories: the open profession's, kept
	-- records refilled when the game's list changes; version changes on each refill
	local TradeSkill = {
		Difficulty = RecipeDifficulty, open = NewValue(nil), recipes = {}, categories = {}, version = NewValue(0),
		Signal = { Shown = RawEvent("TRADE_SKILL_SHOW"), Closed = RawEvent("TRADE_SKILL_CLOSE") },
	}
	local recipes, categories = TradeSkill.recipes, TradeSkill.categories
	local byID = {} -- recipe id -> its record

	local function ReadCategories()
		local n = 0
		local headers = { TS.GetCategories() } -- luacheck: ignore (on a list change only)
		local skillLine
		for h = 1, #headers do
			local info = TS.GetCategoryInfo(headers[h])
			if info then
				skillLine = skillLine or info.skillLineID
				n = n + 1
				local c = categories[n] or {}
				categories[n] = c
				c.id, c.name, c.parentID = info.categoryID, info.name, nil
				local subs = { TS.GetSubCategories(headers[h]) } -- luacheck: ignore
				for s = 1, #subs do
					local sub = TS.GetCategoryInfo(subs[s])
					if sub then
						n = n + 1
						local d = categories[n] or {}
						categories[n] = d
						d.id, d.name, d.parentID = sub.categoryID, sub.name, info.categoryID
					end
				end
			end
		end
		for i = n + 1, #categories do
			categories[i] = nil
		end
		return skillLine
	end

	local function ReadRecipes()
		local ids = TS.GetAllRecipeIDs()
		local n = 0
		for i = 1, #ids do
			local info = TS.GetRecipeInfo(ids[i])
			if info then
				n = n + 1
				local r = recipes[n] or {}
				recipes[n] = r
				r.id, r.name, r.icon, r.categoryID = info.recipeID, info.name, info.icon, info.categoryID
				r.difficulty, r.learned, r.favorite = info.relativeDifficulty, info.learned, info.favorite
				r.craftable = info.learned and TS.GetCraftableCount(info.recipeID) or 0
				r.grey = info.maxTrivialLevel
				byID[r.id] = r
			end
		end
		for i = n + 1, #recipes do
			byID[recipes[i].id] = nil
			recipes[i] = nil
		end
	end

	local function Refill()
		if not TradeSkill.open:Peek() then
			return
		end
		ReadCategories()
		ReadRecipes()
		TradeSkill.version:Set(TradeSkill.version:Peek() + 1)
	end
	TradeSkill.Signal.Shown:Subscribe(function()
		TradeSkill.open:Set(ReadCategories() or true)
		Refill()
	end, false)
	TradeSkill.Signal.Closed:Subscribe(function()
		TradeSkill.open:Set(nil)
	end, false)
	RawEvent("TRADE_SKILL_LIST_UPDATE"):Subscribe(function()
		local skillLine = ReadCategories()
		if TradeSkill.open:Peek() and skillLine then
			TradeSkill.open:Set(skillLine)
		end
		Refill()
	end, false)
	RawEvent("BAG_UPDATE_DELAYED"):Subscribe(Refill, false) -- what the bags can make changes with them

	--- The recipe's record, nil when it isn't the open profession's.
	function TradeSkill:Recipe(id) -- luacheck: ignore 212
		return byID[id]
	end
	--- Opens a profession by its skill line (the game's own window opens with it; the module hides it).
	function TradeSkill:Open(skillLine) -- luacheck: ignore 212
		TS.OpenTradeSkill(skillLine)
	end
	function TradeSkill:Close() -- luacheck: ignore 212
		TS.CloseTradeSkill()
	end
	-- the chosen recipe's reagents and output, refilled by Schematic: one kept table
	local schematic = { reagents = {}, outputItemID = nil, makes = 1 }
	TradeSkill.schematic = schematic
	--- A recipe's reagents (need and have) and what it makes: one kept table, refilled on each call.
	function TradeSkill:Schematic(id) -- luacheck: ignore 212
		local s = TS.GetRecipeSchematic(id, false)
		local reagents, n = schematic.reagents, 0
		if s then
			schematic.outputItemID, schematic.makes = s.outputItemID, s.quantityMin or 1
			local slots = s.reagentSlotSchematics
			for i = 1, #slots do
				local slot = slots[i]
				local first = slot.reagents and slot.reagents[1]
				if first and first.itemID and slot.required then
					n = n + 1
					local r = reagents[n] or {}
					reagents[n] = r
					r.itemID, r.need = first.itemID, slot.quantityRequired
					r.have = C_Item.GetItemCount(first.itemID)
				end
			end
		end
		for i = n + 1, #reagents do
			reagents[i] = nil
		end
		return schematic
	end
	local NO_REAGENTS = {}
	--- The recipe's description (what the made thing does), "" when it has none.
	function TradeSkill:Description(id) -- luacheck: ignore 212
		return TS.GetRecipeDescription(id, NO_REAGENTS) or ""
	end
	--- What the work needs (tools, an anvil, a fire): the game's list, each { name, met }.
	function TradeSkill:Requirements(id) -- luacheck: ignore 212
		return TS.GetRecipeRequirements(id)
	end
	--- Makes `count` of a recipe: only from a click (the game takes it from a hardware event).
	function TradeSkill:Craft(id, count) -- luacheck: ignore 212
		TS.CraftRecipe(id, count)
	end
	function TradeSkill:SetFavorite(id, on) -- luacheck: ignore 212
		TS.SetRecipeFavorite(id, on)
	end
	return TradeSkill
end

setmetatable(Game, {
	__index = function(game, key)
		local make = DOMAINS[key]
		if not make then
			return nil
		end
		local domain = make()
		rawset(game, key, domain)
		return domain
	end,
})

local GameMeta = { __index = Game }

--- A module's game: the shared one plus its own ui.
---@param module table
function Game.ForModule(module)
	local ui = ns.Draw.NewUi(module)
	local game = setmetatable({ ui = ui }, GameMeta)
	ui._game = game
	return game
end
