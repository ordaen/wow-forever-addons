-- The micro menu's and bags' buttons tell more than their names (design tooltips/text «Buttons»), added through the
-- module's own API (its events, filtered by the owner's name): what the window behind the button holds, read from the game when
-- its tooltip shows. One handler per button, made once; strings only per show.
local format, floor = string.format, math.floor

-- the bags: the backpack and the four bag slots, their container ids
local BAGS = { MainMenuBarBackpackButton = 0, CharacterBag0Slot = 1, CharacterBag1Slot = 2, CharacterBag2Slot = 3,
	CharacterBag3Slot = 4 }
local LOW = { 1, 0.25, 0.25, 1 } -- durability under a quarter: red (one table: the draw compares tables)

local function FreeOf(bag)
	return C_Container.GetContainerNumFreeSlots(bag) or 0, C_Container.GetContainerNumSlots(bag) or 0
end

---@param self table the module (its subscriptions end with it)
---@param events table the API's events by kind
---@param For fun(filter: any, fn: function): function the API's filter helper
---@param On fun(): boolean the «Сведения на кнопках» setting
---@param L table the module's locales
return function(self, events, For, On, L)
	local function OnTooltip(kind, fn, filter)
		self:On(events[kind], For(filter, fn))
	end
	OnTooltip("text", function(tip)
		if not On() then
			return
		end
		local _, equipped = GetAverageItemLevel()
		if equipped and equipped > 0 then
			tip:AddRow(L.EXTRA_ILVL, tostring(floor(equipped)))
		end
		local lowest
		for slot = 1, 18 do
			local now, most = GetInventoryItemDurability(slot)
			if now and most and most > 0 and (not lowest or now / most < lowest) then
				lowest = now / most
			end
		end
		if lowest then
			local percent = floor(lowest * 100 + 0.5)
			tip:AddRow(L.EXTRA_DURABILITY, percent .. "%", nil, percent < 25 and LOW or nil)
		end
	end, "CharacterMicroButton")

	OnTooltip("text", function(tip)
		local points = On() and GetNumUnspentTalents and GetNumUnspentTalents() or 0
		if points > 0 then
			tip:AddRow(L.EXTRA_TALENTS, tostring(points))
		end
	end, "TalentMicroButton")

	OnTooltip("text", function(tip)
		if not On() then
			return
		end
		local a, b, c, d, e = GetProfessions()
		for i = 1, 5 do
			local index = i == 1 and a or i == 2 and b or i == 3 and c or i == 4 and d or e
			if index then
				local name, _, rank, most = GetProfessionInfo(index)
				if name then
					tip:AddRow(name, format("%d / %d", rank or 0, most or 0))
				end
			end
		end
	end, "ProfessionMicroButton")

	OnTooltip("text", function(tip)
		local points = On() and GetTotalAchievementPoints() or 0
		if points > 0 then
			tip:AddRow(L.EXTRA_ACHIEVEMENTS, tostring(points))
		end
	end, "AchievementMicroButton")

	OnTooltip("text", function(tip)
		if not On() then
			return
		end
		local _, quests = C_QuestLog.GetNumQuestLogEntries()
		tip:AddRow(L.EXTRA_QUESTS, format("%d / %d", quests or 0, C_QuestLog.GetMaxNumQuestsCanAccept() or 0))
	end, "QuestLogMicroButton")

	OnTooltip("text", function(tip)
		if not On() or not IsInGuild() then
			return
		end
		local total, online = GetNumGuildMembers()
		tip:AddRow(L.EXTRA_ONLINE, format("%d / %d", online or 0, total or 0))
	end, "GuildMicroButton")

	-- the backpack: free slots over all the bags; a bag slot: its own bag's (shown as text when empty, an item else)
	local function Bags(tip, _, owner)
		if not On() then
			return
		end
		local bag = BAGS[owner:GetName()]
		local free, slots = 0, 0
		if bag == 0 then
			for i = 0, 4 do
				local f, s = FreeOf(i)
				free, slots = free + f, slots + s
			end
		else
			free, slots = FreeOf(bag)
		end
		if slots > 0 then
			tip:AddRow(L.EXTRA_FREE, format("%d / %d", free, slots))
		end
	end
	local function IsBag(owner)
		local name = owner and owner.GetName and owner:GetName()
		return name ~= nil and BAGS[name] ~= nil
	end
	OnTooltip("text", Bags, IsBag)
	OnTooltip("item", Bags, IsBag)
end
