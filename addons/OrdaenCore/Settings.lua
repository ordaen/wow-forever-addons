-- Ordaen Core: an addon's settings page on Blizzard's Settings API (Options > AddOns), from its settings manifest
-- (RegisterSchema, below) or from the older declaration in spec.settings of OrdaenCore.NewAddon (Register), which
-- also keeps the saved values valid.
--
--   settings = {
--   	title = "SETTINGS_TITLE",               -- locale key (default: the addon's TOC title)
--   	onChange = function(key, value) end,    -- after any setting changed (features hear first: Feature.lua)
--   	{ header = "HEADER_MAP" },
--   	{ key = "style", label = "STYLE", tooltip = "STYLE_TOOLTIP", choices = ns.STYLES }, -- { id = ..., label = key }
--   	{ key = "scale", label = "SCALE", min = 0.8, max = 1.6, step = 0.05, format = "percent" }, -- or "px"
--   	{ key = "columns", label = "COLUMNS", min = 2, max = 12, step = 1 },
--   	{ key = "enabled", label = "ENABLED" },  -- a boolean default makes a checkbox
--   }
--
-- Each key needs a value in spec.defaults. A dotted key ("ui.theme") is a value in a nested table (db.ui.theme).
-- Labels and tooltips are locale keys of the addon.
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core
local SettingsPage = {}
Core.Settings = SettingsPage

--- The table holding a (possibly dotted) key, and the last part: ("ui.theme", db) -> db.ui, "theme".
--- Runs at load only (registration, sanitizing), never per event.
local function resolve(root, key)
	local tbl = root
	local dot = key:find(".", 1, true)
	while dot and tbl do
		tbl = tbl[key:sub(1, dot - 1)]
		key = key:sub(dot + 1)
		dot = key:find(".", 1, true)
	end
	return tbl, key
end
SettingsPage.Resolve = resolve

local function byId(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

--- Make every declared setting valid: unknown choices and wrong types go back to the default, numbers are
--- clamped to their range (and rounded for whole-number steps).
function SettingsPage.Sanitize(addon)
	local db, defaults = addon.db, addon.spec.defaults or {}
	if not db then
		return
	end
	for _, entry in ipairs(addon.spec.settings or {}) do
		if entry.key then
			local tbl, key = resolve(db, entry.key)
			local defaultTbl = resolve(defaults, entry.key)
			local default = defaultTbl and defaultTbl[key]
			if tbl then
				local value = tbl[key]
				if entry.choices then
					if not byId(entry.choices, value) then
						tbl[key] = default
					end
				elseif type(default) == "number" then
					value = tonumber(value)
					if not value then
						tbl[key] = default
					else
						if entry.step == 1 then
							value = math.floor(value + 0.5)
						end
						tbl[key] = math.min(entry.max or value, math.max(entry.min or value, value))
					end
				elseif type(value) ~= type(default) then
					tbl[key] = default
				end
			end
		end
	end
end

local function percent(value)
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

-- A size in UI units, with the screen pixels it takes now ("60 (72 px)"): the game lays sizes out in units, so
-- "60 px" read like 60 screen pixels and wasn't (on a 1440p screen at 100 % a unit is 1.2 pixels).
local function px(value)
	local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
	local scale = UIParent and UIParent:GetEffectiveScale()
	if factor and factor > 0 and scale then
		return ns.L.SIZE_UNITS:format(math.floor(value + 0.5), math.floor(value * scale / factor + 0.5))
	end
	return string.format("%d", math.floor(value + 0.5))
end

local FORMATS = { percent = percent, px = px }

--- Register the settings page. The framework calls it on the addon's ADDON_LOADED (it binds to the
--- SavedVariables table, so not earlier).
function SettingsPage.Register(addon)
	local spec, db, L = addon.spec.settings, addon.db, addon.L
	SettingsPage.Sanitize(addon)
	if not (db and Settings and Settings.RegisterVerticalLayoutCategory) then
		return
	end
	local title = spec.title and L[spec.title] or C_AddOns.GetAddOnMetadata(addon.name, "Title") or addon.name
	local category, layout = Settings.RegisterVerticalLayoutCategory(title)
	local defaults = addon.spec.defaults or {}
	local Debug = addon.Debug
	local onChange = spec.onChange and Debug:Wrap(spec.onChange)

	for _, entry in ipairs(spec) do
		if entry.header then
			if layout and CreateSettingsListSectionHeaderInitializer then
				layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L[entry.header]))
			end
		else
			local key = entry.key
			local tbl, leaf = resolve(db, key)
			local defaultTbl = resolve(defaults, key)
			local default = defaultTbl[leaf]
			local setting = Settings.RegisterAddOnSetting(category, addon.name .. "_" .. key:gsub("%.", "_"), leaf, tbl,
				type(default), L[entry.label], default)
			-- Features first (Feature.lua: switch the one this setting turns on/off, tell the others), then onChange.
			setting:SetValueChangedCallback(function(_, value)
				if Debug:TraceEnabled() then
					Debug:Trace("setting", key .. "=" .. tostring(value))
				end
				addon:_SettingChanged(key, value)
				if onChange then
					onChange(key, value)
				end
			end)
			local tooltip = entry.tooltip and L[entry.tooltip]
			if entry.choices then
				local choices = entry.choices
				Settings.CreateDropdown(category, setting, function()
					local container = Settings.CreateControlTextContainer()
					for _, choice in ipairs(choices) do
						container:Add(choice.id, L[choice.label])
					end
					return container:GetData()
				end, tooltip)
			elseif type(default) == "number" then
				local options = Settings.CreateSliderOptions(entry.min, entry.max, entry.step or 1)
				if FORMATS[entry.format] then
					options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FORMATS[entry.format])
				else
					options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
				end
				Settings.CreateSlider(category, setting, options, tooltip)
			else
				Settings.CreateCheckbox(category, setting, tooltip)
			end
		end
	end
	Settings.RegisterAddOnCategory(category)
	addon._settingsCategory = category
end

-- The page of an addon with a settings manifest ------------------------------------------------------------------
-- Drawn with Blizzard's Settings API for now (a page drawn with OrdaenCore.UI components is on docs/roadmap.md).
-- Proxy settings: the page reads through the store and writes with store:Set, so only the player's choices are
-- saved and every change is announced (features, then the addon's onChange).

local VAR_TYPES = { boolean = "boolean", number = "number", choice = "string", asset = "string" }

-- Asset ids of a kind in a fixed order (by id), made once per kind.
local assetIdsCache = {}
local function assetIds(kind)
	local ids = assetIdsCache[kind]
	if not ids then
		ids = {}
		for id in pairs(Core._SettingsStore.Assets(kind) or {}) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		assetIdsCache[kind] = ids
	end
	return ids
end

-- A dropdown's options: choices with the addon's labels, or the assets of a kind with Ordaen Core's labels.
local function optionsOf(addon, setting)
	return function()
		local container = Settings.CreateControlTextContainer()
		if setting.type == "choice" then
			for i, id in ipairs(setting.choices) do
				local label = setting.choiceLabels and setting.choiceLabels[i]
				container:Add(id, label and addon.L[label] or tostring(id))
			end
		else
			local assets = Core._SettingsStore.Assets(setting.of) or {}
			for _, id in ipairs(assetIds(setting.of)) do
				local label = assets[id].label
				container:Add(id, label and ns.L[label] or id)
			end
		end
		return container:GetData()
	end
end

local function control(addon, category, key, setting)
	local store = addon._store --[[@as OrdaenSettingsStore]]
	local varType = VAR_TYPES[setting.type]
	if not varType then
		return nil -- colour, text, keybinding, sound, action, map: not on this page yet
	end
	local L = addon.L
	local proxy = Settings.RegisterProxySetting(category, addon.name .. "_" .. key:gsub("%.", "_"), varType,
		L[setting.label], store:Default(key), function()
			return store:Get(key)
		end, function(value)
			store:Set(key, value)
		end)
	local tooltip = setting.tooltip and L[setting.tooltip]
	if setting.type == "boolean" then
		return Settings.CreateCheckbox(category, proxy, tooltip)
	elseif setting.type == "number" then
		local options = Settings.CreateSliderOptions(setting.min, setting.max, setting.step or 1)
		if FORMATS[setting.format] then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FORMATS[setting.format])
		else
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end
		return Settings.CreateSlider(category, proxy, options, tooltip)
	end
	return Settings.CreateDropdown(category, proxy, optionsOf(addon, setting), tooltip)
end

--- Register the page of an addon with a settings manifest: its sections in order, settings with `page = false`
--- left out, `enabledBy` greys a control out while its boolean is off. The framework calls it on ADDON_LOADED,
--- after the store is bound.
---@param addon OrdaenAddon
---@param schema table ns.SETTINGS_SCHEMA
function SettingsPage.RegisterSchema(addon, schema)
	if not (addon._store and Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then
		return
	end
	local L, store = addon.L, addon._store --[[@as OrdaenSettingsStore]]
	local title = schema.title and L[schema.title] or C_AddOns.GetAddOnMetadata(addon.name, "Title") or addon.name
	local category, layout = Settings.RegisterVerticalLayoutCategory(title)
	local initializers = {} -- key -> initializer, for enabledBy
	local shown = 0
	for _, section in ipairs(schema.sections or {}) do
		if section.header and layout and CreateSettingsListSectionHeaderInitializer then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L[section.header]))
		end
		for _, key in ipairs(section.keys) do
			local setting = schema.settings[key]
			if setting and setting.page ~= false then
				local init = control(addon, category, key, setting)
				if init then
					shown = shown + 1
					initializers[key] = init
					local parentKey = setting.enabledBy
					local parent = parentKey and initializers[parentKey]
					if parent and init.SetParentInitializer then
						init:SetParentInitializer(parent, function()
							return store:Get(parentKey) == true
						end)
					end
				else
					addon.Debug:Logf("settings: %s (%s) isn't on the page yet", key, setting.type)
				end
			end
		end
	end
	if shown == 0 then
		return -- nothing to show: no page, no category
	end
	Settings.RegisterAddOnCategory(category)
	addon._settingsCategory = category
end
