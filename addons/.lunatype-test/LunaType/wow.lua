-- The game's side of drawing: LTML's elements on WoW's frames, textures and font strings.
--
-- The runtime (lunatype.lua) knows a host by five calls: `create`, `set`, `on`, `order`, `remove`, and `flush` once a
-- frame. This file is that host for WoW. An element is a node here: { kind, parent, children, attrs, state }. A `box`
-- owns a Frame, a `text` a FontString on the frame of the box it stands in, and a `group` (what `$if`, `$for` and a
-- component stand in) owns nothing: its children are laid out as its parent's, in its place. A `surface` is a box
-- whose frame is the screen's and not its parent's: it has no place in its parent's layout, and is laid out by
-- itself on the layer it names.
--
-- A change to an attribute is kept and the tree marked; `flush` then lays the marked trees out and places their
-- frames, once, however many attributes changed. Laying out is two passes over a box's children, as the box model
-- says: the widths of its columns (fixed, then content, then shares of what is left), then the heights of its rows
-- from the children laid out at those widths.
--
-- Nothing here is WoW's until `install` is called, so the file loads under plain Lua too.
local R = LunaType
local Wow = {}
R.wow = Wow

local max, min = math.max, math.min
local type, unpack, pairs = type, unpack, pairs

-- Pools -----------------------------------------------------------------------------------------------------------
-- WoW never frees a frame, so frames, textures and font strings are only ever borrowed.

local framePool, nFrames = {}, 0
local holder -- the frame that owns what the pools hold

local function takeFrame(parent)
	local frame
	if nFrames > 0 then
		frame = framePool[nFrames]
		framePool[nFrames] = nil
		nFrames = nFrames - 1
		frame:SetParent(parent)
	else
		frame = CreateFrame("Button", nil, parent)
	end
	frame:ClearAllPoints()
	frame:SetAlpha(1)
	frame:Show()
	return frame
end

local scripts = { "OnSizeChanged", "OnClick", "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnDragStart", "OnDragStop", "OnUpdate",
	"OnKeyDown", "OnMouseWheel" }

local function giveFrame(frame)
	for i = 1, #scripts do
		frame:SetScript(scripts[i], nil)
	end
	frame:EnableMouse(false)
	frame:EnableMouseWheel(false)
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetParent(holder)
	frame.node, frame.within, frame.dragging, frame.sizedArt = nil, nil, nil, nil
	-- Its textures are its own and come back with it: none shows until the next box asks for it.
	if frame.textures then
		for _, t in pairs(frame.textures) do
			t:Hide()
		end
	end
	nFrames = nFrames + 1
	framePool[nFrames] = frame
end

-- The fields the player types into: the game's edit boxes, borrowed like frames.
local editPool, nEdits = {}, 0

local function takeEdit(parent)
	local edit
	if nEdits > 0 then
		edit = editPool[nEdits]
		editPool[nEdits] = nil
		nEdits = nEdits - 1
		edit:SetParent(parent)
	else
		edit = CreateFrame("EditBox", nil, parent)
		edit:SetAutoFocus(false)
	end
	edit:ClearAllPoints()
	edit:Show()
	return edit
end

local function giveEdit(edit)
	edit:SetScript("OnTextChanged", nil)
	edit:SetScript("OnEscapePressed", nil)
	edit:SetScript("OnEnterPressed", nil)
	edit:ClearFocus()
	edit:SetText("")
	edit:Hide()
	edit:ClearAllPoints()
	edit:SetParent(holder)
	edit.node = nil
	nEdits = nEdits + 1
	editPool[nEdits] = edit
end

-- Textures and font strings stay with the frame that made them: a frame from the pool brings its own back.
local function texture(frame, slot, layer)
	local textures = frame.textures
	if not textures then
		textures = {}
		frame.textures = textures
	end
	local t = textures[slot]
	if not t then
		t = frame:CreateTexture(nil, layer)
		textures[slot] = t
	end
	return t
end

local function fontString(frame)
	local free = frame.freeStrings
	if free and #free > 0 then
		local fs = free[#free]
		free[#free] = nil
		fs:Show()
		return fs
	end
	return frame:CreateFontString(nil, "ARTWORK")
end

local function giveFontString(frame, fs)
	fs:Hide()
	fs:ClearAllPoints()
	fs:SetText("")
	local free = frame.freeStrings
	if not free then
		free = {}
		frame.freeStrings = free
	end
	free[#free + 1] = fs
end

-- Attributes -------------------------------------------------------------------------------------------------------

local dirty = false -- something that changes the layout was set since the last flush
local surfaces = {} -- the boxes that stand on the screen, in the order they were made
local rewire = false -- something that decides whose state a node follows, or who takes the mouse, was set
local roots = {} -- the nodes drawing starts from: what `mount` was given

-- An attribute's value now: the node's own, or the one its `style` gives; a value that follows the element's state
-- ({ default, hover, pressed, disabled }) is the one for the state it is in.
local function attr(node, name)
	local value = node.attrs[name]
	if value == nil then
		local style = node.attrs.style
		if style then
			value = style[name]
		end
	end
	if type(value) == "table" and value.default ~= nil then
		local source = node.stateOf
		while source.stateOf ~= source do
			source = source.stateOf
		end
		local state = source.state
		local now = state and value[state]
		if now == nil then
			now = value.default
		end
		return now
	end
	return value
end

-- What changes where things are, as against only how they look.
local shapes = {
	width = true, height = true, columns = true, rows = true, gap = true, padding = true, xAlign = true, yAlign = true,
	position = true, left = true, top = true, right = true, bottom = true, border = true, shown = true, style = true,
	value = true, arguments = true, textSize = true, textFamily = true, wrap = true, columnSpan = true,
}

-- The box a text takes its look from: the nearest one above it that sets the attribute.
local function inherited(node, name)
	local value = attr(node, name)
	local up = node.parent
	while value == nil and up do
		if up.kind == "box" then
			value = attr(up, name)
		end
		up = up.parent
	end
	return value
end

-- Painting ---------------------------------------------------------------------------------------------------------

local WHITE = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_SIZE = 12

local function paintText(node)
	local fs = node.fs
	local size = inherited(node, "textSize") or DEFAULT_SIZE
	local family = inherited(node, "textFamily") or "Fonts\\FRIZQT__.TTF"
	-- A line round the letters: 1 a thin one, 2 a thick one.
	local outline = inherited(node, "textOutline") or 0
	if node.fontSize ~= size or node.fontFamily ~= family or node.fontOutline ~= outline then
		fs:SetFont(family, size, outline >= 2 and "THICKOUTLINE" or outline >= 1 and "OUTLINE" or "")
		node.fontSize, node.fontFamily, node.fontOutline = size, family, outline
	end
	local color = inherited(node, "textColor") or WHITE
	fs:SetTextColor(color.r, color.g, color.b, color.a)
	local shadow = inherited(node, "textShadow")
	if shadow then
		fs:SetShadowColor(shadow.color.r, shadow.color.g, shadow.color.b, shadow.color.a)
		fs:SetShadowOffset(shadow.x, shadow.y)
	else
		fs:SetShadowOffset(0, 0)
	end
	fs:SetWordWrap(attr(node, "wrap") ~= false)
	local value, arguments = attr(node, "value"), attr(node, "arguments")
	if value == nil then
		fs:SetText("")
	elseif arguments then
		-- A format with its values apart: no Lua string is made when one of them changes.
		fs:SetFormattedText(value, unpack(arguments))
	else
		fs:SetText(value)
	end
end

local sides = { "top", "right", "bottom", "left" }

-- Portraits: the boxes that show a unit's face, each with its unit. The game says when a unit's look changes;
-- it is listened to only while a face shows.
local portraits, nPortraits, portraitWatcher = {}, 0, nil

local function onPortrait(_, _, unit)
	for node, own in pairs(portraits) do
		local textures = node.frame and node.frame.textures
		if own == unit and textures and textures.face then
			SetPortraitTexture(textures.face, own, true)
		end
	end
end

local function portray(node, unit)
	local was = portraits[node]
	if was == unit then
		return
	end
	portraits[node] = unit
	nPortraits = nPortraits + (unit and 1 or 0) - (was and 1 or 0)
	if nPortraits > 0 and not (portraitWatcher and portraitWatcher.on) then
		portraitWatcher = portraitWatcher or CreateFrame("Frame")
		portraitWatcher:SetScript("OnEvent", onPortrait)
		portraitWatcher:RegisterEvent("UNIT_PORTRAIT_UPDATE")
		portraitWatcher.on = true
	elseif nPortraits == 0 and portraitWatcher and portraitWatcher.on then
		portraitWatcher:UnregisterEvent("UNIT_PORTRAIT_UPDATE")
		portraitWatcher.on = false
	end
end

local function drawn(border, side)
	local list = border.sides
	if not list then
		return true
	end
	for i = 1, #list do
		if list[i] == side then
			return true
		end
	end
	return false
end

-- Art --------------------------------------------------------------------------------------------------------------
-- A piece of art is a file's path or an atlas's name, or one of the theme's, which says how it is drawn:
-- (`Piece` in ltml.d.luna): repeated, tiled along the box, or one of its rows by the box's state, with caps.
-- A metal ({ nineSlice, ... }) is drawn from the client's own frame art, side by side (below).
local MEDIA = "Interface\\AddOns\\Ordaen\\media\\"

local function setPicture(tex, art)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(art)
	if info then
		tex:SetAtlas(art)
	else
		tex:SetTexCoord(0, 1, 0, 1)
		tex:SetTexture(art)
	end
end

-- The state a node is in: its own, or that of the node it follows.
local function stateOf(node)
	local source = node.stateOf
	while source.stateOf ~= source do
		source = source.stateOf
	end
	return source.state
end

-- One row of a piece on three textures: the caps at the box's ends, the middle stretched between them; with no
-- caps the middle alone, over the whole box.
local function sliceRow(frame, middle, leftSlot, rightSlot, layer, art, row, rows, u, capW)
	local v0, v1 = row / rows, (row + 1) / rows
	middle:SetTexCoord(u, 1 - u, v0, v1)
	middle:ClearAllPoints()
	local left, right = frame.textures[leftSlot], frame.textures[rightSlot]
	if u > 0 then
		left, right = texture(frame, leftSlot, layer), texture(frame, rightSlot, layer)
		left:SetTexture(art.file)
		right:SetTexture(art.file)
		left:ClearAllPoints()
		right:ClearAllPoints()
		left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		left:SetWidth(capW)
		right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		right:SetWidth(capW)
		left:SetTexCoord(0, u, v0, v1)
		right:SetTexCoord(1 - u, 1, v0, v1)
		left:Show()
		right:Show()
		middle:SetPoint("TOPLEFT", frame, "TOPLEFT", capW, 0)
		middle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -capW, 0)
	else
		middle:SetAllPoints(frame)
		if left then
			left:Hide()
		end
		if right then
			right:Hide()
		end
	end
end

local function hideSlots(frame, ...)
	for i = 1, select("#", ...) do
		local tex = frame.textures[select(i, ...)]
		if tex then
			tex:Hide()
		end
	end
end

-- A theme's piece fitted to its frame's size and state: again whenever either changes.
local function fitArt(frame)
	local art, bg = frame.sizedArt, frame.textures and frame.textures.background
	if not art or not bg then
		return
	end
	local w, h = frame:GetWidth(), frame:GetHeight()
	if not w or not h or w <= 0 or h <= 0 then
		return
	end
	if art.repeatSize then
		bg:SetTexCoord(0, w / art.repeatSize, 0, h / art.repeatSize)
		return
	end
	if art.tile then
		-- Along the box, at the box's height.
		bg:SetTexCoord(0, w / (art.width * h / art.height), 0, 1)
		return
	end
	local rows, state = art.rows or 1, frame.artState
	local row = state == "pressed" and art.pressed or state == "hover" and art.hover or art.normal or 0
	local u = art.cap and art.cap > 0 and art.cap / art.width or 0
	local capW = math.min(h * (art.capHeight or 1), w / 2)
	sliceRow(frame, bg, "capLeft", "capRight", "BACKGROUND", art, row, rows, u, capW)
	if art.glow and state == "hover" then
		local glow = texture(frame, "glow", "BORDER")
		glow:SetTexture(art.file)
		glow:Show()
		sliceRow(frame, glow, "glowLeft", "glowRight", "BORDER", art, art.glow, rows, u, capW)
	else
		hideSlots(frame, "glow", "glowLeft", "glowRight")
	end
end

local function onArtSized(frame)
	fitArt(frame)
end

-- A border of the theme's metal: the client's own frame art (`border.nineSlice`, one of its NineSliceLayouts), drawn
-- inside the box on the sides `border.sides` names, each at its atlas's size times `border.scale`:
--   bottom, left, right  the layout's edges, tiling along; the bottom corners the layout's, where both sides meet
--   top                  the left edge turned a quarter to lie along the top, stretched across
--   top corners          mitred: a square of the side's edge under a square of the turned top, each masked to its
--                        half of the diagonal (media/mitre-*)
--   radius               a corner `border.radius` names is rounded in place of the above (media/metal-corner-*)
--   flare                a side `border.flare` names curves out at its bottom into a line under the box
-- The art stands on a frame of its own over the box's content.
local CORNERS = {
	topLeft = { "TOPLEFT", 0, 1, 0, 1 }, topRight = { "TOPRIGHT", 1, 0, 0, 1 },
	bottomLeft = { "BOTTOMLEFT", 0, 1, 1, 0 }, bottomRight = { "BOTTOMRIGHT", 1, 0, 1, 0 },
}

local function atlasSize(piece)
	local info = type(piece) == "table" and piece.atlas and C_Texture.GetAtlasInfo(piece.atlas)
	if info then
		return piece.atlas, info.width, info.height
	end
end

local function hideMetal(frame)
	if frame.artFrame then
		frame.artFrame:Hide()
	end
end

local function paintMetal(frame, border)
	local layout = NineSliceLayouts and NineSliceLayouts[border.nineSlice]
	local leftAtlas, leftW, leftH = atlasSize(type(layout) == "table" and layout.LeftEdge)
	if not leftAtlas then
		return hideMetal(frame)
	end
	local holder = frame.artFrame
	if not holder then
		holder = CreateFrame("Frame", nil, frame)
		holder:SetAllPoints(frame)
		frame.artFrame, frame.artPieces, frame.artMasks = holder, {}, {}
	end
	holder:SetFrameLevel(frame:GetFrameLevel() + 2)
	holder:Show()
	local pieces, masks = frame.artPieces, frame.artMasks
	for _, tex in pairs(pieces) do
		tex:Hide()
	end
	for _, mask in pairs(masks) do
		mask:Hide()
	end
	local top, right, bottom, left = drawn(border, "top"), drawn(border, "right"), drawn(border, "bottom"),
		drawn(border, "left")
	local k = border.scale or 1
	local T = leftW * k -- the left edge's thickness: the mitred corners' square
	local f = leftW / leftH -- that square's share of the left edge's length
	local D = top and right and 9.5 * k or 0
	local radius, curves = border.radius, border.curves
	local function round(corner, a, b)
		local name = a and b and radius and radius[corner]
		return name and curves[name] * k or nil
	end
	local rTL, rTR = round("topLeft", top, left), round("topRight", top, right)
	local rBL, rBR = round("bottomLeft", bottom, left), round("bottomRight", bottom, right)
	local fL, fR = false, false
	if border.flare then
		for i = 1, #border.flare do
			fL, fR = fL or border.flare[i] == "left", fR or border.flare[i] == "right"
		end
	end
	local F = (fL or fR) and curves.flare * k or 0
	local function piece(key, sub)
		local tex = pieces[key]
		if not tex then
			tex = holder:CreateTexture(nil, "BORDER", nil, sub)
			tex:SetSnapToPixelGrid(false)
			tex:SetTexelSnappingBias(0)
			pieces[key] = tex
		end
		tex:ClearAllPoints()
		tex:SetTexCoord(0, 1, 0, 1)
		tex:SetHorizTile(false)
		tex:SetVertTile(false)
		tex:Show()
		return tex
	end
	local function masked(key, tex, file, over)
		local mask = masks[key]
		if not mask then
			mask = holder:CreateMaskTexture()
			mask:SetTexture(MEDIA .. "mitre-" .. file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			tex:AddMaskTexture(mask)
			masks[key] = mask
		end
		mask:SetAllPoints(over)
		mask:Show()
	end
	local blAtlas, blW, blH = atlasSize(layout.BottomLeftCorner)
	local brAtlas, brW, brH = atlasSize(layout.BottomRightCorner)
	blW, blH, brW, brH = (blW or 0) * k, (blH or 0) * k, (brW or 0) * k, (brH or 0) * k
	if top then
		local tex = piece("top", 0)
		tex:SetAtlas(leftAtlas)
		tex:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
		tex:SetPoint("TOPLEFT", holder, "TOPLEFT", rTL or (left and T or 0), 0)
		tex:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -(rTR or (right and T or 0)), 0)
		tex:SetHeight(T)
	end
	if bottom then
		local atlas, _, h = atlasSize(layout.BottomEdge)
		if atlas then
			local tex = piece("bottom", 0)
			tex:SetAtlas(atlas)
			tex:SetHorizTile(true)
			tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", rBL or (left and blW or 0), 0)
			tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -(rBR or (right and brW or 0)), 0)
			tex:SetHeight(h * k)
		end
	end
	if left then
		local tex = piece("left", 0)
		tex:SetAtlas(leftAtlas)
		tex:SetVertTile(true)
		tex:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(rTL or (top and T or 0)))
		tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, fL and F or rBL or (bottom and blH or 0))
		tex:SetWidth(T)
	end
	local rightAtlas, rightW = atlasSize(layout.RightEdge)
	if right and rightAtlas then
		local tex = piece("right", 0)
		-- A rounded frame's right side is its left edge mirrored, so its line lies as deep as its curves'.
		local mirrored = radius ~= nil
		tex:SetAtlas(mirrored and leftAtlas or rightAtlas)
		if mirrored then
			tex:SetTexCoord(1, 0, 0, 1)
		end
		tex:SetVertTile(true)
		tex:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -(rTR or (top and D + T or 0)))
		tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, fR and F or rBR or (bottom and brH or 0))
		tex:SetWidth(mirrored and T or rightW * k)
	end
	if bottom and left and blAtlas and not rBL then
		local tex = piece("bl", 1)
		tex:SetAtlas(blAtlas)
		tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
		tex:SetSize(blW, blH)
	end
	if bottom and right and brAtlas and not rBR then
		local tex = piece("br", 1)
		tex:SetAtlas(brAtlas)
		tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
		tex:SetSize(brW, brH)
	end
	local function curve(key, file, size, corner)
		local at = CORNERS[corner]
		local tex = piece(key, 1)
		tex:SetTexture(MEDIA .. "metal-" .. file)
		tex:SetTexCoord(at[2], at[3], at[4], at[5])
		tex:SetPoint(at[1], holder, at[1], 0, 0)
		tex:SetSize(size, size)
	end
	if rTL then
		curve("roundTL", "corner-" .. radius.topLeft, rTL, "topLeft")
	end
	if rTR then
		curve("roundTR", "corner-" .. radius.topRight, rTR, "topRight")
	end
	if rBL then
		curve("roundBL", "corner-" .. radius.bottomLeft, rBL, "bottomLeft")
	end
	if rBR then
		curve("roundBR", "corner-" .. radius.bottomRight, rBR, "bottomRight")
	end
	if fL then
		local tex = piece("flareL", 1)
		tex:SetTexture(MEDIA .. "metal-flare")
		tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
		tex:SetSize(F, F)
	end
	if fR then
		local tex = piece("flareR", 1)
		tex:SetTexture(MEDIA .. "metal-flare")
		tex:SetTexCoord(1, 0, 0, 1)
		tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
		tex:SetSize(F, F)
	end
	-- The mitred top corners: the side's square (its lower half), the turned top's square (its upper half).
	if top and left and not rTL then
		local side = piece("tlSide", 1)
		side:SetAtlas(leftAtlas)
		side:SetTexCoord(0, 1, 0, f)
		side:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		side:SetSize(T, T)
		local turned = piece("tlTop", 2)
		turned:SetAtlas(leftAtlas)
		turned:SetTexCoord(0, 1, 1, 1, 0, 1 - f, 1, 1 - f)
		turned:SetAllPoints(side)
		masked("tlSide", side, "ll", side)
		masked("tlTop", turned, "ur", side)
	end
	if top and right and rightAtlas and not rTR then
		local side = piece("trSide", 1)
		side:SetAtlas(rightAtlas)
		side:SetTexCoord(0, 1, 0, f)
		side:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -D)
		side:SetSize(T, T)
		-- The turned top drawn D higher: the square's upper T - D show the art's lower part.
		local turned = piece("trTop", 2)
		turned:SetAtlas(leftAtlas)
		local u = D / T
		turned:SetTexCoord(u, 1, 1, 1, u, 1 - f, 1, 1 - f)
		turned:SetPoint("TOPLEFT", side, "TOPLEFT")
		turned:SetPoint("TOPRIGHT", side, "TOPRIGHT")
		turned:SetHeight(T - D)
		masked("trSide", side, "lr", side)
		masked("trTop", turned, "ul", side)
	end
end

local function paintBox(node)
	local frame = node.frame
	local background = attr(node, "background")
	local bg = frame.textures and frame.textures.background
	if background ~= nil then
		bg = texture(frame, "background", "BACKGROUND")
		-- Under a metal the background starts inside the art: its reach past the line, and its inset.
		local metal = attr(node, "border")
		if type(metal) == "table" and metal.nineSlice then
			local k, out, inset = metal.scale or 1, metal.reach, metal.inset or 0
			bg:ClearAllPoints()
			bg:SetPoint("TOPLEFT", frame, "TOPLEFT", drawn(metal, "left") and out.left * k + inset or 0,
				-(drawn(metal, "top") and out.top * k + inset or 0))
			bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(drawn(metal, "right") and out.right * k + inset or 0),
				drawn(metal, "bottom") and out.bottom * k + inset or 0)
		else
			bg:SetAllPoints(frame)
		end
		local sized = type(background) == "table" and background.file and background or nil
		if frame.sizedArt ~= sized then
			frame.sizedArt = sized
			frame:SetScript("OnSizeChanged", sized and onArtSized or nil)
			if not sized then
				hideSlots(frame, "glow", "glowLeft", "glowRight", "capLeft", "capRight")
			end
		end
		if sized then
			bg:SetVertexColor(1, 1, 1, 1)
			if sized.repeatSize then
				bg:SetTexture(sized.file, "REPEAT", "REPEAT")
			elseif sized.tile then
				bg:SetTexture(sized.file, "REPEAT", "CLAMP")
			else
				bg:SetTexture(sized.file)
			end
			frame.artState = stateOf(node)
			fitArt(frame)
		elseif type(background) == "table" then
			bg:SetColorTexture(background.r, background.g, background.b, background.a)
		else
			setPicture(bg, background)
			local tint = attr(node, "tint")
			if tint then
				bg:SetVertexColor(tint.r, tint.g, tint.b, tint.a)
			else
				bg:SetVertexColor(1, 1, 1, 1)
			end
			bg:SetDesaturated(attr(node, "desaturate") == true)
		end
		bg:Show()
	elseif bg then
		bg:Hide()
	end

	-- A unit's face over the background, as the game draws it without its own round cut.
	local unit = attr(node, "portrait")
	local face = frame.textures and frame.textures.face
	if unit then
		face = texture(frame, "face", "ARTWORK")
		face:SetAllPoints(frame)
		SetPortraitTexture(face, unit, true)
		face:Show()
	elseif face then
		face:Hide()
	end
	portray(node, unit)

	-- The shape that shows of the background and the face. A frame from the pool may carry the last one's.
	local shape = attr(node, "mask")
	local mask = frame.mask
	if shape and not mask then
		mask = frame:CreateMaskTexture()
		mask:SetAllPoints(frame)
		frame.mask = mask
	end
	if shape then
		mask:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
	if mask then
		local masked = shape and background ~= nil and bg or nil
		if frame.maskedBg ~= masked then
			if frame.maskedBg then
				frame.maskedBg:RemoveMaskTexture(mask)
			end
			if masked then
				masked:AddMaskTexture(mask)
			end
			frame.maskedBg = masked
		end
		masked = shape and unit and face or nil
		if frame.maskedFace ~= masked then
			if frame.maskedFace then
				frame.maskedFace:RemoveMaskTexture(mask)
			end
			if masked then
				masked:AddMaskTexture(mask)
			end
			frame.maskedFace = masked
		end
	end

	-- A plain line round the box, or along some of its sides: one texture a side.
	local border = attr(node, "border")
	local line = type(border) == "table" and not border.art and border or nil
	for i = 1, 4 do
		local side = sides[i]
		local shown = line ~= nil
		if shown and line.sides then
			shown = false
			for j = 1, #line.sides do
				if line.sides[j] == side then
					shown = true
				end
			end
		end
		local edge = frame.textures and frame.textures[side]
		if shown then
			edge = texture(frame, side, "BORDER")
			edge:ClearAllPoints()
			edge:SetColorTexture(line.color.r, line.color.g, line.color.b, line.color.a)
			if side == "top" or side == "bottom" then
				edge:SetPoint(side == "top" and "TOPLEFT" or "BOTTOMLEFT", frame, side == "top" and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
				edge:SetPoint(side == "top" and "TOPRIGHT" or "BOTTOMRIGHT", frame, side == "top" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
				edge:SetHeight(line.width)
			else
				edge:SetPoint(side == "left" and "TOPLEFT" or "TOPRIGHT", frame, side == "left" and "TOPLEFT" or "TOPRIGHT", 0, 0)
				edge:SetPoint(side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT", frame, side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
				edge:SetWidth(line.width)
			end
			edge:Show()
		elseif edge then
			edge:Hide()
		end
	end
	-- A border that is a piece of art covers the box: the art carries its own corners.
	local art = frame.textures and frame.textures.frame
	local picture = type(border) == "string" and border or (type(border) == "table" and border.art) or nil
	if type(border) == "table" and border.nineSlice then
		picture = nil
		paintMetal(frame, border)
	else
		hideMetal(frame)
	end
	if picture then
		art = texture(frame, "frame", "BORDER")
		art:SetAllPoints(frame)
		art:SetTexture(picture)
		art:Show()
	elseif art then
		art:Hide()
	end

	frame:SetAlpha(attr(node, "opacity") or 1)
	-- Over the frame it stands in, and over its neighbours by its `zLevel`. Always told: a frame from the pool
	-- has the level of its last life.
	frame:SetFrameLevel(node.parentFrame:GetFrameLevel() + 1 + (attr(node, "zLevel") or 0))
	local overflow = attr(node, "overflow")
	frame:SetClipsChildren(overflow == "hidden" or overflow == "scroll")
end

-- Paint a node and everything below it: after a state or a look changed.
-- An `input`'s field: its text's look, how much it takes, and the text its cell holds where that isn't what it
-- shows already (typing wrote the cell: the field is left alone, and the caret with it).
local function paintInput(node)
	local edit = node.edit
	local size = inherited(node, "textSize") or DEFAULT_SIZE
	local family = inherited(node, "textFamily") or "Fonts\\FRIZQT__.TTF"
	if node.fontSize ~= size or node.fontFamily ~= family then
		edit:SetFont(family, size, "")
		node.fontSize, node.fontFamily = size, family
	end
	local color = inherited(node, "textColor") or WHITE
	edit:SetTextColor(color.r, color.g, color.b, color.a)
	edit:SetMaxLetters(attr(node, "maxLength") or 0)
	local disabled = attr(node, "disabled") == true
	edit:EnableMouse(not disabled)
	if disabled then
		edit:ClearFocus()
	end
	local shown = attr(node, "text") or ""
	if edit:GetText() ~= shown then
		edit:SetText(shown)
	end
end

local function paint(node)
	if node.kind == "box" then
		paintBox(node)
		if node.edit then
			paintInput(node)
		end
	elseif node.kind == "text" then
		paintText(node)
	elseif node.kind == "frame" then
		node.takeOver(node)
	end
	local children = node.children
	for i = 1, #children do
		paint(children[i])
	end
end

-- Layout -----------------------------------------------------------------------------------------------------------
-- A node's place is `x`, `y` in the box it stands in (from that box's top left, y down), and its size `w`, `h`.

-- How far a box's metal stands out past its line: top, right, bottom, left, on the sides it draws. The art is the
-- box's own (border-box): a size the box is given is its size at the line and grows by this, and what it places by
-- offsets is placed from the line.
local function reach(node)
	local border = attr(node, "border")
	if type(border) ~= "table" or not border.art then
		return 0, 0, 0, 0
	end
	local out, k = border.reach, border.scale
	return drawn(border, "top") and out.top * k or 0, drawn(border, "right") and out.right * k or 0,
		drawn(border, "bottom") and out.bottom * k or 0, drawn(border, "left") and out.left * k or 0
end

-- The width and the height a box is given, with what its metal adds; anything but a number as it is.
local function givenWidth(node)
	local width = attr(node, "width")
	if type(width) == "number" then
		local _, right, _, left = reach(node)
		return width + right + left
	end
	return width
end

local function givenHeight(node)
	local height = attr(node, "height")
	if type(height) == "number" then
		local top, _, bottom = reach(node)
		return height + top + bottom
	end
	return height
end

-- The space a box keeps round its content: its padding, and its border: a line's width, or a metal's line and the
-- art past it.
local function insets(node)
	local top, right, bottom, left = 0, 0, 0, 0
	local padding = attr(node, "padding")
	if type(padding) == "number" then
		top, right, bottom, left = padding, padding, padding, padding
	elseif padding then
		top, right, bottom, left = padding.top or 0, padding.right or 0, padding.bottom or 0, padding.left or 0
	end
	local border = attr(node, "border")
	if type(border) == "table" and border.art then
		local rt, rr, rb, rl = reach(node)
		local width = border.width
		top, right = top + (drawn(border, "top") and width + rt or 0), right + (drawn(border, "right") and width + rr or 0)
		bottom, left = bottom + (drawn(border, "bottom") and width + rb or 0), left + (drawn(border, "left") and width + rl or 0)
	elseif type(border) == "table" then
		local width = border.width
		if border.sides then
			for i = 1, #border.sides do
				local side = border.sides[i]
				if side == "top" then
					top = top + width
				elseif side == "right" then
					right = right + width
				elseif side == "bottom" then
					bottom = bottom + width
				else
					left = left + width
				end
			end
		else
			top, right, bottom, left = top + width, right + width, bottom + width, left + width
		end
	end
	return top, right, bottom, left
end

local function gaps(node)
	local gap = attr(node, "gap")
	if type(gap) == "table" then
		return gap.columns or 0, gap.rows or 0
	end
	return gap or 0, gap or 0
end

-- The children a box lays out in its grid, in order: what stands in a group counts as the box's own, rows in the
-- order the host was told; what is placed by offsets or isn't shown stands apart.
local function gather(node, flow, placed)
	local children = node.children
	for i = 1, #children do
		local child = children[i]
		if child.kind == "group" then
			gather(child, flow, placed)
		elseif child.kind == "frame" or child.surface then
			-- A frame taken over stays where the game keeps it, and a surface stands on the screen: neither has a
			-- place in this box.
			child.x = nil
		elseif attr(child, "shown") == false then
			child.w, child.h = 0, 0
		elseif (child.kind == "box" or child.kind == "embed") and attr(child, "position") == "absolute" then
			placed[#placed + 1] = child
		else
			flow[#flow + 1] = child
		end
	end
end

-- A box's columns: the list it gives, that many equal shares for a number, one share for none.
local ONE_SHARE = { fr = 1 }
local SINGLE = { ONE_SHARE }
local equal = {} -- by count: the list of that many shares, made once

local function tracks(node)
	local columns = attr(node, "columns")
	if type(columns) == "number" then
		local list = equal[columns]
		if not list then
			list = {}
			for i = 1, columns do
				list[i] = ONE_SHARE
			end
			equal[columns] = list
		end
		return list
	end
	return columns or SINGLE
end

local arrange -- below

-- The width a node needs so that nothing in it wraps or is cut.
local function natural(node, narrow)
	if node.kind == "text" then
		-- In a box as narrow as it can be, a text that wraps asks for no width of its own.
		if narrow and attr(node, "wrap") ~= false then
			return 0
		end
		return node.fs:GetUnboundedStringWidth()
	end
	if node.kind == "embed" then
		local width = attr(node, "width")
		return type(width) == "number" and width or 0
	end
	local width = givenWidth(node)
	if type(width) == "number" then
		return width
	end
	narrow = narrow or width == "min"
	local _, right, _, left = insets(node)
	local flow, placed = {}, {}
	gather(node, flow, placed)
	local columns = tracks(node)
	local n = #columns
	local columnGap = gaps(node)
	local least = attr(node, "minWidth")
	if least then
		-- At its metal's line, like a width it is given.
		local _, reachRight, _, reachLeft = reach(node)
		least = least + reachRight + reachLeft
	end
	local total = left + right + columnGap * (n - 1)
	for c = 1, n do
		local track = columns[c]
		if type(track) == "number" then
			total = total + track
		else
			local widest = 0
			for i = c, #flow, n do
				widest = max(widest, natural(flow[i], narrow))
			end
			total = total + widest
		end
	end
	return least and max(least, total) or total
end

local function aligned(align, room, size)
	if align == "center" then
		return (room - size) / 2
	elseif align == "end" then
		return room - size
	end
	return 0
end

-- Lay a node out at `width` (nil: as narrow as its content) and give its height.
function arrange(node, width, heightGiven)
	if node.kind == "text" then
		local fs = node.fs
		local line = fs:GetUnboundedStringWidth()
		-- A text that doesn't wrap keeps its one line, however narrow its place.
		if not width or (attr(node, "wrap") == false and line > width) then
			width = line
		end
		fs:SetWidth(width)
		node.w, node.h = width, fs:GetStringHeight()
		return node.h
	end
	if node.kind == "embed" then
		-- A frame of the game's: the size it is given, or its cell's.
		local own = attr(node, "width")
		node.w = type(own) == "number" and own or width or 0
		node.h = attr(node, "height") or heightGiven or 0
		return node.h
	end

	local top, right, bottom, left = insets(node)
	local flow, placed = {}, {}
	gather(node, flow, placed)
	local columns = tracks(node)
	local n = #columns
	local columnGap, rowGap = gaps(node)

	-- The columns: fixed ones, then those as wide as their content, then shares of what is left.
	local widths, shares, used = {}, 0, columnGap * (n - 1)
	for c = 1, n do
		local track = columns[c]
		if type(track) == "number" then
			widths[c] = track
		elseif type(track) == "table" and track.percent then
			widths[c] = width and (width - left - right) * track.percent / 100 or 0
		elseif type(track) == "table" and track.fr and width then
			shares = shares + track.fr
			widths[c] = false
		else
			local widest = 0
			for i = c, #flow, n do
				widest = max(widest, natural(flow[i]))
			end
			widths[c] = widest
		end
		used = used + (widths[c] or 0)
	end
	if width then
		local rest = max(0, width - left - right - used)
		-- Among several columns a share is never narrower than what stands in it: one that would be keeps its
		-- content's width, and the others share what is left. (A box of one column has nothing to give way.)
		if n > 1 and shares > 0 then
			local again = true
			while again do
				again = false
				for c = 1, n do
					if widths[c] == false then
						local need = 0
						for i = c, #flow, n do
							need = max(need, natural(flow[i]))
						end
						if need > rest * columns[c].fr / shares then
							widths[c] = need
							rest = max(0, rest - need)
							shares = shares - columns[c].fr
							again = true
						end
					end
				end
			end
		end
		for c = 1, n do
			if widths[c] == false then
				widths[c] = rest * columns[c].fr / shares
			end
		end
	else
		width = used + left + right
	end

	-- The rows: each child laid out at its cell's width, a row as high as its highest child.
	local xAlign, yAlign = attr(node, "xAlign") or "stretch", attr(node, "yAlign") or "start"
	local rows = attr(node, "rows")
	local heights = {}
	for i = 1, #flow do
		local child = flow[i]
		local c = (i - 1) % n + 1
		local r = (i - 1 - (c - 1)) / n + 1
		local cell = widths[c]
		local own = child.kind == "box" and givenWidth(child) or nil
		local childWidth
		if type(own) == "number" then
			childWidth = own
		elseif type(own) == "table" and own.percent then
			childWidth = cell * own.percent / 100
		elseif xAlign == "stretch" then
			childWidth = cell
		else
			childWidth = min(cell, natural(child))
		end
		local childHeight = arrange(child, childWidth)
		child.cell, child.row = c, r
		heights[r] = max(heights[r] or 0, childHeight)
	end
	local given = givenHeight(node)
	if type(given) ~= "number" then
		given = heightGiven
	end
	if type(rows) == "table" then
		local rowShares, fixed = 0, rowGap * (max(#rows, #heights) - 1)
		for r = 1, #rows do
			local track = rows[r]
			if type(track) == "number" then
				heights[r] = track
			elseif type(track) == "table" and track.fr and given then
				rowShares = rowShares + track.fr
				heights[r] = 0
			end
			fixed = fixed + (heights[r] or 0)
		end
		for r = #rows + 1, #heights do
			fixed = fixed + heights[r]
		end
		-- The rows that share what is left of a box whose height is known; a box in one is as high as its row.
		if rowShares > 0 then
			local rest = max(0, given - top - bottom - fixed)
			for r = 1, #rows do
				local track = rows[r]
				if type(track) == "table" and track.fr then
					heights[r] = rest * track.fr / rowShares
				end
			end
			for i = 1, #flow do
				local child = flow[i]
				local track = rows[child.row]
				if child.kind == "box" and type(track) == "table" and track.fr and type(attr(child, "height")) ~= "number" then
					arrange(child, child.w, heights[child.row])
				end
			end
		end
	end

	local content = 0
	for r = 1, #heights do
		content = content + heights[r] + (r > 1 and rowGap or 0)
	end
	local height = givenHeight(node)
	if type(height) ~= "number" then
		height = heightGiven or (content + top + bottom)
	end
	node.w, node.h = width, height
	-- How high its content is, for a box that scrolls.
	node.content = content + top + bottom

	-- Where each child stands: its cell's corner, moved by the box's alignment.
	local x, column = left, {}
	-- Columns that don't fill a box wider than them stand, together, where its alignment says.
	if xAlign == "center" or xAlign == "end" then
		local across = columnGap * (n - 1)
		for c = 1, n do
			across = across + widths[c]
		end
		x = x + max(0, aligned(xAlign, width - left - right, across))
	end
	for c = 1, n do
		column[c] = x
		x = x + widths[c] + columnGap
	end
	-- Rows that don't fill a box of a given height stand, together, where its alignment says.
	local y, row = top, {}
	if yAlign == "center" or yAlign == "end" then
		y = y + max(0, aligned(yAlign, height - top - bottom, content))
	end
	for r = 1, #heights do
		row[r] = y
		y = y + heights[r] + rowGap
	end
	for i = 1, #flow do
		local child = flow[i]
		child.x = column[child.cell] + aligned(xAlign, widths[child.cell], child.w)
		if yAlign == "stretch" and child.kind == "box" and type(attr(child, "height")) ~= "number" then
			child.h = heights[child.row]
		end
		child.y = row[child.row] + aligned(yAlign, heights[child.row], child.h)
	end

	-- What is placed by offsets: from the box's own edges, or from its metal's line, out of the grid.
	local lineTop, lineRight, lineBottom, lineLeft = reach(node)
	for i = 1, #placed do
		local child = placed[i]
		local l, t, r, b = attr(child, "left"), attr(child, "top"), attr(child, "right"), attr(child, "bottom")
		local own, ownHeight = child.kind == "box" and givenWidth(child) or attr(child, "width"), attr(child, "height")
		local childWidth
		if type(own) == "number" then
			childWidth = own
		elseif type(own) == "table" and own.percent then
			childWidth = max(0, width - lineLeft - lineRight) * own.percent / 100
		elseif l and r then
			-- In a box too small for its offsets it has no size, never less than none.
			childWidth = max(0, width - lineLeft - lineRight - l - r)
		end
		local given
		if type(ownHeight) ~= "number" and t and b then
			given = max(0, height - lineTop - lineBottom - t - b)
		end
		arrange(child, childWidth, given)
		child.x = l and lineLeft + l or (r and width - lineRight - r - child.w) or lineLeft
		child.y = t and lineTop + t or (b and height - lineBottom - b - child.h) or lineTop
	end
	return height
end

-- A frame of the game's that an `embed` held goes back to where it was.
local function giveBack(node)
	local frame, was = node.embedded, node.was
	if frame and was then
		frame:SetParent(was.parent)
		frame:ClearAllPoints()
		for i = 1, #was.points do
			local point = was.points[i]
			frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
		end
		frame:SetSize(was.width, was.height)
		frame:SetAlpha(was.alpha)
	end
	node.embedded, node.was = nil, nil
end

-- A taken-over frame sent off the screen goes back to where it stood.
local function giveBackPlace(frame, was)
	local points = was.points
	if points then
		frame:ClearAllPoints()
		for i = 1, #points do
			local point = points[i]
			frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
		end
		was.points = nil
	end
end

-- A frame of the game's changed where the game keeps it (`frame`): shown or hidden, its opacity. What it was is
-- kept, and given back when the element goes or names another frame.
local function takeOver(node)
	local frame = attr(node, "of")
	if node.taken ~= frame then
		local old, was = node.taken, node.takenWas
		if old and was then
			old:SetShown(was.shown)
			old:SetAlpha(was.alpha)
			giveBackPlace(old, was)
		end
		node.taken = frame
		node.takenWas = frame and { shown = frame:IsShown(), alpha = frame:GetAlpha() } or nil
	end
	if frame then
		local shown, opacity = attr(node, "shown"), attr(node, "opacity")
		if shown ~= nil then
			frame:SetShown(shown)
		end
		if opacity ~= nil then
			frame:SetAlpha(opacity)
		end
		-- Off the screen, where it takes no click; where it stood is kept to give back.
		local was = node.takenWas
		local away = attr(node, "away") == true
		if away and not was.points then
			was.points = {}
			for i = 1, frame:GetNumPoints() do
				was.points[i] = { frame:GetPoint(i) }
			end
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 0)
		elseif not away then
			giveBackPlace(frame, was)
		end
	end
end

-- Put every frame and font string where the layout says.
local function place(node, parentFrame, offsetX, offsetY)
	if node.kind == "group" then
		-- A group has no box of its own: its children stand in its parent's.
		local children = node.children
		for i = 1, #children do
			place(children[i], parentFrame, offsetX, offsetY)
		end
		return
	end
	if node.x == nil then
		return
	end
	local x, y = offsetX + node.x, offsetY + node.y
	if node.kind == "embed" then
		-- The game's frame goes into our layout: its parent, one point and its size are ours while it is drawn,
		-- and what they were is kept to give back.
		local frame = attr(node, "frame")
		if node.embedded ~= frame then
			giveBack(node)
			node.embedded = frame
			if frame then
				node.was = { parent = frame:GetParent(), points = {}, width = frame:GetWidth(), height = frame:GetHeight(), alpha = frame:GetAlpha() }
				for i = 1, frame:GetNumPoints() do
					node.was.points[i] = { frame:GetPoint(i) }
				end
			end
		end
		if frame then
			frame:SetParent(parentFrame)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, -y)
			frame:SetSize(max(node.w, 0), max(node.h, 0))
			frame:SetAlpha(attr(node, "opacity") or 1)
		end
		return
	end
	if node.kind == "text" then
		local fs = node.fs
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, -y)
		fs:SetWidth(node.w)
		fs:SetShown(attr(node, "shown") ~= false)
		return
	end
	local frame = node.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, -y)
	frame:SetSize(max(node.w, 0), max(node.h, 0))
	frame:SetShown(attr(node, "shown") ~= false)
	if node.edit then
		-- The field fills the box inside its border and its padding.
		local top, right, bottom, left = insets(node)
		local edit = node.edit
		edit:ClearAllPoints()
		edit:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
		edit:SetSize(max(node.w - left - right, 0), max(node.h - top - bottom, 0))
	end
	-- A box that scrolls shows its content from `scroll` down, never past its end.
	local up = 0
	if attr(node, "overflow") == "scroll" then
		up = max(0, min(node.scroll or 0, node.content - node.h))
		node.scroll = up
	end
	local children = node.children
	for i = 1, #children do
		place(children[i], frame, 0, -up)
	end
end

-- Input ------------------------------------------------------------------------------------------------------------
-- A box takes the mouse when something listens to it or one of its attributes follows its state. Its state is
-- "hover" under the cursor and "pressed" while held; an element with `stateFromParent` is in its parent's.

local click, drag = {}, {} -- what the events carry: one table each, filled for every firing

-- The cursor in UI units from the screen's bottom left (the game gives it in pixels).
local function cursor()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	return x / scale, y / scale
end

local function cursorIn(frame)
	local x, y = cursor()
	return x - frame:GetLeft(), frame:GetTop() - y
end

local function fire(node, event, payload)
	local listener = node.listeners and node.listeners[event]
	if listener then
		listener.fn(listener.obj, payload)
	end
end

local function setState(node, state)
	if node.state ~= state then
		node.state = state
		dirty = true
		node.repaint = true
	end
end

local watch

local function onEnter(frame)
	local node = frame.node
	if frame.within then
		-- Back from something inside it: it never left.
		frame.within = nil
		watch(frame)
		return
	end
	node.hovered = true
	if not node.held then
		setState(node, "hover")
	end
	local cursor = attr(node, "cursor")
	if cursor then
		SetCursor(cursor)
	end
	fire(node, "enter")
end

local function reallyLeft(frame)
	local node = frame.node
	node.hovered = false
	if not node.held then
		setState(node, nil)
	end
	if attr(node, "cursor") then
		ResetCursor()
	end
	fire(node, "leave")
end

-- A frame's one `OnUpdate` serves both things that need a look every frame: a drag in hand, and a box that counts
-- as under the cursor while the cursor is anywhere over it (`hoverWithin`), its children included.
local onFrameUpdate

function watch(frame)
	frame:SetScript("OnUpdate", (frame.dragging or frame.within) and onFrameUpdate or nil)
end

local function onLeave(frame)
	local node = frame.node
	if attr(node, "hoverWithin") then
		-- The cursor may have gone onto something inside the box: it has left only once it is outside the box.
		local x, y = cursorIn(frame)
		if x >= 0 and y >= 0 and x <= frame:GetWidth() and y <= frame:GetHeight() then
			frame.within = true
			watch(frame)
			return
		end
	end
	reallyLeft(frame)
end

local function onMouseDown(frame)
	local node = frame.node
	node.held = true
	setState(node, "pressed")
end

local function onMouseUp(frame)
	local node = frame.node
	node.held = false
	setState(node, node.hovered and "hover" or nil)
end

local function onClick(frame, button)
	click.button = button
	click.x, click.y = cursorIn(frame)
	fire(frame.node, "click", click)
end

-- While a box is dragged its `drag` fires at most once a frame, and only when the cursor moved.
function onFrameUpdate(frame)
	local x, y = cursorIn(frame)
	if frame.dragging then
		-- By the cursor on the screen: a box that follows the cursor keeps it at the same place in itself.
		local screenX, screenY = cursor()
		if screenX ~= frame.dragX or screenY ~= frame.dragY then
			frame.dragX, frame.dragY = screenX, screenY
			drag.x, drag.y = x, y
			drag.dx, drag.dy = screenX - frame.grabX, frame.grabY - screenY
			fire(frame.node, "drag", drag)
		end
	end
	if frame.within and (x < 0 or y < 0 or x > frame:GetWidth() or y > frame:GetHeight()) then
		frame.within = nil
		watch(frame)
		reallyLeft(frame)
	end
end

local function onDragStart(frame)
	drag.x, drag.y = cursorIn(frame)
	drag.dx, drag.dy = 0, 0
	frame.grabX, frame.grabY = cursor()
	frame.dragX, frame.dragY = frame.grabX, frame.grabY
	fire(frame.node, "dragStart", drag)
	frame.dragging = true
	watch(frame)
end

-- The boxes that take what is let go over them.
local dropTargets = setmetatable({}, { __mode = "k" })

-- The box a drag ends over: the smallest of those that listen for it and hold the cursor.
local function dropTarget()
	local best, bestArea
	for node in pairs(dropTargets) do
		local frame = node.frame
		if frame and frame.node == node and frame:IsVisible() and node.listeners and node.listeners.drop then
			local x, y = cursorIn(frame)
			local w, h = frame:GetWidth(), frame:GetHeight()
			if x >= 0 and y >= 0 and x <= w and y <= h and (not best or w * h < bestArea) then
				best, bestArea = node, w * h
			end
		end
	end
	return best
end

local function onDragStop(frame)
	frame.dragging = nil
	watch(frame)
	-- Whoever takes it hears first: the dragged box forgets what it carried when it hears it was let go.
	local target = dropTarget()
	if target then
		fire(target, "drop")
	end
	fire(frame.node, "dragStop")
end

-- What is typed into an `input` is told to whoever listens: the runtime writes it to the field's cell. What the
-- host itself put there (the cell's text) isn't typing.
local function onTyped(edit, byPlayer)
	if byPlayer then
		fire(edit.node, "change", edit:GetText())
	end
end

local function onLeaveField(edit)
	edit:ClearFocus()
end

-- A box that scrolls follows the wheel: a notch is three lines of text.
local NOTCH = 36

local function onWheel(frame, delta)
	local node = frame.node
	local to = max(0, min((node.scroll or 0) - delta * NOTCH, node.content - node.h))
	if to ~= node.scroll then
		node.scroll = to
		dirty = true
	end
end

-- A surface that listens to `escape` hears the keys: Escape is its own, every other goes on to the game.
local function onKeyDown(frame, key)
	if key == "ESCAPE" then
		frame:SetPropagateKeyboardInput(false)
		fire(frame.node, "escape")
	else
		frame:SetPropagateKeyboardInput(true)
	end
end

local function takeMouse(node)
	if node.mouse then
		return
	end
	node.mouse = true
	local frame = node.frame
	frame.node = node
	frame:EnableMouse(true)
	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnEnter", onEnter)
	frame:SetScript("OnLeave", onLeave)
	frame:SetScript("OnMouseDown", onMouseDown)
	frame:SetScript("OnMouseUp", onMouseUp)
	frame:SetScript("OnClick", onClick)
end

local LAYERS = { screen = "MEDIUM", dialog = "DIALOG", tooltip = "TOOLTIP" }

-- A box that listens to `clickOutside` stands over a frame as large as the screen, raised over everything else:
-- a click that isn't on the box lands there.
local function onOutside(frame)
	fire(frame.node, "clickOutside")
end

local function catch(node)
	local frame = takeFrame(UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("FULLSCREEN")
	frame.node = node
	frame:EnableMouse(true)
	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnClick", onOutside)
	node.catcher = frame
end

local function uncatch(node)
	giveFrame(node.catcher)
	node.catcher = nil
end

local function dropMouse(node)
	if not node.mouse then
		return
	end
	node.mouse = nil
	-- What gave the cursor its look goes from under it.
	if node.hovered and attr(node, "cursor") then
		ResetCursor()
	end
	node.hovered, node.held, node.state = nil, nil, nil
	node.repaint = true
	local frame = node.frame
	frame:EnableMouse(false)
	frame.within = nil
	watch(frame)
end

-- Whose state each node is in and which boxes take the mouse, worked out from the attributes and listeners as they
-- stand: the order they were set in never matters. A node with `stateFromParent` is in the state of the nearest box
-- above it, which may follow its own parent in turn; a box takes the mouse when something listens to it, when it
-- counts the cursor inside it (`hoverWithin`), when one of its own values follows its state, or when another node
-- follows it.
local function wire(node, box, strata)
	local kind = node.kind
	if kind == "box" then
		node.followers = nil
		if node.root then
			strata = node.frame:GetFrameStrata()
		else
			local outside = node.listeners and node.listeners.clickOutside
			if outside and not node.catcher then
				catch(node)
			elseif node.catcher and not outside then
				uncatch(node)
			end
			-- Which of the screen's layers its frame stands on: its surface's, or over the frame that catches the
			-- clicks outside it. A frame may keep the layer it was last given, whatever it stands in since, so
			-- every box is told its own.
			if node.catcher then
				strata = "FULLSCREEN_DIALOG"
			elseif node.surface and strata ~= "FULLSCREEN_DIALOG" then
				strata = LAYERS[attr(node, "layer") or "dialog"]
			end
			if node.strata ~= strata then
				node.strata = strata
				node.frame:SetFrameStrata(strata)
			end
			local scrolls = attr(node, "overflow") == "scroll"
			if scrolls ~= (node.wheel or false) then
				node.wheel = scrolls
				local frame = node.frame
				frame.node = node
				frame:EnableMouseWheel(scrolls)
				frame:SetScript("OnMouseWheel", scrolls and onWheel or nil)
			end
		end
	end
	if kind == "box" or kind == "text" then
		if box and not node.root and attr(node, "stateFromParent") then
			local source = box.stateOf
			node.stateOf = source
			local followers = source.followers
			if not followers then
				followers = {}
				source.followers = followers
			end
			followers[#followers + 1] = node
		else
			node.stateOf = node
		end
	end
	local children = node.children
	local inner = kind == "box" and node or box
	for i = 1, #children do
		wire(children[i], inner, strata)
	end
	if kind == "box" and not node.root then
		local own = node.stateOf == node
		if node.listeners or attr(node, "hoverWithin") or attr(node, "cursor") or node.followers
			or (own and ((node.stated or 0) > 0 or (node.styleStated or 0) > 0)) then
			takeMouse(node)
		else
			dropMouse(node)
		end
	end
end

-- The host ---------------------------------------------------------------------------------------------------------

local host = {}

-- The frame of the nearest box above a node: where its own frame, or its text, lives.
local function frameAbove(node)
	local up = node
	while up do
		if up.frame then
			return up.frame
		end
		up = up.parent
	end
end

function host.create(kind, parent)
	local node = { kind = kind, parent = parent, children = {}, attrs = {} }
	node.stateOf = node
	if kind == "frame" then
		node.takeOver = takeOver
	end
	parent.children[#parent.children + 1] = node
	rewire = true
	local above = frameAbove(parent)
	if kind == "surface" then
		-- A box in everything but where it stands.
		node.kind, node.surface = "box", true
		above = UIParent
		surfaces[#surfaces + 1] = node
	elseif kind == "input" then
		-- A box with the game's field in it.
		node.kind = "box"
	end
	node.parentFrame = above
	if node.kind == "box" then
		node.frame = takeFrame(above)
		if kind == "input" then
			local edit = takeEdit(node.frame)
			edit.node = node
			edit:SetScript("OnTextChanged", onTyped)
			edit:SetScript("OnEscapePressed", onLeaveField)
			edit:SetScript("OnEnterPressed", onLeaveField)
			node.edit = edit
		end
	elseif kind == "text" then
		node.fs = fontString(above)
		node.fs:SetFont("Fonts\\FRIZQT__.TTF", DEFAULT_SIZE, "")
		node.fontSize, node.fontFamily = DEFAULT_SIZE, "Fonts\\FRIZQT__.TTF"
	end
	dirty = true
	return node
end

local function follows(value)
	return type(value) == "table" and value.default ~= nil
end

-- An attribute is only kept here. What it means for the node's state and the mouse is worked out in `flush`.
function host.set(node, name, value)
	local attrs = node.attrs
	local was = attrs[name]
	attrs[name] = value
	if name == "style" then
		local count = 0
		if value then
			for _, entry in pairs(value) do
				if follows(entry) then
					count = count + 1
				end
			end
		end
		node.styleStated = count
		rewire = true
	elseif name == "stateFromParent" or name == "hoverWithin" or name == "layer" or name == "overflow" then
		rewire = true
	elseif follows(was) ~= follows(value) then
		node.stated = (node.stated or 0) + (follows(value) and 1 or -1)
		rewire = true
	end
	node.repaint = true
	dirty = true
end

function host.on(node, event, obj, fn)
	local listeners = node.listeners
	if not listeners then
		listeners = {}
		node.listeners = listeners
	end
	listeners[event] = { obj = obj, fn = fn }
	if event == "change" then
		-- The field's own: the box around it takes no mouse for it.
		return
	end
	rewire, dirty = true, true
	if event == "escape" then
		local frame = node.frame
		frame.node = node
		frame:EnableKeyboard(true)
		frame:SetScript("OnKeyDown", onKeyDown)
	end
	if event == "drop" then
		dropTargets[node] = true
	end
	if event == "drag" or event == "dragStart" or event == "dragStop" then
		local frame = node.frame
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", onDragStart)
		frame:SetScript("OnDragStop", onDragStop)
	end
end

function host.order(node, index)
	node.index = index
	-- Rows stand in their group in the order given.
	local siblings = node.parent.children
	local at
	for i = 1, #siblings do
		if siblings[i] == node then
			at = i
			break
		end
	end
	if at and at ~= index and index <= #siblings then
		table.remove(siblings, at)
		table.insert(siblings, index, node)
	end
	dirty = true
end

local function release(node)
	local children = node.children
	for i = #children, 1, -1 do
		release(children[i])
		children[i] = nil
	end
	if node.catcher then
		uncatch(node)
	end
	if portraits[node] then
		portray(node, nil)
	end
	if node.hovered and attr(node, "cursor") then
		ResetCursor()
	end
	if node.surface then
		for i = #surfaces, 1, -1 do
			if surfaces[i] == node then
				table.remove(surfaces, i)
				break
			end
		end
		local frame = node.frame
		frame:EnableKeyboard(false)
		frame:SetToplevel(false)
		frame:SetClampedToScreen(false)
	end
	if node.edit then
		giveEdit(node.edit)
		node.edit = nil
	end
	if node.kind == "embed" then
		giveBack(node)
	elseif node.kind == "frame" and node.taken then
		-- Back to what it was when it was taken.
		node.attrs = {}
		local frame, was = node.taken, node.takenWas
		frame:SetShown(was.shown)
		frame:SetAlpha(was.alpha)
		giveBackPlace(frame, was)
		node.taken, node.takenWas = nil, nil
	end
	if node.fs then
		giveFontString(node.parentFrame, node.fs)
		node.fs = nil
	elseif node.frame and not node.root then
		giveFrame(node.frame)
		node.frame = nil
	end
end

function host.remove(node)
	if node.root then
		for i = #roots, 1, -1 do
			if roots[i] == node then
				table.remove(roots, i)
			end
		end
	end
	local parent = node.parent
	if parent then
		local siblings = parent.children
		for i = #siblings, 1, -1 do
			if siblings[i] == node then
				table.remove(siblings, i)
				break
			end
		end
	end
	release(node)
	rewire, dirty = true, true
end

-- Repaint the nodes whose look changed, and whatever follows their state.
local function repaintMarked(node)
	if node.repaint then
		node.repaint = nil
		paint(node)
		local followers = node.followers
		if followers then
			for i = 1, #followers do
				paint(followers[i])
			end
		end
	end
	local children = node.children
	for i = 1, #children do
		repaintMarked(children[i])
	end
end

-- Lay a surface out and stand it on the screen: over all of it, or as large as it says or its content needs, at
-- the point it names.
local CENTER = { point = "CENTER" }
local DOCK = { top = "TOP", right = "RIGHT", bottom = "BOTTOM", left = "LEFT" }

local function settle(node)
	local frame = node.frame
	local shown = attr(node, "shown") ~= false
	frame:SetShown(shown)
	if not shown then
		return
	end
	frame:SetToplevel(attr(node, "raise") == true)
	frame:SetClampedToScreen(attr(node, "clamp") == true)
	frame:ClearAllPoints()
	local spot = attr(node, "place") or CENTER
	if spot == "fill" then
		arrange(node, UIParent:GetWidth(), UIParent:GetHeight())
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	elseif spot.side then
		-- Along a side of the screen: across it, or as long as its content in the side's middle. Its other
		-- measure is the one it is given.
		local side = spot.side
		if side == "top" or side == "bottom" then
			arrange(node, spot.whole and UIParent:GetWidth() or nil)
		else
			local width = givenWidth(node)
			arrange(node, type(width) == "number" and width or nil, spot.whole and UIParent:GetHeight() or nil)
		end
		local point = DOCK[side]
		frame:SetPoint(point, UIParent, point, 0, 0)
	elseif spot.beside then
		-- Beside what it explains: under it, or over it in the screen's lower half; on its left edge, or on its
		-- right edge in the screen's right third.
		local width = givenWidth(node)
		arrange(node, type(width) == "number" and width or nil)
		local by = spot.beside
		if by == "parent" then
			by = frameAbove(node.parent)
		end
		local x, y = by:GetCenter()
		local scale = by:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local side = (x and x * scale > UIParent:GetWidth() * 2 / 3) and "RIGHT" or "LEFT"
		local below = not y or y * scale > UIParent:GetHeight() / 2
		frame:SetPoint((below and "TOP" or "BOTTOM") .. side, by, (below and "BOTTOM" or "TOP") .. side, 0, 0)
	else
		local width = givenWidth(node)
		arrange(node, type(width) == "number" and width or nil)
		frame:SetPoint(spot.point, spot.by or UIParent, spot.to or spot.point, spot.x or 0, -(spot.y or 0))
	end
	frame:SetSize(max(node.w, 0), max(node.h, 0))
	local children = node.children
	for i = 1, #children do
		place(children[i], frame, 0, 0)
	end
end

function host.flush()
	if not dirty then
		return
	end
	dirty = false
	if rewire then
		rewire = false
		for i = 1, #roots do
			wire(roots[i], nil, false)
		end
	end
	for i = 1, #roots do
		local root = roots[i]
		repaintMarked(root)
		-- A root is as large as the frame it draws into, and lays its children out like a box.
		local frame = root.frame
		arrange(root, frame:GetWidth(), frame:GetHeight())
		local children = root.children
		for c = 1, #children do
			place(children[c], frame, 0, 0)
		end
	end
	for i = 1, #surfaces do
		settle(surfaces[i])
	end
end

-- Every node below `node` with its place on the screen, for tests: `visit(node, left, top)`, a group's children as
-- its parent's.
function Wow.walk(node, visit, left, top)
	left, top = left or 0, top or 0
	local children = node.children
	for i = 1, #children do
		local child = children[i]
		if child.kind == "group" then
			Wow.walk(child, visit, left, top)
		elseif child.x then
			visit(child, left + child.x, top + child.y)
			if child.kind == "box" then
				Wow.walk(child, visit, left + child.x, top + child.y)
			end
		end
	end
end

-- What a box keeps round its content, for tests.
Wow.insets = insets
-- How far a box that scrolls is scrolled, and how far it can be, for tests.
function Wow.scrolled(node)
	return node.scroll or 0, max(0, (node.content or 0) - (node.h or 0))
end
-- The boxes that stand on the screen, for tests.
function Wow.surfaces()
	return surfaces
end
Wow.attr = attr

-- For the dev addon's inspector (`LunaType.dev`): the box a frame is, the deepest box or text under a point, a
-- line for one and all that is known of one. A point is in the frame's own units, from the screen's bottom left.
local function regionOf(node)
	return node.frame or node.fs
end

local function holds(node, x, y)
	local region = regionOf(node)
	if not region or not region:IsVisible() then
		return false
	end
	local left, bottom, width, height = region:GetLeft(), region:GetBottom(), region:GetWidth(), region:GetHeight()
	return left ~= nil and x >= left and x <= left + width and y >= bottom and y <= bottom + height
end

local function nodeAt(node, x, y)
	local children = node.children
	for i = #children, 1, -1 do
		local child = children[i]
		if child.kind == "group" then
			-- A group owns nothing: what stands in it is looked at in its place.
			local found = nodeAt(child, x, y)
			if found ~= child then
				return found
			end
		elseif holds(child, x, y) then
			return nodeAt(child, x, y)
		end
	end
	return node
end

local function shown(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for key, inner in pairs(value) do
		parts[#parts + 1] = tostring(key) .. ":" .. shown(inner)
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

local function labelOf(node)
	local what = node.kind
	if node.kind == "text" and node.fs then
		what = what .. " " .. string.format("%q", tostring(node.fs:GetText()))
	end
	return string.format("%s %.0fx%.0f", what, node.w or 0, node.h or 0)
end

R.dev = {
	_NodeOf = function(frame)
		return frame.node
	end,
	_NodeAt = nodeAt,
	_Label = labelOf,
	_InspectNode = function(node)
		local out = { kind = node.kind }
		local attributes = {}
		for name, value in pairs(node.attrs or {}) do
			attributes[#attributes + 1] = name .. "=" .. shown(value)
		end
		table.sort(attributes)
		out.attributes = table.concat(attributes, " ")
		out.layout = string.format("x=%s y=%s w=%s h=%s", tostring(node.x), tostring(node.y), tostring(node.w),
			tostring(node.h))
		local region = regionOf(node)
		if region then
			local width, height = region:GetWidth(), region:GetHeight()
			out.frame = string.format("%.1fx%.1f shown=%s visible=%s alpha=%.2f", width, height,
				tostring(region:IsShown()), tostring(region:IsVisible()), region:GetAlpha())
			-- The real size against the layout's: any difference is a fault in the layout.
			if node.w and node.h and (math.abs(width - node.w) > 0.05 or math.abs(height - node.h) > 0.05) then
				out.mismatch = string.format("drawn %.2fx%.2f, laid out %.2fx%.2f", width, height, node.w, node.h)
			end
		end
		if node.frame then
			out.stack = string.format("%s/%d mouse=%s", node.frame:GetFrameStrata(), node.frame:GetFrameLevel(),
				tostring(node.frame:IsMouseEnabled()))
		end
		out.state = tostring(node.state)
		return out
	end,
}

-- Whether something set since the last flush waits to be laid out or wired.
function Wow.pending()
	return dirty or rewire
end

-- A node to mount a component into: it draws into `frame`, a frame of the game's.
function Wow.root(frame)
	local node = { kind = "box", root = true, children = {}, attrs = {}, frame = frame, parentFrame = frame, x = 0, y = 0 }
	node.stateOf = node
	roots[#roots + 1] = node
	return node
end

-- Make this the host the runtime draws through.
function Wow.install()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:Hide()
	R.setHost(host)
	return host
end

-- Forget every root and everything pooled: for a test that starts the game over.
function Wow.reset()
	roots, surfaces, framePool, nFrames, editPool, nEdits, dirty, rewire = {}, {}, {}, 0, {}, 0, false, false
end

return Wow
