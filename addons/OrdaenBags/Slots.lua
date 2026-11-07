-- Ordaen Bags, the slots: Blizzard's own item buttons (ContainerFrameItemButtonTemplate), so clicking, dragging,
-- using, splitting, the tooltip and the button's own art are Blizzard's. As Baganator does, each bag has a hidden
-- frame whose ID is the bag, and each button's ID is its slot: Blizzard's code reads them from there. A button is
-- made the first time its slot holds something, never in combat (the caller tries again after it).
--
-- Cost: one button per bag slot ever used, made once; filling one is Blizzard's own calls, no tables of ours.
local _, ns = ...

local Slots = {}
ns.Slots = Slots

--- One slot's button: Blizzard's ItemButton with the container button's methods.
---@class OrdaenBagsSlot : ItemButton, ContainerFrameItemButtonMixin, ItemButtonMixin
---@field item OrdaenBagsItem|nil what it shows now

local host ---@type Frame|nil the window's frame: the bags' frames live on it
local bagFrames = {} ---@type table<number, Frame> bag -> its frame (ID = the bag)
local buttons = {} ---@type table<number, OrdaenBagsSlot> bag * 1000 + slot -> its button

--- The frame the slots sit on (the window's), set once the window exists.
---@param frame Frame
function Slots.SetHost(frame)
	host = frame
end

local function frameOfBag(bag)
	local frame = bagFrames[bag]
	if not frame then
		frame = CreateFrame("Frame", nil, host)
		frame:SetID(bag)
		frame:SetAllPoints(host)
		frame:SetFrameLevel(host:GetFrameLevel() + 10) -- over the window's own surfaces
		bagFrames[bag] = frame
	end
	return frame
end

--- The button of a slot, made on first use; nil in combat until it exists (see the file's top).
---@param bag number
---@param slot number
---@return OrdaenBagsSlot|nil
function Slots.Get(bag, slot)
	local key = bag * 1000 + slot
	local button = buttons[key]
	if not button and host and not InCombatLockdown() then
		button = CreateFrame("ItemButton", "OrdaenBagsSlot" .. bag .. "_" .. slot, frameOfBag(bag),
			"ContainerFrameItemButtonTemplate") --[[@as OrdaenBagsSlot]]
		button:SetID(slot)
		button:SetBagID(bag)
		buttons[key] = button
	end
	return button
end

--- Draw `item` on its slot's button, as Blizzard's bag frames do.
---@param button OrdaenBagsSlot
---@param item OrdaenBagsItem
function Slots.Fill(button, item)
	button.item = item
	local texture = item.texture
	button:SetHasItem(texture)
	SetItemButtonTexture(button, texture)
	SetItemButtonQuality(button, item.quality, item.link, false, item.bound)
	SetItemButtonCount(button, item.count)
	SetItemButtonDesaturated(button, item.locked)
	button:UpdateQuestItem(item.quest, item.questID, item.questActive)
	button:UpdateNewItem(item.quality)
	button:UpdateJunkItem(item.quality, item.noValue)
	button:UpdateCooldown(texture)
	button:SetMatchesSearch(not item.filtered)
end

--- Hide every button (a new layout shows the ones it places).
function Slots.HideAll()
	for _, button in pairs(buttons) do
		button:Hide()
		button.item = nil
	end
end

--- Every button that shows an item now (for search and cooldown updates), as `fn(button, item)`.
---@param fn fun(button: OrdaenBagsSlot, item: OrdaenBagsItem)
function Slots.EachShown(fn)
	for _, button in pairs(buttons) do
		if button.item then
			fn(button, button.item)
		end
	end
end
