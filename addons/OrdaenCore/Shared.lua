-- Ordaen Core: shared items, such as the zone name and the time, which several Ordaen addons can show (Minimap,
-- Panel). One addon at a time shows each: the one whose setting the player turned on last. Turning it on in one
-- addon turns it off in the others, both ways, like radio buttons across addons. Each addon only ever changes its
-- own setting, when Core tells it that it lost the item; the owners are saved in Ordaen Core's settings
-- (OrdaenCoreDB.sharedOwners).
--
--   local zone = A:Shared("zone", {
--   	lost = function() A:Set("zoneText", false) end,      -- another addon shows it now: switch ours off
--   	regained = function() A:Set("zoneText", true) end,   -- its owner is gone (removed, disabled): show it again
--   	fallback = true,                                     -- this addon takes it back then (the minimap)
--   })
--   A:OnLogin(function() zone:Sync(A:Get("zoneText")) end)  -- line up the saved setting with the owner
--   -- in the addon's onChange for that setting: if value then zone:Claim() else zone:Release() end
--
-- At login, an addon whose setting is on keeps the item when it is the recorded owner, or there is none, or the
-- owner isn't loaded; otherwise it loses it (`lost` runs). A `fallback` addon whose setting is off takes the item
-- back (`regained`) when the recorded owner isn't loaded any more. Sync runs on PLAYER_LOGIN (A:OnLogin), when
-- every addon that will load at startup has, so "loaded" is known either way round.
--
-- Cost: a table lookup per Claim, Release or Sync; nothing per frame or event.
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core
---@class OrdaenAddon
local Addon = ns.AddonClass

--- One addon's hold on a shared item (A:Shared). Methods are called with `:`.
---@class OrdaenShared
---@field item string
---@field addon OrdaenAddon
---@field private lost function|nil
---@field private regained function|nil
---@field private fallback boolean
local Shared = {}
local SharedMeta = { __index = Shared }

local holders = {} ---@type table<string, table<string, OrdaenShared>> item -> addon name -> its hold

-- The saved owners (item -> addon name), in Ordaen Core's SavedVariables; nil before they load.
local function owners()
	local db = rawget(_G, "OrdaenCoreDB")
	if type(db) ~= "table" then
		return nil
	end
	local map = db.sharedOwners
	if type(map) ~= "table" then
		map = {}
		db.sharedOwners = map
	end
	return map
end

local function run(hold, fn)
	if fn then
		Core._RunAs(hold.addon, fn)
	end
end

--- Take part in a shared item. Once per addon and item (at load).
---@param item string "zone", "clock"
---@param opts { lost: fun()|nil, regained: fun()|nil, fallback: boolean|nil }
---@return OrdaenShared
function Addon:Shared(item, opts)
	local hold = setmetatable({
		item = item, addon = self, lost = opts.lost, regained = opts.regained, fallback = opts.fallback == true,
	}, SharedMeta)
	local list = holders[item]
	if not list then
		list = {}
		holders[item] = list
	end
	list[self.name] = hold
	return hold
end

--- The addon that shows the item now (its name), or nil.
---@return string|nil
function Shared:Owner()
	local map = owners()
	return map and map[self.item]
end

--- This addon shows the item now (the player turned its setting on): every other addon taking part loses it.
function Shared:Claim()
	local map = owners()
	if not map or map[self.item] == self.addon.name then
		return
	end
	map[self.item] = self.addon.name
	self.addon.Debug:Logf("shared %s: shown here now", self.item)
	for name, other in pairs(holders[self.item]) do
		if name ~= self.addon.name then
			run(other, other.lost)
		end
	end
end

--- This addon stopped showing the item (its setting went off). Nobody shows it until someone claims it.
function Shared:Release()
	local map = owners()
	if map and map[self.item] == self.addon.name then
		map[self.item] = nil
		self.addon.Debug:Logf("shared %s: released", self.item)
	end
end

--- Line up this addon's saved setting with the recorded owner (at login). Returns whether this addon shows the item.
---@param on boolean whether this addon's setting says to show it
---@return boolean
function Shared:Sync(on)
	local map = owners()
	if not map then
		return on
	end
	local owner = map[self.item]
	local ownerHere = owner ~= nil and owner ~= self.addon.name and Core._IsAddOnLoaded(owner)
	if on then
		if ownerHere then
			self.addon.Debug:Logf("shared %s: %s shows it; ours goes off", self.item, owner)
			run(self, self.lost)
			return false
		end
		map[self.item] = self.addon.name
		return true
	end
	if owner == self.addon.name then
		map[self.item] = nil -- saved as on elsewhere, off here: nobody shows it
	elseif owner ~= nil and not ownerHere and self.fallback then
		self.addon.Debug:Logf("shared %s: %s isn't loaded; shown here again", self.item, owner)
		map[self.item] = self.addon.name
		run(self, self.regained)
		return true
	end
	return false
end

--- Specs: forget every hold.
function Shared._Clear()
	for item in pairs(holders) do
		holders[item] = nil
	end
end
Core._Shared = Shared
