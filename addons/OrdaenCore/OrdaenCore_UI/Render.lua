-- OrdaenCore.UI renderer: the one drawing code. It measures text for the layout engine and draws a laid-out
-- block tree onto a surface frame, taking every look from the theme (ns.Theme).
--
-- Surfaces are drawn without art where the theme says so: a vertical gradient fill, edges of an exact number
-- of physical pixels, a darkened rim (vignette), all on one white texture tinted with SetGradient. Nested blocks
-- with a style draw their own surface (a header band); `bleed` takes it over the parent's padding.
--
-- Cost: font strings and textures are pooled per surface and reused on every draw; measurements are cached
-- per element (one small table per element, created once) and redone only when its text, the theme, the width
-- or the surface's scale changes. Colours go through two colour objects per surface. Nothing runs per frame.
local _, ns = ...

local Render = {}
ns.Render = Render

local Layout, Theme = ns.Layout, ns.Theme
local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min
local unpack = unpack

local WHITE = "Interface\\Buttons\\WHITE8X8"
local NO_ARGS = {}

local function textStyle(el)
	return Theme.TextStyle(el.style or (el.separator and "caption") or "body")
end

local function caps(el, style)
	if el.caps ~= nil then
		return el.caps
	end
	return style.caps
end

-- Text ------------------------------------------------------------------------------------------------

-- Upper-cased text per element, made again only when the text changes (caps applies to plain `text`; a
-- format string keeps its case, since upper-casing would break "%d").
local upperCache = setmetatable({}, { __mode = "k" }) -- element -> { source, upper }

local function shownText(el, style)
	local text = el.text
	if text == nil or not caps(el, style) then
		return text
	end
	local c = upperCache[el]
	if not c then
		c = {}
		upperCache[el] = c
	end
	if c.source ~= text then
		c.source, c.upper = text, Theme.Upper(text)
	end
	return c.upper
end

-- Put an element's text on a font string: a plain string, or a format with arguments through WoW's
-- SetFormattedText, which builds the string in C (no Lua string per change).
local function setContent(fs, el, style)
	if el.format then
		local args = el.args or NO_ARGS
		fs:SetFormattedText(el.format, unpack(args, 1, #args))
	else
		fs:SetText(shownText(el, style))
	end
end

local function setFont(fs, style)
	if not fs:SetFont(style.file, style.size, "") then
		fs:SetFontObject(GameFontNormal) -- a font file that didn't load; never leave a font string without one
	end
	if style.shadow then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Measuring ------------------------------------------------------------------------------------

-- Text is measured on the surface it will be drawn on, never elsewhere. WoW rasterizes fonts at whole-pixel
-- sizes for a frame's effective scale, so the same text has a slightly different width in UI units at another
-- scale; measured on an unparented frame (scale 1) and drawn under UIParent (the UI scale), lines that "fit"
-- wrapped onto an extra line and overflowed the tooltip. Each surface has one hidden measuring font string, and
-- the caches remember the scale and the theme version they measured with.
local measurers = setmetatable({}, { __mode = "k" }) -- surface -> its hidden measuring font string
local measuring, measuringScale -- the surface being drawn and its effective scale (set by Render.Draw)
local naturalCache = setmetatable({}, { __mode = "k" }) -- element -> { text|format, args, style, scale, w, h }
local wrappedCache = setmetatable({}, { __mode = "k" }) -- element -> the same, plus width

-- Whether the cache entry `c` was measured for the element's current content (compared value by value, so a
-- changed argument measures again and an unchanged one doesn't).
local function sameContent(c, el, style)
	if c.style ~= style or c.version ~= Theme.version or c.scale ~= measuringScale or c.text ~= el.text
		or c.format ~= el.format or c.caps ~= el.caps then
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

local function remember(c, el, style)
	c.style, c.version, c.scale = style, Theme.version, measuringScale
	c.text, c.format, c.caps = el.text, el.format, el.caps
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
	setFont(fs, style)
	return fs
end

--- Size of a text element: natural (one line) when width is nil, else wrapped to width. For the layout engine.
local function measure(el, width)
	local style = textStyle(el)
	if width == nil then
		local c = naturalCache[el]
		if not c then
			c = {}
			naturalCache[el] = c
		end
		if not sameContent(c, el, style) then
			local fs = measurerFor(style)
			fs:SetWidth(0)
			setContent(fs, el, style)
			remember(c, el, style)
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
	if c.width ~= width or not sameContent(c, el, style) then
		local fs = measurerFor(style)
		fs:SetWidth(width)
		setContent(fs, el, style)
		remember(c, el, style)
		c.width, c.h = width, ceil(fs:GetStringHeight())
	end
	return width, c.h
end

-- One physical pixel in the surface's UI units: edges and lines are whole pixels at any UI scale.
local function pixel()
	return PixelUtil.GetPixelToUIUnitFactor() / measuringScale
end

local MIN_CAPTION_LINE = 8

--- Natural width and height of a stretch element (separator, bar). For the layout engine.
local function element(el)
	if el.bar ~= nil then
		return el.width or 0, el.height or Theme.bar.height
	end
	local look = Theme.separators[el.separator] or Theme.separators.rule
	local line = look.width * pixel()
	if el.separator == "caption" and (el.text or el.format) then
		local w, h = measure(el, nil)
		return w + 2 * (look.gap + MIN_CAPTION_LINE), max(h, line) + 2 * look.space
	end
	return 0, line + 2 * look.space
end

local NO_DEFAULTS = {}
local function defaults(style)
	return Theme.BlockStyle(style) or NO_DEFAULTS
end

-- An embedded component's size: what it drew itself at (its owner refreshes it before laying out the block).
local function embedSize(el)
	local frame = el.embed.frame
	return frame:GetWidth() or 0, frame:GetHeight() or 0
end

Render.context = {
	measure = measure, defaults = defaults, element = element, embed = embedSize, space = Theme.Space, shift = false,
}

-- Drawing --------------------------------------------------------------------------------------

-- Per surface: pools of font strings, images and solid (white, tinted) textures, how many are in use this
-- draw, and two colour objects for gradients.
local pools = setmetatable({}, { __mode = "k" })

local function poolOf(surface)
	local p = pools[surface]
	if not p then
		p = {
			fonts = {}, images = {}, solids = {}, usedFonts = 0, usedImages = 0, usedSolids = 0,
			embeds = {}, placed = {}, -- embedded frames placed in the last draw (set), and in this one
			from = CreateColor(0, 0, 0, 0), to = CreateColor(0, 0, 0, 0),
		}
		pools[surface] = p
	end
	return p
end

-- Colour spec { r, g, b, a?, accent = k? } -> r, g, b, a: the colour plus k times the accent.
local function rgba(spec, accent)
	local k = spec.accent
	if k then
		return min(1, spec[1] + accent[1] * k), min(1, spec[2] + accent[2] * k), min(1, spec[3] + accent[3] * k),
			spec[4] or 1
	end
	return spec[1], spec[2], spec[3], spec[4] or 1
end
Render.RGBA = rgba

-- A rectangle of colour on `layer`: a vertical gradient from `first` (top) to `second` (bottom), or horizontal
-- from `first` (left) to `second` (right); equal specs for a flat colour. `alphaFirst`/`alphaSecond` override
-- the specs' alpha (vignettes fade to 0).
local function solid(surface, p, layer, sublevel, x, y, w, h, first, second, accent, horizontal, alphaFirst,
		alphaSecond)
	p.usedSolids = p.usedSolids + 1
	local tex = p.solids[p.usedSolids]
	if not tex then
		tex = surface:CreateTexture(nil, layer)
		tex:SetTexture(WHITE)
		p.solids[p.usedSolids] = tex
	end
	tex:SetDrawLayer(layer, sublevel)
	local r1, g1, b1, a1 = rgba(first, accent)
	local r2, g2, b2, a2 = rgba(second, accent)
	-- SetGradient: "VERTICAL" runs from the bottom (min colour) to the top; "HORIZONTAL" from left to right.
	if horizontal then
		p.from:SetRGBA(r1, g1, b1, alphaFirst or a1)
		p.to:SetRGBA(r2, g2, b2, alphaSecond or a2)
		tex:SetGradient("HORIZONTAL", p.from, p.to)
	else
		p.from:SetRGBA(r2, g2, b2, alphaSecond or a2)
		p.to:SetRGBA(r1, g1, b1, alphaFirst or a1)
		tex:SetGradient("VERTICAL", p.from, p.to)
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", surface, "TOPLEFT", x, -y)
	tex:SetSize(max(w, 0.01), max(h, 0.01))
	tex:Show()
end

local BLACK = { 0, 0, 0, 1 }

-- A block's own surface (fill, vignette, edges), from its look, on rectangle x, y, w, h. `depth` puts nested
-- surfaces above their parent's.
local function drawSurface(surface, p, look, accent, x, y, w, h, depth)
	local sub = min(6, depth * 2 - 2)
	local fill = look.fill
	if fill then
		solid(surface, p, "BACKGROUND", sub, x, y, w, h, fill.top, fill.bottom, accent)
	end
	local vignette = look.vignette
	if vignette then
		local s, a = min(vignette.size, h / 2, w / 2), vignette.alpha
		local layer = sub + 1
		solid(surface, p, "BACKGROUND", layer, x, y, w, s, BLACK, BLACK, accent, false, a, 0)
		solid(surface, p, "BACKGROUND", layer, x, y + h - s, w, s, BLACK, BLACK, accent, false, 0, a)
		solid(surface, p, "BACKGROUND", layer, x, y, s, h, BLACK, BLACK, accent, true, a, 0)
		solid(surface, p, "BACKGROUND", layer, x + w - s, y, s, h, BLACK, BLACK, accent, true, 0, a)
	end
	local edges = look.edges
	if edges then
		local px = pixel()
		local level = min(7, depth)
		local e = edges.top
		if e then
			solid(surface, p, "BORDER", level, x, y, w, e[1] * px, e[2], e[2], accent)
		end
		e = edges.bottom
		if e then
			solid(surface, p, "BORDER", level, x, y + h - e[1] * px, w, e[1] * px, e[2], e[2], accent)
		end
		e = edges.left
		if e then
			solid(surface, p, "BORDER", level, x, y, e[1] * px, h, e[2], e[2], accent)
		end
		e = edges.right
		if e then
			solid(surface, p, "BORDER", level, x + w - e[1] * px, y, e[1] * px, h, e[2], e[2], accent)
		end
	end
end

local JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }

local function drawText(surface, p, el, x, y, w, justify, accent)
	p.usedFonts = p.usedFonts + 1
	local fs = p.fonts[p.usedFonts]
	if not fs then
		fs = surface:CreateFontString(nil, "OVERLAY")
		fs:SetWordWrap(true)
		fs:SetNonSpaceWrap(true)
		p.fonts[p.usedFonts] = fs
	end
	local style = textStyle(el)
	setFont(fs, style)
	local color = el.color
	if color then
		fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	else
		fs:SetTextColor(rgba(style.color, accent))
	end
	fs:SetJustifyH(justify or JUSTIFY[el.align] or "LEFT")
	fs:SetWidth(w)
	setContent(fs, el, style)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", surface, "TOPLEFT", x, -y)
	fs:Show()
end

local function drawImage(surface, p, el, x, y, w, h)
	p.usedImages = p.usedImages + 1
	local tex = p.images[p.usedImages]
	if not tex then
		tex = surface:CreateTexture(nil, "ARTWORK")
		p.images[p.usedImages] = tex
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

local function drawSeparator(surface, p, el, x, y, w, h, accent)
	local look = Theme.separators[el.separator] or Theme.separators.rule
	local line = look.width * pixel()
	local mid = y + floor(h / 2) - line / 2
	local color = look.color
	if el.separator == "caption" and (el.text or el.format) then
		local tw, th = measure(el, nil)
		local tx = x + floor((w - tw) / 2 + 0.5)
		drawText(surface, p, el, tx, y + floor((h - th) / 2 + 0.5), tw, "CENTER", accent)
		if line > 0 then
			local side = tx - x - look.gap
			solid(surface, p, "ARTWORK", 0, x, mid, side, line, color, color, accent)
			solid(surface, p, "ARTWORK", 0, tx + tw + look.gap, mid, side, line, color, color, accent)
		end
	elseif el.separator == "divider" and look.gap > 0 then
		local side = (w - look.gap) / 2
		solid(surface, p, "ARTWORK", 0, x, mid, side, line, color, color, accent)
		solid(surface, p, "ARTWORK", 0, x + side + look.gap, mid, side, line, color, color, accent)
	elseif line > 0 then
		solid(surface, p, "ARTWORK", 0, x, mid, w, line, color, color, accent)
	end
end

local function drawBar(surface, p, el, x, y, w, h, accent)
	local bar = Theme.bar
	solid(surface, p, "ARTWORK", 0, x, y, w, h, bar.track, bar.track, accent)
	local value = max(0, min(1, tonumber(el.bar) or 0))
	if value > 0 then
		local fill = el.color or bar.fill
		solid(surface, p, "ARTWORK", 1, x, y, w * value, h, fill, fill, accent)
	end
end

local function drawBlock(surface, p, result, ox, oy, accent, depth)
	for i = 1, result.count do
		local item = result.items[i]
		local node = item.node
		local x, y = ox + item.x, oy + item.y
		local own = node.accent or accent
		if Layout.IsEmbed(node) then
			local frame = node.embed.frame
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", surface, "TOPLEFT", x, -y)
			frame:Show()
			p.placed[frame] = true
		elseif Layout.IsStretch(node) then
			if node.bar ~= nil then
				drawBar(surface, p, node, x, y, item.w, item.h, own)
			else
				drawSeparator(surface, p, node, x, y, item.w, item.h, own)
			end
		elseif Layout.IsText(node) then
			drawText(surface, p, node, x, y, item.w, nil, own)
		elseif Layout.IsImage(node) then
			drawImage(surface, p, node, x, y, item.w, item.h)
		else
			local look = Theme.BlockStyle(node.style)
			if look then
				local sx, sy, sw, sh = x, y, item.w, item.h
				if look.bleed then
					sx, sw = sx - result.padLeft, sw + result.padLeft + result.padRight
					if item.row == 1 then
						sy, sh = sy - result.padTop, sh + result.padTop
					end
				end
				drawSurface(surface, p, look, own, sx, sy, sw, sh, depth + 1)
			end
			drawBlock(surface, p, Layout.ResultOf(node), x, y, own, depth + 1)
		end
	end
end

-- The style's hover highlight: one texture per surface on the HIGHLIGHT layer, which WoW shows by itself while
-- the mouse is over a mouse-enabled Button frame (and on LockHighlight). It covers the content box.
local function drawHighlight(surface, p, look, result)
	local tex = p.highlight
	if not tex then
		tex = surface:CreateTexture(nil, "HIGHLIGHT")
		tex:SetBlendMode("ADD")
		p.highlight = tex
	end
	local highlight = look and look.highlight
	if not highlight then
		tex:SetAlpha(0) -- the theme changed to one without a highlight for this role
		return
	end
	tex:SetAlpha(1)
	if highlight.texture then
		tex:SetTexture(highlight.texture)
		tex:SetVertexColor(1, 1, 1, 1)
	else
		local c = highlight.color
		tex:SetTexture(WHITE)
		tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", surface, "TOPLEFT", result.padLeft, -result.padTop)
	tex:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -result.padRight, result.padBottom)
end

local function drawBackdrop(surface, look)
	if not surface.SetBackdrop then
		return
	end
	local backdrop = look and look.backdrop or nil
	if surface.ordaenBackdrop ~= backdrop then
		if backdrop then
			surface:SetBackdrop(backdrop)
		else
			surface:ClearBackdrop() -- the theme changed to one drawn without art
		end
		surface.ordaenBackdrop = backdrop
	end
	if backdrop then
		local bg, border = look.background, look.border
		surface:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
		surface:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	end
end

local function hideRest(list, used)
	for i = used + 1, #list do
		list[i]:Hide()
	end
end

--- What was measured and drawn on `surface` last time (dev-mode dumps only; builds tables, never call when hot).
function Render.Describe(surface, root)
	local p = pools[surface]
	local out = {
		theme = Theme.name,
		textSize = Theme.size.body,
		surfaceSize = { surface:GetWidth(), surface:GetHeight() },
		surfaceScale = surface:GetEffectiveScale(),
		measuredAtScale = measurers[surface] and measuringScale or false,
		layout = {},
		drawn = {},
	}
	-- Every laid-out node, nested blocks' children too, in drawing order; x, y relative to the surface.
	local function describe(result, ox, oy, depth)
		for i = 1, result and result.count or 0 do
			local item = result.items[i]
			local node = item.node
			local c = naturalCache[node]
			out.layout[#out.layout + 1] = {
				text = node.text or node.format, separator = node.separator, bar = node.bar, depth = depth,
				x = ox + item.x, y = oy + item.y, w = item.w, h = item.h, natural = c and { c.w, c.h } or false,
			}
			if Layout.IsBlock(node) then
				describe(Layout.ResultOf(node), ox + item.x, oy + item.y, depth + 1)
			end
		end
	end
	describe(root and Layout.ResultOf(root), 0, 0, 1)
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

--- Lay out `root` and draw it onto `surface` (a frame; BackdropTemplate for themes with art).
--- `width` nil = shrink to fit. Sizes the surface; returns the root's layout result.
function Render.Draw(surface, root, width)
	Theme.Ensure()
	measuring, measuringScale = surface, surface:GetEffectiveScale()
	local ctx = Render.context
	ctx.shift = IsShiftKeyDown() and true or false
	local result = Layout.Run(root, width, ctx)
	local p = poolOf(surface)
	p.usedFonts, p.usedImages, p.usedSolids = 0, 0, 0
	local look = Theme.BlockStyle(root.style)
	local accent = root.accent or Theme.accent
	drawBackdrop(surface, look)
	if look then
		drawSurface(surface, p, look, accent, 0, 0, result.width, result.height, 1)
	end
	drawBlock(surface, p, result, 0, 0, accent, 1)
	hideRest(p.fonts, p.usedFonts)
	hideRest(p.images, p.usedImages)
	hideRest(p.solids, p.usedSolids)
	-- Embedded frames placed last time but not now (hidden children): hide them. Then this draw's set becomes the
	-- last one (two sets swapped, so no table per draw).
	local before, now = p.embeds, p.placed
	for frame in pairs(before) do
		if not now[frame] then
			frame:Hide()
		end
		before[frame] = nil
	end
	p.embeds, p.placed = now, before
	if (look and look.highlight) or p.highlight then
		drawHighlight(surface, p, look, result)
	end
	surface:SetSize(result.width, result.height)
	return result
end

--- Whether a block tree has rows that depend on Shift (its tooltip then listens for Shift while shown).
---@return boolean
function Render.UsesShift(node)
	for i = 1, #node do
		local child = node[i]
		if child.shift ~= nil or (Layout.IsBlock(child) and Render.UsesShift(child)) then
			return true
		end
	end
	return false
end
