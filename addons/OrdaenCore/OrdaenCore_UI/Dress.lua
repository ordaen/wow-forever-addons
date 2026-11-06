-- OrdaenCore.UI dressing: one of Blizzard's frames in our look, without taking it over. Blizzard's frame keeps its
-- clicks, menus, scripts, text and size rules and stays on top; its art (textures, never its text) goes to alpha 0
-- and stays there when Blizzard fades it back in, and our block is drawn underneath. :Undress() gives the art back.
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
---@field extend number[]|nil with size "frame": { left, right, top, bottom } UI units added around `cover`
---@field art table[]|nil the textures to hide; default every texture of the frame and its children (give a list
--- when the frame's children hold content, e.g. a chat window's message lines)
---@field states table<string, string>|nil state -> style role for :SetState (any other state: `style`)

---@class OrdaenUIDress
---@field frame Frame Blizzard's frame
---@field clickable Frame the frame that gets the mouse
---@field look OrdaenUIComponent our block, under Blizzard's frame
---@field icon OrdaenUIImage|nil the icon element of `look` (none when dressed with size "frame" and no icon)
---@field alphas table<table, number> each hidden region's alpha before dressing
---@field size number[] Blizzard's frame size before dressing
---@field dressed boolean
---@field opts OrdaenUIDressOpts
---@field state string|nil the state set with :SetState
local Dress = {}
local DressMeta = { __index = Dress }

local byClickable = {} -- Blizzard's clickable frame -> its dress
local hooked = {} -- clickable frames whose OnEnter/OnLeave carry our hooks (HookScript can't be undone)
local ownerOf = setmetatable({}, { __mode = "k" }) -- hidden texture -> its dress (for the SetAlpha hook)
local alphaHooked = setmetatable({}, { __mode = "k" }) -- textures whose SetAlpha carries our hook
local zeroing = false

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
		look:SetPoint("TOPLEFT", cover, "TOPLEFT", -e[1], e[3])
		look:SetPoint("BOTTOMRIGHT", cover, "BOTTOMRIGHT", e[2], -e[4])
	else
		look:SetAllPoints(cover)
	end
end

-- Our block is a sibling of Blizzard's frame (so it never covers it): it shows and hides with that frame. Without
-- this, every hidden chat window, tab and voice button left its look on screen (2026-11-06).
local function onFrameShown(frame)
	for _, dress in pairs(byClickable) do
		if dress.frame == frame and dress.dressed then
			dress.look:Show()
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

-- With size "frame" our block follows the size it covers (Blizzard's or Edit Mode's): redraw at that size.
local function resize(self)
	if not self.dressed then
		return
	end
	local look = self.look
	local block = look.block
	local width, height = look:GetWidth(), look:GetHeight()
	if block.width ~= width or block.height ~= height then
		block.width, block.height = width, height
		look:Refresh()
	end
end

--- Put the look on (again, after :Undress): hide Blizzard's art, show ours under the frame.
function Dress:Apply()
	local frame, look = self.frame, self.look
	self.dressed = true
	look:SetParent(frame:GetParent())
	look:SetFrameStrata(frame:GetFrameStrata())
	if self.opts.size == "frame" then
		placeOver(self)
		look:SetShown(frame:IsShown())
		resize(self)
	else
		look:ClearAllPoints()
		look:SetPoint("CENTER", frame, "CENTER")
		look:SetShown(frame:IsShown())
		frame:SetSize(look:GetWidth(), look:GetHeight())
		if self.clickable ~= frame then
			self.clickable:ClearAllPoints()
			self.clickable:SetAllPoints(frame)
		end
	end
	local level = frame:GetFrameLevel()
	look:SetFrameLevel(level > 1 and level - 1 or 1)
	if level < 2 then
		frame:SetFrameLevel(2)
	end
	hideArt(self)
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

--- Show a state of the frame (a tab "selected" or "flash"): the style role `opts.states[state]`, or the frame's own
--- style for any other state. Call it from a hook on Blizzard's own state change, never by polling.
---@param state string|nil
function Dress:SetState(state)
	if self.state == state then
		return
	end
	self.state = state
	local states = self.opts.states
	self.look.block.style = (states and state and states[state]) or self.opts.style or "iconButton"
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

--- Dress one of Blizzard's frames in our look. The same frame dressed twice returns the first dress.
---@param frame Frame
---@param opts OrdaenUIDressOpts|nil
---@return OrdaenUIDress
function Dress.New(frame, opts)
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
	if opts.icon or opts.atlas or opts.size ~= "frame" then
		---@type OrdaenUIImage
		icon = { image = opts.icon, atlas = opts.atlas, size = opts.iconSize or ICON, color = opts.iconColor }
	end
	local look = Component.Block({ style = opts.style or "iconButton", parent = frame:GetParent(), icon })
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
	-- Once per dress: dressing the same frame again returns this one.
	frame:HookScript("OnShow", onFrameShown)
	frame:HookScript("OnHide", onFrameHidden)
	if opts.size == "frame" then
		look.frame:HookScript("OnSizeChanged", function()
			resize(self)
		end)
	end
	self:Apply()
	return self
end

-- Fonts --------------------------------------------------------------------------------------------------------------
-- Blizzard's own text (chat lines, tab names, an input) in the theme's font and the global text size. Anything with
-- SetFont(file, size, flags): a FontString, an EditBox, a chat window. Blizzard setting its font again (the chat
-- font size menu) gets ours back; a theme or text size change re-applies every one (Dress.RefreshFonts).

local fonts = setmetatable({}, { __mode = "k" }) -- target -> text style name
local fontHooked = setmetatable({}, { __mode = "k" })
local applyingFont = false

local function applyFont(target)
	local style = fonts[target]
	if not style or applyingFont then
		return
	end
	local look = Theme.TextStyle(style)
	local _, _, flags = target:GetFont()
	applyingFont = true
	target:SetFont(look.file, look.size, flags or "")
	if target.SetShadowOffset then
		if look.shadow then
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

--- Re-apply every dressed font (the theme or the text size changed: Tooltip.Restyle).
function Dress.RefreshFonts()
	for target in pairs(fonts) do
		applyFont(target)
	end
end

ns.Dress = Dress
