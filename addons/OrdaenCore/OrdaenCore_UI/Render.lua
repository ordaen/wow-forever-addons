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
			fonts = {}, images = {}, solids = {}, bars = {}, usedFonts = 0, usedImages = 0, usedSolids = 0, usedBars = 0,
			embeds = {}, placed = {}, -- embedded frames placed in the last draw (set), and in this one
			siblings = {}, -- depth -> rectangles of the styled children drawn so far (border collapse), reused
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

-- Edges collapsed into a neighbour's (border-collapse): bits of `skip` in drawSurface.
local TOP, RIGHT, BOTTOM, LEFT = 1, 2, 4, 8
local function has(mask, bit)
	return mask % (bit * 2) >= bit
end

-- A block's edges: its style's, with the block's own `edges = { top = false, ... }` on top (false: none on that side,
-- true: the style's, or { width, colour }). Filled into one table per block, reused every draw (no garbage);
-- nil when the block has no edge at all.
local SIDES = { "top", "right", "bottom", "left" }
local DEFAULT_EDGE = { 1, { 0, 0, 0, 1 } }
local mergedEdges = setmetatable({}, { __mode = "k" })
local function edgesOf(look, node)
	local own = node and node.edges
	local base = look and look.edges
	if not own then
		return base
	end
	local out = mergedEdges[node]
	if not out then
		out = {}
		mergedEdges[node] = out
	end
	local any = false
	for _, side in ipairs(SIDES) do
		local e = own[side]
		if e == nil or e == true then
			e = (base and base[side]) or (e == true and (base and (base.top or base.left) or DEFAULT_EDGE)) or nil
		elseif e == false then
			e = nil
		end
		out[side] = e
		any = any or e ~= nil
	end
	return any and out or nil
end

-- A block's own surface (fill, vignette, edges), from its look, on rectangle x, y, w, h. `depth` puts nested
-- surfaces above their parent's. `skip`: edges a neighbour or the parent already draws there (TOP, RIGHT...).
-- `edges`: the block's edges (edgesOf).
local function drawSurface(surface, p, look, accent, x, y, w, h, depth, skip, edges)
	skip = skip or 0
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
	if edges then
		local px = pixel()
		local level = min(7, depth)
		local e = edges.top
		if e and not has(skip, TOP) then
			solid(surface, p, "BORDER", level, x, y, w, e[1] * px, e[2], e[2], accent)
		end
		e = edges.bottom
		if e and not has(skip, BOTTOM) then
			solid(surface, p, "BORDER", level, x, y + h - e[1] * px, w, e[1] * px, e[2], e[2], accent)
		end
		e = edges.left
		if e and not has(skip, LEFT) then
			solid(surface, p, "BORDER", level, x, y, e[1] * px, h, e[2], e[2], accent)
		end
		e = edges.right
		if e and not has(skip, RIGHT) then
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
	if el.portrait then
		SetPortraitTexture(tex, el.portrait) -- a unit's face; the caller refreshes on UNIT_PORTRAIT_UPDATE
	elseif el.atlas then
		tex:SetAtlas(el.atlas)
	else
		tex:SetTexture(el.image)
	end
	local tc = el.texCoord
	if tc then
		tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
	elseif el.crop and not el.atlas then
		-- an item or spell icon without its own border: trimmed by the theme's icon.crop
		local c = tonumber(Theme.Token("icon.crop")) or 0
		tex:SetTexCoord(c, 1 - c, c, 1 - c)
	else
		tex:SetTexCoord(0, 1, 0, 1) -- pooled textures may have been cropped before
	end
	local tint = el.color and Theme.Color(el.color, nil)
	if tint then
		tex:SetVertexColor(tint[1], tint[2], tint[3], tint[4] or 1)
	else
		tex:SetVertexColor(1, 1, 1, 1) -- pooled textures may have been tinted before
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

-- Bars ------------------------------------------------------------------------------------------------
-- A bar is three status bars over a track: the value on top, then `quest` (lighter) and `overlay` (dimmed: rested
-- XP) behind it, each from `min` to its own value. Status bars because the game animates a value change itself
-- (SetValue with interpolation, no Lua per frame). A gain flashes the new part for a moment; a value that drops
-- (a new level) fills to the end first, then starts again. Pooled per surface like font strings.

local INTERPOLATE = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local QUEST_ALPHA, OVERLAY_ALPHA = 0.7, 0.45 -- how strong the parts behind the value are drawn
local WRAP_TIME = 0.5 -- seconds the bar takes to run to the end on a wrap before starting again
local FLASH_ALPHA, FLASH_FADES = 0.35, 6 -- the gain flash: how bright it starts, how many theme fades it lasts
local NO_EDGE = { 0, 0, 0, 0.6 } -- section lines of a theme whose bars have no edge

local function statusBar(parent, level)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetFrameLevel(level)
	return bar
end

-- Set a status bar's value: animated when the element asks for it and the bar showed this element before.
local function setValue(bar, v, animate)
	if animate and INTERPOLATE then
		bar:SetValue(v, INTERPOLATE)
	else
		bar:SetValue(v)
	end
end

local function newBar(surface)
	local base = surface:GetFrameLevel()
	local b = {
		overlay = statusBar(surface, base + 1),
		quest = statusBar(surface, base + 2),
		value = statusBar(surface, base + 3),
	}
	-- The gain flash: a texture over the value bar, faded out by an animation (no OnUpdate).
	local flash = b.value:CreateTexture(nil, "OVERLAY")
	flash:SetTexture(WHITE)
	flash:SetBlendMode("ADD")
	flash:SetAlpha(0)
	local fade = flash:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha") --[[@as Alpha]]
	alpha:SetFromAlpha(FLASH_ALPHA)
	alpha:SetToAlpha(0)
	alpha:SetSmoothing("OUT")
	b.flash, b.fade, b.fadeAlpha = flash, fade, alpha
	b.label = b.value:CreateFontString(nil, "OVERLAY")
	b.label:SetWordWrap(false)
	b.ticks = {} -- the section lines, made on first use
	b.glints = {} -- the faint light line beside each (engraved sections), made on first use
	-- b.scrimLeft, b.scrimRight, b.scrimDark, b.scrimClear: the scrim under the label, made on first use
	-- After a wrap ran to the end: start again from the bottom (made once per bar, not per draw).
	b.wrap = function()
		if b.wrapTo then
			b.value:SetValue(b.lo)
			setValue(b.value, b.wrapTo, true)
			b.wrapTo = nil
		end
	end
	return b
end

local function paint(bar, texture, color, alpha, accent, lo, hi)
	bar:SetStatusBarTexture(texture)
	local r, g, b = rgba(color, accent)
	bar:SetStatusBarColor(r, g, b, alpha)
	bar:SetMinMaxValues(lo, hi)
end

local function place(bar, surface, x, y, w, h)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", surface, "TOPLEFT", x, -y)
	bar:SetSize(max(w, 0.01), max(h, 0.01))
	bar:Show()
end

-- A bronze bezel around the bar, `n` UI units wide (whole pixels): lit top and left, shaded bottom and right, then
-- a dark line inside it. Returns the rectangle inside.
local function bezel(surface, p, f, x, y, w, h, accent)
	local px = pixel()
	local n = f.width * px
	solid(surface, p, "ARTWORK", 1, x, y, w, n, f.light, f.mid, accent)
	solid(surface, p, "ARTWORK", 1, x, y + n, n, h - n, f.light, f.mid, accent, true)
	solid(surface, p, "ARTWORK", 1, x + n, y + h - n, w - n, n, f.mid, f.dark, accent)
	solid(surface, p, "ARTWORK", 1, x + w - n, y + n, n, h - 2 * n, f.mid, f.dark, accent, true)
	x, y, w, h = x + n, y + n, w - 2 * n, h - 2 * n
	solid(surface, p, "ARTWORK", 1, x, y, w, px, f.inner, f.inner, accent)
	solid(surface, p, "ARTWORK", 1, x, y + h - px, w, px, f.inner, f.inner, accent)
	solid(surface, p, "ARTWORK", 1, x, y + px, px, h - 2 * px, f.inner, f.inner, accent)
	solid(surface, p, "ARTWORK", 1, x + w - px, y + px, px, h - 2 * px, f.inner, f.inner, accent)
	return x + px, y + px, w - 2 * px, h - 2 * px
end

-- A groove cut into the panel: two pixels of shadow above, one on the left, a light bronze lip below and a softer
-- side on the right. Returns the rectangle inside.
local function groove(surface, p, f, x, y, w, h, accent)
	local px = pixel()
	solid(surface, p, "ARTWORK", 1, x, y, w, px, f.shadow, f.shadow, accent)
	solid(surface, p, "ARTWORK", 1, x, y + px, w, px, f.softShadow, f.softShadow, accent)
	solid(surface, p, "ARTWORK", 1, x, y + 2 * px, px, h - 3 * px, f.shadow, f.shadow, accent)
	solid(surface, p, "ARTWORK", 1, x, y + h - px, w, px, f.lip, f.lip, accent)
	solid(surface, p, "ARTWORK", 1, x + w - px, y + 2 * px, px, h - 3 * px, f.side, f.side, accent)
	return x + px, y + 2 * px, w - 2 * px, h - 3 * px
end

local CONSTRUCTIONS = { bezel = bezel, groove = groove }

local function drawBar(surface, p, el, x, y, w, h, accent)
	local look = Theme.bar
	local edge = look.edge
	local build = look.frame and CONSTRUCTIONS[look.frame]
	if build then
		-- Built into the panel: a frame (the bezel or the groove), then a recessed track with a soft shadow under
		-- its top edge; the parts sit in it.
		x, y, w, h = build(surface, p, look.frames[look.frame], x, y, w, h, accent)
		local recessed = look.recessed
		solid(surface, p, "ARTWORK", 0, x, y, w, h, recessed.top, recessed.bottom, accent)
		local shade = look.shade
		solid(surface, p, "ARTWORK", 2, x, y, w, min(h, 3 * pixel()), shade, shade, accent, false, shade[4], 0)
	else
		-- The theme's edge: one pixel around the bar, its corners left out (a one-pixel radius, Blizzard's bars
		-- without their curves); the track and the parts sit inside it.
		if edge then
			local px = pixel()
			solid(surface, p, "ARTWORK", 1, x + px, y, w - 2 * px, px, edge, edge, accent)
			solid(surface, p, "ARTWORK", 1, x + px, y + h - px, w - 2 * px, px, edge, edge, accent)
			solid(surface, p, "ARTWORK", 1, x, y + px, px, h - 2 * px, edge, edge, accent)
			solid(surface, p, "ARTWORK", 1, x + w - px, y + px, px, h - 2 * px, edge, edge, accent)
			x, y, w, h = x + px, y + px, w - 2 * px, h - 2 * px
		end
		solid(surface, p, "ARTWORK", 0, x, y, w, h, look.track, look.trackBottom or look.track, accent)
	end
	p.usedBars = p.usedBars + 1
	local b = p.bars[p.usedBars]
	if not b then
		b = newBar(surface)
		p.bars[p.usedBars] = b
	end
	local lo = tonumber(el.min) or 0
	local hi = tonumber(el.max) or 1
	if hi <= lo then
		hi = lo + 1
	end
	local value = max(lo, min(hi, tonumber(el.bar) or lo))
	local quest = max(value, min(hi, tonumber(el.quest) or value))
	local overlay = max(quest, min(hi, tonumber(el.overlay) or quest))
	local texture = Theme.BarTexture()
	local fill = Theme.Color(el.color, look.fill)
	paint(b.value, texture, fill, 1, accent, lo, hi)
	paint(b.quest, texture, Theme.Color(el.questColor, fill), QUEST_ALPHA, accent, lo, hi)
	paint(b.overlay, texture, Theme.Color(el.overlayColor, fill), look.ahead or OVERLAY_ALPHA, accent, lo, hi)
	place(b.value, surface, x, y, w, h)
	place(b.quest, surface, x, y, w, h)
	place(b.overlay, surface, x, y, w, h)
	-- Animate only a change of the same element on the same bar (pooled bars can move to another element).
	local same = b.element == el and b.lo == lo and b.hi == hi
	local animate = el.animate and same
	if animate and value < b.last then
		-- a wrap (a new level): run to the end, then start again from the bottom
		setValue(b.value, hi, true)
		b.wrapTo = value
		C_Timer.After(WRAP_TIME, b.wrap)
	else
		b.wrapTo = nil
		setValue(b.value, value, animate)
	end
	setValue(b.quest, quest, animate)
	setValue(b.overlay, overlay, animate)
	-- The gain flash over the newly filled part.
	if animate and value > b.last and Theme.Fade() > 0 then
		local from = (b.last - lo) / (hi - lo) * w
		b.flash:ClearAllPoints()
		b.flash:SetPoint("TOPLEFT", b.value, "TOPLEFT", from, 0)
		b.flash:SetSize(max((value - b.last) / (hi - lo) * w, 0.01), h)
		b.fade:Stop()
		b.fadeAlpha:SetDuration(Theme.Fade() * FLASH_FADES)
		b.fade:Play()
	end
	b.element, b.lo, b.hi, b.last = el, lo, hi, value
	-- Sections, as on Blizzard's bars: lines over the parts, one pixel wide; engraved when the theme says so (a dark
	-- line with a faint light one beside it), else in the edge's colour.
	local sections = tonumber(el.sections) or 0
	local ticks, glints = b.ticks, b.glints
	local engraved = look.tick
	local tickColor = engraved and engraved[1] or edge or NO_EDGE
	local px = pixel()
	for i = 1, sections - 1 do
		local t = ticks[i]
		if not t then
			t = b.value:CreateTexture(nil, "ARTWORK", nil, 7)
			t:SetTexture(WHITE)
			ticks[i] = t
		end
		local at = floor(w * i / sections / px + 0.5) * px
		t:SetVertexColor(rgba(tickColor, accent))
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", b.value, "TOPLEFT", at, 0)
		t:SetSize(px, max(h, 0.01))
		t:Show()
		local g = glints[i]
		if engraved then
			if not g then
				g = b.value:CreateTexture(nil, "ARTWORK", nil, 7)
				g:SetTexture(WHITE)
				glints[i] = g
			end
			g:SetVertexColor(rgba(engraved[2], accent))
			g:ClearAllPoints()
			g:SetPoint("TOPLEFT", b.value, "TOPLEFT", at + px, 0)
			g:SetSize(px, max(h, 0.01))
			g:Show()
		elseif g then
			g:Hide()
		end
	end
	for i = max(sections, 1), #ticks do
		ticks[i]:Hide()
	end
	for i = max(sections, 1), #glints do
		glints[i]:Hide()
	end
	-- Text on the bar, centred.
	if el.text or el.format then
		local style = textStyle(el)
		setFont(b.label, style)
		local color = el.textColor
		if color then
			b.label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
		else
			b.label:SetTextColor(rgba(style.color, accent))
		end
		setContent(b.label, el, style)
		b.label:ClearAllPoints()
		b.label:SetPoint("CENTER", b.value, "CENTER", 0, 0)
		b.label:Show()
		-- The scrim: a faint dark gradient from the middle out over the theme's share of the bar, darkest under the
		-- text, so white outlined text reads on any colour (the look the user picked for text on bars).
		local scrim = look.scrim
		if scrim and scrim > 0 then
			if not b.scrimLeft then
				b.scrimLeft = b.value:CreateTexture(nil, "ARTWORK", nil, 6)
				b.scrimLeft:SetTexture(WHITE)
				b.scrimRight = b.value:CreateTexture(nil, "ARTWORK", nil, 6)
				b.scrimRight:SetTexture(WHITE)
				b.scrimDark, b.scrimClear = CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0)
			end
			local half = floor(w * (look.scrimWidth or 0.6) / 2 / px + 0.5) * px
			b.scrimDark:SetRGBA(0, 0, 0, scrim)
			b.scrimLeft:ClearAllPoints()
			b.scrimLeft:SetPoint("TOPRIGHT", b.value, "TOP", 0, 0)
			b.scrimLeft:SetSize(max(half, 0.01), max(h, 0.01))
			b.scrimLeft:SetGradient("HORIZONTAL", b.scrimClear, b.scrimDark)
			b.scrimRight:ClearAllPoints()
			b.scrimRight:SetPoint("TOPLEFT", b.value, "TOP", 0, 0)
			b.scrimRight:SetSize(max(half, 0.01), max(h, 0.01))
			b.scrimRight:SetGradient("HORIZONTAL", b.scrimDark, b.scrimClear)
			b.scrimLeft:Show()
			b.scrimRight:Show()
		elseif b.scrimLeft then
			b.scrimLeft:Hide()
			b.scrimRight:Hide()
		end
	else
		b.label:Hide()
		if b.scrimLeft then
			b.scrimLeft:Hide()
			b.scrimRight:Hide()
		end
	end
end

local function hideBars(p)
	for i = p.usedBars + 1, #p.bars do
		local b = p.bars[i]
		b.value:Hide()
		b.quest:Hide()
		b.overlay:Hide()
		b.element = nil
	end
end

-- Border collapse (like CSS): touching blocks share one edge. A styled child skips the edge it shares with a sibling
-- drawn before it (its left against that one's right, its top against that one's bottom), and the edges on its
-- parent's border when the parent draws an edge there (padding 0). Input buttons in a row showed two borders and a
-- gap between each pair (2026-11-06). Sibling rectangles live in tables reused per depth: no garbage per draw.
local NEAR = 0.5

local function collapse(p, depth, n, parentEdges, ox, oy, pw, ph, x, y, w, h)
	local skip = 0
	if parentEdges then
		if parentEdges.top and y - oy < NEAR then
			skip = skip + TOP
		end
		if parentEdges.left and x - ox < NEAR then
			skip = skip + LEFT
		end
		if parentEdges.right and ox + pw - (x + w) < NEAR then
			skip = skip + RIGHT
		end
		if parentEdges.bottom and oy + ph - (y + h) < NEAR then
			skip = skip + BOTTOM
		end
	end
	local list = p.siblings[depth]
	for j = 1, n do
		local r = list[j]
		local e = r.edges
		if not has(skip, LEFT) and e.right and math.abs(r.x + r.w - x) < NEAR and r.y < y + h and y < r.y + r.h then
			skip = skip + LEFT
		end
		if not has(skip, TOP) and e.bottom and math.abs(r.y + r.h - y) < NEAR and r.x < x + w and x < r.x + r.w then
			skip = skip + TOP
		end
	end
	return skip
end

local function rememberSibling(p, depth, n, edges, x, y, w, h)
	local list = p.siblings[depth]
	if not list then
		list = {}
		p.siblings[depth] = list
	end
	local r = list[n]
	if not r then
		r = {}
		list[n] = r
	end
	r.edges, r.x, r.y, r.w, r.h = edges, x, y, w, h
end

local drawBlock

-- A child's highlight on request (`highlight = true` on the block: a cell lit while the Blizzard button over it is
-- hovered), in its style's highlight colour, over its fill and under its content.
local HIGHLIGHT = { 1, 1, 1, 0.12 }
local function drawCellHighlight(surface, p, look, x, y, w, h, accent)
	local hl = look.highlight
	local c = (hl and hl.color) or HIGHLIGHT
	solid(surface, p, "ARTWORK", -1, x, y, w, h, c, c, accent)
end

function drawBlock(surface, p, result, ox, oy, accent, depth, parentEdges)
	local styled = 0
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
			local edges = nil -- its edges once drawn (edgesOf), for collapsing its children against them
			if look then
				local sx, sy, sw, sh = x, y, item.w, item.h
				if look.bleed then
					sx, sw = sx - result.padLeft, sw + result.padLeft + result.padRight
					if item.row == 1 then
						sy, sh = sy - result.padTop, sh + result.padTop
					end
				end
				local skip = 0
				edges = edgesOf(look, node)
				if edges then
					skip = collapse(p, depth, styled, parentEdges, ox, oy, result.width, result.height, sx, sy, sw, sh)
					styled = styled + 1
					rememberSibling(p, depth, styled, edges, sx, sy, sw, sh)
				end
				drawSurface(surface, p, look, own, sx, sy, sw, sh, depth + 1, skip, edges)
				if node.highlight then
					drawCellHighlight(surface, p, look, sx, sy, sw, sh, own)
				end
			end
			drawBlock(surface, p, Layout.ResultOf(node), x, y, own, depth + 1, edges)
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

local backdrops = setmetatable({}, { __mode = "k" }) -- surface -> the backdrop it shows (no keys on frames)

local function drawBackdrop(surface, look)
	if not surface.SetBackdrop then
		return
	end
	local backdrop = look and look.backdrop or nil
	if backdrops[surface] ~= backdrop then
		if backdrop then
			surface:SetBackdrop(backdrop)
		else
			surface:ClearBackdrop() -- the theme changed to one drawn without art
		end
		backdrops[surface] = backdrop
	end
	if backdrop then
		local bg, border = look.background, look.border
		surface:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
		surface:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	end
end

-- Blizzard's window art (a look with `frameArt`, resolved from theme tokens by Theme.lua): Blizzard's own NineSlice
-- layout put on the surface by NineSliceUtil (its corners reach outside the rectangle as on Blizzard's windows), its
-- border pieces scaled (0.5 on small surfaces), tinted by the block's own accent if it has one (quality), and one
-- background texture inside the border (an atlas, or a file that tiles; `inset` in the art's pixels). The pieces
-- are the surface's own textures, under its text. Root blocks only. Applied once per surface and resolved look
-- (a theme change resolves new ones); a draw only re-tints.
local BORDER_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
	"BottomEdge", "LeftEdge", "RightEdge" }
local artShown = setmetatable({}, { __mode = "k" }) -- surface -> the frameArt it shows
local artOpen = setmetatable({}, { __mode = "k" }) -- surface -> the open sides it was drawn with (bits)
local artFills = setmetatable({}, { __mode = "k" }) -- surface -> its fill texture
-- surface -> how its fill covers it, for a background that doesn't tile: { atlas, x, y (the insets, together), w, h
-- (the size last fitted) }
local artFits = setmetatable({}, { __mode = "k" })

-- An atlas's size and texture coordinates (C_Texture.GetAtlasInfo), once per atlas; false when the game has none.
local atlasCache = {}
-- The top corners a mirrored top takes from the bottom ones, and the point each sits at.
local MIRRORED_CORNERS = { { "TopLeftCorner", "BottomLeftCorner", "TOPLEFT" },
	{ "TopRightCorner", "BottomRightCorner", "TOPRIGHT" } }

local function atlasOf(name)
	local cached = atlasCache[name]
	if cached == nil then
		local info = C_Texture.GetAtlasInfo(name)
		cached = info and info.width and info.width > 0 and info.height > 0 and {
			info.width / info.height, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord,
		} or false
		atlasCache[name] = cached
	end
	return cached
end

-- Cover-fit: a background that doesn't tile fills the surface at its own aspect, cropped at the long sides (centred),
-- never stretched. Redone only when the size changes; a secret size (combat numbers) is left as it was.
local function fitFill(surface, width, height)
	local fit = artFits[surface]
	if not fit or issecretvalue(width) or issecretvalue(height) then
		return
	end
	local w, h = width - fit.x, height - fit.y
	if w <= 0 or h <= 0 or (w == fit.w and h == fit.h) then
		return
	end
	fit.w, fit.h = w, h
	local atlas = atlasOf(fit.atlas)
	if not atlas then
		return
	end
	local aspect, l, r, t, b = atlas[1], atlas[2], atlas[3], atlas[4], atlas[5]
	local surfaceAspect = w / h
	if surfaceAspect > aspect then -- wider than the art: its full width, a band of its height
		local cut = (b - t) * (1 - aspect / surfaceAspect) / 2
		t, b = t + cut, b - cut
	else -- taller: its full height, a band of its width
		local cut = (r - l) * (1 - surfaceAspect / aspect) / 2
		l, r = l + cut, r - cut
	end
	artFills[surface]:SetTexCoord(l, r, t, b)
end
local artAbove = setmetatable({}, { __mode = "k" }) -- surface -> the frame its border goes above (a dressed window)
local artOverlays = setmetatable({}, { __mode = "k" }) -- surface -> the overlay frame holding its border

-- Where the border pieces go: the surface itself, or (a dressed Blizzard window, whose opaque content reaches its
-- edges) an overlay over the surface placed above that window and its children, as Blizzard draws its own NineSlice.
-- The overlay takes no mouse. Its strata and level follow the window on each draw: the level of the window's own
-- NineSlice (Blizzard's templates put it 500 levels above the window, over every content child; at +50 the
-- character window's panes covered our border, 2026-11-07), else the window's level + 500 like Blizzard's.
local ABOVE_LEVELS = 500

local function aboveLevel(target)
	local nine = rawget(target, "NineSlice")
	local borderFrame = rawget(target, "BorderFrame")
	if not nine and type(borderFrame) == "table" then
		nine = rawget(borderFrame, "NineSlice")
	end
	if type(nine) == "table" and nine.GetFrameLevel then
		return nine:GetFrameLevel()
	end
	return target:GetFrameLevel() + ABOVE_LEVELS
end

local function borderHolder(surface)
	local target = artAbove[surface]
	if not target then
		return surface
	end
	local overlay = artOverlays[surface]
	if not overlay then
		overlay = CreateFrame("Frame", nil, surface)
		overlay:SetAllPoints(surface)
		overlay:EnableMouse(false)
		artOverlays[surface] = overlay
	end
	overlay:SetFrameStrata(target:GetFrameStrata())
	overlay:SetFrameLevel(min(10000, aboveLevel(target)))
	return overlay
end

--- Draw `surface`'s window border above `target` and its children (Dress, `borderAbove`); the next draw moves a
--- border already drawn on the surface.
---@param surface Frame
---@param target Frame
function Render.BorderAbove(surface, target)
	if artShown[surface] and not artAbove[surface] then
		NineSliceUtil.HideLayout(surface)
		artShown[surface] = nil
	end
	artAbove[surface] = target
end

-- Open sides (a block's `open`): no border there, as if the metal ran on past the screen edge or into the surface
-- next to it. The side's edge and its two corners hide; the neighbouring edges reach to the outer line of those
-- corners; the fill reaches the side. Blizzard's NineSliceUtil anchors each edge between its corners' inner sides,
-- so an open end moves to the corner's outer side (hidden regions still anchor).
local OPEN_TOP, OPEN_RIGHT, OPEN_BOTTOM, OPEN_LEFT = 1, 2, 4, 8

local function openBits(open)
	if type(open) ~= "table" then
		return 0
	end
	return (open.top and OPEN_TOP or 0) + (open.right and OPEN_RIGHT or 0) + (open.bottom and OPEN_BOTTOM or 0)
		+ (open.left and OPEN_LEFT or 0)
end

local function openSides(holder, bits)
	local top, right, bottom, left = has(bits, OPEN_TOP), has(bits, OPEN_RIGHT), has(bits, OPEN_BOTTOM),
		has(bits, OPEN_LEFT)
	local tl, tr, bl, br = holder.TopLeftCorner, holder.TopRightCorner, holder.BottomLeftCorner, holder.BottomRightCorner
	local te, be, le, re = holder.TopEdge, holder.BottomEdge, holder.LeftEdge, holder.RightEdge
	tl:SetShown(not (top or left))
	tr:SetShown(not (top or right))
	bl:SetShown(not (bottom or left))
	br:SetShown(not (bottom or right))
	te:SetShown(not top)
	be:SetShown(not bottom)
	le:SetShown(not left)
	re:SetShown(not right)
	-- Each edge spans its corners: between their inner sides, or to the outer side of a corner on an open side. Both
	-- anchors are set here (whichever points Blizzard's layout used: a third point would fight them).
	te:ClearAllPoints()
	te:SetPoint("TOPLEFT", tl, left and "TOPLEFT" or "TOPRIGHT")
	te:SetPoint("BOTTOMRIGHT", tr, right and "BOTTOMRIGHT" or "BOTTOMLEFT")
	be:ClearAllPoints()
	be:SetPoint("TOPLEFT", bl, left and "TOPLEFT" or "TOPRIGHT")
	be:SetPoint("BOTTOMRIGHT", br, right and "BOTTOMRIGHT" or "BOTTOMLEFT")
	le:ClearAllPoints()
	le:SetPoint("TOPLEFT", tl, top and "TOPLEFT" or "BOTTOMLEFT")
	le:SetPoint("BOTTOMRIGHT", bl, bottom and "BOTTOMRIGHT" or "TOPRIGHT")
	re:ClearAllPoints()
	re:SetPoint("TOPLEFT", tr, top and "TOPLEFT" or "BOTTOMLEFT")
	re:SetPoint("BOTTOMRIGHT", br, bottom and "BOTTOMRIGHT" or "TOPRIGHT")
end

-- A small surface's top drawn as its bottom mirrored (frameArt.mirrorTop): the top corners take the bottom corners'
-- atlases flipped upside down (their atlas coordinates, top and bottom swapped) at the bottom corners' offsets turned
-- upwards, and the top edge takes the bottom edge's atlas turned half a circle (a repeating strip: the same as a flip,
-- and it keeps tiling). A window's own top edge carries its title bar; on a strip that read as two borders stacked.
local function mirrorTop(holder, layoutName)
	local layout = NineSliceLayouts and NineSliceLayouts[layoutName]
	if type(layout) ~= "table" then
		return
	end
	for _, pair in ipairs(MIRRORED_CORNERS) do
		local piece, from = holder[pair[1]], layout[pair[2]]
		local atlas = type(from) == "table" and from.atlas
		local coords = atlas and atlasOf(atlas)
		if piece and coords then
			piece:SetAtlas(atlas, true)
			piece:SetTexCoord(coords[2], coords[3], coords[5], coords[4])
			piece:ClearAllPoints()
			piece:SetPoint(pair[3], holder, pair[3], from.x or 0, -(from.y or 0))
		end
	end
	local edge, from = holder.TopEdge, layout.BottomEdge
	if edge and type(from) == "table" and from.atlas then
		edge:SetAtlas(from.atlas, true)
		edge:SetRotation(math.pi)
	end
end

local function drawFrameArt(surface, look, accent, open, width, height)
	local art = look and look.frameArt or nil
	local shown = artShown[surface]
	local holder = borderHolder(surface)
	local bits = art and openBits(open) or 0
	if art and art == shown and artOpen[surface] ~= bits then
		shown = nil -- sides opened or closed: lay Blizzard's pieces out again, then open them
	end
	if art ~= shown then
		local fill = artFills[surface]
		if shown then
			NineSliceUtil.HideLayout(holder)
			if fill then
				fill:Hide()
			end
		end
		artShown[surface] = art
		if not art then
			return
		end
		NineSliceUtil.ApplyLayoutByName(holder, art.layout)
		if art.mirrorTop then
			mirrorTop(holder, art.layout)
		elseif holder.TopEdge then
			holder.TopEdge:SetRotation(0) -- the same pieces may have worn a mirrored top before
		end
		NineSliceUtil.DisableSharpening(holder)
		NineSliceUtil.ShowLayout(holder)
		artOpen[surface] = bits
		if bits ~= 0 then
			openSides(holder, bits)
		end
		local scale = art.scale or 1
		for i = 1, #BORDER_PIECES do
			local piece = holder[BORDER_PIECES[i]]
			if piece then
				piece:SetScale(scale)
			end
		end
		local background = art.background
		if background then
			if not fill then
				fill = surface:CreateTexture(nil, "BACKGROUND", nil, -8)
				artFills[surface] = fill
			end
			local inset = art.inset
			if background.atlas then
				fill:SetAtlas(background.atlas)
			else
				local wrap = background.tile and "REPEAT" or nil
				fill:SetTexture(background.file, wrap, wrap)
				fill:SetTexCoord(0, 1, 0, 1) -- a cover-fit atlas before may have cropped it
			end
			fill:SetHorizTile(background.tile and true or false)
			fill:SetVertTile(background.tile and true or false)
			fill:ClearAllPoints()
			local t = has(bits, OPEN_TOP) and 0 or inset[1] * scale
			local r = has(bits, OPEN_RIGHT) and 0 or inset[2] * scale
			local b = has(bits, OPEN_BOTTOM) and 0 or inset[3] * scale
			local l = has(bits, OPEN_LEFT) and 0 or inset[4] * scale
			fill:SetPoint("TOPLEFT", surface, "TOPLEFT", l, -t)
			fill:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -r, b)
			fill:Show()
			artFits[surface] = background.atlas and not background.tile
				and { atlas = background.atlas, x = l + r, y = t + b } or nil
		else
			artFits[surface] = nil
		end
	end
	if not art then
		return
	end
	fitFill(surface, width, height)
	local r, g, b = 1, 1, 1
	if accent then
		r, g, b = accent[1], accent[2], accent[3]
	end
	for i = 1, #BORDER_PIECES do
		local piece = holder[BORDER_PIECES[i]]
		if piece then
			piece:SetVertexColor(r, g, b)
		end
	end
end

-- Blizzard's control art (a look with `controlArt`, from the theme's control assets): pieces drawn on the surface's
-- own textures, pooled per surface. A piece is an atlas name; { atlas | file, alpha, coords, outset }; three slices
-- { left, center, right } (the ends keep their aspect at the surface's height, the centre stretches) or
-- { top, middle, bottom }. Drawn in the block's controlState (from the dress's :SetState): the asset's piece for it,
-- checked over normal (the box, then its check), or normal darker for pushed and grey for disabled when it has none.
-- The asset's highlight piece goes on the HIGHLIGHT layer (shown on hover and LockHighlight); `parts` put a part (a
-- dropdown's arrow) at a side, at its own size.
local controlPools = setmetatable({}, { __mode = "k" }) -- surface -> { used = n, [i] = texture }
local FALLBACK_TINT = { pushed = 0.75, disabled = 0.6 }
local OVER_NORMAL = { checked = true, disabledChecked = true } -- states drawn over the normal piece
local NO_PARTS = {}
local drawControlPiece

local function controlTexture(surface, pool, layer, sublevel)
	local n = pool.used + 1
	pool.used = n
	local tex = pool[n]
	if not tex then
		tex = surface:CreateTexture(nil, layer, nil, sublevel)
		pool[n] = tex
	else
		tex:SetDrawLayer(layer, sublevel)
	end
	return tex
end

-- An atlas's aspect (width / height), or 1 for a file or an atlas the game doesn't know.
local function aspectOf(piece)
	local name = type(piece) == "string" and piece or type(piece) == "table" and piece.atlas
	local atlas = name and atlasOf(name)
	return atlas and atlas[1] or 1
end

local function setPiece(tex, piece, tint, grey, accent)
	local alpha = 1
	if type(piece) == "string" then
		tex:SetAtlas(piece)
	else
		if piece.atlas then
			tex:SetAtlas(piece.atlas)
		else
			tex:SetTexture(piece.file)
			tex:SetTexCoord(0, 1, 0, 1)
		end
		local c = piece.coords
		if c then
			tex:SetTexCoord(c[1], c[2], c[3], c[4])
		end
		alpha = piece.alpha or 1
	end
	local r, g, b = tint, tint, tint
	if accent then
		r, g, b = accent[1] * tint, accent[2] * tint, accent[3] * tint
	end
	tex:SetVertexColor(r, g, b)
	tex:SetDesaturated(grey)
	tex:SetAlpha(alpha)
	tex:Show()
end

local function placePiece(surface, tex, x, y, w, h)
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", surface, "TOPLEFT", x, -y)
	tex:SetSize(max(w, 0.01), max(h, 0.01))
end

local function drawSlice(surface, pool, piece, layer, sublevel, x, y, w, h, tint, grey, accent)
	local tex = controlTexture(surface, pool, layer, sublevel)
	setPiece(tex, piece, tint, grey, accent)
	placePiece(surface, tex, x, y, w, h)
end

local function drawPiece(surface, pool, piece, layer, sublevel, x, y, w, h, tint, grey, accent)
	if type(piece) == "table" and piece.left then
		local lw, rw = h * aspectOf(piece.left), h * aspectOf(piece.right)
		local scale = (lw + rw > w and w > 0) and w / (lw + rw) or 1
		lw, rw = lw * scale, rw * scale
		drawSlice(surface, pool, piece.left, layer, sublevel, x, y, lw, h, tint, grey, accent)
		drawSlice(surface, pool, piece.center, layer, sublevel, x + lw, y, w - lw - rw, h, tint, grey, accent)
		drawSlice(surface, pool, piece.right, layer, sublevel, x + w - rw, y, rw, h, tint, grey, accent)
		return
	end
	if type(piece) == "table" and piece.top then
		local th, bh = w / aspectOf(piece.top), w / aspectOf(piece.bottom)
		local scale = (th + bh > h and h > 0) and h / (th + bh) or 1
		th, bh = th * scale, bh * scale
		drawSlice(surface, pool, piece.top, layer, sublevel, x, y, w, th, tint, grey, accent)
		drawSlice(surface, pool, piece.middle, layer, sublevel, x, y + th, w, h - th - bh, tint, grey, accent)
		drawSlice(surface, pool, piece.bottom, layer, sublevel, x, y + h - bh, w, bh, tint, grey, accent)
		return
	end
	local o = type(piece) == "table" and piece.outset or 0
	local tex = controlTexture(surface, pool, layer, sublevel)
	setPiece(tex, piece, tint, grey, accent)
	placePiece(surface, tex, x - o, y - o, w + 2 * o, h + 2 * o)
end

-- One drawn layer of the control (1: its state's piece, 2: a check over it), at the surface's size.
local controlW, controlH = 0, 0
function drawControlPiece(surface, pool, piece, order, tint, grey, accent)
	if piece ~= nil then
		local sublevel = order == 1 and -8 or -5
		drawPiece(surface, pool, piece, "BACKGROUND", sublevel, 0, 0, controlW, controlH, tint, grey, accent)
	end
end

local function drawControlArt(surface, look, accent, w, h, state)
	controlW, controlH = w, h
	local art = look and look.controlArt or nil
	local pool = controlPools[surface]
	if not art then
		if pool then
			for i = 1, #pool do
				pool[i]:Hide()
			end
			pool.used = 0
		end
		return
	end
	if issecretvalue(w) or issecretvalue(h) then
		return -- sized from combat numbers: left as it was
	end
	if not pool then
		pool = { used = 0 }
		controlPools[surface] = pool
	end
	pool.used = 0
	local asset = art.asset
	local tintBy = art.accent and accent or nil
	local base = asset[art.base]
	if state and OVER_NORMAL[state] then -- the box, then its check
		drawControlPiece(surface, pool, base, 1, 1, state == "disabledChecked", tintBy)
		drawControlPiece(surface, pool, asset[state] or asset.checked, 2, 1, false, tintBy)
	elseif state and state ~= "highlight" and asset[state] ~= nil then
		drawControlPiece(surface, pool, asset[state], 1, 1, false, tintBy)
	else
		drawControlPiece(surface, pool, base, 1, FALLBACK_TINT[state] or 1, state == "disabled", tintBy)
	end
	for part, point in pairs(art.parts or NO_PARTS) do
		local piece = asset[part]
		if piece ~= nil then
			local pw = h * aspectOf(piece)
			drawPiece(surface, pool, piece, "BORDER", 0, point == "LEFT" and 0 or w - pw, 0, pw, h, 1, false, nil)
		end
	end
	local highlight = asset.highlight
	if highlight ~= nil then
		drawPiece(surface, pool, highlight, "HIGHLIGHT", 0, 0, 0, w, h, 1, false, nil)
	end
	for i = pool.used + 1, #pool do
		pool[i]:Hide()
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

-- Where `node` was drawn in the last layout of `root`: x, y (from the top left), width, height; nil if not drawn.
local function find(result, node, ox, oy)
	if not result then
		return nil
	end
	for i = 1, result.count do
		local item = result.items[i]
		local x, y = ox + item.x, oy + item.y
		if item.node == node then
			return x, y, item.w, item.h
		end
		if Layout.IsBlock(item.node) then
			local fx, fy, fw, fh = find(Layout.ResultOf(item.node), node, x, y)
			if fx then
				return fx, fy, fw, fh
			end
		end
	end
	return nil
end

--- Where an element of `root` was drawn last: x, y from the surface's top left, width, height (nil: not drawn).
---@return number|nil, number|nil, number|nil, number|nil
function Render.RectOf(root, node)
	return find(Layout.ResultOf(root), node, 0, 0)
end

--- Lay out `root` and draw it onto `surface` (a frame; BackdropTemplate for themes with art).
--- `width` nil = shrink to fit. Sizes the surface; returns the root's layout result.
-- A top-level block's `hints` (what a click or a key does: the addon's own lines, "Left-click: open") and `hotkey`
-- (the key bound to it), drawn the same way in every tooltip (the user's decision, 2026-11-07): dimmed lines at the
-- bottom, the hotkey last ("Key: C", Ordaen Core's words). The rows are added to the block once and grow only when it
-- gets more hints than before; after that only their fields change. They span the block's columns.
Render.strings = { hotkey = "%s" } -- Ordaen Core's, handed over when the module loads (UI._Provide)
local FOOTER = "_hintRows"
local function hintRows(root)
	local hints, key = root.hints, root.hotkey
	local n = type(hints) == "table" and #hints or 0
	local hasKey = key ~= nil and key ~= ""
	local footer = rawget(root, FOOTER)
	if not footer then
		if n == 0 and not hasKey then
			return
		end
		local keyLine = { format = "%s", args = { "" }, style = "hint" }
		footer = { padding = { "sm", 0, 0, 0 }, keyLine = keyLine, keyLine }
		root[#root + 1] = footer
		rawset(root, FOOTER, footer)
	end
	local keyLine = footer.keyLine
	local made = #footer - 1 -- hint lines so far; the key line is always the last
	if n > made then
		for i = made + 1, n do
			footer[i] = { text = "", style = "hint" }
		end
		footer[n + 1] = keyLine
	end
	for i = 1, #footer - 1 do
		local line = footer[i]
		line.hidden = i > n
		if i <= n then
			line.text = hints[i]
		end
	end
	keyLine.hidden = not hasKey
	keyLine.format = Render.strings.hotkey
	if hasKey then
		keyLine.args[1] = key
	end
	footer.hidden = n == 0 and not hasKey
	footer.colSpan = root.columns and #root.columns or 1
end

function Render.Draw(surface, root, width)
	Theme.Ensure()
	hintRows(root)
	measuring, measuringScale = surface, surface:GetEffectiveScale()
	local ctx = Render.context
	ctx.shift = IsShiftKeyDown() and true or false
	local result = Layout.Run(root, width, ctx)
	local p = poolOf(surface)
	p.usedFonts, p.usedImages, p.usedSolids, p.usedBars = 0, 0, 0, 0
	local look = Theme.BlockStyle(root.style)
	local accent = root.accent or Theme.accent
	drawBackdrop(surface, look)
	drawFrameArt(surface, look, root.accent, root.open, result.width, result.height)
	drawControlArt(surface, look, root.accent, result.width, result.height, root.controlState)
	if look and not look.controlArt then
		drawSurface(surface, p, look, accent, 0, 0, result.width, result.height, 1, 0, edgesOf(look, root))
	end
	drawBlock(surface, p, result, 0, 0, accent, 1, edgesOf(look, root))
	hideRest(p.fonts, p.usedFonts)
	hideRest(p.images, p.usedImages)
	hideRest(p.solids, p.usedSolids)
	hideBars(p)
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
