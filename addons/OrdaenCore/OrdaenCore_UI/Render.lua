-- OrdaenCore.UI renderer: the one drawing code. It measures text for the layout engine and draws a laid-out
-- block tree onto a surface frame, taking every look from the theme (ns.Theme).
--
-- Cost: font strings and textures are pooled per surface and reused on every draw; measurements are cached
-- per element (one small table per element, created once) and redone only when its text, font or width
-- changes. Nothing runs per frame.
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

local measurer -- a font string on a frame that is never shown
local naturalCache = setmetatable({}, { __mode = "k" }) -- element -> { text, font, w, h }
local wrappedCache = setmetatable({}, { __mode = "k" }) -- element -> { text, font, width, h }

local function measurerFor(style)
	if not measurer then
		local frame = CreateFrame("Frame")
		frame:Hide()
		measurer = frame:CreateFontString(nil, "OVERLAY")
		measurer:SetWordWrap(true)
		measurer:SetNonSpaceWrap(true)
	end
	measurer:SetFontObject(fontObject(style))
	return measurer
end

--- Size of a text element: natural (one line) when width is nil, else wrapped to width. For the layout engine.
local function measure(el, width)
	local style = textStyle(el)
	local text = el.text
	if width == nil then
		local c = naturalCache[el]
		if not c then
			c = {}
			naturalCache[el] = c
		end
		if c.text ~= text or c.font ~= style.font then
			local fs = measurerFor(style)
			fs:SetWidth(0)
			fs:SetText(text)
			-- One pixel more than measured, so rounding never wraps a line that fits.
			c.text, c.font, c.w, c.h = text, style.font, ceil(fs:GetUnboundedStringWidth()) + 1, ceil(fs:GetStringHeight())
		end
		return c.w, c.h
	end
	local c = wrappedCache[el]
	if not c then
		c = {}
		wrappedCache[el] = c
	end
	if c.text ~= text or c.font ~= style.font or c.width ~= width then
		local fs = measurerFor(style)
		fs:SetWidth(width)
		fs:SetText(text)
		c.text, c.font, c.width, c.h = text, style.font, width, ceil(fs:GetStringHeight())
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
	fs:SetText(el.text)
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
	tex:SetTexture(el.image)
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
		if node.text ~= nil then
			drawText(surface, p, node, x, y, item.w)
		elseif node.image ~= nil then
			drawImage(surface, p, node, x, y, item.w, item.h)
		else
			drawBlock(surface, p, Layout.ResultOf(node), x, y)
		end
	end
end

--- Lay out `root` and draw it onto `surface` (a frame; BackdropTemplate if its style has a backdrop).
--- `width` nil = shrink to fit. Sizes the surface; returns the root's layout result.
function Render.Draw(surface, root, width)
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
	surface:SetSize(result.width, result.height)
	return result
end
