-- The WoW drawing backend (development/framework/mvp, "Contract: engine and backend"): the engine owns the tree, this
-- file owns everything WoW. Frames and font strings come from pools and go back to them, attributes are applied with
-- only the setters whose value changed, Layout.lua places what changed at the end of each flush, and mouse states
-- (hover, pressed) restyle a box without the engine. Module code runs only through ns.Engine:Handle.
--
-- Costs: nothing per frame (no OnUpdate, no events; a layer's OnSizeChanged lays it out again), no tables per Set or
-- Flush once a node exists, text measured only when its text, size or wrapped width changes.
local _, ns = ...

local Layout = ns.Layout
local Theme = ns.Theme

local CreateFrame, UIParent, GetPhysicalScreenSize = CreateFrame, UIParent, GetPhysicalScreenSize
local InCombatLockdown, hooksecurefunc = InCombatLockdown, hooksecurefunc
local floor, ceil, max, type, rawget, tonumber, unpack = math.floor, math.ceil, math.max, type, rawget, tonumber, unpack

---A node of the tree: what Create, Layer and Take return. Opaque to the engine.
---@class OrdaenNode

---@class OrdaenBackendFrame : Button
---@field node OrdaenBackendNode

---@class OrdaenBackendNode : OrdaenNode
---@field kind "box"|"text"|"root"
---@field a table                     -- the attributes as last set (copied)
---@field frame Frame?                -- a box's pooled button, a layer's frame, a taken Blizzard frame
---@field fs FontString?              -- a text node's font string
---@field parent OrdaenBackendNode?
---@field children OrdaenBackendNode[]
---@field count integer
---@field [string] any               -- layout fields (Layout.lua's header) and caches of what was applied
local Node = {}
local NodeMeta = { __index = Node }

---@class OrdaenBackend
local Backend = {}
ns.Backend = Backend

local FONT = STANDARD_TEXT_FONT
local STRATA = { screen = "MEDIUM", dialog = "DIALOG", tooltip = "TOOLTIP" }
local JUSTIFY = { start = "LEFT", center = "CENTER", ["end"] = "RIGHT" }

-- What each attribute changes: the node's own size, its offsets (where a free node sits, not its size), its
-- content's layout, its look, its mouse handlers.
local OWN, CONTENT, LOOK, BORDER, INPUT, TEXT, POSITION, OFFSET = 1, 2, 3, 4, 5, 6, 7, 8
local GROUP = {
	width = OWN, height = OWN, columnSpan = OWN, top = OFFSET, right = OFFSET, bottom = OFFSET, left = OFFSET,
	position = POSITION,
	columns = CONTENT, gap = CONTENT, padding = CONTENT, xAlign = CONTENT, yAlign = CONTENT,
	border = BORDER,
	background = LOOK, opacity = LOOK, textColor = LOOK, textAlign = LOOK,
	OnClick = INPUT, OnEnter = INPUT, OnLeave = INPUT,
	text = TEXT, textSize = TEXT, wrap = TEXT,
}
local BOX_KEYS = { "width", "height", "columnSpan", "position", "top", "right", "bottom", "left", "columns", "gap",
	"padding", "xAlign", "yAlign", "border", "background", "opacity", "OnClick", "OnEnter", "OnLeave" }
local TEXT_KEYS = { "width", "columnSpan", "position", "top", "right", "bottom", "left", "text", "textSize", "wrap",
	"textColor", "textAlign", "opacity" }
local TAKEN_KEYS = { "position", "top", "right", "bottom", "left", "opacity" }

-- Theme references and per-state maps -------------------------------------------------------------------------

local function isRef(v)
	local test = ns.IsThemeRef
	return test ~= nil and test(v)
end

-- rawget: a theme reference may build paths on index.
local function isStateMap(v)
	return rawget(v, "default") ~= nil or rawget(v, "hover") ~= nil or rawget(v, "pressed") ~= nil
end

local function resolveRef(v)
	if type(v) == "table" and isRef(v) then
		return Theme[v.path]
	end
	return v
end

-- A value as drawn now: the state's entry of a per-state map, then the theme's value of a reference.
local function resolve(node, v)
	if type(v) ~= "table" or isRef(v) then
		return resolveRef(v)
	end
	if isStateMap(v) then
		local s
		if node.pressed and rawget(v, "pressed") ~= nil then
			s = v.pressed
		elseif node.hovered and rawget(v, "hover") ~= nil then
			s = v.hover
		else
			s = rawget(v, "default")
		end
		return resolveRef(s)
	end
	return v
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

local function updateScreen()
	local _, physH = GetPhysicalScreenSize()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	ctx.screenW, ctx.screenH = w, h
	px = physH and physH > 0 and h / physH or 1
end

local function snap(v)
	return floor(v / px + 0.5) * px
end

-- Up to the next whole pixel: text sizes, so lines of one font stack the same number of pixels apart (12 UI units at
-- 0.94 px per unit would land 11 and 12 px apart in turn). The small margin keeps an exact pixel from rounding up.
local function pixelsUp(v)
	return ceil(v / px - 0.001) * px
end

-- The pool's hidden holder and the queue of nodes to lay out ------------------------------------------------------

local holder ---@type Frame
local boxPool, nBoxPool = {}, 0
local textPool, nTextPool = {}, 0
local queue, nQueue = {}, 0
local stamp = 0
local layers = {}
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

local function newNode(kind)
	local node = setmetatable({ kind = kind, a = {}, children = {}, count = 0, args = {}, nargs = 0 }, NodeMeta)
	node.padT, node.padR, node.padB, node.padL, node.gapR, node.gapC, node.bw = 0, 0, 0, 0, 0, 0, 0
	Layout.Columns(node, nil, resolveRef)
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

function ctx.place(node)
	local parent = node.parent
	if not parent then
		return
	end
	local x, y = snap(node.x), snap(node.y)
	if node.kind == "text" then
		local fs = node.fs
		fs:SetPoint("TOPLEFT", parent.frame, "TOPLEFT", x, -y)
		fs:SetSize(node.w, node.h)
	else
		local frame = node.frame
		frame:SetPoint("TOPLEFT", node.pos == "fixed" and UIParent or parent.frame, "TOPLEFT", x, -y)
		frame:SetSize(max(snap(node.x + node.w) - x, 0), max(snap(node.y + node.h) - y, 0))
	end
end

function ctx.measure(node, width)
	local fs = node.fs
	fs:SetWidth(width)
	local h = pixelsUp(fs:GetStringHeight())
	if node.w then
		fs:SetWidth(node.w)
	end
	return h
end

-- Applying attributes --------------------------------------------------------------------------------------------

-- Copy layout attributes into the fields Layout reads.
function Node:ApplyLayout()
	local a = self.a
	self.wKind, self.wAmount = Layout.Size(resolve(self, a.width))
	self.hKind, self.hAmount = Layout.Size(resolve(self, a.height))
	self.span = resolve(self, a.columnSpan)
	local pos = resolve(self, a.position)
	self.pos = pos
	self.offT, self.offR = resolve(self, a.top), resolve(self, a.right)
	self.offB, self.offL = resolve(self, a.bottom), resolve(self, a.left)
	if self.kind ~= "box" then
		return
	end
	Layout.Columns(self, resolve(self, a.columns), resolveRef)
	local gap = resolve(self, a.gap)
	if type(gap) == "table" then
		self.gapR, self.gapC = resolveRef(gap[1]) or 0, resolveRef(gap[2]) or 0
	else
		gap = gap or 0
		self.gapR, self.gapC = gap, gap
	end
	local pad = resolve(self, a.padding)
	if type(pad) == "table" then
		self.padT, self.padR = resolveRef(pad[1]) or 0, resolveRef(pad[2]) or 0
		self.padB, self.padL = resolveRef(pad[3]) or 0, resolveRef(pad[4]) or 0
	else
		pad = pad or 0
		self.padT, self.padR, self.padB, self.padL = pad, pad, pad, pad
	end
	local border = resolve(self, a.border)
	local bw = type(border) == "table" and resolveRef(border.width) or 0
	self.bw = bw > 0 and max(px, snap(bw)) or 0
end

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

-- Text, size and wrapping; measures the text. Returns true when its size changed (the layout must run).
function Node:ApplyText()
	local a, fs = self.a, self.fs
	local size = resolve(self, a.textSize) or Theme["text.body"]
	if size ~= self.fontSize then
		self.fontSize = size
		fs:SetFont(FONT, size, "")
	end
	local wrap = resolve(self, a.wrap) ~= false
	self.wrap = wrap
	fs:SetWordWrap(wrap)
	local text = resolve(self, a.text) or ""
	if self.nargs > 0 then
		fs:SetFormattedText(text, unpack(self.args, 1, self.nargs))
	else
		fs:SetText(text)
	end
	fs:SetWidth(0)
	local natW, lineH = pixelsUp(fs:GetStringWidth()), pixelsUp(fs:GetStringHeight())
	if self.w then
		fs:SetWidth(self.w)
	end
	self.mW = nil
	local changed = natW ~= self.natW or lineH ~= self.lineH or (self.w ~= nil and natW > self.w)
	self.natW, self.lineH = natW, lineH
	return changed
end

-- A box takes the mouse only with a handler or a per-state map, and never at opacity 0.
function Node:ApplyMouse()
	local frame = self.frame
	if self.kind ~= "box" then
		return
	end
	local a = self.a
	local want = (self.states or a.OnClick ~= nil or a.OnEnter ~= nil or a.OnLeave ~= nil) and (self.lookOpacity or 1) > 0
	if want ~= self.mouse then
		self.mouse = want
		frame:EnableMouse(want)
		if not want then
			self.hovered, self.pressed = false, false
		end
	end
end

-- Whether any attribute is a per-state map, and whether one of them is a layout attribute.
function Node:ScanStates(keys)
	local a = self.a
	local states, stateLayout = false, false
	for i = 1, #keys do
		local v = a[keys[i]]
		if type(v) == "table" and not isRef(v) and isStateMap(v) then
			states = true
			local g = GROUP[keys[i]]
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
		self:ApplyLayout()
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
	local obj = node.kind == "text" and node.fs or node.frame
	if shown then
		obj:Show()
	else
		obj:Hide()
	end
end

local function attach(child, parent)
	child.parent = parent
	local pf = parent.frame
	if child.kind == "text" then
		child.fs:SetParent(pf)
	else
		local frame = child.frame
		frame:SetParent(pf)
		frame:SetFrameLevel(pf:GetFrameLevel() + 1)
		frame:ClearAllPoints()
	end
	child.x = nil -- placed again against its new parent
	show(child, true)
end

local function detach(child)
	child.parent = nil
	child.x, child.valid, child.natValid = nil, false, false
	show(child, false)
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

---A new node from the pool, detached and hidden.
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
			node.fs, node.lookJustify = fs, "LEFT"
			node.natW, node.lineH = 0, 0
			node.fontSize = Theme["text.body"]
			fs:SetFont(FONT, node.fontSize, "")
			node:ApplyLook()
		end
		node.fs:Hide()
	else
		if nBoxPool > 0 then
			node, boxPool[nBoxPool] = boxPool[nBoxPool], nil
			nBoxPool = nBoxPool - 1
		else
			node = newNode("box")
			local frame = CreateFrame("Button", nil, getHolder()) --[[@as OrdaenBackendFrame]]
			frame.node = node
			frame:EnableMouse(false)
			frame:RegisterForClicks("AnyUp")
			frame:SetScript("OnEnter", onEnter)
			frame:SetScript("OnLeave", onLeave)
			frame:SetScript("OnMouseDown", onMouseDown)
			frame:SetScript("OnMouseUp", onMouseUp)
			frame:SetScript("OnClick", onClick)
			node.frame, node.mouse = frame, false
		end
		node.frame:Hide()
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

---Copy the attributes the node uses and apply what changed. The table is the engine's: nothing keeps it.
---@param node OrdaenNode
---@param attributes table
function Backend:Set(node, attributes)
	---@cast node OrdaenBackendNode
	local own = node.a
	local keys = node.kind == "text" and TEXT_KEYS or node.taken and TAKEN_KEYS or BOX_KEYS
	local ownChg, posChg, offsetChg, contentChg, lookChg, inputChg, textChg = false, false, false, false, false, false, false
	for i = 1, #keys do
		local k = keys[i]
		local v = attributes[k]
		if own[k] ~= v then
			own[k] = v
			local g = GROUP[k]
			if g == OWN then
				ownChg = true
			elseif g == POSITION then
				ownChg, posChg = true, true
			elseif g == OFFSET then
				offsetChg = true
			elseif g == CONTENT then
				contentChg = true
			elseif g == LOOK then
				lookChg = true
			elseif g == BORDER then
				contentChg, lookChg = true, true
			elseif g == TEXT then
				textChg = true
			else
				inputChg = true
			end
		end
	end
	if node.kind == "text" then
		local args, mine = attributes.arguments, node.args
		local n = args and #args or 0
		if n ~= node.nargs then
			textChg = true
		end
		for i = 1, n do
			local v = args[i]
			if mine[i] ~= v then
				mine[i], textChg = v, true
			end
		end
		for i = n + 1, node.nargs do
			mine[i] = nil
		end
		node.nargs = n
	end
	if not (ownChg or offsetChg or contentChg or lookChg or inputChg or textChg) then
		return
	end
	node:ScanStates(keys)
	if node.taken then
		node:ApplyTaken()
		return
	end
	if ownChg or offsetChg or contentChg then
		node:ApplyLayout()
	end
	local resized = textChg and node:ApplyText()
	if lookChg or contentChg then
		node:ApplyLook()
	end
	node:ApplyMouse()
	if ownChg then
		enqueue(Layout.Invalidate(node, true))
		if posChg and node.parent then
			enqueue(Layout.Invalidate(node.parent))
		end
	else
		if offsetChg then
			enqueue(Layout.Offsets(node))
		end
		if contentChg or resized then
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

---Detach the node and pool it; a taken frame is given back as it was. The engine releases children first.
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
	if node.parent then
		detach(node)
	else
		show(node, false)
	end
	local a = node.a
	for k in pairs(a) do
		a[k] = nil
	end
	for i = 1, node.nargs do
		node.args[i] = nil
	end
	for i = 1, node.count do
		local child = node.children[i]
		if child.parent == node then
			detach(child)
		end
		node.children[i] = nil
	end
	node.nargs, node.count = 0, 0
	node.w, node.h, node.lw, node.lh, node.nhW, node.mW = nil, nil, nil, nil, nil, nil
	node.states, node.stateLayout, node.hovered, node.pressed = false, false, false, false
	-- Back to the defaults: the engine sets nothing on a node whose attributes are all empty.
	node:ApplyLayout()
	node:ApplyLook()
	if node.kind == "text" then
		node.fs:SetText("")
		node.natW, node.lineH = 0, 0
		nTextPool = nTextPool + 1
		textPool[nTextPool] = node
	else
		node:ApplyMouse()
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

---End of every scheduler flush: lay out and place what changed.
function Backend:Flush()
	if nQueue == 0 then
		return
	end
	local i = 1
	while i <= nQueue do -- a layout may queue more (a restyle); the loop sees it
		local node = queue[i]
		queue[i] = nil
		node.queued = false
		if attached(node) then
			if node.taken then
				node.w, node.h = node.frame:GetWidth(), node.frame:GetHeight()
			end
			Layout.Relayout(node, ctx)
		end
		i = i + 1
	end
	nQueue = 0
end
