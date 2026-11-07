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
-- dragstop, wheel) and the framework's own (render: drawn, with its width and height), upper case = Blizzard's
-- game events, with Blizzard's arguments unchanged. Listeners get the instance first. No bubbling. The frame takes
-- the mouse only once a user listener exists. Sizes change only when the framework draws (or the UI scale changes,
-- which re-places panels), so `render` is where anything that follows a block's size hooks in: nobody watches
-- frame sizes.
--
-- Cost: one metatable per component kind, one table per instance, created once. The WoW scripts are a fixed set
-- of dispatchers (one function per event name, made at load), so :On creates no closure. Game events go through
-- one shared frame that registers an event only while some instance listens.
local _, ns = ...

local Render = ns.Render

local Component = {}
ns.Component = Component

-- Listeners run protected: an error in one is reported (geterrorhandler: BugSack, Blizzard, dev mode) and the rest
-- still run. Not through securecallfunction: it ends the "the player clicked" state the game needs for protected
-- calls, so a button whose listener calls ReloadUI was blocked ("call to Reload() was blocked", the conflict
-- dialog, 2026-11-06). xpcall keeps the listener in the click's own call. WoW's xpcall passes arguments; plain Lua
-- 5.1 (the specs) doesn't, so that case falls back to pcall and reports the error afterwards.
local function report(err)
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		handler(err)
	end
	return err
end
local XPCALL_PASSES_ARGS = select(2, xpcall(function(value)
	return value
end, report, true)) == true
local call
if XPCALL_PASSES_ARGS then
	call = function(fn, ...)
		return xpcall(fn, report, ...)
	end
else
	call = function(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			report(err)
		end
	end
end

local byFrame = setmetatable({}, { __mode = "k" }) -- WoW frame -> instance

---@class OrdaenUIComponent
---@field frame Button the WoW frame this instance draws on (for anchoring other frames to it)
---@field block OrdaenUIBlock the instance's block tree (change fields, then :Refresh())
---@field tooltip OrdaenUITooltip|nil shown while the mouse is over it
---@field listeners table<string, function[]> event -> listeners, in the order added (replaced, never changed)
---@field onDrawn fun(self: OrdaenUIComponent)|nil the framework's own follower of each draw (a panel's inset)
--- Placement and visibility, passed to the frame (PASSTHROUGH below):
---@field SetPoint fun(self: OrdaenUIComponent, point: string, relTo: any, relPoint: string?, x: number?, y: number?)
---@field ClearAllPoints fun(self: OrdaenUIComponent)
---@field SetAllPoints fun(self: OrdaenUIComponent, target: table)
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

-- The framework's own events: no WoW script behind them, fired by the framework itself.
local OWN_EVENTS = { render = true }

local dispatchers = {}
for event in pairs(SCRIPTS) do
	dispatchers[event] = function(frame, ...)
		local instance = byFrame[frame]
		if instance then
			run(instance.listeners[event], instance, ...)
		end
	end
end
-- enter and leave also show a hover drawn under the content (`highlight.under` in the style: Render.Hover)
local function hoverDispatcher(event, on)
	local listeners = dispatchers[event]
	dispatchers[event] = function(frame, ...)
		Render.Hover(frame, on)
		listeners(frame, ...)
	end
end
hoverDispatcher("enter", true)
hoverDispatcher("leave", false)

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
-- Each component's own frame registers the game events it listens to (only while it does), with one dispatcher made
-- at load. The frame was made when the addon built the component, so WoW's profiler bills the events to that addon,
-- not to the framework (one shared frame made them all OrdaenCore_UI's).

local function onGameEvent(frame, event, ...)
	local instance = byFrame[frame]
	if instance then
		run(instance.listeners[event], instance, ...)
	end
end

local function listenGame(instance, event)
	local frame = instance.frame
	if not frame:GetScript("OnEvent") then
		frame:SetScript("OnEvent", onGameEvent)
	end
	frame:RegisterEvent(event)
end

local function stopGame(instance, event)
	instance.frame:UnregisterEvent(event)
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
		elseif not OWN_EVENTS[event] then
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

-- Draw an instance, then tell who listens: its own "render" listeners (other addons following its size), and the
-- framework's internal follower (a panel recording how much of its edge it covers).
local function draw(instance)
	local frame = instance.frame
	Render.Draw(frame, instance.block, instance.block.width)
	if Render.HasHover(frame) and not frame:GetScript("OnEnter") then
		-- its style hovers under the content: it needs the mouse and enter/leave even without listeners
		frame:EnableMouse(true)
		frame:SetScript("OnEnter", dispatchers.enter)
		frame:SetScript("OnLeave", dispatchers.leave)
	end
	if instance.onDrawn then
		instance.onDrawn(instance)
	end
	local list = instance.listeners.render
	if list then
		run(list, instance, frame:GetWidth(), frame:GetHeight())
	end
end

--- Where an element of this block (a child at any depth) was drawn last: x, y from the frame's top left, width,
--- height; nil when it isn't drawn (hidden). For putting other frames exactly over a cell (Blizzard's buttons over
--- the cells of a row we draw).
---@param element table
---@return number|nil, number|nil, number|nil, number|nil
function Base:RectOf(element)
	return Render.RectOf(self.block, element)
end

--- Open sides of its window art: none there, as if it ran on past the screen edge or into the surface beside it
--- (a panel on the bottom edge: { bottom = true }; the chat on that panel: { bottom = true }, the panel:
--- { top = true }). Set by the addon that docks it; nil closes them all. Redraws.
---@param sides { top: boolean|nil, right: boolean|nil, bottom: boolean|nil, left: boolean|nil }|nil
function Base:SetOpen(sides)
	self.block.open = sides
	self:Refresh()
end

--- Lay out and redraw after the block's fields changed. Fires "render" (width, height) when drawn.
function Base:Refresh()
	draw(self)
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
	"SetPoint", "ClearAllPoints", "SetAllPoints", "GetPoint", "SetParent", "GetParent",
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
		draw(instance)
	end
end

--- The instance that owns a WoW frame, if any (for specs and dumps).
function Component.Of(frame)
	return byFrame[frame]
end

Component.Base = Base

-- Panels: a block pinned to a screen edge -----------------------------------------------------------------------
-- Full length (the whole edge) or fit to its content, centred on the edge. Faded by an animation group (the game
-- runs it, no OnUpdate); a faded panel takes no clicks but still notices the mouse, so "show on mouseover" can bring
-- it back.

---@class OrdaenUIPanelOpts
---@field edge string|nil "bottom" (default), "top", "left", "right"
---@field fit string|nil "full" (default: the whole edge) or "center" (as long as its content, centred)
---@field offset number|nil distance from the edge

---@class OrdaenUIPanel : OrdaenUIComponent
---@field panel OrdaenUIPanelOpts
---@field fade AnimationGroup
---@field fadeAlpha Alpha
---@field targetAlpha number

local EDGE_POINT = { bottom = "BOTTOM", top = "TOP", left = "LEFT", right = "RIGHT" }
local EDGE_DIRECTION = { bottom = { 0, 1 }, top = { 0, -1 }, left = { 1, 0 }, right = { -1, 0 } }

---@class OrdaenUIPanel
local Panel = setmetatable({}, { __index = Base })
local PanelMeta = { __index = Panel }

-- How much of each screen edge the panels cover (thickness plus offset), so other frames can sit beside them
-- (Ordaen Chat above a bottom panel). A change is announced with EventRegistry "OrdaenUI.InsetsChanged".
local covers = {} -- panel -> { edge, thickness }
local insets = { bottom = 0, top = 0, left = 0, right = 0 }

local updateInsets

-- A panel's thickness on its edge, from its frame as drawn: run after every draw (placed or refreshed), because a
-- panel grows after its first placement as its content fills in (13 then 40 UI units for Ordaen Panel,
-- 2026-11-06). A faded panel still covers its edge (fading it doesn't move what sits beside it).
local function recordCover(self)
	local cover = covers[self]
	if not cover then
		return
	end
	local frame = self.frame
	local horizontal = cover[1] == "bottom" or cover[1] == "top"
	cover[2] = (horizontal and frame:GetHeight() or frame:GetWidth()) + (cover[3] or 0)
	updateInsets()
end

function updateInsets()
	local changed = false
	for edge, old in pairs(insets) do
		local inset = 0
		for _, cover in pairs(covers) do
			if cover[1] == edge and cover[2] > inset then
				inset = cover[2]
			end
		end
		if inset ~= old then
			insets[edge], changed = inset, true
		end
	end
	if changed then
		EventRegistry:TriggerEvent("OrdaenUI.InsetsChanged")
	end
end

--- How much of `edge` ("bottom", "top", "left", "right") the panels cover, in UI units (0 when none).
---@param edge string
---@return number
function Component.ScreenInset(edge)
	return insets[edge] or 0
end

-- Size and place the panel for the screen as it is now (again after a resolution or UI scale change).
local function placePanel(self)
	local opts, block, frame = self.panel, self.block, self.frame
	-- an owner that put in a new block (a layout change) keeps the panel's look: no style means "panel" here too
	if block.style == nil then
		block.style = "panel"
	end
	local edge = EDGE_POINT[opts.edge] and opts.edge or "bottom"
	local horizontal = edge == "bottom" or edge == "top"
	if opts.fit ~= "center" then
		if horizontal then
			block.width, block.height = UIParent:GetWidth(), nil
		else
			block.width, block.height = nil, UIParent:GetHeight()
		end
	end
	local d = EDGE_DIRECTION[edge]
	local offset = opts.offset or 0
	frame:ClearAllPoints()
	frame:SetPoint(EDGE_POINT[edge], UIParent, EDGE_POINT[edge], d[1] * offset, d[2] * offset)
	local cover = covers[self] or {}
	covers[self] = cover
	cover[1], cover[3] = edge, offset
	draw(self) -- records the cover (onDrawn)
end

local function onScreenChanged(self)
	placePanel(self)
end

--- Fade to `alpha` over `seconds` (default: the theme's motion.fade). Below full alpha the panel takes no clicks
--- (they reach what's underneath) but still gets enter/leave, so mouseover can show it again.
---@param alpha number 0..1
---@param seconds number|nil
function Panel:FadeTo(alpha, seconds)
	local frame = self.frame
	seconds = seconds or ns.Theme.Fade()
	self.targetAlpha = alpha
	frame:SetMouseClickEnabled(alpha >= 1)
	self.fade:Stop()
	if seconds <= 0 or frame:GetAlpha() == alpha then
		frame:SetAlpha(alpha)
		return
	end
	self.fadeAlpha:SetFromAlpha(frame:GetAlpha())
	self.fadeAlpha:SetToAlpha(alpha)
	self.fadeAlpha:SetDuration(seconds)
	self.fade:Play()
end

--- Whether the panel is faded (or fading) below full alpha.
---@return boolean
function Panel:IsFaded()
	return self.targetAlpha < 1
end

--- Place the panel again (after its options changed: edge, fit, offset).
function Panel:Place()
	placePanel(self)
end

--- A block pinned to a screen edge (style "panel" unless given). Takes events like any component.
---@param spec OrdaenUIComponentSpec
---@param opts OrdaenUIPanelOpts|nil
---@return OrdaenUIPanel
function Component.Panel(spec, opts)
	local instance = create(spec, "panel") --[[@as OrdaenUIPanel]]
	setmetatable(instance, PanelMeta)
	instance.panel = opts or {}
	instance.targetAlpha = 1
	local fade = instance.frame:CreateAnimationGroup()
	fade:SetToFinalAlpha(true)
	instance.fade = fade
	instance.fadeAlpha = fade:CreateAnimation("Alpha") --[[@as Alpha]]
	instance:On("DISPLAY_SIZE_CHANGED", onScreenChanged)
	instance:On("UI_SCALE_CHANGED", onScreenChanged)
	instance.onDrawn = recordCover
	placePanel(instance)
	return instance
end

-- Windows: a block the player drags around, closed by Escape, its position remembered by the framework ------------
-- (OrdaenCoreDB.ui.windows[name]: the addon keeps nothing). It needs a global name: that's what Escape closes and what
-- the position is saved under. Hidden until the owner shows it.

---@class OrdaenUIWindowOpts
---@field point string|nil where it opens the first time (default "CENTER" of the screen)
---@field x number|nil
---@field y number|nil

---@class OrdaenUIWindow : OrdaenUIComponent
---@field window OrdaenUIWindowOpts

---@class OrdaenUIWindow
local Window = setmetatable({}, { __index = Base })
local WindowMeta = { __index = Window }

-- The saved window positions (name -> { point, x, y }), in Ordaen Core's SavedVariables; nil before they load.
local function windowPositions()
	local db = rawget(_G, "OrdaenCoreDB")
	if type(db) ~= "table" then
		return nil
	end
	db.ui = type(db.ui) == "table" and db.ui or {}
	db.ui.windows = type(db.ui.windows) == "table" and db.ui.windows or {}
	return db.ui.windows
end

local function placeWindow(self)
	local frame, opts = self.frame, self.window
	local saved = windowPositions()
	saved = saved and saved[frame:GetName()]
	frame:ClearAllPoints()
	if type(saved) == "table" and type(saved[1]) == "string" then
		frame:SetPoint(saved[1], UIParent, saved[1], saved[2] or 0, saved[3] or 0)
	else
		local point = opts.point or "CENTER"
		frame:SetPoint(point, UIParent, point, opts.x or 0, opts.y or 0)
	end
end

local function onWindowDragStart(self)
	self.frame:StartMoving()
end

-- Dropped: remember where (one small table per drag, a player's action).
local function onWindowDragStop(self)
	local frame = self.frame
	frame:StopMovingOrSizing()
	local point, _, _, x, y = frame:GetPoint(1)
	local saved = windowPositions()
	if saved and point then
		saved[frame:GetName()] = { point, math.floor(x + 0.5), math.floor(y + 0.5) }
	end
end

--- Place it where it was left again (or where it opens the first time).
function Window:Place()
	placeWindow(self)
end

--- Forget where the player left it: it opens at its first place again.
function Window:ResetPosition()
	local saved = windowPositions()
	if saved then
		saved[self.frame:GetName()] = nil
	end
	placeWindow(self)
end

--- A window (style "window" unless the spec names one): dragged by any spot that isn't a child taking the mouse,
--- closed by Escape, its position remembered. Hidden until shown.
---@param spec OrdaenUIComponentSpec needs `name`
---@param opts OrdaenUIWindowOpts|nil
---@return OrdaenUIWindow
function Component.Window(spec, opts)
	assert(type(spec.name) == "string", "a window needs a name: its position is saved under it")
	local instance = create(spec, "window") --[[@as OrdaenUIWindow]]
	setmetatable(instance, WindowMeta)
	instance.window = opts or {}
	local frame = instance.frame
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	instance:On("dragstart", onWindowDragStart)
	instance:On("dragstop", onWindowDragStop)
	table.insert(UISpecialFrames, spec.name) -- Escape closes it, as Blizzard's windows
	frame:Hide()
	placeWindow(instance)
	return instance
end

-- Inputs: a text box (Blizzard's EditBox) in the theme's look and font -------------------------------------------
-- Put it in a block with { embed = input }. Events: "change" (the player typed: text), "enter", "escape" (it gives up
-- the keyboard first). A placeholder in the hint style shows while it's empty and not being typed in.

---@class OrdaenUIInputSpec
---@field name string|nil global name of the EditBox
---@field parent Frame|nil default UIParent
---@field width number|nil UI units (default 160)
---@field placeholder string|nil shown while empty ("Search")
---@field on table<string, fun(self: OrdaenUIInput, ...)>|nil listeners, as with :On

---@class OrdaenUIInput
---@field frame EditBox
---@field listeners table<string, function[]>
---@field placeholder FontString
local Input = {}
local InputMeta = { __index = Input }

local INPUT_EVENTS = { change = true, enter = true, escape = true }
local inputs = setmetatable({}, { __mode = "k" }) -- EditBox -> its input

--- Listen to "change" (text), "enter" or "escape". Plain functions; they get the input first.
---@param event string
---@param fn function
function Input:On(event, fn)
	assert(INPUT_EVENTS[event], "an input's events are change, enter and escape")
	local list = self.listeners[event]
	if not list then
		list = {}
		self.listeners[event] = list
	end
	list[#list + 1] = fn
end

---@param event string
---@param fn function
function Input:Off(event, fn)
	local list = self.listeners[event]
	for i = list and #list or 0, 1, -1 do
		if list[i] == fn then
			table.remove(list, i)
		end
	end
end

local function showPlaceholder(self)
	local box = self.frame
	self.placeholder:SetShown(box:GetText() == "" and not box:HasFocus())
end

---@return string
function Input:GetText()
	return self.frame:GetText()
end

--- Set the text (no "change" event: only the player's typing fires it).
---@param text string
function Input:SetText(text)
	self.frame:SetText(text or "")
	showPlaceholder(self)
end

function Input:ClearFocus()
	self.frame:ClearFocus()
end

local function onInputTextChanged(box, userInput)
	local self = inputs[box]
	if not self then
		return
	end
	showPlaceholder(self)
	if userInput then
		run(self.listeners.change, self, box:GetText())
	end
end

local function onInputEnter(box)
	local self = inputs[box]
	if self then
		run(self.listeners.enter, self)
	end
end

local function onInputEscape(box)
	box:ClearFocus()
	local self = inputs[box]
	if self then
		run(self.listeners.escape, self)
	end
end

local function onInputFocus(box)
	local self = inputs[box]
	if self then
		showPlaceholder(self)
	end
end

--- A text box. Its size: `width` and the theme's body text height plus room around it.
---@param spec OrdaenUIInputSpec
---@return OrdaenUIInput
function Component.Input(spec)
	local box = CreateFrame("EditBox", spec.name, spec.parent or UIParent) --[[@as EditBox]]
	local Theme = ns.Theme
	box:SetAutoFocus(false)
	local space = Theme.Space
	local textStyle = Theme.TextStyle("body")
	local role = Theme.BlockStyle("input")
	box:SetSize(spec.width or 160, role and role.height or textStyle.size + 2 * space("sm"))
	-- The text starts past the border's end caps (as drawn), plus a little room.
	local capLeft, capRight = Render.ControlInsets("input")
	box:SetTextInsets(capLeft + space("sm"), capRight + space("sm"), 0, 0)
	ns.Dress.Font(box, "body")
	local placeholder = box:CreateFontString(nil, "ARTWORK")
	ns.Dress.Font(placeholder, "hint")
	local hint = Theme.TextStyle("hint").color
	placeholder:SetTextColor(hint[1], hint[2], hint[3], hint[4] or 1)
	placeholder:SetPoint("LEFT", box, "LEFT", capLeft + space("sm"), 0)
	placeholder:SetText(spec.placeholder or "")
	local self = setmetatable({ frame = box, listeners = {}, placeholder = placeholder }, InputMeta)
	inputs[box] = self
	box:SetScript("OnTextChanged", onInputTextChanged)
	box:SetScript("OnEnterPressed", onInputEnter)
	box:SetScript("OnEscapePressed", onInputEscape)
	box:SetScript("OnEditFocusGained", onInputFocus)
	box:SetScript("OnEditFocusLost", onInputFocus)
	ns.Dress.New(box, { style = "input", size = "frame", art = {} }) -- after SetScript: it hooks the box's scripts
	for event, fn in pairs(spec.on or {}) do
		self:On(event, fn)
	end
	showPlaceholder(self)
	return self
end
