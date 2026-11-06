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
---@field style string|nil text style in the theme: title, subtitle, body (default), label, value, hint, normal, small
---@field color number[]|nil { r, g, b [, a] }, for meaning only (a pending invite), not decoration

---@class OrdaenUIImage
---@field image string|number|nil texture path or file ID, or:
---@field atlas string|nil atlas name
---@field width number|nil
---@field height number|nil
---@field size number|nil width and height
---@field texCoord number[]|nil { left, right, top, bottom }

---@class OrdaenUIBlock
---@field style string|nil style role in the theme (tooltip, button, iconButton, slot)
---@field columns (number|string)[]|nil tracks: number = fixed, "auto", "Nfr"; default { "1fr" }
---@field gap number|number[]|nil n, or { column, row }
---@field padding number|number[]|nil n, or { top, right, bottom, left }
---@field width number|nil exact width; nil = shrink to fit
---@field minWidth number|nil
---@field maxWidth number|nil
---@field height number|nil
---@field hidden boolean|nil as a child: skipped, no cell
---@field colSpan number|nil as a child: columns it spans
---@field align string|nil as a child: "left", "center" or "right" in its cell

---@class OrdaenUITooltipOpts
---@field side string|nil "right" (default), "left", "below", "above", or "default" (Edit Mode's HUD Tooltip spot)
---@field x number|nil
---@field y number|nil

--- Called by OrdaenCore_UI when it loads. Not for addons.
function UI._Provide(functions)
	impl = functions
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
