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
local floor, ceil, max, type, rawget, tonumber, unpack = math.floor, math.ceil, math.max, type, rawget, tonumber, unpack
local find = string.find
local createTable = table.create

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

local FONT = STANDARD_TEXT_FONT
local STRATA = { screen = "MEDIUM", dialog = "DIALOG", tooltip = "TOOLTIP" }
local JUSTIFY = { start = "LEFT", center = "CENTER", ["end"] = "RIGHT" }
local EMPTY = {}

-- What each attribute changes: the node's own size, its offsets (where a free node sits, not its size), its
-- content's layout, its border, its look, its text, its mouse handlers.
-- The layout attributes come from Layout.ATTRIBUTES (their groups and the fields they fill); the rest are listed here.
local OWN, CONTENT, LOOK, BORDER, INPUT, TEXT, POSITION, OFFSET = 1, 2, 3, 4, 5, 6, 7, 8
local next = next
local GROUP = {
	background = LOOK, opacity = LOOK, textColor = LOOK, textAlign = LOOK,
	OnClick = INPUT, OnEnter = INPUT, OnLeave = INPUT,
	text = TEXT, textSize = TEXT, wrap = TEXT,
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
for _, key in ipairs({ "background", "opacity", "OnClick", "OnEnter", "OnLeave" }) do
	BOX_KEYS[#BOX_KEYS + 1] = key
end
for _, key in ipairs({ "text", "textSize", "wrap", "textColor", "textAlign", "opacity" }) do
	TEXT_KEYS[#TEXT_KEYS + 1] = key
end
local TAKEN_KEYS = { "position", "top", "right", "bottom", "left", "opacity" }
-- The same lists as sets, so a Set walks only the keys a table has (usually a few), not every key a kind takes.
local function set(keys)
	local s = {}
	for _, key in ipairs(keys) do
		s[key] = true
	end
	return s
end
local BOX_TAKES, TEXT_TAKES, TAKEN_TAKES = set(BOX_KEYS), set(TEXT_KEYS), set(TAKEN_KEYS)

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
local lineHeights = {} -- one line of FONT at a size, in UI units on whole pixels (one value per size, not per text)

local function updateScreen()
	local _, physH = GetPhysicalScreenSize()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	ctx.screenW, ctx.screenH = w, h
	local old = px
	px = physH and physH > 0 and h / physH or 1
	if px ~= old then
		for size in pairs(lineHeights) do
			lineHeights[size] = nil
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
-- Read by Backend.dev.lua (the bench's node counts); the tables themselves, never replaced.
Backend._boxPool, Backend._textPool, Backend._layers = boxPool, textPool, layers
local takenBy = setmetatable({}, { __mode = "k" }) -- Blizzard frame -> the node holding it
local hooked = setmetatable({}, { __mode = "k" })
local pendingCombat = {} -- taken nodes whose protected frame waits for combat to end
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

-- A node table sized for its fields up front (no rehash while it fills): a text node or a box (which also has a
-- grid: children, padding, gaps, columns).
local function newNode(kind)
	local node = setmetatable(createTable(0, 64), NodeMeta)
	node.kind = kind
	if kind == "text" then
		node.a, node.args, node.nargs = createTable(0, 16), {}, 0
	else
		node.a, node.children, node.count = createTable(0, 32), {}, 0
		node.padT, node.padR, node.padB, node.padL, node.gapR, node.gapC, node.bw = 0, 0, 0, 0, 0, 0, 0
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
	node.hovered = true
	if node.states then
		node:Restyle()
	end
	local fn = node.a.OnEnter
	if fn then
		handle(fn)
	end
end

local function onLeave(frame)
	local node = frame.node
	node.hovered, node.pressed = false, false
	if node.states then
		node:Restyle()
	end
	local fn = node.a.OnLeave
	if fn then
		handle(fn)
	end
end

local function onMouseDown(frame)
	local node = frame.node
	node.pressed = true
	if node.states then
		node:Restyle()
	end
end

local function onMouseUp(frame)
	local node = frame.node
	node.pressed = false
	if node.states then
		node:Restyle()
	end
end

local function onClick(frame, button)
	local fn = frame.node.a.OnClick
	if fn then
		handle(fn, button)
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
	if node.kind == "text" then
		obj, rel, w, h = node.fs, parent.frame, node.w, node.h
	else
		obj, rel = node.frame, node.pos == "fixed" and UIParent or parent.frame
		w, h = max(snap(node.x + node.w) - x, 0), max(snap(node.y + node.h) - y, 0)
	end
	if rel ~= node.pRel or x ~= node.pX or y ~= node.pY then
		node.pRel, node.pX, node.pY = rel, x, y
		obj:SetPoint("TOPLEFT", rel, "TOPLEFT", x, -y)
	end
	if w ~= node.pW or h ~= node.pH then
		node.pW, node.pH = w, h
		obj:SetSize(w, h)
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

function Node:ApplyBorder(border)
	local frame = self.frame
	local bw = self.bw
	local edges = self.edges
	if bw == 0 or type(border) ~= "table" then
		if edges then
			for i = 1, 4 do
				edges[i]:Hide()
			end
		end
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
	edges[1]:SetHeight(bw)
	edges[2]:SetHeight(bw)
	edges[3]:SetWidth(bw)
	edges[4]:SetWidth(bw)
	local c = color(resolveRef(border.color)) or Theme["color.border"]
	for i = 1, 4 do
		edges[i]:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		edges[i]:Show()
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
	end
	local bg = resolve(self, a.background)
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
				tex:SetAllPoints(frame)
				self.bg = tex
			end
			local c = color(bg)
			if c then
				tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
			else
				tex:SetTexture(bg)
			end
			tex:Show()
		end
	end
	local border = resolve(self, a.border)
	if border ~= self.lookBorder or self.bw ~= self.lookBw then
		self.lookBorder, self.lookBw = border, self.bw
		self:ApplyBorder(border)
	end
end

-- One line of the font at `size`: the font's line height on whole pixels, measured once per size.
local function lineHeight(fs, size)
	local h = lineHeights[size]
	if not h then
		h = pixelsUp(fs:GetLineHeight())
		lineHeights[size] = h
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
	local a, fs = self.a, self.fs
	local size = resolve(self, a.textSize) or Theme["text.body"]
	if size ~= self.fontSize then
		self.fontSize = size
		fs:SetFont(FONT, size, "")
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
		natW, lineH = pixelsUp(fs:GetUnboundedStringWidth()), lineHeight(fs, size)
	end
	local oldW, oldH = self.natW, self.lineH
	self.natW, self.lineH, self.mW = natW, lineH, nil
	return Layout.TextResized(self, oldW, oldH)
end

-- A box takes the mouse only with a handler or a per-state map, and never at opacity 0.
function Node:ApplyMouse()
	if self.kind ~= "box" then
		return
	end
	local a = self.a
	local want = (self.states or a.OnClick or a.OnEnter or a.OnLeave) and (self.lookOpacity or 1) > 0 and true or false
	if want ~= self.mouse then
		self.mouse = want
		self.frame:EnableMouse(want)
		if not want then
			self.hovered, self.pressed = false, false
		end
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

-- Hover or pressed changed: resolve the per-state maps again.
function Node:Restyle()
	self:ApplyLook()
	if self.stateLayout then
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

-- The tree ------------------------------------------------------------------------------------------------------

local function show(node, shown)
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

local function attach(child, parent)
	child.parent = parent
	local pf = parent.frame
	if child.fparent ~= pf then -- a node reused under the frame it last sat in keeps it
		child.fparent = pf
		if child.kind == "text" then
			child.fs:SetParent(pf)
		else
			local frame = child.frame
			frame:SetParent(pf)
			local level = pf:GetFrameLevel()
			if frame:GetFrameLevel() <= level then
				frame:SetFrameLevel(level + 1)
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
			fs:SetFont(FONT, node.fontSize, "")
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
	node.parent0, node.scale0, node.alpha0, node.shown0 = frame:GetParent(), frame:GetScale(), frame:GetAlpha(), frame:IsShown()
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
	end
	return node
end

---Copy the attributes the node uses and apply what changed: only the work of the groups that changed. The table is
---the engine's: nothing keeps it.
---@param node OrdaenNode
---@param attributes table
function Backend:Set(node, attributes)
	---@cast node OrdaenBackendNode
	node.stale = nil
	local own = node.a
	local takes = node.kind == "text" and TEXT_TAKES or node.taken and TAKEN_TAKES or BOX_TAKES
	local size, position, offset, content, border, look, input, text, tables =
		false, false, false, false, false, false, false, false, false
	-- What changed: the keys the new table has, then the old keys it no longer has. Both tables hold only the
	-- attributes in use, so this walks a few keys, not every key the node's kind takes.
	local k, v = next(attributes)
	while k ~= nil do
		local old = own[k]
		if old ~= v and takes[k] then
			own[k] = v
			if type(v) == "table" or type(old) == "table" then
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
	local key, old = next(own)
	while key ~= nil do
		local after = next(own, key) -- clearing a field while walking a table is allowed in Lua; adding one isn't
		if attributes[key] == nil then
			own[key] = nil
			if type(old) == "table" then
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
	if node.kind == "text" then
		local args, mine = attributes.arguments, node.args
		local n = args and #args or 0
		if n ~= node.nargs then
			text = true
		end
		for i = 1, n do
			local v = args[i]
			if mine[i] ~= v then
				mine[i], text = v, true
			end
		end
		for i = n + 1, node.nargs do
			mine[i] = nil
		end
		node.nargs = n
	end
	if not (size or offset or content or border or look or input or text) then
		return
	end
	if tables then
		node:ScanStates()
		input = true -- a per-state map makes the box take the mouse
	end
	if node.taken then
		node:ApplyTaken()
		return
	end
	if size then
		Layout.ApplySize(node, own, resolve, px)
	end
	if offset then
		Layout.ApplyOffsets(node, own, resolve)
	end
	if content then
		Layout.ApplyContent(node, own, resolve, resolveRef, px)
	end
	if border then
		Layout.ApplyBorder(node, own, resolve, resolveRef, px)
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

---The ordered children of a node (the engine's reused array: copied). Nodes left out are detached.
---@param node OrdaenNode
---@param children OrdaenNode[]
---@param count integer
function Backend:SetChildren(node, children, count)
	---@cast node OrdaenBackendNode
	stamp = stamp + 1
	for i = 1, count do
		children[i].mark = stamp
	end
	local mine = node.children
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
	node.released, node.stale = true, nil
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
