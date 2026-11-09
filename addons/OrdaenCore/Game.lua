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
-- the micro menu, the bag bar and the social button by the chat, under their own names (every one in the dump of 70862)
for _, name in ipairs({
	"CharacterMicroButton", "PlayerSpellsMicroButton", "SpellbookMicroButton", "TalentMicroButton",
	"ProfessionMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton",
	"CollectionsMicroButton", "EJMicroButton", "HousingMicroButton", "LegacyMicroButton", "MainMenuMicroButton",
	"HelpMicroButton", "StoreMicroButton", "MicroMenu", "MicroMenuContainer",
	"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
	"CharacterReagentBag0Slot", "BagBarExpandToggle", "BagsBar",
	"QuickJoinToastButton",
}) do
	FRAME_NAMES[name] = name
end
local FrameRef = {}
local FrameRefMeta = { __index = FrameRef }
function FrameRef:Get()
	return _G[self.global]
end

function DOMAINS.Frame()
	return setmetatable({}, {
		__index = function(frames, key)
			local global = FRAME_NAMES[key]
			if not global then
				return nil
			end
			local ref = setmetatable({ global = global }, FrameRefMeta)
			frames[key] = ref
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
	local Bags = { Signal = { Toggled = toggled, Changed = RawEvent("BAG_UPDATE_DELAYED") } }
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
