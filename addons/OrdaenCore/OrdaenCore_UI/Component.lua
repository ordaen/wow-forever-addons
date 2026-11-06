-- OrdaenCore.UI components: Block and Button. A component instance is an object that owns one WoW frame (its
-- surface), draws its block tree onto it with the renderer, and takes events through :On(event, fn).
--
--   local clock = UI.Button({ name = "MyClock", parent = Minimap, tooltip = clockTip,
--   	{ format = "%02d:%02d", args = { 0, 0 }, style = "small" } })
--   clock:On("click", function(self, mouseButton) ToggleCalendar() end)
--   clock:On("CALENDAR_UPDATE_PENDING_INVITES", function(self) ... end)
--   clock:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", -2, -9)
--
-- Events: lower case = the player's input on this block (click, enter, leave, mousedown, mouseup, dragstart,
-- dragstop, wheel), upper case = Blizzard's game events, with Blizzard's arguments unchanged. Listeners get the
-- instance first. No bubbling. The frame takes the mouse only once a user listener exists.
--
-- Cost: one metatable per component kind, one table per instance, created once. The WoW scripts are a fixed set
-- of dispatchers (one function per event name, made at load), so :On creates no closure. Game events go through
-- one shared frame that registers an event only while some instance listens.
local _, ns = ...

local Render = ns.Render

local Component = {}
ns.Component = Component

-- securecallfunction (when the client has it): an error in one listener is reported and the rest still run.
local call = securecallfunction or function(fn, ...)
	return fn(...)
end

local byFrame = setmetatable({}, { __mode = "k" }) -- WoW frame -> instance

---@class OrdaenUIComponent
---@field frame Button the WoW frame this instance draws on (for anchoring other frames to it)
---@field block OrdaenUIBlock the instance's block tree (change fields, then :Refresh())
---@field tooltip OrdaenUITooltip|nil shown while the mouse is over it
---@field listeners table<string, function[]> event -> listeners, in the order added (replaced, never changed)
--- Placement and visibility, passed to the frame (PASSTHROUGH below):
---@field SetPoint fun(self: OrdaenUIComponent, point: string, relTo: any, relPoint: string?, x: number?, y: number?)
---@field ClearAllPoints fun(self: OrdaenUIComponent)
---@field GetPoint fun(self: OrdaenUIComponent, index: number|nil): string|nil, any, string|nil, number|nil, number|nil
---@field SetParent fun(self: OrdaenUIComponent, parent: any)
---@field GetParent fun(self: OrdaenUIComponent): any
---@field Show fun(self: OrdaenUIComponent)
---@field Hide fun(self: OrdaenUIComponent)
---@field IsShown fun(self: OrdaenUIComponent): boolean
---@field IsVisible fun(self: OrdaenUIComponent): boolean
---@field SetShown fun(self: OrdaenUIComponent, shown: boolean)
---@field SetFrameStrata fun(self: OrdaenUIComponent, strata: string)
---@field GetFrameStrata fun(self: OrdaenUIComponent): string
---@field SetFrameLevel fun(self: OrdaenUIComponent, level: number)
---@field GetFrameLevel fun(self: OrdaenUIComponent): number
---@field SetScale fun(self: OrdaenUIComponent, scale: number)
---@field GetScale fun(self: OrdaenUIComponent): number
---@field GetEffectiveScale fun(self: OrdaenUIComponent): number
---@field GetCenter fun(self: OrdaenUIComponent): number|nil, number|nil
---@field GetWidth fun(self: OrdaenUIComponent): number
---@field GetHeight fun(self: OrdaenUIComponent): number
---@field IsMouseOver fun(self: OrdaenUIComponent): boolean
---@field LockHighlight fun(self: OrdaenUIComponent)
---@field UnlockHighlight fun(self: OrdaenUIComponent)
---@field SetAlpha fun(self: OrdaenUIComponent, alpha: number)
---@field SetClampedToScreen fun(self: OrdaenUIComponent, clamped: boolean)
local Base = {}
local BaseMeta = { __index = Base }

local function run(list, instance, ...)
	if list then
		for i = 1, #list do
			call(list[i], instance, ...)
		end
	end
end

-- User events --------------------------------------------------------------------------------------

-- event -> WoW script, and what the frame needs before the script fires.
local SCRIPTS = {
	click = "OnClick",
	enter = "OnEnter",
	leave = "OnLeave",
	mousedown = "OnMouseDown",
	mouseup = "OnMouseUp",
	dragstart = "OnDragStart",
	dragstop = "OnDragStop",
	wheel = "OnMouseWheel",
}

local dispatchers = {}
for event in pairs(SCRIPTS) do
	dispatchers[event] = function(frame, ...)
		local instance = byFrame[frame]
		if instance then
			run(instance.listeners[event], instance, ...)
		end
	end
end

local function prepare(instance, event)
	local frame = instance.frame
	if event == "wheel" then
		frame:EnableMouseWheel(true)
	else
		frame:EnableMouse(true)
	end
	if event == "click" then
		frame:RegisterForClicks("AnyUp")
	elseif event == "dragstart" or event == "dragstop" then
		frame:RegisterForDrag("LeftButton")
	end
	frame:SetScript(SCRIPTS[event], dispatchers[event])
end

-- Game events ------------------------------------------------------------------------------------

local eventFrame
local gameListeners = {} -- event -> array of instances listening (replaced, never changed, while dispatching)

local function onGameEvent(_, event, ...)
	local list = gameListeners[event]
	if list then
		for i = 1, #list do
			local instance = list[i]
			run(instance.listeners[event], instance, ...)
		end
	end
end

local function listenGame(instance, event)
	local old = gameListeners[event]
	local list = {}
	if old then
		for i = 1, #old do
			if old[i] == instance then
				return -- already listening; its own handler list holds the new function
			end
			list[i] = old[i]
		end
	else
		if not eventFrame then
			eventFrame = CreateFrame("Frame")
			eventFrame:SetScript("OnEvent", onGameEvent)
		end
		eventFrame:RegisterEvent(event)
	end
	list[#list + 1] = instance
	gameListeners[event] = list
end

local function stopGame(instance, event)
	local old = gameListeners[event]
	if not old then
		return
	end
	local list = {}
	for i = 1, #old do
		if old[i] ~= instance then
			list[#list + 1] = old[i]
		end
	end
	if #list == 0 then
		gameListeners[event] = nil
		eventFrame:UnregisterEvent(event)
	else
		gameListeners[event] = list
	end
end

local function isGameEvent(event)
	return event:find("^%u[%u%d_]*$") ~= nil
end

-- Methods ----------------------------------------------------------------------------------------

--- Call `fn(self, ...)` on `event`: a user event (lower case) or a Blizzard game event (UPPER_CASE).
---@param event string
---@param fn fun(self: OrdaenUIComponent, ...)
function Base:On(event, fn)
	local list = self.listeners[event]
	if list then
		local copy = {}
		for i = 1, #list do
			copy[i] = list[i]
		end
		list = copy
	else
		list = {}
		if isGameEvent(event) then
			listenGame(self, event)
		elseif SCRIPTS[event] then
			prepare(self, event)
		else
			error("OrdaenCore.UI: unknown event " .. tostring(event), 2)
		end
	end
	list[#list + 1] = fn
	self.listeners[event] = list
end

--- Stop calling `fn` on `event`.
function Base:Off(event, fn)
	local old = self.listeners[event]
	if not old then
		return
	end
	local list = {}
	for i = 1, #old do
		if old[i] ~= fn then
			list[#list + 1] = old[i]
		end
	end
	if #list > 0 then
		self.listeners[event] = list
		return
	end
	self.listeners[event] = nil
	if isGameEvent(event) then
		stopGame(self, event)
	end
end

local function showTooltip(self)
	self.tooltip:Show(self.frame)
end

local function hideTooltip(self)
	self.tooltip:Hide(self.frame)
end

--- Show `tooltip` while the mouse is over this block (`tooltip = tip` in the spec does the same).
---@param tooltip OrdaenUITooltip
function Base:Tooltip(tooltip)
	if not self.tooltip then
		self:On("enter", showTooltip)
		self:On("leave", hideTooltip)
	end
	self.tooltip = tooltip
end

--- Lay out and redraw after the block's fields changed.
function Base:Refresh()
	Render.Draw(self.frame, self.block, self.block.width)
	if self.tooltip then
		self.tooltip:Refresh()
	end
end

--- Set the text of the block's first text element and redraw.
---@param text string
function Base:SetText(text)
	for i = 1, #self.block do
		local child = self.block[i]
		if child.text ~= nil then
			child.text = text
			self:Refresh()
			return
		end
	end
end

-- Placement and visibility go straight to the frame: they are where the block sits, not how it looks.
local PASSTHROUGH = {
	"SetPoint", "ClearAllPoints", "GetPoint", "SetParent", "GetParent",
	"Show", "Hide", "IsShown", "IsVisible", "SetShown",
	"SetFrameStrata", "GetFrameStrata", "SetFrameLevel", "GetFrameLevel",
	"SetScale", "GetScale", "GetEffectiveScale", "GetCenter", "GetWidth", "GetHeight",
	"IsMouseOver", "LockHighlight", "UnlockHighlight", "SetAlpha", "SetClampedToScreen",
}
for _, method in ipairs(PASSTHROUGH) do
	Base[method] = function(self, ...)
		local frame = self.frame
		return frame[method](frame, ...)
	end
end

-- Creating ---------------------------------------------------------------------------------------

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

---@class OrdaenUIComponentSpec : OrdaenUIBlock
---@field name string|nil global name of the frame
---@field parent Frame|nil default UIParent
---@field strata string|nil frame strata
---@field level number|nil frame level
---@field tooltip OrdaenUITooltip|nil shown while the mouse is over it
---@field on table<string, fun(self: OrdaenUIComponent, ...)>|nil listeners, as with :On

local function create(spec, defaultStyle)
	if spec.style == nil then
		spec.style = defaultStyle
	end
	local frame = CreateFrame("Button", spec.name, spec.parent or UIParent, BACKDROP_TEMPLATE)
	frame:EnableMouse(false) -- until a user listener asks for it: clicks pass through to what's underneath
	if spec.strata then
		frame:SetFrameStrata(spec.strata)
	end
	if spec.level then
		frame:SetFrameLevel(spec.level)
	end
	local instance = setmetatable({ frame = frame, block = spec, listeners = {} }, BaseMeta)
	byFrame[frame] = instance
	if spec.on then
		for event, fn in pairs(spec.on) do
			instance:On(event, fn)
		end
	end
	if spec.tooltip then
		local tip = spec.tooltip
		spec.tooltip = nil -- the block tree is data; the tooltip belongs to the instance
		instance:Tooltip(tip)
	end
	instance:Refresh()
	return instance
end

--- A block on its own surface: shows its tree, takes events only if given listeners.
---@param spec OrdaenUIComponentSpec
---@return OrdaenUIComponent
function Component.Block(spec)
	return create(spec, nil)
end

--- A clickable block; style "button" (no surface) unless the spec names one, e.g. "iconButton".
---@param spec OrdaenUIComponentSpec
---@return OrdaenUIComponent
function Component.Button(spec)
	return create(spec, "button")
end

--- Redraw every instance (after a theme or text-size change). Rare: only on a settings change.
function Component.RefreshAll()
	for _, instance in pairs(byFrame) do
		Render.Draw(instance.frame, instance.block, instance.block.width)
	end
end

--- The instance that owns a WoW frame, if any (for specs and dumps).
function Component.Of(frame)
	return byFrame[frame]
end

Component.Base = Base
