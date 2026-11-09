-- The WoW drawing backend (development/framework/mvp, "Contract: engine and backend"): the engine owns the tree, this
-- file owns everything WoW. Frames and font strings come from pools and go back to them, attributes are applied with
-- only the setters whose value changed, Layout.lua places what changed at the end of each flush, and mouse states
-- (hover, pressed) restyle a box without the engine. Module code runs only through ns.Engine:Handle.
--
-- Costs (performance.md has the measured WoW call prices):
-- - nothing per frame (no OnUpdate, no events; a layer's OnSizeChanged lays it out again);
-- - no tables per Set or Flush once a node exists;
-- - a Set does only the work of the attribute groups that changed;
-- - text is measured only when its text, size or wrapping changes, and laid out only when its size can matter;
-- - release makes no WoW call: a released node keeps its frame where it was and the attributes it last drew, so
--   reusing it changes only what differs; the one Hide is the closed subtree's top node, when its parent drops it;
-- - placing calls SetPoint and SetSize only for what changed.
--
-- The placing rules that make that safe: every node has one anchor point, TOPLEFT, to its parent's frame (UIParent for
-- position "fixed"), and Layout places a parent before its children. A reused node's stale point is replaced before
-- anything is anchored to it, so no two frames ever anchor to each other.
local _, ns = ...

local Layout = ns.Layout
local Theme = ns.Theme

local CreateFrame, UIParent, GetPhysicalScreenSize = CreateFrame, UIParent, GetPhysicalScreenSize
local InCombatLockdown, hooksecurefunc = InCombatLockdown, hooksecurefunc
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local type, rawget, tonumber, unpack = type, rawget, tonumber, unpack
local find = string.find
local createTable, isfrozen = table.create, table.isfrozen

---A node of the tree: what Create, Layer and Take return. Opaque to the engine.
---@class OrdaenNode

---@class OrdaenBackendFrame : Button
---@field node OrdaenBackendNode

---@class OrdaenBackendNode : OrdaenNode
---@field kind "box"|"text"|"root"
---@field a table                     -- the attributes as last drawn (copied)
---@field frame Frame?                -- a box's pooled button, a layer's frame, a taken Blizzard frame
---@field fs FontString?              -- a text node's font string
---@field parent OrdaenBackendNode?
---@field children OrdaenBackendNode[]? -- boxes and roots
---@field count integer?
---@field [string] any               -- layout fields (Layout.lua's header) and caches of what was applied
local Node = {}
local NodeMeta = { __index = Node }

---@class OrdaenBackend
---@field _boxPool OrdaenBackendNode[]   -- for Backend.dev.lua's counts only
---@field _textPool OrdaenBackendNode[]
---@field _layers table<string, OrdaenBackendNode>
local Backend = {}
ns.Backend = Backend

local STRATA = { screen = "MEDIUM", dialog = "DIALOG", tooltip = "TOOLTIP" }
local JUSTIFY = { start = "LEFT", center = "CENTER", ["end"] = "RIGHT" }
local EMPTY = {}
local BLACK = { 0, 0, 0, 1 } -- a text shadow without a colour

-- What each attribute changes: the node's own size, its offsets (where a free node sits, not its size), its
-- content's layout, its border, its look, its text, its mouse handlers.
-- The layout attributes come from Layout.ATTRIBUTES (their groups and the fields they fill); the rest are listed here.
local OWN, CONTENT, LOOK, BORDER, INPUT, TEXT, POSITION, OFFSET = 1, 2, 3, 4, 5, 6, 7, 8
local next = next
local GROUP = {
	background = LOOK, opacity = LOOK, textColor = LOOK, textAlign = LOOK, portrait = LOOK, mask = LOOK, look = LOOK,
	shown = LOOK, textShadow = LOOK, overflow = LOOK,
	OnClick = INPUT, OnEnter = INPUT, OnLeave = INPUT, stateFrom = INPUT, OnChange = INPUT, OnSubmit = INPUT,
	OnWheel = INPUT, OnDragStart = INPUT, OnDrag = INPUT, OnDragStop = INPUT,
	text = TEXT, textSize = TEXT, textFamily = TEXT, wrap = TEXT, kind = TEXT, focus = TEXT, maxLength = TEXT,
}
local LAYOUT_GROUP = { own = OWN, content = CONTENT, position = POSITION, offset = OFFSET, border = BORDER }
local BOX_KEYS, TEXT_KEYS = {}, {}
for _, attribute in ipairs(Layout.ATTRIBUTES) do
	GROUP[attribute.key] = LAYOUT_GROUP[attribute.group]
	BOX_KEYS[#BOX_KEYS + 1] = attribute.key
	if attribute.text then
		TEXT_KEYS[#TEXT_KEYS + 1] = attribute.key
	end
end
for _, key in ipairs({ "background", "opacity", "portrait", "mask", "overflow", "stateFrom", "OnClick", "OnEnter",
	"OnLeave", "OnWheel", "OnDragStart", "OnDrag", "OnDragStop",
	-- an input box (kind = "input"): its text, how it's drawn, its keyboard focus and handlers
	"kind", "text", "textSize", "textFamily", "textColor", "textAlign", "maxLength", "focus", "OnChange", "OnSubmit" }) do
	BOX_KEYS[#BOX_KEYS + 1] = key
end
for _, key in ipairs({ "text", "textSize", "textFamily", "wrap", "textColor", "textShadow", "textAlign", "opacity" }) do
	TEXT_KEYS[#TEXT_KEYS + 1] = key
end
-- a taken Blizzard frame (Backend:Take): where it sits, its opacity, and `shown = false` (hidden while we hold it)
local TAKEN_KEYS = { "position", "top", "right", "bottom", "left", "opacity", "shown" }
-- an embedded Blizzard frame (Backend:Embed): its place and size in the grid, and its opacity; nothing of its look
local EMBED_KEYS = { "width", "height", "columnSpan", "position", "top", "right", "bottom", "left", "opacity", "look" }
-- The same lists as sets, so a Set walks only the keys a table has (usually a few), not every key a kind takes.
local function set(keys)
	local s = {}
	for _, key in ipairs(keys) do
		s[key] = true
	end
	return s
end
local BOX_TAKES, TEXT_TAKES, TAKEN_TAKES = set(BOX_KEYS), set(TEXT_KEYS), set(TAKEN_KEYS)
local EMBED_TAKES = set(EMBED_KEYS)

-- Theme references and per-state maps -------------------------------------------------------------------------

-- A theme reference is the only attribute value with a raw `path` (Define.lua's interned references; ns.IsThemeRef
-- tests the same by metatable): one rawget, no call. rawget also keeps a reference from building paths on index.
local function resolveRef(v)
	if type(v) == "table" then
		local path = rawget(v, "path")
		if path ~= nil then
			return Theme[path]
		end
	end
	return v
end

-- A value as drawn now: the state's entry of a per-state map, then the theme's value of a reference.
local function resolve(node, v)
	if type(v) ~= "table" then
		return v
	end
	local path = rawget(v, "path")
	if path ~= nil then
		return Theme[path]
	end
	local default = rawget(v, "default")
	local hover, pressed = rawget(v, "hover"), rawget(v, "pressed")
	if default == nil and hover == nil and pressed == nil then
		return v -- a plain table value (a border, a column list)
	end
	if node.pressed and pressed ~= nil then
		return resolveRef(pressed)
	elseif node.hovered and hover ~= nil then
		return resolveRef(hover)
	end
	return resolveRef(default)
end

-- "#rrggbb" / "#rrggbbaa" as { r, g, b, a }, parsed once per string.
local hexColors = {}
local function color(v)
	if type(v) == "string" then
		local c = hexColors[v]
		if c == nil then
			c = false
			local hex = v:match("^#(%x+)$")
			if hex and (#hex == 6 or #hex == 8) then
				c = {
					tonumber(hex:sub(1, 2), 16) / 255,
					tonumber(hex:sub(3, 4), 16) / 255,
					tonumber(hex:sub(5, 6), 16) / 255,
					#hex == 8 and tonumber(hex:sub(7, 8), 16) / 255 or 1,
				}
			end
			hexColors[v] = c
		end
		return c or nil
	elseif type(v) == "table" and type(v[1]) == "number" then
		return v
	end
	return nil
end

-- Pixels -------------------------------------------------------------------------------------------------------

local px = 1 -- one screen pixel in UI units (UIParent's)
local ctx = { screenW = 0, screenH = 0 } ---@type OrdaenLayoutContext
local lineHeights = {} -- [font][size]: one line in UI units on whole pixels (one value per font and size, not per text)
-- A frozen attribute table's layout fields, worked out once and copied into every box drawn from it (its column
-- arrays shared, never written). Only for tables without per-state maps (those depend on each node's hover and
-- pressed); false for a table that can't be cached. Weak keys: a module's tables go when it does. Pixel sizes are in
-- the fields, so a new pixel size starts it again.
local styles = setmetatable({}, { __mode = "k" })
-- Which pixel size a node's fields were rounded and measured at: node.gen is the pxGen of its last full Apply. A new
-- pixel size (the UI scale or the resolution changed) rounds again every node in the trees at once (repixelTrees), and
-- any other node (pooled, or not attached yet) at its next Set or attach.
local pxGen = 0
local repixelTrees -- forward: defined with the tree

local function updateScreen()
	local _, physH = GetPhysicalScreenSize()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	ctx.screenW, ctx.screenH = w, h
	local old = px
	px = physH and physH > 0 and h / physH or 1
	if px ~= old then
		for font in pairs(lineHeights) do
			lineHeights[font] = nil
		end
		for t in pairs(styles) do
			styles[t] = nil
		end
		pxGen = pxGen + 1
		if repixelTrees then
			repixelTrees()
		end
	end
end

local function snap(v)
	return floor(v / px + 0.5) * px
end

-- Up to the next whole pixel: text sizes, so lines of one font stack the same number of pixels apart (12 UI units at
-- 0.94 px per unit would land 11 and 12 px apart in turn). The small margin keeps an exact pixel from rounding up.
local function pixelsUp(v)
	return ceil(v / px - 0.001) * px
end

-- The pools, the queues, the layers ---------------------------------------------------------------------------------

local holder ---@type Frame
local boxPool, nBoxPool = {}, 0
local textPool, nTextPool = {}, 0
local queue, nQueue = {}, 0 -- nodes to lay out at Flush
local stale, nStale = {}, 0 -- reused nodes still drawing their previous attributes, until a Set or Flush
local orphans, nOrphans = {}, 0 -- children a reused node held in its previous life: hidden at Flush unless reused
local stamp = 0
local layers = {}
-- boxes with overflow = "scroll": their content's extent is measured again after a layout (weak: a released box goes)
local scrollers = setmetatable({}, { __mode = "k" })
local attach -- forward: Node:ApplyOverflow moves the children
-- Read by Backend.dev.lua (the bench's node counts); the tables themselves, never replaced.
Backend._boxPool, Backend._textPool, Backend._layers = boxPool, textPool, layers
local takenBy = setmetatable({}, { __mode = "k" }) -- Blizzard frame -> the node holding it
local hooked = setmetatable({}, { __mode = "k" })
local hookedEmbed = setmetatable({}, { __mode = "k" }) -- frames whose placing calls are hooked for Embed (once each)
local pendingCombat = {} -- taken nodes whose protected frame waits for combat to end
local embeddedBy = setmetatable({}, { __mode = "k" }) -- Blizzard frame -> the node holding it as a cell
local pendingEmbed = {} -- embedded nodes whose protected frame waits for combat to end
local embedding = false -- our own calls on an embedded frame (its hooks ignore them)
local combatFrame ---@type Frame?

local function enqueue(node)
	if node and not node.queued then
		node.queued = true
		nQueue = nQueue + 1
		queue[nQueue] = node
	end
end

local function getHolder()
	if not holder then
		updateScreen() -- the pixel size, before the first text is measured
		holder = CreateFrame("Frame", nil, UIParent)
		holder:Hide()
	end
	return holder
end

-- A node table sized for the fields it fills (a hash slot is 40 bytes, and a node lives in its pool for good): a
-- text node holds about 30 fields, a box about 60 (it also has a grid: children, padding, gaps, columns); the copy of
-- its attributes, a few keys (a table with more grows once).
local function newNode(kind)
	local node = setmetatable(createTable(0, kind == "text" and 32 or 64), NodeMeta)
	node.kind, node.gen = kind, pxGen
	if kind == "text" then
		node.a, node.na, node.args, node.nargs = createTable(0, 4), 0, {}, 0
	else
		node.a, node.na, node.children, node.count = createTable(0, 8), 0, {}, 0
		node.padT, node.padR, node.padB, node.padL, node.gapR, node.gapC = 0, 0, 0, 0, 0, 0
		node.bwT, node.bwR, node.bwB, node.bwL = 0, 0, 0, 0
		Layout.Columns(node, nil, resolveRef)
	end
	return node
end

-- Input ---------------------------------------------------------------------------------------------------------

local function handle(fn, ...)
	local engine = ns.Engine
	if engine then
		engine:Handle(fn, ...)
	end
end

local function onEnter(frame)
	local node = frame.node
	node:SetState(true, node.pressed)
	local fn = node.a.OnEnter
	if fn then
		handle(fn)
	end
end

local function onLeave(frame)
	local node = frame.node
	node:SetState(false, false)
	local fn = node.a.OnLeave
	if fn then
		handle(fn)
	end
end

local function onMouseDown(frame)
	local node = frame.node
	node:SetState(node.hovered, true)
end

local function onMouseUp(frame)
	local node = frame.node
	node:SetState(node.hovered, false)
end

-- The cursor from a frame's top left in UI units (x right, y down): from where the frame's top left was when a drag
-- began while it lasts, so a box that moves with the drag (a window) still sees the cursor move.
local function cursorIn(frame)
	local x, y = GetCursorPosition()
	local scale = frame:GetEffectiveScale()
	return x / scale - (frame.dragL or frame:GetLeft() or 0), (frame.dragT or frame:GetTop() or 0) - y / scale
end

local function onClick(frame, button)
	local fn = frame.node.a.OnClick
	if fn then
		handle(fn, button, cursorIn(frame))
	end
end

-- Dragging: OnDragStart(x, y), OnDrag(x, y) at most once a frame while the cursor moves, OnDragStop(x, y). The
-- per-frame script runs only during a drag.
local function onDragUpdate(frame)
	local x, y = cursorIn(frame)
	if x ~= frame.dragX or y ~= frame.dragY then
		frame.dragX, frame.dragY = x, y
		local fn = frame.node.a.OnDrag
		if fn then
			handle(fn, x, y)
		end
	end
end

local function onDragStart(frame)
	frame.dragL, frame.dragT = frame:GetLeft(), frame:GetTop()
	local x, y = cursorIn(frame)
	frame.dragX, frame.dragY = x, y
	frame:SetScript("OnUpdate", onDragUpdate)
	local fn = frame.node.a.OnDragStart
	if fn then
		handle(fn, x, y)
	end
end

local function onDragStop(frame)
	frame:SetScript("OnUpdate", nil)
	local x, y = cursorIn(frame)
	frame.dragL, frame.dragT, frame.dragX, frame.dragY = nil, nil, nil, nil
	local fn = frame.node.a.OnDragStop
	if fn then
		handle(fn, x, y)
	end
end

-- Placing (Layout's callback) -------------------------------------------------------------------------------------

-- Only the calls whose values changed: the point (pRel, pX, pY as last set) and the size (pW, pH).
function ctx.place(node)
	local parent = node.parent
	if not parent then
		return
	end
	local x, y = snap(node.x), snap(node.y)
	local obj, rel, w, h
	if node.embedded then
		node.pRel, node.pX, node.pY = parent.inner or parent.frame, x, y
		node.pW, node.pH = max(snap(node.x + node.w) - x, 0), max(snap(node.y + node.h) - y, 0)
		node:PlaceEmbedded()
		return
	elseif node.kind == "text" then
		obj, rel, w, h = node.fs, parent.inner or parent.frame, node.w, node.h
	else
		obj, rel = node.frame, node.pos == "fixed" and UIParent or parent.inner or parent.frame
		w, h = max(snap(node.x + node.w) - x, 0), max(snap(node.y + node.h) - y, 0)
	end
	if rel ~= node.pRel or x ~= node.pX or y ~= node.pY then
		node.pRel, node.pX, node.pY = rel, x, y
		obj:SetPoint("TOPLEFT", rel, "TOPLEFT", x, -y)
	end
	if w ~= node.pW or h ~= node.pH then
		node.pW, node.pH = w, h
		obj:SetSize(w, h)
		if node.lookFit then
			node:FitBackground()
		elseif node.lookArt then
			node:DrawArt()
		end
	end
end

function ctx.measure(node, width)
	local fs = node.fs
	fs:SetWidth(width)
	local h = pixelsUp(fs:GetStringHeight())
	fs:SetWidth(node.pW or 0) -- back to the width it's drawn at
	return h
end

-- Applying attributes --------------------------------------------------------------------------------------------

local function edge(frame)
	local t = frame:CreateTexture(nil, "BORDER")
	t:SetColorTexture(1, 1, 1, 1)
	return t
end

-- A border drawn with a Blizzard nine-slice's art (border.nineSlice, a NineSliceLayouts name), as the design site's
-- MetalFrame draws its small and dialog frames: the sides border.sides names (all four when unset), each at its
-- atlas's size times border.scale (k):
--   bottom, left, right  the layout's edges, tiling along; the bottom corners the layout's, where both sides meet;
--   top                  the left edge turned a quarter to lie along the top (lit from the top-left like the rest),
--                        stretched across;
--   top corners          mitred: a square of the side's edge (as thick as the left edge is wide, T) under a square of
--                        the turned top, each masked to its half of the diagonal (media/mitre-*). The top line sits
--                        11.5 units in from its outer side, the right edge's only 2, so the top-right square sits
--                        9.5 k lower and its top piece shows the art 9.5 k higher, to stay in line with the top.
-- The pieces reach past the box as the layout's corner offsets say (8 k left, 4 k right, 3 k up and down); a side
-- not drawn leaves its neighbours running to their outer end. Anchored to the box's corners: no size needed.
local MITRE = "Interface\\AddOns\\OrdaenCore\\media\\mitre-"

local function artPiece(frame, sub)
	local tex = frame:CreateTexture(nil, "BORDER", nil, sub)
	tex:SetSnapToPixelGrid(false) -- as NineSliceUtil.DisableSharpening: the art stays sharp at any scale
	tex:SetTexelSnappingBias(0)
	return tex
end

local function maskOf(frame, tex, file)
	local mask = frame:CreateMaskTexture()
	mask:SetTexture(MITRE .. file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	tex:AddMaskTexture(mask)
	return mask
end

local function atlasSize(piece)
	local info = type(piece) == "table" and piece.atlas and C_Texture.GetAtlasInfo(piece.atlas)
	if info then
		return piece.atlas, info.width, info.height
	end
end

function Node:ApplyFrameArt(border)
	local layout = NineSliceLayouts and NineSliceLayouts[border.nineSlice]
	if type(layout) ~= "table" then
		return
	end
	local leftAtlas, leftW, leftH = atlasSize(layout.LeftEdge)
	if not leftAtlas then
		return
	end
	local frame = self.frame
	local art = self.frameArt
	if not art then
		art = {}
		self.frameArt = art
	end
	local sides = border.sides
	local top, right, bottom, left = true, true, true, true
	if sides then
		top, right, bottom, left = false, false, false, false
		for i = 1, #sides do
			local side = sides[i]
			if side == "top" then
				top = true
			elseif side == "right" then
				right = true
			elseif side == "bottom" then
				bottom = true
			elseif side == "left" then
				left = true
			end
		end
	end
	local k = border.scale or 1
	local T = snap(leftW * k) -- the left edge's thickness: the mitred corners' square
	local f = leftW / leftH -- that square's share of the left edge's atlas length
	local outL, outR, outV = snap(8 * k), snap(4 * k), snap(3 * k)
	local D = top and right and snap(9.5 * k) or 0
	local function piece(key, sub)
		local tex = art[key]
		if not tex then
			tex = artPiece(frame, sub)
			art[key] = tex
		end
		tex:ClearAllPoints()
		tex:Show()
		return tex
	end
	local blAtlas, blW, blH = atlasSize(layout.BottomLeftCorner)
	local brAtlas, brW, brH = atlasSize(layout.BottomRightCorner)
	blW, blH, brW, brH = snap((blW or 0) * k), snap((blH or 0) * k), snap((brW or 0) * k), snap((brH or 0) * k)
	-- top: the left edge turned (within the atlas: the piece's top-left shows its bottom-left, top-right its top-left)
	if top then
		local tex = piece("top", 0)
		tex:SetAtlas(leftAtlas)
		tex:SetHorizTile(false)
		tex:SetVertTile(false)
		tex:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
		tex:SetPoint("TOPLEFT", frame, "TOPLEFT", left and T - outL or -outL, outV)
		tex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", right and outR - T or outR, outV)
		tex:SetHeight(T)
	end
	if bottom then
		local atlas, _, h = atlasSize(layout.BottomEdge)
		if atlas then
			local tex = piece("bottom", 0)
			tex:SetAtlas(atlas)
			tex:SetHorizTile(true)
			tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left and blW - outL or -outL, -outV)
			tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right and outR - brW or outR, -outV)
			tex:SetHeight(snap(h * k))
		end
	end
	if left then
		local tex = piece("left", 0)
		tex:SetAtlas(leftAtlas)
		tex:SetVertTile(true)
		tex:SetPoint("TOPLEFT", frame, "TOPLEFT", -outL, top and outV - T or outV)
		tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -outL, bottom and blH - outV or -outV)
		tex:SetWidth(T)
	end
	local rightAtlas, rightW = atlasSize(layout.RightEdge)
	if right and rightAtlas then
		local tex = piece("right", 0)
		tex:SetAtlas(rightAtlas)
		tex:SetVertTile(true)
		tex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", outR, top and outV - D - T or outV)
		tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outR, bottom and brH - outV or -outV)
		tex:SetWidth(snap(rightW * k))
	end
	if bottom and left and blAtlas then
		local tex = piece("bl", 1)
		tex:SetAtlas(blAtlas)
		tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -outL, -outV)
		tex:SetSize(blW, blH)
	end
	if bottom and right and brAtlas then
		local tex = piece("br", 1)
		tex:SetAtlas(brAtlas)
		tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outR, -outV)
		tex:SetSize(brW, brH)
	end
	-- the mitred top corners: the side's square (lower half), the turned top's square (upper half)
	if top and left then
		local side = piece("tlSide", 1)
		side:SetAtlas(leftAtlas)
		side:SetTexCoord(0, 1, 0, f)
		side:SetPoint("TOPLEFT", frame, "TOPLEFT", -outL, outV)
		side:SetSize(T, T)
		local turned = piece("tlTop", 2)
		turned:SetAtlas(leftAtlas)
		turned:SetTexCoord(0, 1, 1, 1, 0, 1 - f, 1, 1 - f)
		turned:SetAllPoints(side)
		if not art.tlSideMask then
			art.tlSideMask = maskOf(frame, side, "ll")
			art.tlTopMask = maskOf(frame, turned, "ur")
		end
		art.tlSideMask:SetAllPoints(side)
		art.tlTopMask:SetAllPoints(side)
	end
	if top and right and rightAtlas then
		local side = piece("trSide", 1)
		side:SetAtlas(rightAtlas)
		side:SetTexCoord(0, 1, 0, f)
		side:SetPoint("TOPRIGHT", frame, "TOPRIGHT", outR, outV - D)
		side:SetSize(T, T)
		-- the turned top drawn D higher: the square's upper T - D show the art's lower part (its rows D to T)
		local turned = piece("trTop", 2)
		turned:SetAtlas(leftAtlas)
		local u = D / T
		turned:SetTexCoord(u, 1, 1, 1, u, 1 - f, 1, 1 - f)
		turned:SetPoint("TOPLEFT", side, "TOPLEFT")
		turned:SetPoint("TOPRIGHT", side, "TOPRIGHT")
		turned:SetHeight(T - D)
		if not art.trSideMask then
			art.trSideMask = maskOf(frame, side, "lr")
			art.trTopMask = maskOf(frame, turned, "ul")
		end
		art.trSideMask:SetAllPoints(side)
		art.trTopMask:SetAllPoints(side)
	end
end

-- The background's inset under the frame art, per side: the art's inset (border.inset) on the sides it draws.
local function fillInsets(border)
	if type(border) ~= "table" or not border.nineSlice then
		return 0, 0, 0, 0
	end
	local inset = snap(border.inset or 0)
	local sides = border.sides
	if not sides then
		return inset, inset, inset, inset
	end
	local t, r, b, l = 0, 0, 0, 0
	for i = 1, #sides do
		local side = sides[i]
		if side == "top" then
			t = inset
		elseif side == "right" then
			r = inset
		elseif side == "bottom" then
			b = inset
		elseif side == "left" then
			l = inset
		end
	end
	return t, r, b, l
end

function Node:ApplyBorder(border)
	local frame = self.frame
	local t, r, b, l = self.bwT, self.bwR, self.bwB, self.bwL
	local edges = self.edges
	if edges then
		for i = 1, 4 do
			edges[i]:Hide()
		end
	end
	local art = self.frameArt
	if art then
		for _, tex in next, art do
			if tex.Hide then
				tex:Hide()
			end
		end
	end
	if type(border) ~= "table" or t + r + b + l == 0 then
		return
	end
	if border.nineSlice then
		self:ApplyFrameArt(border)
		return
	end
	if not edges then
		edges = { edge(frame), edge(frame), edge(frame), edge(frame) }
		self.edges = edges
		edges[1]:SetPoint("TOPLEFT")
		edges[1]:SetPoint("TOPRIGHT")
		edges[2]:SetPoint("BOTTOMLEFT")
		edges[2]:SetPoint("BOTTOMRIGHT")
		edges[3]:SetPoint("TOPLEFT", edges[1], "BOTTOMLEFT")
		edges[3]:SetPoint("BOTTOMLEFT", edges[2], "TOPLEFT")
		edges[4]:SetPoint("TOPRIGHT", edges[1], "BOTTOMRIGHT")
		edges[4]:SetPoint("BOTTOMRIGHT", edges[2], "TOPRIGHT")
	end
	-- a side without width keeps its edge (the others anchor to it) at no height, hidden
	edges[1]:SetHeight(t)
	edges[2]:SetHeight(b)
	edges[3]:SetWidth(l)
	edges[4]:SetWidth(r)
	local c = color(resolveRef(border.color)) or Theme["color.border"]
	for i = 1, 4 do
		edges[i]:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	end
	edges[1]:SetShown(t > 0)
	edges[2]:SetShown(b > 0)
	edges[3]:SetShown(l > 0)
	edges[4]:SetShown(r > 0)
end

-- Portraits: a box's `portrait` shows a unit's face over its background, filling the box.
--   "player" (a unit)            the face as a texture (SetPortraitTexture without Blizzard's round mask: square, so a
--                                box's own `mask` gives it its shape), drawn again on UNIT_PORTRAIT_UPDATE and
--                                PORTRAITS_UPDATED
--   { unit = "player", live = true }  the unit's 3D model zoomed to its head (a PlayerModel), alive, drawn again on
--                                UNIT_MODEL_CHANGED. A model can't take a mask texture: it stays a rectangle under the
--                                rim, and it costs a model render every frame.
-- The events are registered only while a portrait shows: one frame per unit shown, registered for that unit only.
local portraits = {} -- node -> its unit, while it shows a face or a model
local portraitFrames = {} -- unit -> its event frame (kept: a unit's frame is made once)

local function onPortraitEvent(_, event, unit)
	for node, own in pairs(portraits) do
		if event == "PORTRAITS_UPDATED" or own == unit then
			local model = node.model3d
			if model and model:IsShown() then
				if event == "UNIT_MODEL_CHANGED" then
					model:RefreshUnit()
				end
			elseif event ~= "UNIT_MODEL_CHANGED" then
				SetPortraitTexture(node.face, own, true)
			end
		end
	end
end

local function portraitEvents()
	local shown = {}
	for _, unit in pairs(portraits) do
		shown[unit] = true
	end
	local all = false -- PORTRAITS_UPDATED on one frame only
	for unit in pairs(shown) do
		local frame = portraitFrames[unit]
		if not frame then
			frame = CreateFrame("Frame")
			frame:SetScript("OnEvent", onPortraitEvent)
			portraitFrames[unit] = frame
		end
		frame:UnregisterAllEvents()
		frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", unit)
		frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", unit)
		if not all then
			all = true
			frame:RegisterEvent("PORTRAITS_UPDATED")
		end
	end
	for unit, frame in pairs(portraitFrames) do
		if not shown[unit] then
			frame:UnregisterAllEvents()
		end
	end
end

-- Frame levels over a box with a live portrait: its model just above it, the rim above the model (OverFrame), its
-- child boxes (the panel's level badge) above the rim. A box without one keeps its rim on its own frame, under its
-- children, and they sit one level up, as every child does.
local MODEL_LEVELS, CHILD_LEVELS = 1, 3

-- The box's rim on the frame it belongs to now: over the model while a live portrait shows, else the box's own.
function Node:PlaceRim()
	local rim = self.rimTex
	if rim then
		rim:SetParent(self.liveModel and self:OverFrame() or self.frame)
		rim:SetDrawLayer("OVERLAY")
	end
end

-- The child boxes' frames above a live portrait's rim (attach raises a new child the same way).
function Node:RaiseChildren()
	local level = self.frame:GetFrameLevel() + (self.liveModel and CHILD_LEVELS or 1)
	local children = self.children
	for i = 1, self.count or 0 do
		local child = children[i]
		local frame = child.kind ~= "text" and not child.embedded and child.frame
		if frame and frame:GetFrameLevel() < level then
			frame:SetFrameLevel(level)
		end
	end
end

-- A frame above the box's own regions and its model, for the rim while a live portrait shows (made on first use).
function Node:OverFrame()
	local over = self.overFrame
	if not over then
		over = CreateFrame("Frame", nil, self.frame)
		over:SetAllPoints(self.frame)
		self.overFrame = over
	end
	over:SetFrameLevel(self.frame:GetFrameLevel() + 2)
	return over
end

function Node:ApplyPortrait(portrait)
	local face, model = self.face, self.model3d
	local live = type(portrait) == "table" and portrait.live
	local unit = type(portrait) == "table" and portrait.unit or portrait
	if face and (unit == nil or live) then
		face:Hide()
	end
	if model and not live then
		model:ClearModel()
		model:Hide()
	end
	if (live or false) ~= (self.liveModel or false) then
		self.liveModel = live or nil
		self:PlaceRim()
		self:RaiseChildren()
	end
	if unit == nil then
		if portraits[self] then
			portraits[self] = nil
			portraitEvents()
		end
		return
	end
	if live then
		if not model then
			model = CreateFrame("PlayerModel", nil, self.frame)
			model:SetAllPoints(self.frame)
			self.model3d = model
		end
		model:SetFrameLevel(self.frame:GetFrameLevel() + MODEL_LEVELS)
		model:SetUnit(unit)
		model:SetPortraitZoom(1)
		model:SetCamDistanceScale(1)
		model:Show()
	else
		if not face then
			face = self.frame:CreateTexture(nil, "BORDER")
			face:SetAllPoints(self.frame)
			self.face = face
			if self.maskTex then
				face:AddMaskTexture(self.maskTex)
			end
		end
		SetPortraitTexture(face, unit, true) -- square: the box's mask shapes it
		face:Show()
	end
	if portraits[self] ~= unit then
		portraits[self] = unit
		portraitEvents()
	end
end

-- A box's `mask` (a theme value { mask, rim }): its shape cuts its background and its face, and its rim art lies over
-- both, all stretched to the box (the art is drawn for the box's aspect). Clicks still land on the whole rectangle:
-- a frame's hit area can't follow a shape, so a masked box takes the mouse only with a handler, as any box.
function Node:ApplyMask(mask)
	local tex, rim = self.maskTex, self.rimTex
	if type(mask) ~= "table" or not mask.mask then
		if tex then
			if self.bg then
				self.bg:RemoveMaskTexture(tex)
			end
			if self.face then
				self.face:RemoveMaskTexture(tex)
			end
			self.maskTex = nil
		end
		if rim then
			rim:Hide()
		end
		return
	end
	if not tex then
		tex = self.frame:CreateMaskTexture()
		tex:SetAllPoints(self.frame)
		self.maskTex = tex
		if self.bg then
			self.bg:AddMaskTexture(tex)
		end
		if self.face then
			self.face:AddMaskTexture(tex)
		end
	end
	tex:SetTexture(mask.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	if mask.rim then
		if not rim then
			rim = self.frame:CreateTexture(nil, "OVERLAY")
			rim:SetAllPoints(self.frame)
			self.rimTex = rim
			self:PlaceRim()
		end
		rim:SetTexture(mask.rim)
		rim:Show()
	elseif rim then
		rim:Hide()
	end
end

-- Art a background can be besides a colour, a file or an atlas (theme values; design site: Slice3, PanelCell, XpTube):
--   { file, size = { w, h }, cap, capHeight, rows, normal, pressed, glow }  three-sliced across the box: the caps are
--     `cap` texture px of the file drawn capHeight x the box's height wide, the middle stretches; `rows` rows of equal
--     height: `normal`, or `pressed` while the box is pressed, and the `glow` row over it while hovered (not pressed)
--   { file, size = { w, h }, tile = true }  the file repeated along the box, each copy as high as the box
-- Drawn again only when the box's size or state changed.
local SLICE_POINTS = { "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT" }

-- Three textures for a three-slice in `key` (the base, or the glow over it), made on first use.
function Node:Slices(key, sublevel, file)
	local list = self[key]
	if not list then
		local frame = self.frame
		list = {}
		for i = 1, 3 do
			list[i] = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
		end
		list[1]:SetPoint(SLICE_POINTS[1], frame, SLICE_POINTS[1])
		list[1]:SetPoint(SLICE_POINTS[2], frame, SLICE_POINTS[2])
		list[3]:SetPoint(SLICE_POINTS[3], frame, SLICE_POINTS[3])
		list[3]:SetPoint(SLICE_POINTS[4], frame, SLICE_POINTS[4])
		list[2]:SetPoint("TOPLEFT", list[1], "TOPRIGHT")
		list[2]:SetPoint("BOTTOMRIGHT", list[3], "BOTTOMLEFT")
		self[key] = list
	end
	if list.file ~= file then
		list.file = file
		for i = 1, 3 do
			list[i]:SetTexture(file)
		end
	end
	return list
end

-- Art without caps (cap = 0: a knob, an icon drawn whole) hides them; they keep a hair's width, never 0 (a region's
-- width 0 can mean "the file's own size").
local function sliceRow(list, capW, u, row, rows)
	local v0, v1 = row / rows, (row + 1) / rows
	local caps = capW > 0
	list[1]:SetWidth(caps and capW or 0.001)
	list[3]:SetWidth(caps and capW or 0.001)
	list[1]:SetTexCoord(0, u, v0, v1)
	list[2]:SetTexCoord(u, 1 - u, v0, v1)
	list[3]:SetTexCoord(1 - u, 1, v0, v1)
	list[1]:SetShown(caps)
	list[2]:Show()
	list[3]:SetShown(caps)
end

local function hideSlices(list)
	if list then
		for i = 1, 3 do
			list[i]:Hide()
		end
	end
end

function Node:DrawArt()
	local art, w, h = self.lookArt, self.pW, self.pH
	if not art or not w or not h or h <= 0 then
		return
	end
	local state = self.pressed and 2 or self.hovered and 1 or 0
	if w == self.artW and h == self.artH and state == self.artState then
		return
	end
	self.artW, self.artH, self.artState = w, h, state
	local size = art.size
	if art.tile then
		local tileW = size[1] * h / size[2]
		self.bg:SetTexCoord(0, w / tileW, 0, 1)
		return
	end
	local capW = snap(h * (art.capHeight or 1))
	if 2 * capW > w then
		capW = w / 2
	end
	local u, rows = (art.cap or 0) / size[1], art.rows or 1
	sliceRow(self:Slices("slices", 0, art.file), capW, u, state == 2 and art.pressed or art.normal or 0, rows)
	if art.glow and state == 1 then
		sliceRow(self:Slices("glows", 1, art.file), capW, u, art.glow, rows)
	else
		hideSlices(self.glows)
	end
end

-- An art background covers the box: the art's full width and a band of its height, or the other way round, so it
-- keeps its aspect (texture coordinates count within the atlas after SetAtlas). Again only when the box's size changed.
function Node:FitBackground()
	local aspect, w, h = self.lookFit, self.pW, self.pH
	-- the background starts inside the border art's inset
	w = w and w - (self.fillLeft or 0) - (self.fillRight or 0)
	h = h and h - (self.fillTop or 0) - (self.fillBottom or 0)
	if not aspect or not w or not h or h <= 0 or (w == self.fitW and h == self.fitH) then
		return
	end
	self.fitW, self.fitH = w, h
	local l, r, t, b = 0, 1, 0, 1
	local boxAspect = w / h
	if boxAspect > aspect then
		local cut = (1 - aspect / boxAspect) / 2
		t, b = cut, 1 - cut
	else
		local cut = (1 - boxAspect / aspect) / 2
		l, r = cut, 1 - cut
	end
	self.bg:SetTexCoord(l, r, t, b)
end

-- overflow: "clip" cuts the children at the box's edges; "scroll" clips too and holds them in an inner frame the
-- mouse wheel moves (one SetPoint a notch), as tall as their extent (Node:ScrollTo). "visible" or unset draws them as
-- they fall.
local SCROLL_STEP = 40 -- UI units a wheel notch moves

local function onWheel(frame, delta)
	local node = frame.node
	local fn = node.a.OnWheel
	if fn then
		handle(fn, delta)
	elseif node.inner then
		node:ScrollTo((node.scrollY or 0) - delta * SCROLL_STEP)
	end
end

-- The wheel is on for a box with OnWheel or overflow = "scroll".
function Node:ApplyWheel()
	local on = (self.inner or self.a.OnWheel) and true or false
	if on ~= (self.wheelOn or false) then
		self.wheelOn = on or nil
		self.frame:EnableMouseWheel(on)
		self.frame:SetScript("OnMouseWheel", on and onWheel or nil)
	end
end

function Node:ApplyOverflow(overflow)
	local frame = self.frame
	local scroll = overflow == "scroll"
	frame:SetClipsChildren(scroll or overflow == "clip")
	if scroll == (self.inner ~= nil) then
		return
	end
	if scroll then
		local inner = self.innerFrame
		if not inner then
			inner = CreateFrame("Frame", nil, frame)
			self.innerFrame = inner
		end
		inner:Show()
		inner:ClearAllPoints()
		inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		self.inner, self.scrollY, self.innerW, self.innerH = inner, 0, nil, nil
		scrollers[self] = true
	else
		self.innerFrame:Hide()
		self.inner, self.scrollY, self.innerW, self.innerH = nil, nil, nil, nil
		scrollers[self] = nil
	end
	self:ApplyWheel()
	-- the children move to the new host frame, and are placed again
	local host = self.inner or frame
	local tf = self.textFrame
	if tf then
		tf:SetParent(host)
		tf:ClearAllPoints()
		tf:SetAllPoints(host)
	end
	if self.textHost and self.textHost ~= tf then
		self.textHost = host
	end
	local children = self.children
	for i = 1, self.count or 0 do
		local child = children[i]
		child.fparent, child.pRel, child.x = nil, nil, nil
		attach(child, self)
	end
	enqueue(Layout.Invalidate(self))
end

---Scroll a box with overflow = "scroll" to `y` UI units from its content's top, held between 0 and its content's
---extent (its children's bottom and its bottom padding) less its height, on whole pixels.
---@param y number
function Node:ScrollTo(y)
	local inner = self.inner
	if not inner then
		return
	end
	local extent = 0
	local children = self.children
	for i = 1, self.count or 0 do
		local child = children[i]
		local cy, ch = child.y, child.h
		if cy and ch and cy + ch > extent then
			extent = cy + ch
		end
	end
	extent = extent + (self.padB or 0)
	local view = self.pH or 0
	y = snap(min(max(y, 0), max(0, extent - view)))
	if y ~= self.scrollY then
		self.scrollY = y
		inner:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y)
	end
	local w, h = self.pW or 0, max(extent, view)
	if w ~= self.innerW or h ~= self.innerH then
		self.innerW, self.innerH = w, h
		inner:SetSize(w, h)
	end
end

-- kind = "input": an edit box filling the box inside its padding, drawn with the text attributes. `text` is what it
-- shows; typing calls OnChange(text) (only for the player's typing, not for a `text` the render set), Enter
-- OnSubmit(text) and leaves the box, Escape leaves it. `focus` true takes the keyboard, false gives it back. The edit
-- box is made on first use and hidden while the box is another kind.
local function onEditChanged(edit, userInput)
	local fn = userInput and edit.node.a.OnChange
	if fn then
		handle(fn, edit:GetText())
	end
end

local function onEditEnter(edit)
	local fn = edit.node.a.OnSubmit
	edit:ClearFocus()
	if fn then
		handle(fn, edit:GetText())
	end
end

local function onEditEscape(edit)
	edit:ClearFocus()
end

function Node:ApplyInput()
	local a, edit = self.a, self.edit
	if resolve(self, a.kind) ~= "input" then
		if edit and edit:IsShown() then
			edit:ClearFocus()
			edit:Hide()
		end
		return
	end
	if not edit then
		edit = CreateFrame("EditBox", nil, self.frame)
		edit:SetAutoFocus(false)
		edit:SetAllPoints(self.frame)
		edit.node = self
		edit:SetScript("OnTextChanged", onEditChanged)
		edit:SetScript("OnEnterPressed", onEditEnter)
		edit:SetScript("OnEscapePressed", onEditEscape)
		self.edit = edit
	end
	edit:Show()
	local size = resolve(self, a.textSize) or Theme["text.body"]
	local font = resolve(self, a.textFamily) or Theme["font.body"]
	if size ~= self.editSize or font ~= self.editFont then
		self.editSize, self.editFont = size, font
		edit:SetFont(font, size, "")
	end
	local c = color(resolve(self, a.textColor)) or Theme["color.text"]
	if c ~= self.editColor then
		self.editColor = c
		edit:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	end
	local justify = JUSTIFY[resolve(self, a.textAlign)] or "LEFT"
	if justify ~= edit:GetJustifyH() then
		edit:SetJustifyH(justify)
	end
	edit:SetTextInsets(self.padL or 0, self.padR or 0, self.padT or 0, self.padB or 0)
	local maxLength = resolve(self, a.maxLength) or 0
	if maxLength ~= edit:GetMaxLetters() then
		edit:SetMaxLetters(maxLength)
	end
	local text = resolve(self, a.text) or ""
	if text ~= edit:GetText() then -- what the player typed, written back, leaves the cursor where it is
		edit:SetText(text)
	end
	local focus = resolve(self, a.focus)
	if focus == true and not edit:HasFocus() then
		edit:SetFocus()
	elseif focus == false and edit:HasFocus() then
		edit:ClearFocus()
	end
end

-- The look: background, border, opacity, text colour and alignment. Each setter runs only when its value changed.
function Node:ApplyLook()
	local a = self.a
	local opacity = resolve(self, a.opacity) or 1
	if self.kind == "text" then
		local fs = self.fs
		local c = color(resolve(self, a.textColor)) or Theme["color.text"]
		if c ~= self.lookColor then
			self.lookColor = c
			fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
		end
		-- textShadow { color, x, y }: x and y in UI units on whole pixels, y up; no shadow when unset. It doesn't
		-- change the text's size (as in CSS). The same colour one pixel right reads as bold where a font has no bold
		-- face (Blizzard's Arial Narrow).
		local shadow = a.textShadow
		if shadow ~= nil then
			shadow = resolve(self, shadow)
		end
		if shadow ~= self.lookShadow then
			self.lookShadow = shadow
			if shadow then
				local sc = color(resolveRef(shadow.color)) or BLACK
				fs:SetShadowColor(sc[1], sc[2], sc[3], sc[4] or 1)
				fs:SetShadowOffset(snap(shadow.x or 0), snap(shadow.y or 0))
			else
				fs:SetShadowOffset(0, 0)
			end
		end
		local justify = JUSTIFY[resolve(self, a.textAlign)] or "LEFT"
		if justify ~= self.lookJustify then
			self.lookJustify = justify
			fs:SetJustifyH(justify)
		end
		if opacity ~= self.lookOpacity then
			self.lookOpacity = opacity
			fs:SetAlpha(opacity)
		end
		return
	end
	local frame = self.frame
	if opacity ~= self.lookOpacity then
		self.lookOpacity = opacity
		frame:SetAlpha(opacity)
	end
	if self.kind ~= "box" then
		return
	elseif self.embedded then
		local look = resolve(self, a.look)
		if look ~= self.lookEmbed then
			self.lookEmbed = look
			self:ApplyEmbedLook(look == "icon")
		end
		return
	end
	local mask = resolve(self, a.mask)
	if mask ~= self.lookMask then
		self.lookMask = mask
		self:ApplyMask(mask)
	end
	if self.edit or a.kind ~= nil then
		self:ApplyInput()
	end
	local overflow = a.overflow
	if overflow ~= nil then
		overflow = resolve(self, overflow)
	end
	if overflow ~= self.lookOverflow then
		self.lookOverflow = overflow
		self:ApplyOverflow(overflow)
	end
	local bg = resolve(self, a.background)
	-- under a border drawn with Blizzard's art the background starts at the art's inset (MetalFrame's fill)
	local border = resolve(self, a.border)
	local fillTop, fillRight, fillBottom, fillLeft = fillInsets(border)
	if fillTop ~= (self.fillTop or 0) or fillRight ~= (self.fillRight or 0) or fillBottom ~= (self.fillBottom or 0)
		or fillLeft ~= (self.fillLeft or 0) then
		self.fitW = nil
		self.fillTop = fillTop ~= 0 and fillTop or nil
		self.fillRight = fillRight ~= 0 and fillRight or nil
		self.fillBottom = fillBottom ~= 0 and fillBottom or nil
		self.fillLeft = fillLeft ~= 0 and fillLeft or nil
		if self.bg then
			self.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", fillLeft, -fillTop)
			self.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -fillRight, fillBottom)
			self:FitBackground()
		end
	end
	if bg ~= self.lookBg then
		self.lookBg = bg
		local tex = self.bg
		if bg == nil then
			if tex then
				tex:Hide()
			end
		else
			if not tex then
				tex = frame:CreateTexture(nil, "BACKGROUND")
				tex:SetPoint("TOPLEFT", frame, "TOPLEFT", self.fillLeft or 0, -(self.fillTop or 0))
				tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(self.fillRight or 0), self.fillBottom or 0)
				self.bg = tex
				if self.maskTex then
					tex:AddMaskTexture(self.maskTex)
				end
			end
			local c = color(bg)
			self.lookFit, self.lookArt, self.artW = nil, nil, nil
			hideSlices(self.slices)
			hideSlices(self.glows)
			if type(bg) == "table" and bg.file and not bg.tile then -- three-slice: its own textures
				tex:Hide()
				self.lookArt = bg
				self:DrawArt()
			elseif type(bg) == "table" and bg.file then -- tiled along
				tex:SetTexture(bg.file, "REPEAT", "CLAMP")
				self.lookArt = bg
				self:DrawArt()
			elseif c then
				tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
				tex:SetTexCoord(0, 1, 0, 1) -- an art background before may have cropped it
			elseif type(bg) == "table" and bg.atlas then
				tex:SetAtlas(bg.atlas)
				local info = C_Texture.GetAtlasInfo(bg.atlas)
				if info and info.width > 0 and info.height > 0 then
					self.lookFit, self.fitW = info.width / info.height, nil -- cropped to the box when it's placed
					self:FitBackground()
				end
			else
				tex:SetTexture(bg)
				tex:SetTexCoord(0, 1, 0, 1)
			end
			if not (self.lookArt and not bg.tile) then
				tex:Show()
			end
		end
	end
	if self.lookArt then
		self:DrawArt()
	end
	local unit = resolve(self, a.portrait)
	if unit ~= self.lookPortrait then
		self.lookPortrait = unit
		self:ApplyPortrait(unit)
	end
	-- the widths change together (the pixel size) or with the border's sides (another border): one sum tells
	local bw = self.bwT + self.bwR + self.bwB + self.bwL
	if border ~= self.lookBorder or bw ~= self.lookBw then
		self.lookBorder, self.lookBw = border, bw
		self:ApplyBorder(border)
	end
end

-- One line of `font` at `size`: its line height on whole pixels, measured once per font and size.
local function lineHeight(fs, font, size)
	local sizes = lineHeights[font]
	if not sizes then
		sizes = {}
		lineHeights[font] = sizes
	end
	local h = sizes[size]
	if not h then
		h = pixelsUp(fs:GetLineHeight())
		sizes[size] = h
	end
	return h
end

-- Whether the drawn text can hold a line break (then it's measured as lines, not as one).
function Node:HasBreak(text)
	if find(text, "\n", 1, true) then
		return true
	end
	local args = self.args
	for i = 1, self.nargs do
		local v = args[i]
		if type(v) == "string" and find(v, "\n", 1, true) then
			return true
		end
	end
	return false
end

-- Text, size and wrapping; measures the text. Returns true when the layout must run (Layout.TextResized).
function Node:ApplyText()
	if self.kind ~= "text" then
		self:ApplyInput()
		return false -- an input box is the size its attributes give it, whatever is typed
	end
	local a, fs = self.a, self.fs
	local size = resolve(self, a.textSize) or Theme["text.body"]
	-- node.font: the font when it isn't the body font (nil for most texts: a text node's fields fit its 32 slots)
	local font = a.textFamily
	if font ~= nil then
		font = resolve(self, font)
	end
	if font == Theme["font.body"] then
		font = nil
	end
	if size ~= self.fontSize or font ~= self.font then
		self.fontSize, self.font = size, font
		fs:SetFont(font or Theme["font.body"], size, "")
	end
	local wrap = resolve(self, a.wrap) ~= false
	if wrap ~= self.wrap then
		self.wrap = wrap
		fs:SetWordWrap(wrap)
	end
	local text = resolve(self, a.text) or ""
	if self.nargs > 0 then
		fs:SetFormattedText(text, unpack(self.args, 1, self.nargs))
	else
		fs:SetText(text)
	end
	local natW, lineH
	if self:HasBreak(text) then
		fs:SetWidth(0) -- lines: the widest and their height, measured without a width
		natW, lineH = pixelsUp(fs:GetStringWidth()), pixelsUp(fs:GetStringHeight())
		fs:SetWidth(self.pW or 0)
	else
		natW, lineH = pixelsUp(fs:GetUnboundedStringWidth()), lineHeight(fs, font or Theme["font.body"], size)
	end
	local oldW, oldH = self.natW, self.lineH
	self.natW, self.lineH, self.mW = natW, lineH, nil
	return Layout.TextResized(self, oldW, oldH)
end

-- A box takes the mouse only with a handler or a per-state map, and never at opacity 0.
function Node:ApplyMouse()
	if self.kind ~= "box" or self.embedded then -- an embedded frame keeps its own mouse
		return
	end
	local a = self.a
	local drag = (a.OnDragStart or a.OnDrag or a.OnDragStop) and true or false
	local want = (self.states or a.OnClick or a.OnEnter or a.OnLeave or drag) and (self.lookOpacity or 1) > 0 and true
		or false
	local frame = self.frame
	if want ~= self.mouse then
		self.mouse = want
		frame:EnableMouse(want)
		if not want then
			self.hovered, self.pressed = false, false
		end
	end
	if drag ~= (self.dragOn or false) then
		self.dragOn = drag or nil
		if drag then
			frame:RegisterForDrag("LeftButton")
		else
			frame:RegisterForDrag()
			if frame.dragL then -- released mid-drag
				onDragStop(frame)
			end
		end
		frame:SetScript("OnDragStart", drag and onDragStart or nil)
		frame:SetScript("OnDragStop", drag and onDragStop or nil)
	end
	if self.inner or a.OnWheel or self.wheelOn then
		self:ApplyWheel()
	end
end

-- Whether any attribute is a per-state map, and whether one of them is a layout attribute.
function Node:ScanStates()
	local states, stateLayout = false, false
	for key, v in next, self.a do
		if type(v) == "table" and rawget(v, "path") == nil
			and (rawget(v, "default") ~= nil or rawget(v, "hover") ~= nil or rawget(v, "pressed") ~= nil) then
			states = true
			local g = GROUP[key]
			if g ~= LOOK and g ~= INPUT then
				stateLayout = true
			end
		end
	end
	self.states, self.stateLayout = states, stateLayout
end

-- An attribute the layout can't take: reported through the game's error handler at the Set that gave it (the dev
-- addon shows it), laid out as if unset, so one wrong value never stops the flush.
local function badAttribute(key, value)
	if key then
		geterrorhandler()(("Ordaen: %s = %s is not a number of UI units (a share of the parent is a width or height"
			.. " like \"10%%\")"):format(key, type(value) == "string" and ("%q"):format(value) or tostring(value)))
	end
end

-- The fields Layout.Apply fills for a box, from a frozen attribute table without per-state maps (nil otherwise).
local function styleOf(t)
	local style = styles[t]
	if style == nil then
		style = false
		if isfrozen(t) then
			local plain = true
			for _, v in next, t do
				if type(v) == "table" and rawget(v, "path") == nil
					and (rawget(v, "default") ~= nil or rawget(v, "hover") ~= nil or rawget(v, "pressed") ~= nil) then
					plain = false
					break
				end
			end
			if plain then
				style = { kind = "box" }
				badAttribute(Layout.Apply(style, t, resolve, resolveRef, px))
			end
		end
		styles[t] = style
	end
	return style or nil
end

-- Before a box's column arrays are written: its own, not a style's shared ones.
local function ownColumns(node)
	if node.colShared then
		node.colKind, node.colAmount, node.colShared = nil, nil, nil
	end
end

-- The mouse's state on the box: hovered, pressed. Its per-state maps and state art follow; so do the children whose
-- `stateFrom` is "parent" (a cell's icon moving down while the cell is pressed).
function Node:SetState(hovered, pressed)
	if self.hovered == hovered and self.pressed == pressed then
		return
	end
	self.hovered, self.pressed = hovered, pressed
	if self.states or self.lookArt then
		self:Restyle()
	end
	local children = self.children
	for i = 1, self.count or 0 do
		local child = children[i]
		if child.a.stateFrom == "parent" then
			child:SetState(hovered, pressed)
		end
	end
end

-- Hover or pressed changed: resolve the per-state maps again.
function Node:Restyle()
	self:ApplyLook()
	if self.stateLayout then
		ownColumns(self)
		Layout.Apply(self, self.a, resolve, resolveRef, px)
		if self.kind == "text" then
			self:ApplyText()
		end
		enqueue(Layout.Invalidate(self, true))
		Backend:Flush() -- no engine flush follows a hover that writes nothing
	end
end

-- Taken Blizzard frames --------------------------------------------------------------------------------------------

local function onCombatEnd()
	for node in pairs(pendingCombat) do
		pendingCombat[node] = nil
		if takenBy[node.frame] == node then
			node:ApplyTaken()
		end
	end
	for node in pairs(pendingEmbed) do
		pendingEmbed[node] = nil
		if embeddedBy[node.frame] == node then
			node:PlaceEmbedded()
		end
	end
	if combatFrame then
		combatFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end

-- Blizzard moved or faded a frame we hold: put it back (hooksecurefunc runs after its call; nothing is replaced).
local function onBlizzardChange(frame)
	local node = takenBy[frame]
	if node and not node.applying then
		node:ApplyTaken()
	end
end

function Node:ApplyTaken()
	local frame, a = self.frame, self.a
	self.applying = true
	local opacity = resolve(self, a.opacity)
	if opacity ~= nil and frame:GetAlpha() ~= opacity then
		frame:SetAlpha(opacity)
	end
	-- `shown = false`: hidden while we hold it (Blizzard showing it again is undone: Show and SetShown are hooked); a
	-- protected frame in combat waits for the end, as its points do
	if resolve(self, a.shown) == false and frame:IsShown() then
		if InCombatLockdown() and frame:IsProtected() then
			pendingCombat[self] = true
			if not combatFrame then
				combatFrame = CreateFrame("Frame")
				combatFrame:SetScript("OnEvent", onCombatEnd)
			end
			combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			frame:Hide()
			self.hid = true
		end
	elseif resolve(self, a.shown) ~= false and self.hid then
		self.hid = nil
		frame:SetShown(self.shown0)
	end
	local pos = resolve(self, a.position)
	if pos == "absolute" or pos == "fixed" then
		if InCombatLockdown() and frame:IsProtected() then
			pendingCombat[self] = true
			if not combatFrame then
				combatFrame = CreateFrame("Frame")
				combatFrame:SetScript("OnEvent", onCombatEnd)
			end
			combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			local rel = pos == "fixed" and UIParent or self.parent0
			local l, r = resolveRef(a.left), resolveRef(a.right)
			local t, b = resolveRef(a.top), resolveRef(a.bottom)
			local point = (t and "TOP" or b and "BOTTOM" or "") .. (l and "LEFT" or r and "RIGHT" or "")
			if point == "" then
				point = "CENTER"
			end
			frame:ClearAllPoints()
			frame:SetPoint(point, rel, point, l or (r and -r) or 0, (t and -t) or b or 0)
			self.moved = true
		end
	end
	self.applying = false
end

function Node:GiveBack()
	local frame = self.frame
	takenBy[frame] = nil
	pendingCombat[self] = nil
	self.applying = true
	frame:SetAlpha(self.alpha0)
	if self.hid and not (InCombatLockdown() and frame:IsProtected()) then
		self.hid = nil
		frame:SetShown(self.shown0)
	end
	if self.moved and not (InCombatLockdown() and frame:IsProtected()) then
		frame:ClearAllPoints()
		local points = self.points0
		for i = 1, #points do
			local p = points[i]
			frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
	end
	self.applying = false
end

-- Embedded Blizzard frames -----------------------------------------------------------------------------------------

local function waitForCombat(node)
	pendingEmbed[node] = true
	if not combatFrame then
		combatFrame = CreateFrame("Frame")
		combatFrame:SetScript("OnEvent", onCombatEnd)
	end
	combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Put an embedded frame where its node is: under its parent's frame (a level above it), at its point and size, shown;
-- hidden when detached. Every call at once (rare: a move, Blizzard moving it, combat ending). A protected frame in
-- combat waits for the end.
function Node:PlaceEmbedded()
	local frame = self.frame
	if InCombatLockdown() and frame:IsProtected() then
		waitForCombat(self)
		return
	end
	embedding = true
	local parent = self.parent
	if parent and self.shown then
		local pf = parent.inner or parent.frame
		if frame:GetParent() ~= pf then
			frame:SetParent(pf)
		end
		local level = pf:GetFrameLevel()
		if frame:GetFrameLevel() <= level then
			frame:SetFrameLevel(level + 1)
		end
		if self.pX then
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", self.pRel, "TOPLEFT", self.pX, -self.pY)
			frame:SetSize(self.pW, self.pH)
		end
		if not frame:IsShown() then
			frame:Show()
		end
	elseif frame:IsShown() then
		frame:Hide()
	end
	embedding = false
end

-- An embedded frame's mouse is its parent box's state when the parent's `stateFrom` is "child" (a panel cell under
-- Blizzard's invisible micro button: the cell lights and pushes as the button is hovered and pressed).
local function embedState(frame, hovered, pressed)
	local node = embeddedBy[frame]
	local parent = node and node.parent
	if parent and parent.a.stateFrom == "child" then
		parent:SetState(hovered == nil and parent.hovered or hovered, pressed == nil and parent.pressed or pressed)
	end
end
local function onEmbedEnter(frame)
	embedState(frame, true, nil)
end
local function onEmbedLeave(frame)
	embedState(frame, false, false)
end
local function onEmbedDown(frame)
	embedState(frame, nil, true)
end
local function onEmbedUp(frame)
	embedState(frame, nil, false)
end

-- Blizzard placed, parented or sized a frame we hold as a cell: put it back (hooksecurefunc runs after its call).
local function onEmbedMoved(frame)
	local node = embeddedBy[frame]
	if node and not embedding then
		node:PlaceEmbedded()
	end
end

-- An embedded button's `look`: "icon" shows only its icon, filling the box (its dark rim cropped), every other
-- texture of the button transparent (its ring, highlight, pushed and quality art: alpha 0, since Blizzard shows and
-- hides them itself), its texts kept (a bag's free slots); nil, the button as Blizzard draws it. The icon is the
-- button's `icon`/`Icon` field or its <name>IconTexture region.
local ICON_CROP = 0.07

local function iconOf(frame)
	local icon = rawget(frame, "icon") or rawget(frame, "Icon")
	if not icon then
		local name = frame:GetName()
		icon = name and _G[name .. "IconTexture"]
	end
	return type(icon) == "table" and icon.SetTexCoord and icon or nil
end

function Node:ApplyEmbedLook(iconOnly)
	local frame = self.frame
	local icon = iconOf(frame)
	local hidden = self.hiddenArt
	if iconOnly then
		hidden = hidden or {}
		self.hiddenArt = hidden
		local regions = { frame:GetRegions() } -- once per look change (rare): may allocate
		for i = 1, #regions do
			local r = regions[i]
			if r ~= icon and r:GetObjectType() == "Texture" and hidden[r] == nil then
				hidden[r] = r:GetAlpha()
				r:SetAlpha(0)
			end
		end
		if icon then
			if not self.icon0 then
				local points = {}
				for i = 1, icon:GetNumPoints() do
					points[i] = { icon:GetPoint(i) }
				end
				self.icon0 = { points = points, coords = { icon:GetTexCoord() } }
			end
			icon:ClearAllPoints()
			icon:SetAllPoints(frame)
			icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		end
	else
		self:RestoreEmbedArt()
	end
end

-- The button's own art as it was before `look` changed it.
function Node:RestoreEmbedArt()
	local hidden = self.hiddenArt
	if not hidden and not self.icon0 then
		return -- `look` never changed it
	end
	if hidden then
		for r, alpha in pairs(hidden) do
			r:SetAlpha(alpha)
		end
		self.hiddenArt = nil
	end
	local icon, saved = iconOf(self.frame), self.icon0
	if icon and saved then
		icon:ClearAllPoints()
		for i = 1, #saved.points do
			local p = saved.points[i]
			icon:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
		icon:SetTexCoord(unpack(saved.coords))
		self.icon0 = nil
	end
end

-- Give an embedded frame back as it was. A protected frame in combat can't move: Blizzard's own layout places it.
function Node:Unembed()
	local frame = self.frame
	embeddedBy[frame] = nil
	pendingEmbed[self] = nil
	self:RestoreEmbedArt()
	if InCombatLockdown() and frame:IsProtected() then
		return
	end
	embedding = true
	frame:SetParent(self.parent0)
	frame:SetScale(self.scale0)
	frame:SetAlpha(self.alpha0)
	frame:ClearAllPoints()
	local points = self.points0
	for i = 1, #points do
		local p = points[i]
		frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
	frame:SetSize(self.w0, self.h0)
	frame:SetShown(self.shown0)
	embedding = false
end

-- The tree ------------------------------------------------------------------------------------------------------

local function show(node, shown)
	if node.embedded then
		node.shown = shown
		node:PlaceEmbedded()
		return
	end
	if node.shown ~= shown then
		node.shown = shown
		local obj = node.kind == "text" and node.fs or node.frame
		if shown then
			obj:Show()
		else
			obj:Hide()
		end
	end
end

-- Round and measure the node and its subtree again at the pixel size now, from the attributes they draw.
function Node:Repixel()
	self.gen = pxGen
	-- x forgotten: its rectangle may not change in UI units, but its point snaps to the new pixel grid
	self.valid, self.natValid, self.mW, self.x = false, false, nil, nil
	if self.kind == "text" then
		self:ApplyText()
		if self.lookShadow then -- its offsets snap to the new pixel grid
			self.lookShadow = false
			self:ApplyLook()
		end
	elseif self.kind == "box" and not self.taken then
		ownColumns(self)
		Layout.Apply(self, self.a, resolve, resolveRef, px)
		self:ApplyLook()
	end
	local children = self.children
	for i = 1, self.count or 0 do
		children[i]:Repixel()
	end
end

function repixelTrees()
	for _, layer in pairs(layers) do
		layer:Repixel()
		enqueue(Layout.Invalidate(layer, true))
	end
	for _, node in pairs(takenBy) do
		node:Repixel()
		enqueue(Layout.Invalidate(node, true))
	end
end

-- A box's texts are font strings, drawn with their frame: under its child boxes, which are frames above it. A box
-- with box children holds its texts in a frame of their own above them (TEXT_LEVELS levels up: deeper than any panel
-- or window nests boxes), so a text over a box (a bar's label) shows. A box with only texts draws them itself.
local TEXT_LEVELS = 20

function Node:TextFrame()
	local tf = self.textFrame
	if not tf then
		local host = self.inner or self.frame
		tf = CreateFrame("Frame", nil, host)
		tf:SetAllPoints(host)
		self.textFrame = tf
	end
	tf:SetFrameLevel(self.frame:GetFrameLevel() + TEXT_LEVELS)
	return tf
end

function attach(child, parent)
	if child.gen ~= pxGen then
		child:Repixel() -- rounded at an older pixel size while detached
	end
	child.parent = parent
	local pf = child.kind == "text" and parent.textHost or parent.inner or parent.frame
	if child.embedded then -- its parent, level and point come with its place (PlaceEmbedded)
		child.fparent, child.x, child.shown = pf, nil, true
		return
	end
	if child.fparent ~= pf then -- a node reused under the frame it last sat in keeps it
		child.fparent = pf
		if child.kind == "text" then
			child.fs:SetParent(pf)
		else
			local frame = child.frame
			frame:SetParent(pf)
			local level = pf:GetFrameLevel() + (parent.liveModel and CHILD_LEVELS - 1 or 0)
			if frame:GetFrameLevel() <= level then
				frame:SetFrameLevel(level + 1)
				if child.textFrame then
					child:TextFrame() -- its texts' frame follows it up
				end
			end
		end
	end
	child.x = nil -- placed again in its new place (ctx.place skips the calls that wouldn't change anything)
	show(child, true)
end

local function detach(child)
	child.parent = nil
	child.x, child.valid, child.natValid = nil, false, false
	show(child, false)
end

-- A reused node's children from its previous life: those not reused elsewhere are hidden at the next Flush, unless
-- the new life attaches them here again (then nothing was hidden or shown).
function Node:DropStale()
	local children = self.children
	for i = 1, self.count do
		local child = children[i]
		children[i] = nil
		if child.parent == self then
			child.parent = nil
			nOrphans = nOrphans + 1
			orphans[nOrphans] = child
		end
	end
	self.count = 0
end

---A root: a layer of the screen, the size of UIParent, in WoW's strata order.
---@param name "screen"|"dialog"|"tooltip"
---@return OrdaenNode
function Backend:Layer(name)
	local node = layers[name]
	if node then
		return node
	end
	local strata = STRATA[name]
	if not strata then
		error("Ordaen: unknown layer " .. tostring(name), 2)
	end
	updateScreen()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata(strata)
	node = newNode("root")
	node.frame = frame
	node.w, node.h = ctx.screenW, ctx.screenH
	frame:SetScript("OnSizeChanged", function(_, w, h)
		updateScreen()
		node.w, node.h = w, h
		enqueue(Layout.Invalidate(node, true))
		Backend:Flush()
	end)
	layers[name] = node
	return node
end

---A new node from the pool, detached; it shows nothing until it's attached. A reused node draws its previous
---attributes until its first Set (or, if none comes, the next Flush) changes what differs.
---@param kind "box"|"text"
---@return OrdaenNode
function Backend:Create(kind)
	local node
	if kind == "text" then
		if nTextPool > 0 then
			node, textPool[nTextPool] = textPool[nTextPool], nil
			nTextPool = nTextPool - 1
		else
			node = newNode("text")
			local fs = getHolder():CreateFontString(nil, "ARTWORK")
			fs:SetJustifyH("LEFT")
			fs:SetJustifyV("TOP")
			fs:SetNonSpaceWrap(true)
			fs:Hide()
			node.fs, node.lookJustify, node.shown = fs, "LEFT", false
			node.natW, node.lineH = 0, 0
			node.fontSize = Theme["text.body"]
			fs:SetFont(Theme["font.body"], node.fontSize, "")
			node:ApplyLook()
		end
	else
		if nBoxPool > 0 then
			node, boxPool[nBoxPool] = boxPool[nBoxPool], nil
			nBoxPool = nBoxPool - 1
			if node.count > 0 then
				node:DropStale()
			end
		else
			node = newNode("box")
			local frame = CreateFrame("Button", nil, getHolder()) --[[@as OrdaenBackendFrame]]
			frame.node = node
			frame:Hide()
			frame:EnableMouse(false)
			frame:RegisterForClicks("AnyUp")
			frame:SetScript("OnEnter", onEnter)
			frame:SetScript("OnLeave", onLeave)
			frame:SetScript("OnMouseDown", onMouseDown)
			frame:SetScript("OnMouseUp", onMouseUp)
			frame:SetScript("OnClick", onClick)
			node.frame, node.mouse, node.shown = frame, false, false
		end
	end
	if node.released then
		node.released = nil
		if next(node.a) ~= nil then
			node.stale = true
			nStale = nStale + 1
			stale[nStale] = node
		end
	end
	return node
end

---A Blizzard frame as a node: its points, parent, scale, alpha and shown state are remembered and given back on
---Release. Its children (our boxes) are placed in it like a layer's.
---@param frame Frame
---@return OrdaenNode
function Backend:Take(frame)
	updateScreen()
	local node = newNode("root")
	node.frame, node.taken = frame, true
	node.parent0, node.scale0 = frame:GetParent(), frame:GetScale()
	node.alpha0, node.shown0 = frame:GetAlpha(), frame:IsShown()
	local points = {}
	for i = 1, frame:GetNumPoints() do
		points[i] = { frame:GetPoint(i) }
	end
	node.points0 = points
	node.w, node.h = frame:GetWidth(), frame:GetHeight()
	takenBy[frame] = node
	if not hooked[frame] then
		hooked[frame] = true
		hooksecurefunc(frame, "SetPoint", onBlizzardChange)
		hooksecurefunc(frame, "SetAlpha", onBlizzardChange)
		hooksecurefunc(frame, "Show", onBlizzardChange)
		hooksecurefunc(frame, "SetShown", onBlizzardChange)
	end
	return node
end

---A Blizzard frame as a cell of a box's grid (Ordaen Panel's bag buttons): a box node with no children of ours, laid
---out by its attributes (width, height, columnSpan, position, the offsets; opacity). It keeps its scripts, its mouse
---and its secure state: we set only its parent, one TOPLEFT point, its size and whether it shows (a protected frame in
---combat waits for the end). Blizzard placing, parenting or sizing it again is undone after its call. Release gives
---back its parent, points, size, scale, alpha and shown state; the node isn't pooled.
---@param frame Frame
---@return OrdaenNode
function Backend:Embed(frame)
	getHolder() -- the pixel size, before the first layout
	local node = newNode("box")
	node.frame, node.embedded, node.shown = frame, true, false
	node.parent0, node.scale0 = frame:GetParent(), frame:GetScale()
	node.alpha0, node.shown0 = frame:GetAlpha(), frame:IsShown()
	node.w0, node.h0 = frame:GetWidth(), frame:GetHeight()
	local points = {}
	for i = 1, frame:GetNumPoints() do
		points[i] = { frame:GetPoint(i) }
	end
	node.points0 = points
	embeddedBy[frame] = node
	if not hookedEmbed[frame] then
		hookedEmbed[frame] = true
		hooksecurefunc(frame, "SetPoint", onEmbedMoved)
		hooksecurefunc(frame, "ClearAllPoints", onEmbedMoved)
		hooksecurefunc(frame, "SetParent", onEmbedMoved)
		hooksecurefunc(frame, "SetSize", onEmbedMoved)
		frame:HookScript("OnEnter", onEmbedEnter)
		frame:HookScript("OnLeave", onEmbedLeave)
		frame:HookScript("OnMouseDown", onEmbedDown)
		frame:HookScript("OnMouseUp", onEmbedUp)
	end
	return node
end

local applyGroups -- forward: Set, SetField and Flush share it

---Copy the attributes the node uses and apply what changed: only the work of the groups that changed. The table is
---the engine's: only a frozen one is kept (node.src), since it can't change: the same frozen table again is a no-op.
---@param node OrdaenNode
---@param attributes table
function Backend:Set(node, attributes)
	---@cast node OrdaenBackendNode
	node.stale = nil
	if attributes == node.src and node.gen == pxGen then
		return
	end
	local own = node.a
	local takes = node.kind == "text" and TEXT_TAKES or node.taken and TAKEN_TAKES or node.embedded and EMBED_TAKES
		or BOX_TAKES
	local size, position, offset, content, border, look, input, text, tables =
		false, false, false, false, false, false, false, false, false
	-- What changed: the keys the new table has, then the old keys it no longer has (only when the copy holds more
	-- keys than the new table gave: node.na counts them). Both tables hold only the attributes in use, so this walks a
	-- few keys, not every key the node's kind takes. `tables`: a per-state map came or went (a theme reference, the
	-- other table value that changes often, can't hold one).
	local na, given = node.na, 0
	local k, v = next(attributes)
	while k ~= nil do
		local old = own[k]
		if takes[k] then
			given = given + 1
		end
		if old ~= v and takes[k] then
			own[k] = v
			if old == nil then
				na = na + 1
			end
			if (type(v) == "table" and rawget(v, "path") == nil) or (type(old) == "table" and rawget(old, "path") == nil) then
				tables = true
			end
			local g = GROUP[k]
			if g == OWN then
				size = true
			elseif g == POSITION then
				size, position = true, true
			elseif g == OFFSET then
				offset = true
			elseif g == CONTENT then
				content = true
			elseif g == LOOK then
				look = true
			elseif g == BORDER then
				border = true
			elseif g == TEXT then
				text = true
			else
				input = true
			end
		end
		k, v = next(attributes, k)
	end
	local key, old
	local bound = node.bound -- keys a binding writes (SetField): the static table lacks them, and they stay
	if na > given + (node.nbound or 0) then
		key, old = next(own)
	end
	while key ~= nil do
		local after = next(own, key) -- clearing a field while walking a table is allowed in Lua; adding one isn't
		if attributes[key] == nil and not (bound and bound[key]) then
			own[key] = nil
			na = na - 1
			if type(old) == "table" and rawget(old, "path") == nil then
				tables = true
			end
			local g = GROUP[key]
			if g == OWN then
				size = true
			elseif g == POSITION then
				size, position = true, true
			elseif g == OFFSET then
				offset = true
			elseif g == CONTENT then
				content = true
			elseif g == LOOK then
				look = true
			elseif g == BORDER then
				border = true
			elseif g == TEXT then
				text = true
			else
				input = true
			end
		end
		key = after
		old = after ~= nil and own[after] or nil
	end
	node.na = na
	-- a frozen table can't change: kept, so the same one again returns at once (a text's arguments list isn't
	-- covered by the freeze, so only a text without one)
	node.src = (node.kind ~= "text" or attributes.arguments == nil) and isfrozen(attributes) and attributes or nil
	if node.kind == "text" then
		local args, mine = attributes.arguments, node.args
		local n = args and #args or 0
		if n ~= node.nargs then
			text = true
		end
		for i = 1, n do
			local arg = args[i]
			if mine[i] ~= arg then
				mine[i], text = arg, true
			end
		end
		for i = n + 1, node.nargs do
			mine[i] = nil
		end
		node.nargs = n
	end
	if node.gen ~= pxGen then
		-- rounded at another pixel size: every group again, from the attributes as they now are
		node.gen = pxGen
		size, offset, content, border = true, true, true, true
		text = node.kind == "text"
		node.valid, node.natValid, node.mW = false, false, nil
	end
	if not (size or offset or content or border or look or input or text) then
		return
	end
	applyGroups(node, attributes, size, position, offset, content, border, look, input, text, tables)
end

-- The work of the attribute groups that changed (Set's, SetField's, the arguments at Flush). `attributes`: the static
-- table Set got, whose cached style may stand in for Layout.Apply; nil, or a node with bound keys, applies from the
-- node's own copy.
function applyGroups(node, attributes, size, position, offset, content, border, look, input, text, tables)
	if tables then
		node:ScanStates()
		input = true -- a per-state map makes the box take the mouse
	end
	if node.taken then
		node:ApplyTaken()
		return
	end
	local own = node.a
	-- The node's attributes are exactly the static table's (no bound key on top), so its cached style holds exactly what
	-- Apply would compute.
	local style = attributes and node.kind == "box" and not node.embedded and not node.bound and styleOf(attributes)
	if style then
		if size then
			node.wKind, node.wAmount, node.hKind, node.hAmount = style.wKind, style.wAmount, style.hKind, style.hAmount
			node.span, node.pos = style.span, style.pos
		end
		if offset then
			node.offT, node.offR, node.offB, node.offL = style.offT, style.offR, style.offB, style.offL
		end
		if content then
			node.ncols, node.colKind, node.colAmount, node.colShared = style.ncols, style.colKind, style.colAmount, true
			node.gapR, node.gapC, node.xAlign, node.yAlign = style.gapR, style.gapC, style.xAlign, style.yAlign
			node.padT, node.padR, node.padB, node.padL = style.padT, style.padR, style.padB, style.padL
		end
		if border then
			node.bwT, node.bwR, node.bwB, node.bwL = style.bwT, style.bwR, style.bwB, style.bwL
		end
	else
		if size then
			Layout.ApplySize(node, own, resolve, px)
		end
		if offset then
			badAttribute(Layout.ApplyOffsets(node, own, resolve))
		end
		if content then
			ownColumns(node)
			Layout.ApplyContent(node, own, resolve, resolveRef, px)
		end
		if border then
			Layout.ApplyBorder(node, own, resolve, resolveRef, px)
		end
	end
	local resized = text and node:ApplyText()
	if look or border then
		node:ApplyLook()
	end
	if input or look then
		node:ApplyMouse()
	end
	if size then
		enqueue(Layout.Invalidate(node, true))
		if position and node.parent then
			enqueue(Layout.Invalidate(node.parent))
		end
	else
		if offset then
			enqueue(Layout.Offsets(node))
		end
		if content or border or resized then
			enqueue(Layout.Invalidate(node))
		end
	end
end

---One attribute of a node already drawn, written by a binding: `value` (nil removes it), applied with the work of its
---group only, as a changed key in Set. The key is bound from then on: a later Set of the node's static table, which
---lacks it, keeps it. The same value again does nothing. node.src stays: the static table's identity still means
---"nothing of it changed".
---@param node OrdaenNode
---@param key string
---@param value any
function Backend:SetField(node, key, value)
	---@cast node OrdaenBackendNode
	local takes = node.kind == "text" and TEXT_TAKES or node.taken and TAKEN_TAKES or node.embedded and EMBED_TAKES
		or BOX_TAKES
	if not takes[key] then
		return
	end
	local bound = node.bound
	if not bound then
		bound = {}
		node.bound, node.nbound = bound, 0
	end
	if not bound[key] then
		bound[key] = true
		node.nbound = node.nbound + 1
	end
	local own = node.a
	local old = own[key]
	if old == value then
		return
	end
	own[key] = value
	if old == nil then
		node.na = node.na + 1
	elseif value == nil then
		node.na = node.na - 1
	end
	local tables = (type(value) == "table" and rawget(value, "path") == nil)
		or (type(old) == "table" and rawget(old, "path") == nil)
	local g = GROUP[key]
	applyGroups(node, nil, g == OWN or g == POSITION, g == POSITION, g == OFFSET, g == CONTENT, g == BORDER, g == LOOK,
		g == INPUT, g == TEXT, tables)
end

local dirtyTexts, nDirtyTexts = {}, 0 -- texts whose arguments changed, drawn at the next Flush

---A text's argument `i` (its format's i-th value), written by a binding. Drawn at the next Flush, once for all its
---arguments that changed meanwhile.
---@param node OrdaenNode
---@param i integer
---@param value any
function Backend:SetArgument(node, i, value)
	---@cast node OrdaenBackendNode
	local args = node.args
	if not args or args[i] == value then
		return
	end
	args[i] = value
	if i > node.nargs then
		node.nargs = i
	end
	if not node.argsDirty then
		node.argsDirty = true
		nDirtyTexts = nDirtyTexts + 1
		dirtyTexts[nDirtyTexts] = node
	end
end

---The ordered children of a node (the engine's reused array: copied). Nodes left out are detached.
---@param node OrdaenNode
---@param children OrdaenNode[]
---@param count integer
function Backend:SetChildren(node, children, count)
	---@cast node OrdaenBackendNode
	local mine = node.children
	if count == node.count then -- the same children in the same order: nothing to attach, detach or lay out
		local same = true
		for i = 1, count do
			local child = children[i]
			if mine[i] ~= child or child.parent ~= node then
				same = false
				break
			end
		end
		if same then
			return
		end
	end
	stamp = stamp + 1
	local boxes = false -- any child a frame of its own: then the texts go above them (Node:TextFrame)
	for i = 1, count do
		local child = children[i]
		child.mark = stamp
		boxes = boxes or child.kind ~= "text"
	end
	local host = boxes and node.kind ~= "root" and node:TextFrame() or node.inner or node.frame
	local moved = host ~= node.textHost
	node.textHost = host
	for i = 1, node.count do
		local child = mine[i]
		if child.mark ~= stamp and child.parent == node then
			detach(child)
		end
	end
	for i = 1, count do
		local child = children[i]
		mine[i] = child
		if child.parent ~= node then
			attach(child, node)
		elseif moved and child.kind == "text" then -- staying, but its texts' frame changed
			child.fparent = host
			child.fs:SetParent(host)
		end
	end
	for i = count + 1, node.count do
		mine[i] = nil
	end
	node.count = count
	enqueue(Layout.Invalidate(node))
end

---Pool the node; a taken frame is given back as it was. No WoW call: the node keeps its frame where it was and the
---attributes it last drew (its parent's SetChildren hides it if the parent stays; its children stay inside it). Only
---the references to module code go: its handlers (false, so the next Set sees a change and sets the mouse again).
---@param node OrdaenNode
function Backend:Release(node)
	---@cast node OrdaenBackendNode
	if node.taken then
		node:GiveBack()
		return
	elseif node.embedded then
		node:Unembed()
		return
	end
	if node.kind == "root" then
		return -- layers live as long as the client
	end
	local a = node.a
	if node.kind == "box" then
		if a.OnClick then
			a.OnClick = false
		end
		if a.OnEnter then
			a.OnEnter = false
		end
		if a.OnLeave then
			a.OnLeave = false
		end
		-- scratch arrays sized for a big grid don't stay with a pooled node
		local rowH, cCol = node.rowH, node.cCol
		if rowH and #rowH > 64 then
			node.colW, node.colX, node.rowH, node.rowY = nil, nil, nil, nil
		end
		if cCol and #cCol > 64 then
			node.cCol, node.cRow, node.cSpan, node.cW, node.cTw, node.cTh, node.cGiven = nil, nil, nil, nil, nil, nil, nil
		end
	end
	node.released, node.stale, node.src = true, nil, nil
	node.bound, node.nbound = nil, 0 -- its bindings went with its component
	if portraits[node] then -- it keeps its face, but no event redraws it while pooled
		portraits[node] = nil
		node.lookPortrait = nil
		portraitEvents()
	end
	node.hovered, node.pressed = false, false
	node.valid, node.natValid, node.x = false, false, nil
	node.lw, node.lh, node.nhW, node.mW = nil, nil, nil, nil
	if node.kind == "text" then
		nTextPool = nTextPool + 1
		textPool[nTextPool] = node
	else
		nBoxPool = nBoxPool + 1
		boxPool[nBoxPool] = node
	end
end

local function attached(node)
	while node do
		if node.kind == "root" then
			return true
		end
		node = node.parent
	end
	return false
end

---End of every scheduler flush: draw what reused nodes didn't get a Set for, lay out and place what changed, and hide
---the children reused nodes held before that their new life didn't take.
function Backend:Flush()
	if nDirtyTexts > 0 then
		for i = 1, nDirtyTexts do
			local node = dirtyTexts[i]
			dirtyTexts[i] = nil
			node.argsDirty = nil
			if not node.released then
				applyGroups(node, nil, false, false, false, false, false, false, false, true, false)
			end
		end
		nDirtyTexts = 0
	end
	if nStale > 0 then
		for i = 1, nStale do
			local node = stale[i]
			stale[i] = nil
			if node.stale and not node.released then
				self:Set(node, EMPTY) -- its previous attributes, gone: back to the defaults
			end
		end
		nStale = 0
	end
	if nQueue > 0 then
		local i = 1
		while i <= nQueue do -- a layout may queue more (a restyle); the loop sees it
			local node = queue[i]
			queue[i] = nil
			node.queued = false
			if not node.released and attached(node) then
				if node.taken then
					node.w, node.h = node.frame:GetWidth(), node.frame:GetHeight()
				end
				Layout.Relayout(node, ctx)
			end
			i = i + 1
		end
		nQueue = 0
		for node in next, scrollers do
			if node.released then
				scrollers[node] = nil
			else
				node:ScrollTo(node.scrollY or 0)
			end
		end
	end
	if nOrphans > 0 then
		for i = 1, nOrphans do
			local node = orphans[i]
			orphans[i] = nil
			if node.parent == nil then
				node.x = nil
				show(node, false)
			end
		end
		nOrphans = 0
	end
end
