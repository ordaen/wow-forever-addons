-- Ordaen Panel's start: declares the addon to the Ordaen Core framework (settings come from settings.jsonc) and runs
-- each group as a feature: on while its setting is, with its events registered only then. The drawing (Panel.lua,
-- on OrdaenCore.UI's edge panel, bars and dressed Blizzard buttons) listens to ns.Changed.
local addonName, ns = ...

local A = OrdaenCore.NewAddon(addonName, ns, {
	slash = { "/op", "/ordaenpanel" },
}) --[[@as OrdaenPanelAddon]]
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A

--- A segment's model changed (or its group went on/off): redraw it. Until Panel.lua exists, nothing is drawn.
---@param segment string "social", "experience", "currencies", "bags", "micromenu", "visibility"
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
Micro:OnEnable(function(db)
	if MicroMenu then
		ns.Micro.Order({ MicroMenu:GetChildren() }, db and db.hiddenMicro or {}, microButtons)
	end
	A.Debug:Logf("micromenu: %d buttons", #microButtons)
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
