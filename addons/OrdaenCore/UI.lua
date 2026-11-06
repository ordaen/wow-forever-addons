-- OrdaenCore.UI: the Ordaen UI framework's entry point, the only part every player loads. Addons declare what
-- they want and never learn how it's drawn. The framework itself (layout engine, theme, the one renderer,
-- components) is the load-on-demand addon OrdaenCore_UI, loaded on first use. See CLAUDE.md, "UI framework", and
-- the docs site in docs/.
--
--   local tip = UI.Tooltip({ { text = "Elwynn Forest", style = "title" } }, { side = "below" })
--   local zone = UI.Button({ name = "MyZone", parent = Minimap, tooltip = tip, { text = "", style = "normal" } })
--   zone:On("click", function() ToggleWorldMap() end)
--
-- Tooltip objects are made here and cost nothing until shown: the framework loads on the first :Show.
-- Components (UI.Block, UI.Button) own a frame, so making one loads the framework.
local addonName, ns = ...

local UI = {}
ns.UI = UI
ns.Core.UI = UI

local MODULE = "OrdaenCore_UI"

local impl -- the framework's functions, handed over by the module when it loads
local unavailable = false

---@class OrdaenUIText
---@field text string|nil the text, or:
---@field format string|nil a format for args (drawn with SetFormattedText: no Lua string per change)
---@field args any[]|nil values for format
---@field style string|nil text style in the theme: title, subtitle, body (default), label, value, hint, caption,
--- normal, small (the last two for labels on the world, e.g. the minimap)
---@field color number[]|nil { r, g, b [, a] }, for meaning only (a pending invite), not decoration
---@field caps boolean|nil capitals (plain text only); default from the style
---@field shift boolean|nil as a child: true = only while Shift is held, false = only while it isn't
---@field hidden boolean|nil as a child: skipped
---@field colSpan number|nil as a child: columns it spans
---@field align string|nil as a child: "left", "center" or "right" in its cell

---@class OrdaenUISeparator
---@field separator string "rule" (a hairline), "divider" (a stronger break), "caption" (text between lines)
---@field text string|nil the caption
---@field colSpan number|nil
---@field hidden boolean|nil as a child: skipped
---@field shift boolean|nil as a child: true = only while Shift is held, false = only while it isn't

---@class OrdaenUIBar
---@field bar number filled part, 0..1
---@field color number[]|nil fill colour, for meaning (health, progress); default from the theme and accent
---@field height number|nil
---@field colSpan number|nil
---@field hidden boolean|nil as a child: skipped
---@field shift boolean|nil as a child: true = only while Shift is held, false = only while it isn't

---@class OrdaenUIImage
---@field image string|number|nil texture path or file ID, or:
---@field atlas string|nil atlas name
---@field width number|nil
---@field height number|nil
---@field size number|nil width and height
---@field texCoord number[]|nil { left, right, top, bottom }
---@field hidden boolean|nil as a child: skipped
---@field colSpan number|nil as a child: columns it spans
---@field align string|nil as a child: "left", "center" or "right" in its cell

---@class OrdaenUIBlock
---@field style string|nil style role in the theme (tooltip, header, button, iconButton, slot)
---@field accent number[]|nil { r, g, b }: tints this block's surface, lines and accented text (an item's quality,
--- a zone's PvP colour); children inherit it
---@field columns (number|string)[]|nil tracks: number = fixed, "auto", "Nfr"; default { "1fr" }
---@field gap number|string|(number|string)[]|nil n or a spacing token ("xs".."xl"), or { column, row }
---@field padding number|string|(number|string)[]|nil n or a token, or { top, right, bottom, left }
---@field width number|nil exact width; nil = shrink to fit
---@field minWidth number|nil
---@field maxWidth number|nil
---@field height number|nil
---@field hidden boolean|nil as a child: skipped, no cell
---@field colSpan number|nil as a child: columns it spans
---@field align string|nil as a child: "left", "center" or "right" in its cell
---@field shift boolean|nil as a child: true = only while Shift is held, false = only while it isn't

---@class OrdaenUITooltipOpts
---@field side string|nil "right" (default), "left", "below", "above", or "default" (Edit Mode's HUD Tooltip spot)
---@field x number|nil
---@field y number|nil

--- Called by OrdaenCore_UI when it loads. Not for addons.
function UI._Provide(functions)
	impl = functions
end

--- Called by Ordaen Core when the global UI settings (theme, text size) change: every Ordaen addon's UI on
--- screen takes the new look. Not for addons. Does nothing until the framework is loaded (it reads the
--- settings when it loads).
function UI._SettingsChanged()
	if impl then
		impl.Restyle()
	end
end

local function framework()
	if impl or unavailable then
		return impl
	end
	local ok, reason = C_AddOns.LoadAddOn(MODULE)
	if not ok or not impl then
		-- Disabled in the AddOns list, missing or out of date: say so once, then stay quiet.
		unavailable = true
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"|cff33ff99%s|r: %s could not be loaded (%s); Ordaen UI is off. Enable it in the AddOns list.",
			addonName, MODULE, tostring(reason or "unknown")))
	end
	return impl
end

-- Tooltips -----------------------------------------------------------------------------------------

---@class OrdaenUITooltip : OrdaenUIBlock
local TooltipMethods = {}
local TooltipMeta = { __index = TooltipMethods }
local tooltipOpts = setmetatable({}, { __mode = "k" }) -- tooltip -> its placement options

--- Show the tooltip next to `owner`, replacing any tooltip that is shown. Loads the framework the first time.
---@param owner Frame
function TooltipMethods:Show(owner)
	local f = framework()
	if f then
		f.ShowTooltip(self, owner, tooltipOpts[self])
	end
end

--- Hide the tooltip if it is shown; with `owner`, only if it is shown for that owner.
---@param owner Frame|nil
function TooltipMethods:Hide(owner)
	if impl then
		impl.HideTooltip(self, owner)
	end
end

--- Redraw the tooltip from its changed fields, if it is shown. Cheap when it isn't.
function TooltipMethods:Refresh()
	if impl then
		impl.RefreshTooltip(self)
	end
end

---@return boolean
function TooltipMethods:IsShown()
	return impl ~= nil and impl.TooltipShown(self)
end

--- Make `block` a tooltip object (the same table, with methods): build it once, change its fields, show it.
--- Costs nothing until the first :Show.
---@param block OrdaenUIBlock children: text, images, blocks; style defaults to "tooltip"
---@param opts OrdaenUITooltipOpts|nil placement
---@return OrdaenUITooltip
function UI.Tooltip(block, opts)
	if block.style == nil then
		block.style = "tooltip"
	end
	tooltipOpts[block] = opts
	return setmetatable(block, TooltipMeta) --[[@as OrdaenUITooltip]]
end

-- Presets: block data made the same way in every addon --------------------------------------------

---@class OrdaenUIHeaderSpec
---@field title string
---@field subtitle string|nil
---@field icon string|number|nil texture path or file ID, on the left
---@field iconSize number|nil default 32
---@field texCoord number[]|nil icon crop
---@field plate string|nil a short text under the icon (a level, a count)
---@field accent number[]|nil tints the header band

---@class OrdaenUIHeader : OrdaenUIBlock
---@field titleText OrdaenUIText change .text, then refresh
---@field subtitleText OrdaenUIText hidden while it has no text
---@field iconImage OrdaenUIImage|nil
---@field plateText OrdaenUIText|nil

--- A header block: the icon on the left with an optional plate under it, the title and subtitle beside it,
--- on the theme's header band. Data, like any block: put it first in a tooltip; change `titleText.text` &c.
--- Creates its tables once; loads nothing.
---@param spec OrdaenUIHeaderSpec
---@return OrdaenUIHeader
function UI.Header(spec)
	local title = { text = spec.title or "", style = "title" }
	local subtitle = { text = spec.subtitle or "", style = "subtitle", hidden = not spec.subtitle }
	local column = { gap = { 0, "xs" }, title, subtitle }
	local header = { style = "header", accent = spec.accent, titleText = title, subtitleText = subtitle }
	if spec.icon then
		local icon = { image = spec.icon, size = spec.iconSize or 32, texCoord = spec.texCoord }
		local plate = { text = spec.plate or "", style = "caption", align = "center", hidden = not spec.plate }
		header.columns = { "auto", "1fr" }
		header[1] = { gap = { 0, "xs" }, icon, plate }
		header[2] = column
		header.iconImage, header.plateText = icon, plate
	else
		header[1] = column
	end
	return header --[[@as OrdaenUIHeader]]
end

-- Confirmation dialogs -------------------------------------------------------------------------------

---@class OrdaenUIConfirmButton
---@field text string the button's label (a Blizzard global such as OKAY or CANCEL, or a locale string)
---@field onClick fun()|nil run after the dialog closed

---@class OrdaenUIConfirmSpec
---@field text string the message
---@field buttons OrdaenUIConfirmButton[] up to 4, left to right
---@field onCancel fun()|nil run when the player closes it with Escape

---@class OrdaenUIConfirm : OrdaenUIConfirmSpec
local ConfirmMethods = {}
local ConfirmMeta = { __index = ConfirmMethods }

--- Show the dialog (one at a time for every addon; a second one waits until the first closes). Loads the
--- framework the first time.
function ConfirmMethods:Show()
	local f = framework()
	if f then
		f.ShowConfirm(self)
	end
end

--- Close it if shown, or take it out of the queue. Its onCancel doesn't run.
function ConfirmMethods:Hide()
	if impl then
		impl.HideConfirm(self)
	end
end

---@return boolean
function ConfirmMethods:IsShown()
	return impl ~= nil and impl.ConfirmShown(self)
end

--- Make `spec` a confirm object (the same table, with methods): a message and buttons, shown centred near the top
--- of the screen in the theme's dialog look. Escape closes it and runs onCancel. Change `text` before :Show() to
--- reuse it. Costs nothing until the first :Show.
---
---   local ask = UI.Confirm({ text = L.RELOAD_NEEDED, buttons = { { text = OKAY, onClick = ReloadUI },
---     { text = CANCEL } } })
---   ask:Show()
---@param spec OrdaenUIConfirmSpec
---@return OrdaenUIConfirm
function UI.Confirm(spec)
	return setmetatable(spec, ConfirmMeta) --[[@as OrdaenUIConfirm]]
end

-- Components ---------------------------------------------------------------------------------------

--- A block on its own frame (a label, an icon): see OrdaenCore_UI/Component.lua. Loads the framework.
---@param spec OrdaenUIComponentSpec
---@return OrdaenUIComponent|nil nil when the framework can't load (the player was told)
function UI.Block(spec)
	local f = framework()
	return f and f.Block(spec)
end

--- A clickable block (style "button" unless given): `:On("click", fn)`, `tooltip = tip`. Loads the framework.
---@param spec OrdaenUIComponentSpec
---@return OrdaenUIComponent|nil nil when the framework can't load (the player was told)
function UI.Button(spec)
	local f = framework()
	return f and f.Button(spec)
end

--- The last tooltip as measured and drawn, for dev-mode dumps (false if the framework isn't loaded). Not for
--- regular addon code: it builds tables.
function UI._Describe()
	return impl and impl.Describe() or false
end
