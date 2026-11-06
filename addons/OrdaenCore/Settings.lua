-- Ordaen Core: an addon's settings page, from its declaration (spec.settings of OrdaenCore.NewAddon), on
-- Blizzard's Settings API (Options > AddOns). The same declaration keeps the saved values valid.
--
--   settings = {
--   	title = "SETTINGS_TITLE",               -- locale key (default: the addon's TOC title)
--   	onChange = function(key, value) end,    -- after any setting changed
--   	{ header = "HEADER_MAP" },
--   	{ key = "style", label = "STYLE", tooltip = "STYLE_TOOLTIP", choices = ns.STYLES }, -- { id = ..., label = key }
--   	{ key = "scale", label = "SCALE", min = 0.8, max = 1.6, step = 0.05, format = "percent" },
--   	{ key = "columns", label = "COLUMNS", min = 2, max = 12, step = 1 },
--   	{ key = "enabled", label = "ENABLED" },  -- a boolean default makes a checkbox
--   }
--
-- Each key needs a value in spec.defaults. Labels and tooltips are locale keys of the addon.
local _, ns = ...

local Core = ns.Core
local SettingsPage = {}
Core.Settings = SettingsPage

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
		local key = entry.key
		if key then
			local default, value = defaults[key], db[key]
			if entry.choices then
				if not byId(entry.choices, value) then
					db[key] = default
				end
			elseif type(default) == "number" then
				value = tonumber(value)
				if not value then
					db[key] = default
				else
					if entry.step == 1 then
						value = math.floor(value + 0.5)
					end
					db[key] = math.min(entry.max or value, math.max(entry.min or value, value))
				end
			elseif type(value) ~= type(default) then
				db[key] = default
			end
		end
	end
end

local function percent(value)
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

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
	local onChange = spec.onChange and addon.Debug.Wrap(spec.onChange)

	for _, entry in ipairs(spec) do
		if entry.header then
			if layout and CreateSettingsListSectionHeaderInitializer then
				layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L[entry.header]))
			end
		else
			local key, default = entry.key, defaults[entry.key]
			local setting = Settings.RegisterAddOnSetting(category, addon.name .. "_" .. key, key, db, type(default),
				L[entry.label], default)
			if onChange then
				setting:SetValueChangedCallback(function(_, value)
					onChange(key, value)
				end)
			end
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
				if entry.format == "percent" then
					options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, percent)
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
