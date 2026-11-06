-- The settings page in Options > AddOns > Ordaen Minimap (Blizzard's Settings API).
local _, ns = ...

local Options = {}
ns.Options = Options

local L = ns.L
local category, layout

local function choices(list)
	return function()
		local container = Settings.CreateControlTextContainer()
		for _, entry in ipairs(list) do
			container:Add(entry.id, L[entry.label])
		end
		return container:GetData()
	end
end

--- Register the settings page. Needs the SavedVariables table, so call it on ADDON_LOADED.
---@param db table OrdaenMinimapDB
---@param onChange fun() called after any setting changes
function Options.Register(db, onChange)
	if category or not Settings or not Settings.RegisterVerticalLayoutCategory then
		return
	end
	category, layout = Settings.RegisterVerticalLayoutCategory(L.SETTINGS_TITLE)

	local function register(key, name, default)
		local setting = Settings.RegisterAddOnSetting(category, "OrdaenMinimap_" .. key, key, db,
			type(default), name, default)
		setting:SetValueChangedCallback(function()
			onChange()
		end)
		return setting
	end

	if layout and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.HEADER_BORDER))
	end

	Settings.CreateDropdown(category, register("borderStyle", L.BORDER_STYLE, ns.DEFAULTS.borderStyle),
		choices(ns.BORDER_STYLES), L.BORDER_STYLE_TOOLTIP)
	Settings.CreateDropdown(category, register("borderColor", L.BORDER_COLOR, ns.DEFAULTS.borderColor),
		choices(ns.BORDER_COLORS), L.BORDER_COLOR_TOOLTIP)

	if layout and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.HEADER_MAP))
	end

	local sliderOptions = Settings.CreateSliderOptions(ns.SCALE_MIN, ns.SCALE_MAX, ns.SCALE_STEP)
	sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end)
	Settings.CreateSlider(category, register("scale", L.MAP_SCALE, ns.DEFAULTS.scale), sliderOptions,
		L.MAP_SCALE_TOOLTIP)

	if layout and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.HEADER_DRAWER))
	end
	Settings.CreateCheckbox(category, register("drawerEnabled", L.DRAWER_ENABLED, ns.DEFAULTS.drawerEnabled),
		L.DRAWER_ENABLED_TOOLTIP)
	Settings.CreateCheckbox(category,
		register("hideBlizzardCompartment", L.HIDE_BLIZZARD_COMPARTMENT, ns.DEFAULTS.hideBlizzardCompartment),
		L.HIDE_BLIZZARD_COMPARTMENT_TOOLTIP)
	local columnOptions = Settings.CreateSliderOptions(ns.DRAWER_COLUMNS_MIN, ns.DRAWER_COLUMNS_MAX, 1)
	columnOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
	Settings.CreateSlider(category, register("drawerColumns", L.DRAWER_COLUMNS, ns.DEFAULTS.drawerColumns),
		columnOptions, L.DRAWER_COLUMNS_TOOLTIP)

	Settings.RegisterAddOnCategory(category)
end

function Options.Open()
	if category then
		Settings.OpenToCategory(category:GetID())
	end
end
