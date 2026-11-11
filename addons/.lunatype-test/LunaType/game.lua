-- The game's side of `"$game"`: `src/game` compiled, one file after another. Written by tests/run/game.lua:
-- change the source, not this file.
do
-- Made by lunatype from LunaTypeGame/bags.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __event, __listen, __emit, __class = R.set, R.cell, R.event, R.listen, R.emit, R.class
local __insert = table.insert
local __events_BAG_UPDATE_DELAYED = R.events.BAG_UPDATE_DELAYED
local __events_PLAYER_ENTERING_WORLD = R.events.PLAYER_ENTERING_WORLD
local __math_floor = R.math.floor
local __client__C_Container_CalculateTotalNumberOfFreeBagSlots = R.client.C_Container.CalculateTotalNumberOfFreeBagSlots
local __client__C_Container_GetContainerNumFreeSlots = R.client.C_Container.GetContainerNumFreeSlots
local __client__C_Container_GetContainerNumSlots = R.client.C_Container.GetContainerNumSlots
local __client__C_Container_GetContainerItemInfo = R.client.C_Container.GetContainerItemInfo
local __client__C_Item_GetItemQualityColor = R.client.C_Item.GetItemQualityColor
local __client__C_Item_GetItemInfo = R.client.C_Item.GetItemInfo
local M = {}
R.addon("LunaTypeGame")["bags"] = M
local lastBag, Bags
lastBag = 4

Bags = __class({})

function Bags.new(__owner)
	local self = setmetatable({}, Bags)
	R.adopt(__owner, self)
	self.changed = __event()
	self.free = __cell(0)
	__listen(__events_BAG_UPDATE_DELAYED, self, self.read)
	__listen(__events_PLAYER_ENTERING_WORLD, self, self.read)
	self:read()
	return self
end

function Bags:read()
	__set(self.free, __math_floor(__client__C_Container_CalculateTotalNumberOfFreeBagSlots()))
	__emit(self.changed)
end

function Bags:roomOf(bag)
	local free = __client__C_Container_GetContainerNumFreeSlots(bag)
	return { free = __math_floor(free), slots = __math_floor(__client__C_Container_GetContainerNumSlots(bag)) }
end

function Bags:roomOfAll()
	local free = 0
	local slots = 0
	for bag = 0, 4 do
		local room = self:roomOf(bag)
		free = free + room.free
		slots = slots + room.slots
	end
	return { free = free, slots = slots }
end

function Bags:junk()
	local items = {}
	for bag = 0, 4 do
		local slots = __math_floor(__client__C_Container_GetContainerNumSlots(bag))
		for slot = 1, slots do
			local info = __client__C_Container_GetContainerItemInfo(bag, slot)
			if info ~= nil and info.quality == 0 and not info.hasNoValue then
				local r, g, b = __client__C_Item_GetItemQualityColor(0)
				__insert(items, { id = __math_floor(info.itemID), name = info.itemName, price = Bags.priceOf(info.hyperlink), quality = 0, qualityColor = { r = r, g = g, b = b, a = 1 } })
			end
		end
	end
	return items
end

function Bags.priceOf(link)
	local n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, price = __client__C_Item_GetItemInfo(link)
	return __math_floor(price or 0)
end

M.lastBag = lastBag
M.Bags = Bags
end
do
-- Made by lunatype from LunaTypeGame/clock.luna: change the source, not this file.
local R = LunaType
local __get, __set, __cell, __computed, __listen, __class = R.get, R.set, R.cell, R.computed, R.listen, R.class
local __runtime_ticker = R.runtime.ticker
local __runtime_time = R.runtime.time
local __events_CALENDAR_UPDATE_PENDING_INVITES = R.events.CALENDAR_UPDATE_PENDING_INVITES
local __client_ToggleCalendar = R.client.ToggleCalendar
local __client_GetGameTime = R.client.GetGameTime
local __client__C_CVar_GetCVarBool = R.client.C_CVar.GetCVarBool
local __client__C_DateAndTime_GetCurrentCalendarTime = R.client.C_DateAndTime.GetCurrentCalendarTime
local __string_format = R.string.format
local __math_floor = R.math.floor
local __client__C_Calendar_GetNumPendingInvites = R.client.C_Calendar.GetNumPendingInvites
local M = {}
R.addon("LunaTypeGame")["clock"] = M
local Clock

local function __c1(self)
	return self:read()
end


Clock = __class({})

function Clock.new(__owner)
	local self = setmetatable({}, Clock)
	R.adopt(__owner, self)
	self.seconds = __runtime_ticker(1)
	self.time = __runtime_time()
	self.text = __computed(self, __c1, self)
	self.invites = __cell(0)
	__listen(__events_CALENDAR_UPDATE_PENDING_INVITES, self, self.readInvites)
	self:readInvites()
	return self
end

function Clock:toggleCalendar()
	__client_ToggleCalendar()
end

function Clock:read()
	local _ = __get(self.seconds)
	local hour, minute = __client_GetGameTime()
	if __client__C_CVar_GetCVarBool("timeMgrUseLocalTime") == true then
		local now = __client__C_DateAndTime_GetCurrentCalendarTime()
		hour = now.hour
		minute = now.minute
	end
	if __client__C_CVar_GetCVarBool("timeMgrUseMilitaryTime") == true then
		return __string_format("%02d:%02d", hour, minute)
	end
	local __t2
	if hour < 12 then
		__t2 = "AM"
	else
		__t2 = "PM"
	end
	return __string_format("%d:%02d %s", (hour - 1) % 12 + 1, minute, __t2)
end

function Clock:readInvites()
	__set(self.invites, __math_floor(__client__C_Calendar_GetNumPendingInvites()))
end

M.Clock = Clock
end
do
-- Made by lunatype from LunaTypeGame/colorPicker.luna: change the source, not this file.
local R = LunaType
local __event, __emit, __class = R.event, R.emit, R.class
local __client_ColorPickerFrame = R.client.ColorPickerFrame
local M = {}
R.addon("LunaTypeGame")["colorPicker"] = M
local ColorPicker

ColorPicker = __class({})

function ColorPicker.new(__owner)
	local self = setmetatable({}, ColorPicker)
	R.adopt(__owner, self)
	self.picked = __event()
	self.cancelled = __event()
	self.openings = 0
	return self
end

function ColorPicker:open(color)
	self.openings = self.openings + 1
	local ticket = self.openings
	__client_ColorPickerFrame:SetupColorPickerAndShow({ r = color.r, g = color.g, b = color.b, hasOpacity = false, swatchFunc = function()
		return self:tried(ticket)
	end, cancelFunc = function()
		return __emit(self.cancelled, ticket)
	end })
	return ticket
end

function ColorPicker:tried(ticket)
	local r, g, b = __client_ColorPickerFrame:GetColorRGB()
	__emit(self.picked, ticket, { r = r, g = g, b = b, a = 1 })
end

M.ColorPicker = ColorPicker
end
do
-- Made by lunatype from LunaTypeGame/frames.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __listen, __class = R.set, R.cell, R.listen, R.class
local __runtime_frame = R.runtime.frame
local __events_ADDON_LOADED = R.events.ADDON_LOADED
local M = {}
R.addon("LunaTypeGame")["frames"] = M
local Frames

Frames = __class({})

function Frames.new(__owner)
	local self = setmetatable({}, Frames)
	R.adopt(__owner, self)
	self.MinimapCluster = __cell(__runtime_frame("MinimapCluster"))
	self.MinimapBackdrop = __cell(__runtime_frame("MinimapBackdrop"))
	self.MinimapTrackingButton = __cell(__runtime_frame("MinimapCluster.Tracking.Button"))
	self.MinimapMail = __cell(__runtime_frame("MinimapCluster.IndicatorFrame.MailFrame"))
	self.MinimapCraftingOrder = __cell(__runtime_frame("MinimapCluster.IndicatorFrame.CraftingOrderFrame"))
	self.ExpansionLandingPageMinimapButton = __cell(__runtime_frame("ExpansionLandingPageMinimapButton"))
	self.OrdaenDevButton = __cell(__runtime_frame("OrdaenDevButton"))
	self.Professions = __cell(__runtime_frame("ProfessionsFrame"))
	self.MicroMenuContainer = __cell(__runtime_frame("MicroMenuContainer"))
	self.CharacterMicroButton = __cell(__runtime_frame("CharacterMicroButton"))
	self.ProfessionMicroButton = __cell(__runtime_frame("ProfessionMicroButton"))
	self.SpellbookMicroButton = __cell(__runtime_frame("SpellbookMicroButton"))
	self.TalentMicroButton = __cell(__runtime_frame("TalentMicroButton"))
	self.LegacyMicroButton = __cell(__runtime_frame("LegacyMicroButton"))
	self.QuestLogMicroButton = __cell(__runtime_frame("QuestLogMicroButton"))
	self.LFDMicroButton = __cell(__runtime_frame("LFDMicroButton"))
	self.CollectionsMicroButton = __cell(__runtime_frame("CollectionsMicroButton"))
	self.MainMenuMicroButton = __cell(__runtime_frame("MainMenuMicroButton"))
	self.GuildMicroButton = __cell(__runtime_frame("GuildMicroButton"))
	self.StoreMicroButton = __cell(__runtime_frame("StoreMicroButton"))
	self.HelpMicroButton = __cell(__runtime_frame("HelpMicroButton"))
	self.QuickJoinToastButton = __cell(__runtime_frame("QuickJoinToastButton"))
	self.BagsBar = __cell(__runtime_frame("BagsBar"))
	self.MainMenuBarBackpackButton = __cell(__runtime_frame("MainMenuBarBackpackButton"))
	self.BackpackFreeSlots = __cell(__runtime_frame("MainMenuBarBackpackButton.FreeSlots"))
	self.CharacterBag0Slot = __cell(__runtime_frame("CharacterBag0Slot"))
	self.CharacterBag1Slot = __cell(__runtime_frame("CharacterBag1Slot"))
	self.CharacterBag2Slot = __cell(__runtime_frame("CharacterBag2Slot"))
	self.CharacterBag3Slot = __cell(__runtime_frame("CharacterBag3Slot"))
	self.MainStatusTrackingBarContainer = __cell(__runtime_frame("MainStatusTrackingBarContainer"))
	self.SecondaryStatusTrackingBarContainer = __cell(__runtime_frame("SecondaryStatusTrackingBarContainer"))
	__listen(__events_ADDON_LOADED, self, self.late)
	return self
end

function Frames:late()
	__set(self.ExpansionLandingPageMinimapButton, __runtime_frame("ExpansionLandingPageMinimapButton"))
	__set(self.OrdaenDevButton, __runtime_frame("OrdaenDevButton"))
	__set(self.Professions, __runtime_frame("ProfessionsFrame"))
end

M.Frames = Frames
end
do
-- Made by lunatype from LunaTypeGame/friends.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __listen, __class = R.set, R.cell, R.listen, R.class
local __events_PLAYER_ENTERING_WORLD = R.events.PLAYER_ENTERING_WORLD
local __events_FRIENDLIST_UPDATE = R.events.FRIENDLIST_UPDATE
local __events_BN_FRIEND_ACCOUNT_ONLINE = R.events.BN_FRIEND_ACCOUNT_ONLINE
local __events_BN_FRIEND_ACCOUNT_OFFLINE = R.events.BN_FRIEND_ACCOUNT_OFFLINE
local __events_BN_FRIEND_INFO_CHANGED = R.events.BN_FRIEND_INFO_CHANGED
local __events_BN_CONNECTED = R.events.BN_CONNECTED
local __events_BN_DISCONNECTED = R.events.BN_DISCONNECTED
local __client_BNGetNumFriends = R.client.BNGetNumFriends
local __math_floor = R.math.floor
local __client__C_FriendList_GetNumOnlineFriends = R.client.C_FriendList.GetNumOnlineFriends
local M = {}
R.addon("LunaTypeGame")["friends"] = M
local Friends

Friends = __class({})

function Friends.new(__owner)
	local self = setmetatable({}, Friends)
	R.adopt(__owner, self)
	self.online = __cell(0)
	__listen(__events_PLAYER_ENTERING_WORLD, self, self.read)
	__listen(__events_FRIENDLIST_UPDATE, self, self.read)
	__listen(__events_BN_FRIEND_ACCOUNT_ONLINE, self, self.read)
	__listen(__events_BN_FRIEND_ACCOUNT_OFFLINE, self, self.read)
	__listen(__events_BN_FRIEND_INFO_CHANGED, self, self.read)
	__listen(__events_BN_CONNECTED, self, self.read)
	__listen(__events_BN_DISCONNECTED, self, self.read)
	self:read()
	return self
end

function Friends:read()
	local all, battleNet = __client_BNGetNumFriends()
	__set(self.online, __math_floor(__client__C_FriendList_GetNumOnlineFriends() + battleNet))
end

M.Friends = Friends
end
do
-- Made by lunatype from LunaTypeGame/money.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __listen, __class = R.set, R.cell, R.listen, R.class
local __events_PLAYER_MONEY = R.events.PLAYER_MONEY
local __events_PLAYER_ENTERING_WORLD = R.events.PLAYER_ENTERING_WORLD
local __events_CURRENCY_DISPLAY_UPDATE = R.events.CURRENCY_DISPLAY_UPDATE
local __client__C_CurrencyInfo_GetCoinTextureString = R.client.C_CurrencyInfo.GetCoinTextureString
local __math_floor = R.math.floor
local __client_GetMoney = R.client.GetMoney
local __client__C_CurrencyInfo_GetBackpackCurrencyInfo = R.client.C_CurrencyInfo.GetBackpackCurrencyInfo
local __client_BreakUpLargeNumbers = R.client.BreakUpLargeNumbers
local M = {}
R.addon("LunaTypeGame")["money"] = M
local Money

Money = __class({})

function Money.new(__owner)
	local self = setmetatable({}, Money)
	R.adopt(__owner, self)
	self.amount = __cell(0)
	self.tracked = __cell("")
	__listen(__events_PLAYER_MONEY, self, self.readAmount)
	__listen(__events_PLAYER_ENTERING_WORLD, self, self.readAll)
	__listen(__events_CURRENCY_DISPLAY_UPDATE, self, self.readTracked)
	self:readAll()
	return self
end

function Money:format(copper)
	return __client__C_CurrencyInfo_GetCoinTextureString(copper, nil)
end

function Money:readAll()
	self:readAmount()
	self:readTracked()
end

function Money:readAmount()
	__set(self.amount, __math_floor(__client_GetMoney()))
end

function Money:readTracked()
	local text = ""
	for i = 1, 3 do
		local info = __client__C_CurrencyInfo_GetBackpackCurrencyInfo(i)
		if info == nil then
			break
		end
		if text ~= "" then
			text = text .. "  "
		end
		text = text .. __client_BreakUpLargeNumbers(info.quantity, nil) .. " |T" .. info.iconFileID .. ":0|t"
	end
	__set(self.tracked, text)
end

M.Money = Money
end
do
-- Made by lunatype from LunaTypeGame/player.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __listen, __class = R.set, R.cell, R.listen, R.class
local __client_UnitClass = R.client.UnitClass
local __events_PLAYER_ENTERING_WORLD = R.events.PLAYER_ENTERING_WORLD
local __events_PLAYER_XP_UPDATE = R.events.PLAYER_XP_UPDATE
local __events_UPDATE_EXHAUSTION = R.events.UPDATE_EXHAUSTION
local __events_PLAYER_LEVEL_UP = R.events.PLAYER_LEVEL_UP
local __math_floor = R.math.floor
local __client_UnitLevel = R.client.UnitLevel
local __client_UnitXP = R.client.UnitXP
local __client_UnitXPMax = R.client.UnitXPMax
local __client_GetXPExhaustion = R.client.GetXPExhaustion
local M = {}
R.addon("LunaTypeGame")["player"] = M
local Player

Player = __class({})

function Player.new(__owner)
	local self = setmetatable({}, Player)
	R.adopt(__owner, self)
	self.level = __cell(0)
	self.xp = __cell(0)
	self.xpMax = __cell(0)
	self.rested = __cell(0)
	local name, tag = __client_UnitClass("player")
	self.classTag = tag or ""
	__listen(__events_PLAYER_ENTERING_WORLD, self, self.read)
	__listen(__events_PLAYER_XP_UPDATE, self, self.read)
	__listen(__events_UPDATE_EXHAUSTION, self, self.read)
	__listen(__events_PLAYER_LEVEL_UP, self, self["levelled$PLAYER_LEVEL_UP_Payload"])
	self:read()
	return self
end

function Player:read()
	__set(self.level, __math_floor(__client_UnitLevel("player")))
	__set(self.xp, __math_floor(__client_UnitXP("player")))
	__set(self.xpMax, __math_floor(__client_UnitXPMax("player")))
	__set(self.rested, __math_floor(__client_GetXPExhaustion() or 0))
end

function Player:levelled(up)
	self:read()
	__set(self.level, __math_floor(up.level))
end

Player["levelled$PLAYER_LEVEL_UP_Payload"] = function(self, __up_level, __up_healthDelta, __up_powerDelta, __up_numNewTalents, __up_numNewPvpTalentSlots, __up_strengthDelta, __up_agilityDelta, __up_staminaDelta, __up_intellectDelta, __up_spiritDelta)
	self:read()
	__set(self.level, __math_floor(__up_level))
end

M.Player = Player
end
do
-- Made by lunatype from LunaTypeGame/professions.luna: change the source, not this file.
local R = LunaType
local __peek, __set, __cell, __event, __listen, __emit, __class = R.peek, R.set, R.cell, R.event, R.listen, R.emit, R.class
local __insert = table.insert
local __events_PLAYER_ENTERING_WORLD = R.events.PLAYER_ENTERING_WORLD
local __events_SKILL_LINES_CHANGED = R.events.SKILL_LINES_CHANGED
local __client_GetProfessions = R.client.GetProfessions
local __client_GetProfessionInfo = R.client.GetProfessionInfo
local __runtime_picture = R.runtime.picture
local __events_TRADE_SKILL_SHOW = R.events.TRADE_SKILL_SHOW
local __events_TRADE_SKILL_CLOSE = R.events.TRADE_SKILL_CLOSE
local __events_TRADE_SKILL_LIST_UPDATE = R.events.TRADE_SKILL_LIST_UPDATE
local __events_BAG_UPDATE_DELAYED = R.events.BAG_UPDATE_DELAYED
local __events_ADDON_LOADED = R.events.ADDON_LOADED
local __runtime_whenShown = R.runtime.whenShown
local __client__C_TradeSkillUI_GetCategories = R.client.C_TradeSkillUI.GetCategories
local __client__C_TradeSkillUI_GetCategoryInfo = R.client.C_TradeSkillUI.GetCategoryInfo
local __math_floor = R.math.floor
local __client__C_TradeSkillUI_GetSubCategories = R.client.C_TradeSkillUI.GetSubCategories
local __client__C_TradeSkillUI_GetAllRecipeIDs = R.client.C_TradeSkillUI.GetAllRecipeIDs
local __client__C_TradeSkillUI_GetRecipeInfo = R.client.C_TradeSkillUI.GetRecipeInfo
local __client__C_TradeSkillUI_GetCraftableCount = R.client.C_TradeSkillUI.GetCraftableCount
local __client__C_TradeSkillUI_OpenTradeSkill = R.client.C_TradeSkillUI.OpenTradeSkill
local __runtime_frame = R.runtime.frame
local __client_HideUIPanel = R.client.HideUIPanel
local __client__C_TradeSkillUI_CloseTradeSkill = R.client.C_TradeSkillUI.CloseTradeSkill
local __client__C_TradeSkillUI_GetRecipeDescription = R.client.C_TradeSkillUI.GetRecipeDescription
local __client__C_TradeSkillUI_GetRecipeRequirements = R.client.C_TradeSkillUI.GetRecipeRequirements
local __client__C_TradeSkillUI_GetRecipeSchematic = R.client.C_TradeSkillUI.GetRecipeSchematic
local __client__C_Item_GetItemNameByID = R.client.C_Item.GetItemNameByID
local __client__C_Item_GetItemIconByID = R.client.C_Item.GetItemIconByID
local __client__C_Item_GetItemCount = R.client.C_Item.GetItemCount
local __client__C_TradeSkillUI_CraftRecipe = R.client.C_TradeSkillUI.CraftRecipe
local M = {}
R.addon("LunaTypeGame")["professions"] = M
local gathers, Professions, TradeSkill

function gathers(skillLine)
	return skillLine == 182 or skillLine == 186 or skillLine == 393
end

Professions = __class({})

function Professions.new(__owner)
	local self = setmetatable({}, Professions)
	R.adopt(__owner, self)
	self.list = __cell({})
	__listen(__events_PLAYER_ENTERING_WORLD, self, self.read)
	__listen(__events_SKILL_LINES_CHANGED, self, self.read)
	self:read()
	return self
end

function Professions:read()
	local list = {}
	local first, second, third, fourth, fifth, sixth = __client_GetProfessions()
	Professions.add(list, first)
	Professions.add(list, second)
	Professions.add(list, third)
	Professions.add(list, fourth)
	Professions.add(list, fifth)
	Professions.add(list, sixth)
	__set(self.list, list)
end

function Professions.add(list, index)
	if index == nil then
		return
	end
	local name, icon, rank, max, abilities, offset, skillLine = __client_GetProfessionInfo(index)
	local __t1
	if gathers(skillLine) then
		__t1 = "gathering"
	else
		__t1 = "crafting"
	end
	__insert(list, { skillLine = skillLine, name = name, icon = __runtime_picture(icon), rank = rank, max = max, kind = __t1 })
end

TradeSkill = __class({})

function TradeSkill.new(__owner)
	local self = setmetatable({}, TradeSkill)
	R.adopt(__owner, self)
	self.open = __cell(nil)
	self.categories = __cell({})
	self.recipes = __cell({})
	self.shownEmpty = __event()
	self.hooked = false
	__listen(__events_TRADE_SKILL_SHOW, self, self.shown)
	__listen(__events_TRADE_SKILL_CLOSE, self, self.closed)
	__listen(__events_TRADE_SKILL_LIST_UPDATE, self, self.refill)
	__listen(__events_BAG_UPDATE_DELAYED, self, self.recount)
	__listen(__events_ADDON_LOADED, self, self.hook)
	self:hook()
	return self
end

function TradeSkill:hook()
	if self.hooked then
		return
	end
	self.hooked = __runtime_whenShown("ProfessionsFrame", function()
		return self:windowShown()
	end)
end

function TradeSkill:windowShown()
	if __peek(self.open) == nil then
		__emit(self.shownEmpty)
	end
end

function TradeSkill:shown()
	__set(self.open, self:readCategories() or 0)
	self:readRecipes()
end

function TradeSkill:closed()
	__set(self.open, nil)
end

function TradeSkill:refill()
	if __peek(self.open) == nil then
		return
	end
	local skillLine = self:readCategories()
	if skillLine ~= nil then
		__set(self.open, skillLine)
	end
	self:readRecipes()
end

function TradeSkill:recount()
	if __peek(self.open) ~= nil then
		self:readRecipes()
	end
end

function TradeSkill:readCategories()
	local list = {}
	local skillLine = nil
	local __l3 = { __client__C_TradeSkillUI_GetCategories() }
	for __i2 = 1, #__l3 do
		local header = __l3[__i2]
		local info = __client__C_TradeSkillUI_GetCategoryInfo(header)
		if info ~= nil then
			if skillLine == nil then
				skillLine = __math_floor(info.skillLineID)
			end
			local parent = __math_floor(info.categoryID)
			__insert(list, { id = parent, name = info.name, parentID = nil })
			local __l5 = { __client__C_TradeSkillUI_GetSubCategories(header) }
			for __i4 = 1, #__l5 do
				local under = __l5[__i4]
				local sub = __client__C_TradeSkillUI_GetCategoryInfo(under)
				if sub ~= nil then
					__insert(list, { id = __math_floor(sub.categoryID), name = sub.name, parentID = parent })
				end
			end
		end
	end
	__set(self.categories, list)
	return skillLine
end

function TradeSkill:readRecipes()
	local list = {}
	local __l7 = __client__C_TradeSkillUI_GetAllRecipeIDs()
	for __i6 = 1, #__l7 do
		local id = __l7[__i6]
		local info = __client__C_TradeSkillUI_GetRecipeInfo(id, nil)
		if info ~= nil then
			local __t8
			if info.learned then
				__t8 = __math_floor(__client__C_TradeSkillUI_GetCraftableCount(info.recipeID, nil))
			else
				__t8 = 0
			end
			__insert(list, { id = __math_floor(info.recipeID), name = info.name, icon = __runtime_picture(info.icon or 0), categoryID = __math_floor(info.categoryID), learned = info.learned, difficulty = TradeSkill.difficultyOf(info.relativeDifficulty), craftable = __t8 })
		end
	end
	__set(self.recipes, list)
end

function TradeSkill.difficultyOf(relative)
	if relative == 0 then
		return 0
	elseif relative == 1 then
		return 1
	elseif relative == 2 then
		return 2
	else
		return 3
	end
end

function TradeSkill:show(skillLine)
	__client__C_TradeSkillUI_OpenTradeSkill(skillLine)
end

function TradeSkill:close()
	local window = __runtime_frame("ProfessionsFrame")
	if window ~= nil and window:IsShown() then
		__client_HideUIPanel(window)
	end
	__client__C_TradeSkillUI_CloseTradeSkill()
end

function TradeSkill:description(recipe)
	return __client__C_TradeSkillUI_GetRecipeDescription(recipe, {}, nil)
end

function TradeSkill:requirements(recipe)
	local list = {}
	local __l10 = __client__C_TradeSkillUI_GetRecipeRequirements(recipe)
	for __i9 = 1, #__l10 do
		local requirement = __l10[__i9]
		__insert(list, { name = requirement.name, met = requirement.met })
	end
	return list
end

function TradeSkill:reagents(recipe)
	local list = {}
	local schematic = __client__C_TradeSkillUI_GetRecipeSchematic(recipe, false, nil)
	local __l12 = schematic.reagentSlotSchematics
	for __i11 = 1, #__l12 do
		local slot = __l12[__i11]
		local __t13 = slot.reagents[1]
		local __t14
		if __t13 ~= nil then __t14 = __t13.itemID end
		local found = __t14
		if found ~= nil and slot.required then
			local itemID = __math_floor(found)
			__insert(list, { name = __client__C_Item_GetItemNameByID(itemID) or "", icon = __runtime_picture(__client__C_Item_GetItemIconByID(itemID) or 0), have = __math_floor(__client__C_Item_GetItemCount(itemID, nil, nil, nil, nil)), need = __math_floor(slot.quantityRequired) })
		end
	end
	return list
end

function TradeSkill:craft(recipe, count)
	__client__C_TradeSkillUI_CraftRecipe(recipe, count, nil, nil, nil, nil)
end

M.gathers = gathers
M.Professions = Professions
M.TradeSkill = TradeSkill
end
do
-- Made by lunatype from LunaTypeGame/reputation.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __listen, __class = R.set, R.cell, R.listen, R.class
local __events_PLAYER_ENTERING_WORLD = R.events.PLAYER_ENTERING_WORLD
local __events_UPDATE_FACTION = R.events.UPDATE_FACTION
local __client__C_Reputation_GetWatchedFactionData = R.client.C_Reputation.GetWatchedFactionData
local __math_floor = R.math.floor
local __runtime_text = R.runtime.text
local __client__C_Reputation_GetNumFactions = R.client.C_Reputation.GetNumFactions
local __client__C_Reputation_GetFactionDataByIndex = R.client.C_Reputation.GetFactionDataByIndex
local M = {}
R.addon("LunaTypeGame")["reputation"] = M
local Reputation

Reputation = __class({})

function Reputation.new(__owner)
	local self = setmetatable({}, Reputation)
	R.adopt(__owner, self)
	self.name = __cell("")
	self.standing = __cell("")
	self.value = __cell(0)
	self.min = __cell(0)
	self.max = __cell(0)
	__listen(__events_PLAYER_ENTERING_WORLD, self, self.read)
	__listen(__events_UPDATE_FACTION, self, self.read)
	self:read()
	return self
end

function Reputation:read()
	local data = __client__C_Reputation_GetWatchedFactionData()
	if data == nil or data.name == "" then
		__set(self.name, "")
		return
	end
	__set(self.name, data.name)
	__set(self.standing, Reputation.label(data.reaction))
	__set(self.min, __math_floor(data.currentReactionThreshold))
	__set(self.max, __math_floor(data.nextReactionThreshold))
	__set(self.value, __math_floor(data.currentStanding))
end

function Reputation.label(reaction)
	return __runtime_text("FACTION_STANDING_LABEL" .. reaction) or ""
end

function Reputation:with(faction)
	local count = __math_floor(__client__C_Reputation_GetNumFactions())
	for i = 1, count do
		local data = __client__C_Reputation_GetFactionDataByIndex(i)
		if data ~= nil and data.name == faction and not data.isHeader then
			return { rank = data.reaction, label = Reputation.label(data.reaction) }
		end
	end
	return nil
end

M.Reputation = Reputation
end
do
-- Made by lunatype from LunaTypeGame/input.luna: change the source, not this file.
local R = LunaType
local __class = R.class
local __client_IsShiftKeyDown = R.client.IsShiftKeyDown
local M = {}
R.addon("LunaTypeGame")["input"] = M
local Input

Input = __class({})

function Input.new(__owner)
	local self = setmetatable({}, Input)
	R.adopt(__owner, self)
	return self
end

function Input:shiftDown()
	return __client_IsShiftKeyDown()
end

M.Input = Input
end
do
-- Made by lunatype from LunaTypeGame/location.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __listen, __class = R.set, R.cell, R.listen, R.class
local __events_ZONE_CHANGED = R.events.ZONE_CHANGED
local __events_ZONE_CHANGED_INDOORS = R.events.ZONE_CHANGED_INDOORS
local __events_ZONE_CHANGED_NEW_AREA = R.events.ZONE_CHANGED_NEW_AREA
local __client_GetMinimapZoneText = R.client.GetMinimapZoneText
local __client_GetRealZoneText = R.client.GetRealZoneText
local __client__C_PvP_GetZonePVPInfo = R.client.C_PvP.GetZonePVPInfo
local M = {}
R.addon("LunaTypeGame")["location"] = M
local Location

Location = __class({})

function Location.new(__owner)
	local self = setmetatable({}, Location)
	R.adopt(__owner, self)
	self.zone = __cell("")
	self.realZone = __cell("")
	self.pvp = __cell(nil)
	__listen(__events_ZONE_CHANGED, self, self.read)
	__listen(__events_ZONE_CHANGED_INDOORS, self, self.read)
	__listen(__events_ZONE_CHANGED_NEW_AREA, self, self.read)
	self:read()
	return self
end

function Location:read()
	__set(self.zone, __client_GetMinimapZoneText())
	__set(self.realZone, __client_GetRealZoneText(nil))
	local kind = __client__C_PvP_GetZonePVPInfo()
	__set(self.pvp, Location.pvpOf(kind))
end

function Location.pvpOf(kind)
	if kind == "sanctuary" then
		return "sanctuary"
	elseif kind == "friendly" then
		return "friendly"
	elseif kind == "hostile" then
		return "hostile"
	elseif kind == "contested" then
		return "contested"
	elseif kind == "combat" or kind == "arena" then
		return "combat"
	end
	return nil
end

M.Location = Location
end
do
-- Made by lunatype from LunaTypeGame/minimap.luna: change the source, not this file.
local R = LunaType
local __get, __peek, __set, __cell, __computed, __listen, __class = R.get, R.peek, R.set, R.cell, R.computed, R.listen, R.class
local __insert = table.insert
local __sort = table.sort
local __runtime_frame = R.runtime.frame
local __runtime_ticker = R.runtime.ticker
local __events_PLAYER_ENTERING_WORLD = R.events.PLAYER_ENTERING_WORLD
local __events_ADDON_LOADED = R.events.ADDON_LOADED
local __client_Minimap = R.client.Minimap
local __runtime_publish = R.runtime.publish
local __client__C_Map_GetBestMapForUnit = R.client.C_Map.GetBestMapForUnit
local __client__C_Map_GetPlayerMapPosition = R.client.C_Map.GetPlayerMapPosition
local __string_format = R.string.format
local __client_GetMinimapZoneText = R.client.GetMinimapZoneText
local __client__ChatFrameUtil_InsertLink = R.client.ChatFrameUtil.InsertLink
local __client__ChatFrameUtil_OpenChat = R.client.ChatFrameUtil.OpenChat
local __client_MinimapCluster = R.client.MinimapCluster
local __client_AddonCompartmentFrame = R.client.AddonCompartmentFrame
local __string_find = R.string.find
local __string_lower = R.string.lower
local __runtime_press = R.runtime.press
local __runtime_hover = R.runtime.hover
local M = {}
R.addon("LunaTypeGame")["minimap"] = M
local roundMask, squareMask, Minimap

local function __c1(self)
	return self:place()
end

roundMask = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
squareMask = "Interface\\Buttons\\WHITE8X8"

Minimap = __class({})

function Minimap.new(__owner)
	local self = setmetatable({}, Minimap)
	R.adopt(__owner, self)
	self.frame = __cell(__runtime_frame("Minimap"))
	self.buttons = __cell({})
	self.entries = __cell({})
	self.half = __runtime_ticker(0.5)
	self.coords = __computed(self, __c1, self)
	self.names = {}
	__listen(__events_PLAYER_ENTERING_WORLD, self, self.look)
	__listen(__events_ADDON_LOADED, self, self.look)
	self:look()
	return self
end

function Minimap:square(on)
	local map = __client_Minimap
	local __t2
	if on then
		__t2 = "Interface\\Buttons\\WHITE8X8"
	else
		__t2 = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
	end
	map:SetMaskTexture(__t2)
	local __t3
	if on then
		__t3 = 0
	else
		__t3 = 1
	end
	local scalar = __t3
	map:SetArchBlobRingScalar(scalar)
	map:SetQuestBlobRingScalar(scalar)
	map:SetTaskBlobRingScalar(scalar)
	if on then
		__runtime_publish("GetMinimapShape", function()
			return "SQUARE"
		end)
	else
		__runtime_publish("GetMinimapShape", nil)
	end
end

function Minimap:wheelZoom()
	local map = __client_Minimap
	if map:GetScript("OnMouseWheel", nil) ~= nil then
		return
	end
	map:EnableMouseWheel(true)
	map:SetScript("OnMouseWheel", function(frame, delta)
		return self:zoom(delta)
	end)
end

function Minimap:zoom(delta)
	local map = __client_Minimap
	local __t4
	if delta > 0 then
		__t4 = 1
	else
		__t4 = -1
	end
	local zoom = map:GetZoom() + __t4
	if zoom >= 0 and zoom < map:GetZoomLevels() then
		map:SetZoom(zoom)
	end
end

function Minimap:place()
	local _ = __get(self.half)
	local id = __client__C_Map_GetBestMapForUnit("player")
	if id == nil then
		return ""
	end
	local at = __client__C_Map_GetPlayerMapPosition(id, "player")
	if at == nil then
		return ""
	end
	return __string_format("%.1f, %.1f", at.x * 100, at.y * 100)
end

function Minimap:sendCoords()
	local coords = __peek(self.coords)
	if coords == "" then
		return
	end
	local text = __client_GetMinimapZoneText() .. " (" .. coords .. ")"
	if not __client__ChatFrameUtil_InsertLink(text) then
		__client__ChatFrameUtil_OpenChat(text)
	end
end

function Minimap:look()
	self:scan(__client_Minimap)
	self:scan(__client_MinimapCluster)
	local compartment = __client_AddonCompartmentFrame
	if compartment == nil then
		return
	end
	local entries = {}
	local __l6 = compartment.registeredAddons
	for __i5 = 1, #__l6 do
		local entry = __l6[__i5]
		__insert(entries, { text = entry.text, icon = entry.icon })
	end
	__set(self.entries, entries)
end

function Minimap:scan(parent)
	local changed = false
	local __l8 = { parent:GetChildren() }
	for __i7 = 1, #__l8 do
		local child = __l8[__i7]
		local name = child:GetName()
		if name ~= nil and Minimap.isAddonButton(name) and not self:known(name) then
			__insert(self.names, name)
			changed = true
		end
	end
	if not changed then
		return
	end
	__sort(self.names, function(first, second)
		return first < second
	end)
	local buttons = {}
	local __l10 = self.names
	for __i9 = 1, #__l10 do
		local name = __l10[__i9]
		local button = __runtime_frame(name)
		if button ~= nil then
			__insert(buttons, button)
		end
	end
	__set(self.buttons, buttons)
end

function Minimap:known(name)
	local __l12 = self.names
	for __i11 = 1, #__l12 do
		local known = __l12[__i11]
		if known == name then
			return true
		end
	end
	return false
end

function Minimap.isAddonButton(name)
	if __string_find(name, "^Ordaen") ~= nil then
		return false
	end
	if __string_find(name, "^LibDBIcon10_") ~= nil then
		return true
	end
	local lower = __string_lower(name)
	return __string_find(lower, "minimap") ~= nil and __string_find(lower, "button") ~= nil
end

function Minimap:press(frame, button)
	__runtime_press(frame, button)
end

function Minimap:hover(frame, on)
	__runtime_hover(frame, on)
end

function Minimap:runEntry(entry, button)
	local compartment = __client_AddonCompartmentFrame
	if compartment == nil then
		return
	end
	local __l14 = compartment.registeredAddons
	for __i13 = 1, #__l14 do
		local registered = __l14[__i13]
		if registered.text == entry.text then
			registered.func(registered.text, button)
			return
		end
	end
end

M.roundMask = roundMask
M.squareMask = squareMask
M.Minimap = Minimap
end
do
-- Made by lunatype from LunaTypeGame/situation.luna: change the source, not this file.
local R = LunaType
local __set, __cell, __listen, __class = R.set, R.cell, R.listen, R.class
local __events_PLAYER_REGEN_DISABLED = R.events.PLAYER_REGEN_DISABLED
local __events_PLAYER_REGEN_ENABLED = R.events.PLAYER_REGEN_ENABLED
local __events_PLAYER_CONTROL_LOST = R.events.PLAYER_CONTROL_LOST
local __events_PLAYER_CONTROL_GAINED = R.events.PLAYER_CONTROL_GAINED
local __events_UNIT_ENTERED_VEHICLE = R.events.UNIT_ENTERED_VEHICLE
local __events_UNIT_EXITED_VEHICLE = R.events.UNIT_EXITED_VEHICLE
local __events_PLAYER_UPDATE_RESTING = R.events.PLAYER_UPDATE_RESTING
local __events_PET_BATTLE_OPENING_START = R.events.PET_BATTLE_OPENING_START
local __events_PET_BATTLE_CLOSE = R.events.PET_BATTLE_CLOSE
local __client_InCombatLockdown = R.client.InCombatLockdown
local __client_UnitOnTaxi = R.client.UnitOnTaxi
local __client_UnitInVehicle = R.client.UnitInVehicle
local __client_IsResting = R.client.IsResting
local __client__C_PetBattles_IsInBattle = R.client.C_PetBattles.IsInBattle
local M = {}
R.addon("LunaTypeGame")["situation"] = M
local Situation

Situation = __class({})

function Situation.new(__owner)
	local self = setmetatable({}, Situation)
	R.adopt(__owner, self)
	self.combat = __cell(false)
	self.taxi = __cell(false)
	self.vehicle = __cell(false)
	self.petBattle = __cell(false)
	self.resting = __cell(false)
	__listen(__events_PLAYER_REGEN_DISABLED, self, self.fights)
	__listen(__events_PLAYER_REGEN_ENABLED, self, self.rests)
	__listen(__events_PLAYER_CONTROL_LOST, self, self.read)
	__listen(__events_PLAYER_CONTROL_GAINED, self, self.read)
	__listen(__events_UNIT_ENTERED_VEHICLE, self, self.read)
	__listen(__events_UNIT_EXITED_VEHICLE, self, self.read)
	__listen(__events_PLAYER_UPDATE_RESTING, self, self.read)
	__listen(__events_PET_BATTLE_OPENING_START, self, self.read)
	__listen(__events_PET_BATTLE_CLOSE, self, self.read)
	__set(self.combat, __client_InCombatLockdown())
	self:read()
	return self
end

function Situation:fights()
	__set(self.combat, true)
end

function Situation:rests()
	__set(self.combat, false)
end

function Situation:read()
	__set(self.taxi, __client_UnitOnTaxi("player"))
	__set(self.vehicle, __client_UnitInVehicle("player"))
	__set(self.resting, __client_IsResting())
	__set(self.petBattle, __client__C_PetBattles_IsInBattle())
end

M.Situation = Situation
end
do
-- Made by lunatype from LunaTypeGame/index.luna: change the source, not this file.
local R = LunaType
local __provide, __class = R.provide, R.class
local __LunaTypeGame_location_Location = R.addon("LunaTypeGame")["location"].Location
local __LunaTypeGame_situation_Situation = R.addon("LunaTypeGame")["situation"].Situation
local __LunaTypeGame_input_Input = R.addon("LunaTypeGame")["input"].Input
local __LunaTypeGame_clock_Clock = R.addon("LunaTypeGame")["clock"].Clock
local __LunaTypeGame_frames_Frames = R.addon("LunaTypeGame")["frames"].Frames
local __LunaTypeGame_minimap_Minimap = R.addon("LunaTypeGame")["minimap"].Minimap
local __LunaTypeGame_colorPicker_ColorPicker = R.addon("LunaTypeGame")["colorPicker"].ColorPicker
local __LunaTypeGame_professions_Professions = R.addon("LunaTypeGame")["professions"].Professions
local __LunaTypeGame_professions_TradeSkill = R.addon("LunaTypeGame")["professions"].TradeSkill
local __LunaTypeGame_bags_Bags = R.addon("LunaTypeGame")["bags"].Bags
local __LunaTypeGame_friends_Friends = R.addon("LunaTypeGame")["friends"].Friends
local __LunaTypeGame_money_Money = R.addon("LunaTypeGame")["money"].Money
local __LunaTypeGame_player_Player = R.addon("LunaTypeGame")["player"].Player
local __LunaTypeGame_reputation_Reputation = R.addon("LunaTypeGame")["reputation"].Reputation
local M = {}
R.addon("LunaTypeGame")["index"] = M
local Client

Client = __class({})

function Client.new(__owner)
	local self = setmetatable({}, Client)
	R.adopt(__owner, self)
	self.location = __LunaTypeGame_location_Location.new(self)
	self.situation = __LunaTypeGame_situation_Situation.new(self)
	self.input = __LunaTypeGame_input_Input.new(self)
	self.clock = __LunaTypeGame_clock_Clock.new(self)
	self.frames = __LunaTypeGame_frames_Frames.new(self)
	self.minimap = __LunaTypeGame_minimap_Minimap.new(self)
	self.colorPicker = __LunaTypeGame_colorPicker_ColorPicker.new(self)
	self.professions = __LunaTypeGame_professions_Professions.new(self)
	self.tradeSkill = __LunaTypeGame_professions_TradeSkill.new(self)
	self.bags = __LunaTypeGame_bags_Bags.new(self)
	self.friends = __LunaTypeGame_friends_Friends.new(self)
	self.money = __LunaTypeGame_money_Money.new(self)
	self.player = __LunaTypeGame_player_Player.new(self)
	self.reputation = __LunaTypeGame_reputation_Reputation.new(self)
	__provide(R, "game", { "Location" }, self.location, { "zone", "realZone", "pvp" }, {})
	__provide(R, "game", { "Situation" }, self.situation, { "combat", "taxi", "vehicle", "petBattle", "resting" }, {})
	__provide(R, "game", { "Input" }, self.input, {}, { "shiftDown" })
	__provide(R, "game", { "Clock" }, self.clock, { "text", "seconds", "time", "invites" }, { "toggleCalendar" })
	__provide(R, "game", { "Frames" }, self.frames, { "MinimapCluster", "MinimapBackdrop", "MinimapTrackingButton", "MinimapMail", "MinimapCraftingOrder", "ExpansionLandingPageMinimapButton", "OrdaenDevButton", "Professions", "MicroMenuContainer", "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton", "QuestLogMicroButton", "LFDMicroButton", "CollectionsMicroButton", "MainMenuMicroButton", "GuildMicroButton", "StoreMicroButton", "HelpMicroButton", "QuickJoinToastButton", "BagsBar", "MainMenuBarBackpackButton", "BackpackFreeSlots", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }, {})
	__provide(R, "game", { "Minimap" }, self.minimap, { "frame", "buttons", "entries", "coords" }, { "square", "wheelZoom", "sendCoords", "press", "hover", "runEntry" })
	__provide(R, "game", { "ColorPicker" }, self.colorPicker, { "picked", "cancelled" }, { "open" })
	__provide(R, "game", { "Professions" }, self.professions, { "list" }, {})
	__provide(R, "game", { "TradeSkill" }, self.tradeSkill, { "open", "categories", "recipes", "shownEmpty" }, { "show", "close", "description", "requirements", "reagents", "craft" })
	__provide(R, "game", { "Bags" }, self.bags, { "changed", "free" }, { "roomOf", "roomOfAll", "junk" })
	__provide(R, "game", { "Friends" }, self.friends, { "online" }, {})
	__provide(R, "game", { "Money" }, self.money, { "amount", "tracked" }, { "format" })
	__provide(R, "game", { "Player" }, self.player, { "level", "xp", "xpMax", "rested", "classTag" }, {})
	__provide(R, "game", { "Reputation" }, self.reputation, { "name", "standing", "value", "min", "max" }, { "with" })
	return self
end

M.Client = Client
end
