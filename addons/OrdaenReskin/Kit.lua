-- Ordaen Reskin's control kit: finds Blizzard's standard controls inside a window and dresses each in the theme's
-- role for it (OrdaenCore.UI, UI.Dress drawn on the control): tabs and side tabs, push buttons, the close button,
-- checkboxes, dropdowns, input boxes, scroll bars (track, thumb, steppers), item slots and insets. Only a control's
-- art is handed over to be hidden (its Left/Middle/Right pieces and its Normal/Pushed/Disabled/Highlight
-- textures); its text, icon, clicks and scripts stay Blizzard's. A control whose state matters (enabled, pushed,
-- checked, the selected tab) is dressed with `track`, so the renderer follows it.
--
-- A role the theme doesn't define yet is skipped (the control keeps Blizzard's look), so the kit never leaves a
-- control without art. Prior art: EllesmereUI's window skin engine (ideas only; its licence reserves the code).
--
-- Cost: runs when a window is skinned or shows again (a rare event), never per frame. Each control is dressed once
-- (a weak table remembers it); a scan only looks up controls it has seen.
local _, ns = ...

local UI = OrdaenCore.UI

local Kit = {}
ns.Kit = Kit

local dressed = setmetatable({}, { __mode = "k" }) -- control -> its dress, or false (its role isn't in the theme)
local collect -- the window being skinned is told of each new dress (Kit.CollectInto), so it can undress them

-- Roles every theme had before the renderer could answer UI.HasStyle (the window art, 2026-11-07).
local KNOWN = { window = true, portraitWindow = true, dialog = true, inset = true }

-- Whether the theme draws this role: the renderer answers with UI.HasStyle; without it only the KNOWN roles are, and
-- controls keep Blizzard's look.
local function ready(role)
	local hasStyle = rawget(UI, "HasStyle")
	if type(hasStyle) ~= "function" then
		return KNOWN[role] == true
	end
	return hasStyle(role) and true or false
end

local function isTexture(t)
	return type(t) == "table" and type(t.IsObjectType) == "function" and t:IsObjectType("Texture")
end

local function add(art, t)
	if isTexture(t) then
		art[#art + 1] = t
	end
end

local function addKeys(art, obj, keys)
	for i = 1, #keys do
		add(art, rawget(obj, keys[i]))
	end
end

-- A button's state textures (the Button widget's own slots).
local function addButtonTextures(art, button)
	add(art, button:GetNormalTexture())
	add(art, button:GetPushedTexture())
	add(art, button:GetDisabledTexture())
	add(art, button:GetHighlightTexture())
end

-- Every texture region of a frame (a Track's or a Thumb's three pieces, a NineSlice).
local function addRegions(art, frame)
	if type(frame) ~= "table" or type(frame.GetRegions) ~= "function" then
		return
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		add(art, region)
	end
end

local SLICE_PARTS = { "Left", "Middle", "Right" }
local TAB_PARTS = {
	"Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight",
	"RightHighlight", "LeftDisabled", "MiddleDisabled", "RightDisabled",
}
local INPUT_PARTS = { "Left", "Middle", "Right", "Mid" }
local DROPDOWN_PARTS = { "Background", "Left", "Middle", "Right", "Arrow" }
local SLOT_PARTS = { "IconBorder", "SlotBackground" }

--- Dress `control` in `role` with these art textures hidden; once per control. Returns its dress, or nil when the
--- theme has no such role (or the framework can't load).
---@param control table
---@param role string
---@param art Texture[]
---@param opts table|nil more UI.Dress options (track, states)
---@return OrdaenUIDress|nil
function Kit.Dress(control, role, art, opts)
	local known = dressed[control]
	if known ~= nil then
		return known or nil
	end
	if not ready(role) then
		dressed[control] = false
		return nil
	end
	local spec = { style = role, size = "frame", art = art }
	if opts then
		for k, v in pairs(opts) do
			spec[k] = v
		end
	end
	local dress = UI.Dress(control, spec)
	dressed[control] = dress or false
	if dress and collect then
		collect(dress)
	end
	return dress
end

--- While `fn` runs, every new dress is passed to `into` (a window collecting what it made); nested calls restore.
---@param into fun(dress: OrdaenUIDress)
---@param fn function
function Kit.CollectInto(into, fn, ...)
	local previous = collect
	collect = into
	local ok, err = pcall(fn, ...)
	collect = previous
	if not ok then
		error(err, 0)
	end
end

--- Forget what the kit decided for every control (the theme changed: roles may have appeared).
function Kit.Reset()
	for control, dress in pairs(dressed) do
		if not dress then
			dressed[control] = nil
		end
	end
end

--- A tab (PanelTabButtonTemplate along a window's edge) or, with `side`, a side tab (the square icon tabs).
function Kit.Tab(tab, side)
	local art = {}
	addKeys(art, tab, TAB_PARTS)
	addButtonTextures(art, tab)
	local role = side and "sideTab" or "tab"
	return Kit.Dress(tab, role, art, { track = "tab", states = { selected = role .. "Selected" } })
end

--- A push button (UIPanelButtonTemplate: three slices).
function Kit.Button(button)
	local art = {}
	addKeys(art, button, SLICE_PARTS)
	addButtonTextures(art, button)
	return Kit.Dress(button, "pushButton", art, { track = "button",
		states = { pushed = "pushButtonPushed", disabled = "pushButtonDisabled" } })
end

--- A window's close button (the red X).
function Kit.CloseButton(button)
	local art = {}
	addButtonTextures(art, button)
	add(art, rawget(button, "Border"))
	return Kit.Dress(button, "closeButton", art, { track = "button",
		states = { pushed = "closeButtonPushed", disabled = "closeButtonDisabled" } })
end

--- A checkbox; its tick is part of its state (checked), drawn by the theme.
function Kit.Checkbox(check)
	local art = {}
	addButtonTextures(art, check)
	add(art, check:GetCheckedTexture())
	add(art, check:GetDisabledCheckedTexture())
	return Kit.Dress(check, "checkbox", art, { track = "checkbox", states = { checked = "checkboxChecked" } })
end

--- A dropdown (WowStyle1DropdownTemplate and the older three-slice one).
function Kit.Dropdown(dropdown)
	local art = {}
	addKeys(art, dropdown, DROPDOWN_PARTS)
	addButtonTextures(art, dropdown)
	return Kit.Dress(dropdown, "dropdown", art, { track = "button" })
end

--- An input box (InputBoxTemplate, SearchBoxTemplate: three slices).
function Kit.Input(editBox)
	local art = {}
	addKeys(art, editBox, INPUT_PARTS)
	return Kit.Dress(editBox, "input", art)
end

--- A scroll bar (MinimalScrollBar and ScrollBar templates): its track, thumb and the two steppers.
function Kit.ScrollBar(bar)
	local track, thumb = rawget(bar, "Track"), rawget(bar, "Thumb")
	if type(track) == "table" then
		local art = {}
		addRegions(art, track)
		Kit.Dress(track, "scrollTrack", art)
		thumb = thumb or rawget(track, "Thumb")
	end
	if type(thumb) == "table" then
		local art = {}
		addRegions(art, thumb)
		if thumb.GetNormalTexture then
			addButtonTextures(art, thumb)
		end
		Kit.Dress(thumb, "scrollThumb", art, { track = "button" })
	end
	for _, key in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
		local stepper = rawget(bar, key)
		if type(stepper) == "table" and stepper.GetNormalTexture then
			local art = {}
			addButtonTextures(art, stepper)
			Kit.Dress(stepper, "scrollStepper", art, { track = "button",
				states = { disabled = "scrollStepperDisabled" } })
		end
	end
end

--- An item slot (ItemButton): its frame art goes, its icon and count stay; quality is the dress's accent.
function Kit.Slot(button)
	local art = {}
	addKeys(art, button, SLOT_PARTS)
	add(art, button:GetNormalTexture())
	add(art, button:GetPushedTexture())
	return Kit.Dress(button, "slot", art, { track = "button" })
end

--- An inner pane with its own border (InsetFrameTemplate: a NineSlice and a Bg).
function Kit.Inset(inset)
	local art = {}
	addRegions(art, rawget(inset, "NineSlice"))
	add(art, rawget(inset, "Bg"))
	return Kit.Dress(inset, "inset", art, { borderAbove = true })
end

--- What kind of standard control a frame is, by its widget type and the parts its template gives it; nil for
--- anything else (content, list rows, art).
---@param frame table
---@return string|nil one of "Checkbox", "Input", "Slot", "ScrollBar", "Dropdown", "Tab", "Button", "Inset"
function Kit.Classify(frame)
	if frame:IsForbidden() then
		return nil
	end
	local kind = frame:GetObjectType()
	local track = rawget(frame, "Track")
	if type(track) == "table" and (rawget(frame, "Thumb") or rawget(track, "Thumb")) then
		return "ScrollBar"
	elseif kind == "CheckButton" then
		return "Checkbox"
	elseif kind == "EditBox" then
		return (rawget(frame, "Left") and (rawget(frame, "Middle") or rawget(frame, "Mid"))) and "Input" or nil
	elseif kind == "ItemButton" then
		return "Slot"
	elseif kind == "Button" or kind == "DropdownButton" then
		if rawget(frame, "Arrow") and rawget(frame, "Text") then
			return "Dropdown"
		elseif rawget(frame, "LeftActive") or rawget(frame, "MiddleActive") then
			return "Tab"
		elseif rawget(frame, "Left") and rawget(frame, "Middle") and rawget(frame, "Right") then
			return "Button"
		end
	elseif kind == "Frame" and rawget(frame, "NineSlice") and rawget(frame, "Bg") then
		return "Inset"
	end
	return nil
end

local MAX_DEPTH = 6

--- Dress every standard control under `frame` (to MAX_DEPTH levels), skipping the children in `skip` (a window's
--- content that holds no controls, such as the World Map's canvas).
---@param frame table
---@param skip table<table, boolean>|nil
---@param depth integer|nil
function Kit.ControlsIn(frame, skip, depth)
	depth = depth or 1
	if depth > MAX_DEPTH then
		return
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if not (skip and skip[child]) and not child:IsForbidden() then
			local kind = Kit.Classify(child)
			if kind then
				if dressed[child] == nil then
					Kit[kind](child)
				end
				if kind == "Inset" then
					Kit.ControlsIn(child, skip, depth + 1)
				end
			else
				Kit.ControlsIn(child, skip, depth + 1)
			end
		end
	end
end
