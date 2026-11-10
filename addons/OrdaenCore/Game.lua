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
local FRAME_NAMES = { CombinedBags = "ContainerFrameCombinedBags", Minimap = "Minimap", Merchant = "MerchantFrame" }
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
	"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5",
	"MultiBar6", "MultiBar7",
}) do
	FRAME_NAMES[name] = name
end
-- regions without a global name, as their frame's parentKey: { global, key }
local FRAME_KEYS = {
	-- the backpack's free slots, "(23)" under its icon (seen in game: the dev addon's "bag button" probe)
	BackpackFreeSlots = { "MainMenuBarBackpackButton", "FreeSlots" },
}
local FrameRef = {}
local FrameRefMeta = { __index = FrameRef }
function FrameRef:Get()
	local found = _G[self.global]
	if found and self.key then
		return found[self.key]
	end
	return found
end

function DOMAINS.Frame()
	return setmetatable({}, {
		__index = function(frames, key)
			local global, child = FRAME_NAMES[key], nil
			local path = FRAME_KEYS[key]
			if path then
				global, child = path[1], path[2]
			end
			if not global then
				return nil
			end
			local ref = setmetatable({ global = global, key = child }, FrameRefMeta)
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
function DOMAINS.Ordaen()
	local _, title = C_AddOns.GetAddOnInfo("OrdaenCore")
	return { title = title, icon = C_AddOns.GetAddOnMetadata("OrdaenCore", "IconTexture") }
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

-- Read now if the character is in the world, and again at each login.
local function AtLogin(fn)
	Game.Stage.Login:Subscribe(fn, false)
	if Game.Stage.Login.fired then
		fn()
	end
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

function DOMAINS.Situation()
	-- value signals of what the player is doing, for what shows or hides by it (Ordaen Panel's visibility)
	local Situation = { combat = NewValue(false), resting = NewValue(false), vehicle = NewValue(false),
		petBattle = NewValue(false) }
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
	end)
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
	local Location = { zone = NewValue("") }
	local function Read()
		Location.zone:Set(GetMinimapZoneText() or "")
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
