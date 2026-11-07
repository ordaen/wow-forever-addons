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
---@field bar number the value, from min to max (default 0..1)
---@field min number|nil default 0
---@field max number|nil default 1
---@field quest number|nil a second part behind the value, from the value up to here, lighter (XP from completed quests)
---@field overlay number|nil a third part, dimmed, up to here (rested XP)
---@field color number[]|string|nil the value's colour: { r, g, b } or a theme colour token ("color.xp"); default from
--- the theme and accent
---@field questColor number[]|string|nil default: color
---@field overlayColor number[]|string|nil default: color
---@field animate boolean|nil changes glide (the game animates the status bar), gains flash, a drop wraps around
---@field sections integer|nil split into this many sections by lines in the theme's bar edge colour (Blizzard's 20)
---@field text string|nil text on the bar, centred; or format + args
---@field format string|nil
---@field args any[]|nil
---@field style string|nil the text's style
---@field textColor number[]|nil
---@field height number|nil
---@field colSpan number|nil
---@field hidden boolean|nil as a child: skipped
---@field shift boolean|nil as a child: true = only while Shift is held, false = only while it isn't

---@class OrdaenUIEmbed
---@field embed OrdaenUIComponent a component placed in this cell at its own size (a button in a dialog)
---@field hidden boolean|nil as a child: skipped (its frame is hidden)
---@field colSpan number|nil
---@field align string|nil

---@class OrdaenUIImage
---@field image string|number|nil texture path or file ID, or:
---@field atlas string|nil atlas name
---@field width number|nil
---@field height number|nil
---@field size number|nil width and height
---@field texCoord number[]|nil { left, right, top, bottom }
---@field crop boolean|nil trim an item or spell icon's own border by the theme's icon.crop
---@field portrait string|nil a unit's face ("player"), instead of image or atlas; refresh on UNIT_PORTRAIT_UPDATE
---@field color number[]|string|nil a tint, { r, g, b, a? } or a colour token ("color.icon" for glyph icons)
---@field hidden boolean|nil as a child: skipped
---@field colSpan number|nil as a child: columns it spans
---@field align string|nil as a child: "left", "center" or "right" in its cell

---@class OrdaenUIBlock
---@field style string|nil style role in the theme (tooltip, header, button, iconButton, slot); "none": no look
---@field highlight boolean|nil as a child: lit in its style's highlight colour (a cell whose Blizzard button is
--- hovered)
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
---@field align string|nil as a child: "left", "center" or "right" in its cell (a block shrinks to its content)
---@field valign string|nil as a child: "top", "center" or "bottom" in its row (default: the parent's rowAlign)
---@field rowAlign string|nil "top" (default), "center" or "bottom": children in their rows, rows in a fixed height;
--- "stretch": child blocks as tall as their row (with their own rowAlign "center", content in its middle)
---@field edges table|nil per side (top, right, bottom, left): false = none, true = the style's, { width, colour }
---@field shift boolean|nil as a child: true = only while Shift is held, false = only while it isn't
---@field hotkey string|nil on a top-level block: the key binding ("C", "Shift-M"), drawn as a key cap at the bottom

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
---@field onClick fun()|nil run after the dialog closed (with `macro`: run first, in the same click)
---@field macro string|nil a secure macro the click runs, e.g. "/reload" (reloading is allowed only from secure code);
--- out of combat only: shown in combat, the button runs onClick alone

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

--- A block pinned to a screen edge, the whole edge long or fit to its content (style "panel" unless given):
--- `:FadeTo(alpha, seconds?)`, `:IsFaded()`, `:Place()` after changing its options; events as any component.
--- Re-placed by itself when the resolution or UI scale changes. Loads the framework.
---
---   local bar = UI.Panel({ columns = { "auto", "1fr", "auto" }, left, middle, right }, { edge = "bottom" })
---   bar:FadeTo(0) -- hidden: no clicks, but enter/leave still arrive (show on mouseover)
---@param spec OrdaenUIComponentSpec
---@param opts OrdaenUIPanelOpts|nil edge ("bottom"), fit ("full" | "center"), offset
---@return OrdaenUIPanel|nil nil when the framework can't load (the player was told)
function UI.Panel(spec, opts)
	local f = framework()
	return f and f.Panel(spec, opts)
end

--- Dress one of Blizzard's buttons in our look (style "iconButton" unless given): its art goes to alpha 0 and our
--- block sits under it; Blizzard's frame stays on top and keeps its clicks, menus and scripts. Returns an object
--- with `:SetIcon(icon, atlas)`, `:Refresh()` (hides art Blizzard added later), `:Undress()` and `:Apply()`.
--- Loads the framework.
---
---   local dress = UI.Dress(CharacterMicroButton, { atlas = "UI-HUD-MicroMenu-CharacterInfo-Up" })
---@param frame Frame
--- With `size = "frame"` our block covers Blizzard's frame (or `cover`) and its size stays Blizzard's or Edit
--- Mode's (chat windows, inputs, tabs); `art` lists the textures to hide when the frame's children hold content;
--- `states` + `:SetState(state)` switch the style (a selected tab). Only textures are hidden, never text, and they
--- stay hidden when Blizzard fades them back in.
---@param opts OrdaenUIDressOpts|nil icon or atlas, iconSize (20), style, clickable, size, cover, extend, art, states
---@return OrdaenUIDress|nil nil when the framework can't load (the player was told)
function UI.Dress(frame, opts)
	local f = framework()
	return f and f.Dress(frame, opts)
end

--- How much of a screen edge ("bottom", "top", "left", "right") Ordaen panels cover, in UI units: 0 when there are
--- none (the framework isn't even loaded). Frames that sit beside the panels (the chat above a bottom panel) read
--- it and follow EventRegistry "OrdaenUI.InsetsChanged". Loads nothing.
---@param edge string
---@return number
function UI.ScreenInset(edge)
	return impl and impl.ScreenInset(edge) or 0
end

--- A colour of the current theme: a colour token's value ("color.muted"), or `fallback`. For code that colours
--- Blizzard's own text (a chat line); listen to EventRegistry "OrdaenUI.ThemeChanged" to follow a theme change.
--- Loads the framework.
---@param token string
---@param fallback number[]|nil
---@return number[]|nil
function UI.Color(token, fallback)
	local f = framework()
	return f and f.Color(token, fallback) or fallback
end

local bindingText = {} -- key ("SHIFT-M") -> its text for players ("Shift-M")

--- The key bound to a binding command ("TOGGLEWORLDMAP") as players read it ("M", "Shift-M"), or nil when it has
--- none: a tooltip's `hotkey`. Listen to UPDATE_BINDINGS to follow the player's changes. Creates no strings once a
--- key has been seen. Doesn't load the framework.
---@param command string
---@return string|nil
function UI.Binding(command)
	local key = GetBindingKey(command)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = bindingText[key]
	if not text then
		text = GetBindingText(key) or key
		bindingText[key] = text
	end
	return text
end

--- A spacing token's size in UI units at the current text size ("xs".."xl"; a number comes back as it is). For a
--- Blizzard setting that takes a size (a chat window's line spacing); listen to EventRegistry "OrdaenUI.ThemeChanged"
--- to follow a text size change. Loads the framework.
---@param token string|number
---@return number
function UI.Space(token)
	local f = framework()
	return f and f.Space(token) or 0
end

--- Put the theme's font and the global text size (text style `style`, default "body") on Blizzard's own text: a
--- FontString, an EditBox or a chat window. It stays when Blizzard sets the font again and follows theme and text
--- size changes. Addons never call SetFont themselves. Loads the framework.
---
---   UI.DressFont(ChatFrame1, "body")
---   UI.DressFont(ChatFrame1Tab:GetFontString(), "label")
---@param target table anything with SetFont(file, size, flags) and GetFont()
---@param style string|nil
function UI.DressFont(target, style)
	local f = framework()
	if f then
		f.DressFont(target, style)
	end
end

--- Put the theme's bar texture (token bar.texture), or the bar asset `asset` names (an addon's look setting that
--- follows that token), on Blizzard's StatusBar, and keep it there when Blizzard sets its texture again; a theme
--- change re-applies it. Only the texture: value, colour and text stay Blizzard's. Returns the bar's dress
--- (:Apply(), :SetAsset(id), :Undress() gives Blizzard's texture back), nil when the framework can't load. Loads it.
---
---   local dress = UI.DressBar(entry:GetStatusBar(), A:Get("barTexture"))
---@param bar table a StatusBar
---@param asset string|nil
---@return OrdaenUIBarDress|nil
function UI.DressBar(bar, asset)
	local f = framework()
	return f and f.DressBar(bar, asset)
end

--- The last tooltip as measured and drawn, for dev-mode dumps (false if the framework isn't loaded). Not for
--- regular addon code: it builds tables.
function UI._Describe()
	return impl and impl.Describe() or false
end
