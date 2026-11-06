-- Ordaen Panel's start: declares the addon to the Ordaen Core framework (settings come from settings.jsonc) and runs
-- each group as a feature: on while its setting is, with its events registered only then. The drawing (Panel.lua,
-- on OrdaenCore.UI's edge panel, bars and dressed Blizzard buttons) listens to ns.Changed.
local addonName, ns = ...

-- Edge, length and button size change the layout; the groups and visibility are features (below).
local LAYOUT = { edge = true, fit = true, buttonSize = true }

local A = OrdaenCore.NewAddon(addonName, ns, {
	slash = { "/op", "/ordaenpanel" },
	dump = function()
		return ns.View and ns.View.Dump()
	end,
	onChange = function(key)
		if LAYOUT[key] then
			ns.Changed("layout")
		end
	end,
}) --[[@as OrdaenPanelAddon]]
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A

--- A segment's model changed (or its group went on/off): redraw it (Panel.lua).
---@param segment string "social", "experience", "currencies", "bags", "micromenu", "visibility", "layout"
function ns.Changed(segment)
	local view = ns.View
	if view then
		view.Update(segment)
	end
end

-- Data groups: social, experience, currencies, bags (settings of the same names).
for _, name in ipairs({ "social", "experience", "currencies", "bags" }) do
	local segment = ns.Segments[name]
	local F = A:Feature(name, { setting = name })
	local function onEvent(event)
		if segment.update(event) ~= false then
			ns.Changed(name)
		end
	end
	for _, event in ipairs(segment.events) do
		F:On(event, onEvent)
	end
	F:OnEnable(function()
		if segment.start then
			segment.start()
		end
		segment.update()
		ns.Changed(name)
	end)
	F:OnDisable(function()
		ns.Changed(name)
	end)
end

-- Micro menu: Blizzard's buttons, collected once the world is there (they're laid out by then).
local microButtons = {}
ns.MicroButtons = microButtons
local Micro = A:Feature("micromenu", { setting = "micromenu" })
-- Blizzard's micro buttons by name: on Forever they aren't all children of MicroMenu (the first test found none
-- there), and the API dump doesn't list most of them, so both are looked at; Micro.Order keeps the shown ones.
local MICRO_NAMES = {
	"CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton", "SpellbookMicroButton",
	"TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "HousingMicroButton", "GuildMicroButton",
	"LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "StoreMicroButton", "MainMenuMicroButton",
	"HelpMicroButton",
}

local function microCandidates()
	local list, seen = {}, {}
	if MicroMenu then
		for _, child in ipairs({ MicroMenu:GetChildren() }) do
			list[#list + 1], seen[child] = child, true
		end
	end
	for _, name in ipairs(MICRO_NAMES) do
		local button = _G[name]
		if type(button) == "table" and button.GetObjectType and not seen[button] then
			list[#list + 1], seen[button] = button, true
		end
	end
	return list
end

Micro:OnEnable(function(db)
	local candidates = microCandidates()
	ns.Micro.Order(candidates, db and db.hiddenMicro or {}, microButtons)
	if A.Debug:IsEnabled() then
		local names = {}
		for i, child in ipairs(candidates) do
			local parent = child:GetParent()
			names[i] = (child:GetName() or "?") .. " in " .. (parent and parent:GetName() or "?")
				.. (child:IsVisible() and "" or " (not visible)") .. (child:IsEnabled() and "" or " (disabled)")
		end
		A.Debug:Logf("micromenu: %d of %d candidates: %s", #microButtons, #candidates, table.concat(names, ", "))
	end
	ns.Changed("micromenu")
end)
Micro:OnDisable(function()
	ns.Changed("micromenu")
end)

-- Visibility: only the events the current settings need (Visibility.Events), re-read when a setting changes.
local Visible = A:Feature("visibility")
local registered = {}
local wanted = {}

local function settings()
	local db = A.db
	return db and db.visibility or {}
end

local function onState(event)
	ns.State.Read(event, settings().condition)
	ns.Changed("visibility")
end

local function registerEvents()
	for _, event in ipairs(registered) do
		Visible:Off(event, onState)
	end
	ns.Visibility.Events(settings(), wanted)
	for i, event in ipairs(wanted) do
		Visible:On(event, onState)
		registered[i] = event
	end
	for i = #registered, #wanted + 1, -1 do
		registered[i] = nil
	end
end

Visible:OnEnable(function()
	registerEvents()
	onState(nil)
end)
Visible:OnChange(function(key)
	if key:find("^visibility%.") then
		registerEvents()
		onState(nil)
	end
end)
