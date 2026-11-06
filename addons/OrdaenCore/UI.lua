-- OrdaenCore.UI: the Ordaen UI framework's entry point, the only part every player loads. Addons declare what
-- they want (tooltips now; more block roles later) and never learn how it's drawn. The framework itself (layout
-- engine, theme, the one renderer) is the load-on-demand addon OrdaenCore_UI, loaded on first use.
-- See CLAUDE.md, "UI framework".
--
-- Tooltip content is a block tree (OrdaenCore_UI/Layout.lua documents it):
--   { style = "tooltip", { text = "Elwynn Forest", style = "title" }, { text = "Click: map", style = "hint" } }
-- Build it once and change fields (text, hidden, color) on hover; RefreshTooltip redraws a shown one.
local addonName, ns = ...

local UI = {}
ns.UI = UI
ns.Core.UI = UI

local MODULE = "OrdaenCore_UI"

local impl -- the framework's functions, handed over by the module when it loads
local unavailable = false

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
			"|cff33ff99%s|r: %s could not be loaded (%s); Ordaen tooltips are off. Enable it in the AddOns list.",
			addonName, MODULE, tostring(reason or "unknown")))
	end
	return impl
end

--- Show a tooltip block for `owner` (usually from its OnEnter).
---@param owner table the frame the tooltip belongs to
---@param block table a block tree with style = "tooltip"
---@param opts table|nil { side = "right" | "left" | "below" | "above", x, y }: placement only
function UI.ShowTooltip(owner, block, opts)
	local f = framework()
	if f then
		f.ShowTooltip(owner, block, opts)
	end
end

--- Hide `owner`'s tooltip (usually from its OnLeave). Safe when none is shown; never loads the framework.
function UI.HideTooltip(owner)
	if impl then
		impl.HideTooltip(owner)
	end
end

--- The last tooltip as measured and drawn, for dev-mode dumps (false if the framework isn't loaded). Not for
--- regular addon code: it builds tables.
function UI._Describe()
	return impl and impl.Describe() or false
end

--- Redraw `owner`'s tooltip after its block changed, if it is shown. Never loads the framework.
function UI.RefreshTooltip(owner)
	if impl then
		impl.RefreshTooltip(owner)
	end
end
