-- OrdaenCore.UI tooltips (kind "tooltip"), format v1. Uses only its own locals plus the private registry from
-- UI.lua, so it can be packaged as a library later.
--
-- content = {
--   v = 1,
--   title = { text, icon?, color? },          -- icon: texture path or file ID
--   subtitle = { text, color? },
--   { kind = "row", label, value, color? },   -- label/value pair
--   { kind = "line", text, color? },
--   { kind = "bar", label, value, max, color? },
--   { kind = "separator" },
--   { kind = "hint", text },                  -- footer, e.g. "Click: open the calendar"
-- }
-- color = { r, g, b } (0..1) for MEANING ("an invite is pending"), not decoration: looks are the renderer's.
-- The format only grows: unknown kinds are skipped, or shown as their `text` if they have one.
-- opts = { anchor = "ANCHOR_RIGHT", x = 0, y = 0 }: placement only.
--
-- Cost: nothing is copied per show (we keep references to the caller's tables), no timers, no OnUpdate.
-- Callers keep their content tables and update a few fields; live tooltips call RefreshTooltip from their
-- own timer while shown.
local _, ns = ...
local UI, renderers = ns.UI, ns.renderers

-- Colors of the built-in (plain GameTooltip) output.
local WHITE = { 1, 1, 1 }
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.5, 0.5, 0.5 }

-- owner -> the content/opts it was shown with (references, not copies), and who drew it:
-- a renderer table, or false for the built-in lines. Weak keys: owners can be garbage collected.
local contentOf = setmetatable({}, { __mode = "k" })
local optsOf = setmetatable({}, { __mode = "k" })
local drawnBy = setmetatable({}, { __mode = "k" })

local function rgb(color, default)
	color = color or default
	return color[1], color[2], color[3]
end

local function reportError(err)
	local handler = geterrorhandler()
	if handler then
		handler(err)
	end
end

local function addSlot(tip, slot)
	local kind = slot.kind
	if kind == "row" then
		local r, g, b = rgb(slot.color, WHITE)
		tip:AddDoubleLine(tostring(slot.label or ""), tostring(slot.value or ""), GOLD[1], GOLD[2], GOLD[3], r, g, b)
	elseif kind == "line" then
		local r, g, b = rgb(slot.color, WHITE)
		tip:AddLine(tostring(slot.text or ""), r, g, b, true)
	elseif kind == "bar" then
		local r, g, b = rgb(slot.color, WHITE)
		tip:AddLine(string.format("%s: %s / %s", tostring(slot.label or ""), tostring(slot.value or 0),
			tostring(slot.max or 0)), r, g, b)
	elseif kind == "separator" then
		tip:AddLine(" ")
	elseif kind == "hint" then
		tip:AddLine(tostring(slot.text or ""), GREY[1], GREY[2], GREY[3], true)
	elseif slot.text ~= nil then
		tip:AddLine(tostring(slot.text), WHITE[1], WHITE[2], WHITE[3], true)
	end
end

--- The built-in output: plain GameTooltip lines, nothing else (no textures, no frames of our own).
local function drawLines(owner, content, opts, refresh)
	local tip = GameTooltip
	if refresh then
		tip:ClearLines()
	else
		tip:SetOwner(owner, opts and opts.anchor or "ANCHOR_RIGHT", opts and opts.x or 0, opts and opts.y or 0)
	end
	local title = content.title
	if title then
		local text = tostring(title.text or "")
		if title.icon then
			text = "|T" .. title.icon .. ":0|t " .. text
		end
		tip:AddLine(text, rgb(title.color, WHITE))
	end
	local subtitle = content.subtitle
	if subtitle then
		local r, g, b = rgb(subtitle.color, GOLD)
		tip:AddLine(tostring(subtitle.text or ""), r, g, b, true)
	end
	for i = 1, #content do
		addSlot(tip, content[i])
	end
	tip:Show()
end

--- Show a tooltip for `owner` (usually from its OnEnter).
---@param owner table the frame the tooltip belongs to
---@param content table see the top of this file
---@param opts table|nil placement only
function UI.ShowTooltip(owner, content, opts)
	contentOf[owner], optsOf[owner] = content, opts
	local renderer = renderers.tooltip
	if renderer then
		local ok, err = pcall(renderer.Show, owner, content, opts)
		if ok then
			drawnBy[owner] = renderer
			return
		end
		reportError(err)
	end
	drawnBy[owner] = false
	drawLines(owner, content, opts, false)
end

--- Hide `owner`'s tooltip (usually from its OnLeave). Safe to call when it isn't shown.
function UI.HideTooltip(owner)
	local drawer = drawnBy[owner]
	contentOf[owner], optsOf[owner], drawnBy[owner] = nil, nil, nil
	if drawer then
		local ok, err = pcall(drawer.Hide, owner)
		if not ok then
			reportError(err)
		end
	elseif drawer == false and GameTooltip:IsOwned(owner) then
		GameTooltip:Hide()
	end
end

--- Redraw `owner`'s tooltip from its content table (after the caller changed fields), if it is shown.
function UI.RefreshTooltip(owner)
	local content, drawer = contentOf[owner], drawnBy[owner]
	if not content or drawer == nil then
		return
	end
	if drawer then
		local ok, err = pcall(drawer.Refresh, owner, content)
		if ok then
			return
		end
		reportError(err)
		pcall(drawer.Hide, owner)
		drawnBy[owner] = false
		drawLines(owner, content, optsOf[owner], false)
	elseif GameTooltip:IsOwned(owner) then
		drawLines(owner, content, optsOf[owner], true)
	end
end
