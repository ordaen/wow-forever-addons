-- OrdaenCore.UI renderer: the one drawing code. It measures text for the layout engine and draws a laid-out
-- block tree onto a surface frame, taking every look from the theme (ns.Theme).
--
-- Cost: font strings and textures are pooled per surface and reused on every draw; measurements are cached
-- per element (one small table per element, created once) and redone only when its text, font, width or the
-- surface's scale changes. Nothing runs per frame.
local _, ns = ...

local Render = {}
ns.Render = Render

local Layout, Theme = ns.Layout, ns.Theme
local ceil = math.ceil

local function textStyle(el)
	return Theme.text[el.style or "body"] or Theme.text.body
end

local function fontObject(style)
	return _G[style.font] or _G.GameFontNormal
end

-- Measuring ------------------------------------------------------------------------------------

-- Text is measured on the surface it will be drawn on, never elsewhere. WoW rasterizes fonts at whole-pixel
-- sizes for a frame's effective scale, so the same text has a slightly different width in UI units at another
-- scale; measured on an unparented frame (scale 1) and drawn under UIParent (the UI scale), lines that "fit"
-- wrapped onto an extra line and overflowed the tooltip. Each surface has one hidden measuring font string, and
-- the caches remember the scale they measured at.
local measurers = setmetatable({}, { __mode = "k" }) -- surface -> its hidden measuring font string
local measuring, measuringScale -- the surface being drawn and its effective scale (set by Render.Draw)
local naturalCache = setmetatable({}, { __mode = "k" }) -- element -> { text|format, args, font, scale, w, h }
local wrappedCache = setmetatable({}, { __mode = "k" }) -- element -> the same, plus width
local NO_ARGS = {}
local unpack = unpack

-- Put an element's text on a font string: a plain string, or a format with arguments through WoW's
-- SetFormattedText, which builds the string in C (no Lua string per change).
local function setContent(fs, el)
	if el.format then
		local args = el.args or NO_ARGS
		fs:SetFormattedText(el.format, unpack(args, 1, #args))
	else
		fs:SetText(el.text)
	end
end

-- Whether the cache entry `c` was measured for the element's current content (compared value by value, so a
-- changed argument measures again and an unchanged one doesn't).
local function sameContent(c, el, font)
	if c.font ~= font or c.scale ~= measuringScale or c.text ~= el.text or c.format ~= el.format then
		return false
	end
	local args, seen = el.args, c.args
	local n = args and #args or 0
	if n ~= c.argCount then
		return false
	end
	for i = 1, n do
		if seen[i] ~= args[i] then
			return false
		end
	end
	return true
end

local function remember(c, el, font)
	c.font, c.scale, c.text, c.format = font, measuringScale, el.text, el.format
	local args = el.args
	local n = args and #args or 0
	local seen = c.args
	if not seen then
		seen = {}
		c.args = seen
	end
	for i = 1, n do
		seen[i] = args[i]
	end
	c.argCount = n
end

local function measurerFor(style)
	local fs = measurers[measuring]
	if not fs then
		fs = measuring:CreateFontString(nil, "OVERLAY")
		fs:SetWordWrap(true)
		fs:SetNonSpaceWrap(true)
		fs:Hide()
		measurers[measuring] = fs
	end
	fs:SetFontObject(fontObject(style))
	return fs
end

--- Size of a text element: natural (one line) when width is nil, else wrapped to width. For the layout engine.
local function measure(el, width)
	local style = textStyle(el)
	local font = style.font
	if width == nil then
		local c = naturalCache[el]
		if not c then
			c = {}
			naturalCache[el] = c
		end
		if not sameContent(c, el, font) then
			local fs = measurerFor(style)
			fs:SetWidth(0)
			setContent(fs, el)
			remember(c, el, font)
			-- One unit more than measured, so rounding never wraps a line that fits.
			c.w, c.h = ceil(fs:GetUnboundedStringWidth()) + 1, ceil(fs:GetStringHeight())
		end
		return c.w, c.h
	end
	local c = wrappedCache[el]
	if not c then
		c = {}
		wrappedCache[el] = c
	end
	if c.width ~= width or not sameContent(c, el, font) then
		local fs = measurerFor(style)
		fs:SetWidth(width)
		setContent(fs, el)
		remember(c, el, font)
		c.width, c.h = width, ceil(fs:GetStringHeight())
	end
	return width, c.h
end

local NO_DEFAULTS = {}
local function defaults(style)
	return style and Theme.blocks[style] or NO_DEFAULTS
end

Render.context = { measure = measure, defaults = defaults }

-- Drawing --------------------------------------------------------------------------------------

-- Per surface: pools of font strings and textures, and how many are in use this draw.
local pools = setmetatable({}, { __mode = "k" })

local function poolOf(surface)
	local p = pools[surface]
	if not p then
		p = { fonts = {}, textures = {}, usedFonts = 0, usedTextures = 0 }
		pools[surface] = p
	end
	return p
end

local JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }

local function drawText(surface, p, el, x, y, w)
	p.usedFonts = p.usedFonts + 1
	local fs = p.fonts[p.usedFonts]
	if not fs then
		fs = surface:CreateFontString(nil, "OVERLAY")
		fs:SetWordWrap(true)
		fs:SetNonSpaceWrap(true)
		p.fonts[p.usedFonts] = fs
	end
	local style = textStyle(el)
	fs:SetFontObject(fontObject(style))
	local color = el.color or style.color
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	fs:SetJustifyH(JUSTIFY[el.align] or "LEFT")
	fs:SetWidth(w)
	setContent(fs, el)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", surface, "TOPLEFT", x, -y)
	fs:Show()
end

local function drawImage(surface, p, el, x, y, w, h)
	p.usedTextures = p.usedTextures + 1
	local tex = p.textures[p.usedTextures]
	if not tex then
		tex = surface:CreateTexture(nil, "ARTWORK")
		p.textures[p.usedTextures] = tex
	end
	if el.atlas then
		tex:SetAtlas(el.atlas)
	else
		tex:SetTexture(el.image)
	end
	local tc = el.texCoord
	if tc then
		tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
	else
		tex:SetTexCoord(0, 1, 0, 1) -- pooled textures may have been cropped before
	end
	tex:SetSize(w, h)
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", surface, "TOPLEFT", x, -y)
	tex:Show()
end

local function drawBlock(surface, p, result, ox, oy)
	for i = 1, result.count do
		local item = result.items[i]
		local node = item.node
		local x, y = ox + item.x, oy + item.y
		if Layout.IsText(node) then
			drawText(surface, p, node, x, y, item.w)
		elseif Layout.IsImage(node) then
			drawImage(surface, p, node, x, y, item.w, item.h)
		else
			drawBlock(surface, p, Layout.ResultOf(node), x, y)
		end
	end
end

-- The style's hover highlight: one texture per surface on the HIGHLIGHT layer, which WoW shows by itself while
-- the mouse is over a mouse-enabled Button frame (and on LockHighlight). It covers the content box.
local function drawHighlight(surface, p, look, root)
	local tex = p.highlight
	if not tex then
		tex = surface:CreateTexture(nil, "HIGHLIGHT")
		tex:SetBlendMode("ADD")
		p.highlight = tex
	end
	tex:SetTexture(look.highlight)
	local pad = root.padding or look.padding or 0
	local top, right, bottom, left = pad, pad, pad, pad
	if type(pad) == "table" then
		top, right, bottom, left = pad[1] or 0, pad[2] or 0, pad[3] or 0, pad[4] or 0
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", surface, "TOPLEFT", left, -top)
	tex:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -right, bottom)
end

--- What was measured and drawn on `surface` last time (dev-mode dumps only; builds tables, never call when hot).
function Render.Describe(surface, root)
	local p = pools[surface]
	local out = {
		surfaceSize = { surface:GetWidth(), surface:GetHeight() },
		surfaceScale = surface:GetEffectiveScale(),
		measuredAtScale = measurers[surface] and measuringScale or false,
		layout = {},
		drawn = {},
	}
	local result = root and Layout.ResultOf(root)
	for i = 1, result and result.count or 0 do
		local item = result.items[i]
		local c = naturalCache[item.node]
		out.layout[i] = {
			text = item.node.text or item.node.format, x = item.x, y = item.y, w = item.w, h = item.h,
			natural = c and { c.w, c.h } or false,
		}
	end
	for i = 1, p and p.usedFonts or 0 do
		local fs = p.fonts[i]
		out.drawn[i] = {
			text = fs:GetText(), width = fs:GetWidth(), height = fs:GetHeight(),
			stringWidth = fs:GetStringWidth(), stringHeight = fs:GetStringHeight(),
			unbounded = fs:GetUnboundedStringWidth(),
		}
	end
	return out
end

--- Lay out `root` and draw it onto `surface` (a frame; BackdropTemplate if its style has a backdrop).
--- `width` nil = shrink to fit. Sizes the surface; returns the root's layout result.
function Render.Draw(surface, root, width)
	measuring, measuringScale = surface, surface:GetEffectiveScale()
	local result = Layout.Run(root, width, Render.context)
	local p = poolOf(surface)
	p.usedFonts, p.usedTextures = 0, 0
	drawBlock(surface, p, result, 0, 0)
	for i = p.usedFonts + 1, #p.fonts do
		p.fonts[i]:Hide()
	end
	for i = p.usedTextures + 1, #p.textures do
		p.textures[i]:Hide()
	end
	local look = root.style and Theme.blocks[root.style]
	if look and look.backdrop and surface.SetBackdrop then
		if surface.ordaenBackdrop ~= look.backdrop then
			surface:SetBackdrop(look.backdrop)
			surface.ordaenBackdrop = look.backdrop
		end
		local bg, border = look.background, look.border
		surface:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
		surface:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	end
	if look and look.highlight then
		drawHighlight(surface, p, look, root)
	end
	surface:SetSize(result.width, result.height)
	return result
end
