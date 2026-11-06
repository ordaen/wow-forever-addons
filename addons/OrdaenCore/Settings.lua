-- Ordaen Core: an addon's settings page, from its declaration (spec.settings of OrdaenCore.NewAddon), on
-- Blizzard's Settings API (Options > AddOns). The same declaration keeps the saved values valid.
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

local function px(value)
	return string.format("%d px", math.floor(value + 0.5))
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
