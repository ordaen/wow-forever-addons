-- OrdaenCore.UI dressing: one of Blizzard's frames in our look, without taking it over. Blizzard's frame keeps its
-- clicks, menus, scripts, text and size rules and stays on top; its art (textures, never its text) goes to alpha 0
-- and stays there when Blizzard fades it back in, and our block is drawn underneath: a sibling right under a button
-- (size "look"), or on a window, tab or input itself (size "frame": a child at its level, our fill under its
-- content by layer, following its visibility, alpha, strata and scale). :Undress() gives the art back.
--
--   local dress = UI.Dress(CharacterMicroButton, { atlas = "UI-HUD-MicroMenu-CharacterInfo-Up" })  -- a button
--   UI.Dress(ChatFrame1, { style = "panel", size = "frame", cover = ChatFrame1Background,
--   	art = { ChatFrame1Background, ChatFrame1TopTexture, ... } })                           -- keeps its size
--   local tab = UI.Dress(ChatFrame1Tab, { style = "tab", size = "frame", states = { selected = "tabSelected" } })
--   tab:SetState("selected")
--   UI.DressFont(ChatFrame1, "body")                                  -- the theme's font, re-applied on changes
--
-- Cost: the art is walked once per dress (and on :Refresh); each hidden texture gets one SetAlpha hook (it runs
-- when Blizzard sets that texture's alpha: a cheap check, plus one SetAlpha(0) while dressed); the enter/leave and
-- size hooks are set once per frame. Fonts: one table entry per target, re-applied on a theme change.
local _, ns = ...

local Component = ns.Component
local Theme = ns.Theme

local ICON = 20 -- the "iconButton" style's padding (4 each side) around it makes the gear button's 28 px

---@class OrdaenUIDressOpts
---@field icon string|number|nil texture path or file ID of the icon
---@field atlas string|nil atlas of the icon (instead of `icon`)
---@field iconSize number|nil default 20
---@field iconColor number[]|string|nil the icon's tint: a colour or token ("color.icon" for glyph icons)
---@field style string|nil default "iconButton"
---@field clickable Frame|nil the frame that gets the mouse: default its `.Button` (modern clients), else the frame
---@field size "look"|"frame"|nil "look" (default): Blizzard's frame takes our block's size (buttons); "frame": our
--- block covers Blizzard's frame (or `cover`) and its size stays Blizzard's or Edit Mode's (windows, inputs, tabs)
---@field cover table|nil with size "frame": the region our block covers (default the frame), e.g. a background
--- texture that reaches past the frame
---@field extend (number|string)[]|nil with size "frame": { left, right, top, bottom } added around `cover`, each a
--- spacing token ("md") or UI units; tokens follow the text size (inner padding of a chat window)
---@field art table[]|nil the textures to hide; default every texture of the frame and its children (give a list
--- when the frame's children hold content, e.g. a chat window's message lines)
---@field states table<string, string>|nil state -> style role for :SetState (any other state: `style`)
---@field open table|nil open sides of the look's window art ({ bottom = true }): see :SetOpen
---@field borderAbove boolean|nil with a style that wears Blizzard's window art: its border goes above the frame and
--- its children (a Blizzard window whose opaque content reaches its edges and would hide it); the fill stays under
---@field track "button"|"checkbox"|"tab"|nil follow the control's own state with :SetState (hooked once): "button":
--- "disabled" while disabled, "pushed" while held down; "checkbox": also "checked"; "tab": "selected" while Blizzard
--- has it selected (PanelTemplates). A control style (pushButton, checkbox, tab...) draws its own art for each
--- state; `states` can still map a state to another role. Hover is the look's highlight
---@field title FontString|nil a window's title text (Blizzard's): placed inside the window's top, with the role's
--- engraved rule under it (theme titleRule); put Blizzard's title plate in `art`
---@field focus boolean|nil an EditBox: our look shows only while it has the keyboard focus (being typed in), at full
--- alpha whatever alpha Blizzard gives the frame (Blizzard's IM chat style leaves an inactive input faintly shown)
---@field block OrdaenUIBlock|nil our look as a whole block (a row of cells, say) instead of an icon; `style` is its
--- role. Its cells can be found with dress.look:RectOf(cell) after it's drawn ("render")

---@class OrdaenUIDress
---@field frame Frame Blizzard's frame
---@field clickable Frame the frame that gets the mouse
---@field look OrdaenUIComponent our block: on Blizzard's frame (size "frame", a child at its level), else under it
---@field icon OrdaenUIImage|nil the icon element of `look` (none when dressed with size "frame" and no icon)
---@field alphas table<table, number> each hidden region's alpha before dressing
---@field size number[] Blizzard's frame size before dressing
---@field dressed boolean
---@field opts OrdaenUIDressOpts
---@field state string|nil the state set with :SetState
local Dress = {}
local DressMeta = { __index = Dress }

-- Safety rules (as EllesmereUI's skin engine keeps them): our state about Blizzard's frames lives in weak tables
-- here, never as keys on those frames; their art is hidden by alpha only (never Hide/SetParent/SetScript); their
-- scripts are hooked, never replaced; one failing dress is reported and returns nil (Dress.New), so the caller's
-- other dresses go on; art Blizzard re-creates is hidden again with :Restrip, without a redraw.
local byClickable = setmetatable({}, { __mode = "k" }) -- Blizzard's clickable frame -> its dress
local hooked = setmetatable({}, { __mode = "k" }) -- clickables whose OnEnter/OnLeave carry our hooks (permanent)
local ownerOf = setmetatable({}, { __mode = "k" }) -- hidden texture -> its dress (for the SetAlpha hook)
local alphaHooked = setmetatable({}, { __mode = "k" }) -- textures whose SetAlpha carries our hook
local zeroing = false
local placeTitle -- an engraved title's text and rule (opts.title), below

-- Blizzard's button gets the hover, so ours shows its highlight on request.
local function onEnter(clickable)
	local dress = byClickable[clickable]
	if dress and dress.dressed then
		dress.look:LockHighlight()
	end
end

local function onLeave(clickable)
	local dress = byClickable[clickable]
	if dress and dress.dressed then
		dress.look:UnlockHighlight()
	end
end

-- Blizzard fades or flashes its art back in (chat backgrounds on hover, a tab's glow): it stays at 0 while dressed.
local function keepHidden(texture)
	if zeroing then
		return
	end
	local dress = ownerOf[texture]
	if dress and dress.dressed then
		zeroing = true
		texture:SetAlpha(0)
		zeroing = false
	end
end

local function hide(self, region)
	if not (region.IsObjectType and region:IsObjectType("Texture")) then
		return -- text is content: a tab's name, a button's count
	end
	if self.alphas[region] == nil then
		self.alphas[region] = region:GetAlpha()
	end
	ownerOf[region] = self
	if not alphaHooked[region] then
		alphaHooked[region] = true
		hooksecurefunc(region, "SetAlpha", keepHidden)
	end
	zeroing = true
	region:SetAlpha(0)
	zeroing = false
end

local hideChildren

local function hideRegions(self, ...)
	for i = 1, select("#", ...) do
		hide(self, (select(i, ...)))
	end
end

function hideChildren(self, ...)
	for i = 1, select("#", ...) do
		local child = select(i, ...)
		if child ~= self.look.frame then
			hideRegions(self, child:GetRegions())
			hideChildren(self, child:GetChildren())
		end
	end
end

local function hideArt(self)
	local art = self.opts.art
	if art then
		for _, texture in ipairs(art) do
			hide(self, texture)
		end
		return
	end
	local frame = self.frame
	hideRegions(self, frame:GetRegions())
	hideChildren(self, frame:GetChildren())
end

local function childButton(frame)
	local button = rawget(frame, "Button")
	if type(button) == "table" and button.GetObjectType then
		return button
	end
	return nil
end

local function placeOver(self)
	local look, opts = self.look, self.opts
	local cover = opts.cover or self.frame
	local e = opts.extend
	look:ClearAllPoints()
	if e then
		local space = Theme.Space
		look:SetPoint("TOPLEFT", cover, "TOPLEFT", -space(e[1]), space(e[3]))
		look:SetPoint("BOTTOMRIGHT", cover, "BOTTOMRIGHT", space(e[2]), -space(e[4]))
	else
		look:SetAllPoints(cover)
	end
end

-- Whether our look shows now: with its frame; with `focus`, only while the frame is being typed in.
local function wanted(dress)
	local frame = dress.frame
	if not frame:IsShown() then
		return false
	end
	if dress.opts.focus then
		local box = frame --[[@as EditBox]]
		return box:HasFocus() and true or false
	end
	return true
end

-- Our block sits right under Blizzard's frame: its strata, one level below. Blizzard moves some frames to another
-- strata while they're used (the chat input goes to DIALOG while typing): a look left in the old strata showed the
-- chat's text over the input's background (2026-11-07), so it follows every strata change and each show.
local function layer(dress)
	local frame, look = dress.frame, dress.look
	look:SetFrameStrata(frame:GetFrameStrata())
	local level = frame:GetFrameLevel()
	look:SetFrameLevel(level > 1 and level - 1 or 1)
	if level < 2 then
		frame:SetFrameLevel(2)
	end
end

-- Our block is a sibling of Blizzard's frame (so it never covers it): it shows and hides with that frame. Without
-- this, every hidden chat window, tab and voice button left its look on screen (2026-11-06).
local function onFrameShown(frame)
	for _, dress in pairs(byClickable) do
		if dress.frame == frame and dress.dressed then
			layer(dress)
			dress.look:SetShown(wanted(dress))
		end
	end
end

local function onFrameStrata(frame)
	for _, dress in pairs(byClickable) do
		if dress.frame == frame and dress.dressed then
			layer(dress)
		end
	end
end

local function onFocus(frame)
	for _, dress in pairs(byClickable) do
		if dress.frame == frame and dress.dressed and dress.opts.focus then
			if dress.opts.size ~= "frame" then
				layer(dress)
			end
			dress.look:SetShown(wanted(dress))
		end
	end
end

local function onFrameHidden(frame)
	for _, dress in pairs(byClickable) do
		if dress.frame == frame then
			dress.look:Hide()
		end
	end
end

-- Our block follows Blizzard's fades too: it's a sibling, so the frame's alpha doesn't reach it by itself (the chat
-- input faded out in Blizzard's IM style left our buttons faintly visible, 2026-11-06).
local function onFrameAlpha(frame, alpha)
	for _, dress in pairs(byClickable) do
		if dress.frame == frame and dress.dressed and not dress.opts.focus then
			dress.look:SetAlpha(alpha)
		end
	end
end

-- With size "frame" our block follows the size it covers (Blizzard's or Edit Mode's): redraw at that size.
local function resize(self)
	if not self.dressed then
		return
	end
	if self.opts.title then
		placeTitle(self) -- the rule spans the window's width
	end
	local look = self.look
	local block = look.block
	local width, height = look:GetWidth(), look:GetHeight()
	-- A frame sized from secret combat numbers (the damage meter's bars) has a secret size: our code can't compare
	-- or lay it out (it errored, 2026-11-07). Our look still covers the frame by its anchors; it isn't drawn again
	-- for that size.
	if issecretvalue(width) or issecretvalue(height) then
		return
	end
	if block.width ~= width or block.height ~= height then
		block.width, block.height = width, height
		look:Refresh()
	end
end

--- Put the look on (again, after :Undress): hide Blizzard's art, show ours under the frame.
function Dress:Apply()
	local frame, look = self.frame, self.look
	self.dressed = true
	hideArt(self) -- first: Blizzard's art goes even if something below fails
	if self.opts.size == "frame" then
		-- On the frame itself: a child at the frame's own level, so our regions interleave with Blizzard's by layer
		-- (our fill under its content) and its visibility, alpha, strata and scale reach ours by themselves.
		-- It stays shown: its parent decides. Dressed while the frame is closed (Ordaen Reskin dresses at login), it
		-- would otherwise stay hidden for good, since nothing shows a child again (2026-11-07). An input with `focus`
		-- still shows only while typed in (its focus hooks).
		look:SetParent(frame)
		look.frame:SetUsingParentLevel(true)
		placeOver(self)
		look:SetShown(not self.opts.focus or wanted(self))
		resize(self)
		return
	end
	-- Beside the frame (size "look"): a sibling right under it, the frame taking our block's size.
	look:SetParent(frame:GetParent())
	look:ClearAllPoints()
	look:SetPoint("CENTER", frame, "CENTER")
	look:SetShown(wanted(self))
	frame:SetSize(look:GetWidth(), look:GetHeight())
	if self.clickable ~= frame then
		self.clickable:ClearAllPoints()
		self.clickable:SetAllPoints(frame)
	end
	look:SetAlpha(self.opts.focus and 1 or frame:GetAlpha())
	layer(self)
end

--- Open sides of the look's window art (see the component's :SetOpen), e.g. the chat window on a panel.
---@param sides { top: boolean|nil, right: boolean|nil, bottom: boolean|nil, left: boolean|nil }|nil
function Dress:SetOpen(sides)
	self.opts.open = sides
	self.look:SetOpen(sides)
end

--- Hide art Blizzard added since dressing (a new texture, a re-created child), without drawing again: call it from
--- a hook on whatever makes Blizzard repaint the frame. Allocates nothing.
function Dress:Restrip()
	if self.dressed then
		hideArt(self)
	end
end

--- Hide art Blizzard added since dressing (a new texture, a re-created child) and redraw our look.
function Dress:Refresh()
	if not self.dressed then
		return
	end
	self.look:Refresh()
	hideArt(self)
end

--- Change the icon: a texture path or file ID, or an atlas.
---@param icon string|number|nil
---@param atlas string|nil
function Dress:SetIcon(icon, atlas)
	local el = self.icon
	if not el then
		return -- dressed without an icon
	end
	el.image, el.atlas = icon, atlas
	self.look:Refresh()
end

--- Switch the dressed control's style (role) and redraw, keeping its state: e.g. a pooled Blizzard button that is
--- the menu's exit on this show ("pushButtonAccent") and a plain one on the next ("pushButton").
---@param role string
function Dress:SetStyle(role)
	if self.opts.style == role then
		return
	end
	self.opts.style = role
	local states = self.opts.states
	self.look.block.style = (states and self.state and states[self.state]) or role
	self.look:Refresh()
end

--- Mark the control as new (Blizzard's "New" label, hidden by the caller): the theme's marker at its left end.
---@param on boolean|nil
function Dress:SetNew(on)
	local block = self.look.block
	local isNew = on and true or nil
	if block.newMarker ~= isNew then
		block.newMarker = isNew
		self.look:Refresh()
	end
end

--- Show a state of the frame (a tab "selected" or "flash"): the style role `opts.states[state]`, or the frame's own
--- style for any other state. Call it from a hook on Blizzard's own state change, never by polling.
---@param state string|nil
function Dress:SetState(state)
	if self.state == state then
		return
	end
	self.state = state
	local states = self.opts.states
	local block = self.look.block
	block.style = (states and state and states[state]) or self.opts.style or "iconButton"
	block.controlState = state -- a control style draws its own art for the state (a pushed button, a checked box)
	self.look:Refresh()
end

--- Give Blizzard's frame its own look back: its art's alphas and its size. Our block is hidden; :Apply() dresses
--- it again.
function Dress:Undress()
	if not self.dressed then
		return
	end
	self.dressed = false
	self.look:UnlockHighlight()
	self.look:Hide()
	for region, alpha in pairs(self.alphas) do
		region:SetAlpha(alpha)
		self.alphas[region] = nil
	end
	if self.opts.size ~= "frame" then
		self.frame:SetSize(self.size[1], self.size[2])
	end
end

-- Tracking a control's state (opts.track) ----------------------------------------------------------------------------
-- Hooks set once per control (rarely called methods: enable, disable, check, a press), each recomputing the state and
-- passing it to :SetState, which redraws only when it changed.

local tracked = setmetatable({}, { __mode = "k" }) -- control -> its tracking dress
local held = setmetatable({}, { __mode = "k" }) -- control -> true while the mouse holds it down
local selectedTabs = setmetatable({}, { __mode = "k" }) -- tab -> true while Blizzard has it selected

local function trackedState(self)
	local control = self.clickable --[[@as Button]]
	local kind = self.opts.track
	if kind == "tab" then
		return selectedTabs[control] and "selected" or nil
	end
	if not control:IsEnabled() then
		return "disabled"
	end
	if held[control] or control:GetButtonState() == "PUSHED" then
		return "pushed"
	end
	if kind == "checkbox" and (control --[[@as CheckButton]]):GetChecked() then
		return "checked"
	end
	return nil
end

local function retrack(control)
	local self = tracked[control]
	if self and self.dressed then
		self:SetState(trackedState(self))
	end
end

local function onTrackDown(control)
	held[control] = true
	retrack(control)
end

local function onTrackUp(control)
	held[control] = nil
	retrack(control)
end

local tabsHooked = false
local function onTabSelected(tab)
	selectedTabs[tab] = true
	retrack(tab)
end
local function onTabDeselected(tab)
	selectedTabs[tab] = nil
	retrack(tab)
end

local function track(self)
	local control = self.clickable
	if tracked[control] then
		tracked[control] = self
		return
	end
	tracked[control] = self
	local kind = self.opts.track
	if kind == "tab" then
		if not tabsHooked then
			tabsHooked = true
			hooksecurefunc("PanelTemplates_SelectTab", onTabSelected)
			hooksecurefunc("PanelTemplates_DeselectTab", onTabDeselected)
		end
		-- Already selected before we came: Blizzard's selected panel tab is disabled.
		selectedTabs[control] = not control:IsEnabled() or nil
		return
	end
	hooksecurefunc(control, "Enable", retrack)
	hooksecurefunc(control, "Disable", retrack)
	hooksecurefunc(control, "SetEnabled", retrack)
	hooksecurefunc(control, "SetButtonState", retrack)
	control:HookScript("OnMouseDown", onTrackDown)
	control:HookScript("OnMouseUp", onTrackUp)
	control:HookScript("OnHide", onTrackUp) -- hidden mid-press: no mouse-up comes
	if kind == "checkbox" then
		hooksecurefunc(control, "SetChecked", retrack)
		control:HookScript("OnClick", retrack)
	end
end

local create

-- An engraved title (opts.title): Blizzard's title text inside the window's top, a 1 px rule under it fading out at
-- both ends (4 gradient segments on the look), from the role's titleRule. Blizzard re-anchoring the text gets ours
-- back. Made once per dress.
local titled = setmetatable({}, { __mode = "k" }) -- title FontString -> its dress
local placingTitle = false

local function anchorTitle(self)
	local rule = Theme.BlockStyle(self.opts.style) and Theme.BlockStyle(self.opts.style).titleRule
	local text = self.opts.title
	if not rule or not text then
		return
	end
	placingTitle = true
	text:ClearAllPoints()
	text:SetPoint("TOP", self.frame, "TOP", 0, -rule.textY)
	local c = rule.text
	if c then
		text:SetTextColor(c[1], c[2], c[3])
	end
	placingTitle = false
end

local function onTitlePlaced(text)
	local self = titled[text]
	if self and self.dressed and not placingTitle then
		anchorTitle(self)
	end
end

function placeTitle(self)
	local rule = Theme.BlockStyle(self.opts.style) and Theme.BlockStyle(self.opts.style).titleRule
	if not rule then
		return
	end
	local look = self.look.frame
	-- Per line of the groove: a fade in over its first quarter, solid, a fade out over its last quarter.
	local rows = self.titleRule
	if not rows then
		rows = {}
		for l = 1, #rule.lines do
			local segments = {}
			for i = 1, 3 do
				segments[i] = look:CreateTexture(nil, "ARTWORK")
				segments[i]:SetColorTexture(1, 1, 1, 1)
			end
			rows[l] = segments
		end
		self.titleRule = rows
	end
	local px = PixelUtil.GetPixelToUIUnitFactor() / look:GetEffectiveScale()
	local width = self.frame:GetWidth()
	local span = not issecretvalue(width) and math.max(4, width - 2 * rule.inset) or nil
	for l, segments in ipairs(rows) do
		local c = rule.lines[l]
		local clear, solid = CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], c[4])
		segments[1]:SetGradient("HORIZONTAL", clear, solid)
		segments[2]:SetGradient("HORIZONTAL", solid, solid)
		segments[3]:SetGradient("HORIZONTAL", solid, clear)
		for i = 1, 3 do
			local seg = segments[i]
			seg:ClearAllPoints()
			seg:SetHeight(px)
			if span then
				seg:SetWidth(i == 2 and span / 2 or span / 4)
			end
			seg:Show()
		end
		segments[1]:SetPoint("TOPLEFT", look, "TOPLEFT", rule.inset, -rule.ruleY - (l - 1) * px)
		segments[2]:SetPoint("TOPLEFT", segments[1], "TOPRIGHT")
		segments[3]:SetPoint("TOPLEFT", segments[2], "TOPRIGHT")
	end
	if not titled[self.opts.title] then
		titled[self.opts.title] = self
		hooksecurefunc(self.opts.title, "SetPoint", onTitlePlaced)
	end
	anchorTitle(self)
end

--- Dress one of Blizzard's frames in our look. The same frame dressed twice returns the first dress. A dress that
--- fails (a frame Blizzard changed under us) is reported to the error handler and returns nil.
---@param frame Frame
---@param opts OrdaenUIDressOpts|nil
---@return OrdaenUIDress|nil
function Dress.New(frame, opts)
	-- A closure per dress (setup time, never per event): Lua 5.1's xpcall passes no arguments.
	local ok, dress = xpcall(function()
		return create(frame, opts)
	end, geterrorhandler())
	return ok and dress or nil
end

function create(frame, opts)
	opts = opts or {}
	local clickable = opts.clickable or childButton(frame) or frame
	local existing = byClickable[clickable]
	if existing then
		if not existing.dressed then
			existing:Apply()
		end
		return existing
	end
	local icon
	local spec = opts.block --[[@as OrdaenUIComponentSpec|nil]]
	if not spec then
		if opts.icon or opts.atlas or opts.size ~= "frame" then
			---@type OrdaenUIImage
			icon = { image = opts.icon, atlas = opts.atlas, size = opts.iconSize or ICON, color = opts.iconColor }
		end
		spec = { icon }
	end
	spec.style = opts.style or "iconButton"
	spec.parent = opts.size == "frame" and frame or frame:GetParent()
	spec.open = opts.open
	local look = Component.Block(spec)
	if opts.borderAbove then
		ns.Render.BorderAbove(look.frame, frame)
		look:Refresh() -- drawn once already, before it knew
	end
	local self = setmetatable({
		frame = frame,
		clickable = clickable,
		look = look,
		icon = icon,
		alphas = {},
		size = { frame:GetWidth(), frame:GetHeight() },
		dressed = false,
		opts = opts,
	}, DressMeta)
	byClickable[clickable] = self
	if not hooked[clickable] then
		hooked[clickable] = true
		clickable:HookScript("OnEnter", onEnter)
		clickable:HookScript("OnLeave", onLeave)
	end
	-- Once per dress: dressing the same frame again returns this one. A look beside its frame (size "look") follows
	-- the frame's visibility, alpha and strata by these hooks; one on the frame (size "frame") follows by itself.
	if opts.size ~= "frame" then
		frame:HookScript("OnShow", onFrameShown)
		frame:HookScript("OnHide", onFrameHidden)
		hooksecurefunc(frame, "SetAlpha", onFrameAlpha)
		hooksecurefunc(frame, "SetFrameStrata", onFrameStrata)
	end
	if frame:IsObjectType("EditBox") then -- `focus` may be turned on later
		frame:HookScript("OnEditFocusGained", onFocus)
		frame:HookScript("OnEditFocusLost", onFocus)
	end
	if opts.size == "frame" then
		look.frame:HookScript("OnSizeChanged", function()
			resize(self)
		end)
	end
	self:Apply()
	if opts.title then
		placeTitle(self)
	end
	if opts.track then
		track(self)
		self:SetState(trackedState(self))
	end
	return self
end

-- Fonts --------------------------------------------------------------------------------------------------------------
-- Blizzard's own text (chat lines, tab names, an input) in the theme's font and the global text size. Anything with
-- SetFont(file, size, flags): a FontString, an EditBox, a chat window. Blizzard setting its font again (the chat
-- font size menu) gets ours back; a theme or text size change re-applies every one (Dress.RefreshFonts). A style
-- with an outline (onBar, onBarValue: text on a coloured bar) gets OUTLINE flags and no drop shadow, the outline does
-- that work; other styles keep Blizzard's flags.

local fonts = setmetatable({}, { __mode = "k" }) -- target -> text style name
local fontHooked = setmetatable({}, { __mode = "k" })
local applyingFont = false

local function applyFont(target)
	local style = fonts[target]
	if not style or applyingFont then
		return
	end
	local look = Theme.TextStyle(style)
	local own = look.outline and "OUTLINE" or nil
	local _, _, flags = target:GetFont()
	applyingFont = true
	target:SetFont(look.file, look.size, own or flags or "")
	if target.SetShadowOffset then
		if own then
			target:SetShadowOffset(0, 0)
		elseif look.shadow then
			target:SetShadowOffset(1, -1)
			target:SetShadowColor(0, 0, 0, 1)
		else
			target:SetShadowOffset(0, 0)
		end
	end
	applyingFont = false
end

--- Put the theme's font and size for text style `style` (default "body") on Blizzard's `target`, and keep it there.
---@param target table a FontString, EditBox or chat window (anything with SetFont/GetFont)
---@param style string|nil a text style name (body, label, value, small, ...)
function Dress.Font(target, style)
	fonts[target] = style or "body"
	if not fontHooked[target] then
		fontHooked[target] = true
		hooksecurefunc(target, "SetFont", applyFont)
	end
	applyFont(target)
end

--- Place every dressed look with an `extend` again (the text size changed, so its tokens did: Tooltip.Restyle).
function Dress.RefreshPlaces()
	for _, dress in pairs(byClickable) do
		if dress.dressed and dress.opts.size == "frame" and dress.opts.extend then
			placeOver(dress)
		end
	end
end

--- Re-apply every dressed font (the theme or the text size changed: Tooltip.Restyle).
function Dress.RefreshFonts()
	for target in pairs(fonts) do
		applyFont(target)
	end
end

-- Bars ----------------------------------------------------------------------------------------------------------------
-- A Blizzard StatusBar (a damage meter's bars) with the theme's bar texture, or the bar asset an addon's look setting
-- names. Blizzard setting its texture again (a style change) gets ours back; a theme change re-applies every one
-- (Dress.RefreshBars). Only the texture: the bar's value, colour and text stay Blizzard's.

---@class OrdaenUIBarDress
---@field bar StatusBar Blizzard's bar
---@field asset string|nil the bar asset id to use; nil: the theme's (token bar.texture)
---@field original string|number|nil Blizzard's texture before the first change
---@field dressed boolean
local BarDress = {}
local BarDressMeta = { __index = BarDress }

local barDresses = setmetatable({}, { __mode = "k" }) -- StatusBar -> its dress
local applyingBar = false

local function barFile(asset)
	local store = OrdaenCore._SettingsStore
	local found = asset and store and store.Asset("bar", asset)
	return found and found.file or Theme.BarTexture()
end

local function keepBar(bar)
	local dress = barDresses[bar]
	if dress and dress.dressed and not applyingBar then
		dress:Apply()
	end
end

--- Put the texture on the bar (again).
function BarDress:Apply()
	self.dressed = true
	applyingBar = true
	self.bar:SetStatusBarTexture(barFile(self.asset))
	applyingBar = false
end

--- Use another bar asset (the addon's setting changed); nil: the theme's.
---@param asset string|nil
function BarDress:SetAsset(asset)
	self.asset = asset
	if self.dressed then
		self:Apply()
	end
end

--- Give the bar Blizzard's texture back.
function BarDress:Undress()
	self.dressed = false
	if self.original then
		applyingBar = true
		self.bar:SetStatusBarTexture(self.original)
		applyingBar = false
	end
end

--- Dress a Blizzard StatusBar (once per bar: dressing it again returns the same dress, with `asset` set).
---@param bar StatusBar
---@param asset string|nil a bar asset id (an addon's look setting); nil: the theme's
---@return OrdaenUIBarDress
function Dress.Bar(bar, asset)
	local dress = barDresses[bar]
	if not dress then
		local texture = bar:GetStatusBarTexture()
		dress = setmetatable({ bar = bar, original = texture and texture:GetTexture(), dressed = false },
			BarDressMeta)
		barDresses[bar] = dress
		hooksecurefunc(bar, "SetStatusBarTexture", keepBar)
	end
	dress.asset = asset
	dress:Apply()
	return dress
end

--- Re-apply every dressed bar (the theme changed: Tooltip.Restyle).
function Dress.RefreshBars()
	for _, dress in pairs(barDresses) do
		if dress.dressed then
			dress:Apply()
		end
	end
end

ns.Dress = Dress
