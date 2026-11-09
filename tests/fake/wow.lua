-- A fake WoW client for specs that run built addons whole: frames, textures and font strings with anchors, sizes,
-- scales, visibility and text measured by a fixed-width font; events, OnUpdate frames, slash commands, C_AddOns
-- loading built addons from a dist folder by their TOCs.
--
-- Strict like the game: every widget method and global it offers must exist in the API dump (api/forever/<CURRENT>),
-- checked when the fake is made, and anything it doesn't offer is nil. Addon code runs in an environment of its own
-- (the fake's globals, then Lua's standard library where the dump has the same name), never in busted's _G.
--
-- Layout follows WoW's anchor rules: a region's points fix its edges (one per axis, or two for a size from anchors),
-- otherwise its set size, otherwise (font strings) its text's size. Screen coordinates are physical pixels, y up from
-- the bottom; a region's GetLeft/GetTop/GetWidth are in its own units (screen pixels / effective scale), like WoW.
--
-- Text: every character is half the font size wide, a line is the font size high; text wraps at spaces when the font
-- string has a width (set or from anchors) and word wrap on. The same measure on every side keeps comparisons fair;
-- it doesn't try to match WoW's fonts.
local Fake = {}

local REPO = "."

local function readLines(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local lines = {}
	for line in f:lines() do
		lines[#lines + 1] = line
	end
	f:close()
	return lines
end

-- The dump: "Type:Method" and global names ---------------------------------------------------------------------------

local dump
local function Dump()
	if dump then
		return dump
	end
	local current = readLines(REPO .. "/api/forever/CURRENT")[1]
	local dir = REPO .. "/api/forever/" .. current .. "/"
	dump = { methods = {}, globals = {}, namespaces = {} }
	for _, line in ipairs(readLines(dir .. "widgets.txt")) do
		dump.methods[line] = true
	end
	for _, line in ipairs(readLines(dir .. "globals.txt")) do
		local name = line:match("^([^\t]+)")
		dump.globals[name] = true
	end
	for _, line in ipairs(readLines(dir .. "namespaces.txt")) do
		local name = line:match("^([^\t]+)")
		dump.namespaces[name] = true
	end
	return dump
end

-- Widgets -----------------------------------------------------------------------------------------------------------

local H = { TOPLEFT = "L", LEFT = "L", BOTTOMLEFT = "L", TOP = "C", CENTER = "C", BOTTOM = "C", TOPRIGHT = "R",
	RIGHT = "R", BOTTOMRIGHT = "R" }
local V = { TOPLEFT = "T", TOP = "T", TOPRIGHT = "T", LEFT = "M", CENTER = "M", RIGHT = "M", BOTTOMLEFT = "B",
	BOTTOM = "B", BOTTOMRIGHT = "B" }

local Region = {} -- methods every region has
local FrameMethods = {}
local TextureMethods = {}
local MaskTextureMethods = {}
local FontStringMethods = {}
local FontMethods = {} -- CreateFont's objects (the dump lists no Font type: not checked)

local function copyInto(to, from)
	for k, v in pairs(from) do
		to[k] = v
	end
	return to
end

---@class FakeWow
local Wow = {}
local WowMeta = { __index = Wow }

-- Region ------------------------------------------------------------------------------------------------------------

function Region:GetObjectType()
	return self._type
end

function Region:GetParent()
	return self._parent
end

function Region:GetName()
	return self._name
end

function Region:SetParent(parent)
	local old = self._parent
	if old == parent then
		return
	end
	local list = self._isRegion and "_regions" or "_children"
	if old then
		local t = old[list]
		for i = #t, 1, -1 do
			if t[i] == self then
				table.remove(t, i)
				break
			end
		end
	end
	self._parent = parent
	if parent then
		local t = parent[list]
		t[#t + 1] = self
	end
end

local function relativeOf(self, rel)
	if type(rel) == "string" then
		return self._wow.env[rel]
	end
	return rel
end

function Region:SetPoint(point, a, b, c, d)
	local rel, relPoint, x, y
	if type(a) == "table" or type(a) == "string" then
		rel, relPoint, x, y = relativeOf(self, a), b, c, d
		if type(relPoint) ~= "string" then -- SetPoint(point, rel, x, y)
			relPoint, x, y = point, b, c
		end
	elseif a == nil and b == nil then
		rel, relPoint, x, y = self._parent, point, 0, 0
	else
		rel, relPoint, x, y = self._parent, point, a, b
	end
	if not H[point] or not H[relPoint or point] then
		error("SetPoint: bad point " .. tostring(point) .. " / " .. tostring(relPoint), 2)
	end
	self._points[point] = { rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

function Region:SetAllPoints(rel)
	rel = relativeOf(self, rel) or self._parent
	self._points = {}
	self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0)
	self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0)
end

function Region:ClearAllPoints()
	self._points = {}
end

function Region:GetNumPoints()
	local n = 0
	for _ in pairs(self._points) do
		n = n + 1
	end
	return n
end

function Region:GetPoint(index)
	local i = 0
	for name, p in pairs(self._points) do
		i = i + 1
		if i == (index or 1) then
			return name, p.rel, p.relPoint, p.x, p.y
		end
	end
end

function Region:SetSize(w, h)
	self._w, self._h = w, h
end

function Region:SetWidth(w)
	self._w = w
end

function Region:SetHeight(h)
	self._h = h
end

function Region:Show()
	self._shown = true
end

function Region:Hide()
	self._shown = false
end

function Region:SetShown(shown)
	self._shown = not not shown
end

function Region:IsShown()
	return self._shown
end

function Region:IsVisible()
	local r = self
	while r do
		if not r._shown then
			return false
		end
		r = r._parent
	end
	return true
end

function Region:SetAlpha(a)
	self._alpha = a
end

function Region:GetAlpha()
	return self._alpha
end

function Region:GetScale()
	return self._scale
end

function Region:GetEffectiveScale()
	local s, r = 1, self
	while r do
		s = s * r._scale
		r = r._parent
	end
	return s
end

-- The region's natural size in its own units, when nothing else gives one (font strings: their text).
local function naturalSize(self)
	if self._type == "FontString" then
		return self:GetStringWidth(), self:GetStringHeight()
	end
	return 0, 0
end

-- Edges on the screen (physical pixels, y up): left, right, top, bottom; nil when not placed.
local computeRect

-- Rects are cached until anything that can move one changes (wow.gen, bumped by every mutating method): a region
-- with two points reads its relative twice, so uncached chains would cost 2^depth.
local function rect(self, depth)
	if self._root then
		local w = self._wow
		return 0, w.physW, w.physH, 0
	end
	local gen = self._wow.gen
	if self._rectGen == gen then
		local c = self._rect
		if c then
			return c[1], c[2], c[3], c[4]
		end
		return nil
	end
	local L, R, T, B = computeRect(self, depth)
	self._rectGen = gen
	if L then
		local c = self._rect or {}
		c[1], c[2], c[3], c[4] = L, R, T, B
		self._rect = c
	else
		self._rect = nil
	end
	return L, R, T, B
end

function computeRect(self, depth)
	depth = (depth or 0) + 1
	if depth > 5000 then -- lists anchor each row to the one above: chains run as long as the list
		error("fake wow: anchors loop", 0)
	end
	if not next(self._points) then
		return nil
	end
	local es = self:GetEffectiveScale()
	local L, R, C, T, B, M
	for name, p in pairs(self._points) do
		if not p.rel then
			return nil
		end
		local rl, rr, rt, rb = rect(p.rel, depth)
		if not rl then
			return nil
		end
		local hx = H[p.relPoint]
		local ax = (hx == "L" and rl or hx == "R" and rr or (rl + rr) / 2) + p.x * es
		local vy = V[p.relPoint]
		local ay = (vy == "T" and rt or vy == "B" and rb or (rt + rb) / 2) + p.y * es
		local h, v = H[name], V[name]
		if h == "L" then L = ax elseif h == "R" then R = ax else C = ax end
		if v == "T" then T = ay elseif v == "B" then B = ay else M = ay end
	end
	local nw, nh
	local function natural()
		if not nw then
			nw, nh = naturalSize(self)
		end
	end
	local w = self._w
	if not (L and R) then
		if not w or (w == 0 and self._type == "FontString") then
			natural()
			w = nw
		end
		w = w * es
		if L then
			R = L + w
		elseif R then
			L = R - w
		else
			L, R = C - w / 2, C + w / 2
		end
	end
	local h = self._h
	if not (T and B) then
		if not h or (h == 0 and self._type == "FontString") then
			natural()
			h = nh
		end
		h = h * es
		if T then
			B = T - h
		elseif B then
			T = B + h
		else
			T, B = M + h / 2, M - h / 2
		end
	end
	return L, R, T, B
end

function Region:GetLeft()
	local l = rect(self)
	return l and l / self:GetEffectiveScale()
end

function Region:GetRight()
	local _, r = rect(self)
	return r and r / self:GetEffectiveScale()
end

function Region:GetTop()
	local l, _, t = rect(self)
	return l and t / self:GetEffectiveScale()
end

function Region:GetBottom()
	local l, _, _, b = rect(self)
	return l and b / self:GetEffectiveScale()
end

function Region:GetWidth()
	local l, r = rect(self)
	if l then
		return (r - l) / self:GetEffectiveScale()
	end
	if self._w and not (self._w == 0 and self._type == "FontString") then
		return self._w
	end
	return (naturalSize(self))
end

function Region:GetHeight()
	local l, _, t, b = rect(self)
	if l then
		return (t - b) / self:GetEffectiveScale()
	end
	if self._h and not (self._h == 0 and self._type == "FontString") then
		return self._h
	end
	local _, h = naturalSize(self)
	return h
end

function Region:GetSize()
	return self:GetWidth(), self:GetHeight()
end

-- Frames ------------------------------------------------------------------------------------------------------------

copyInto(FrameMethods, Region)

function FrameMethods:SetScale(s)
	self._scale = s
end

function FrameMethods:CreateTexture(_, layer)
	return self._wow:NewRegion("Texture", self, layer)
end

function FrameMethods:CreateMaskTexture()
	return self._wow:NewRegion("MaskTexture", self, "ARTWORK")
end

function FrameMethods:CreateFontString(_, layer, template)
	local fs = self._wow:NewRegion("FontString", self, layer)
	if template then
		local font = self._wow.env[template] or self._wow:BlizzardFont(template)
		if not font then
			error("CreateFontString: no font object " .. tostring(template), 2)
		end
		fs._font, fs._size = font._font, font._size
	end
	return fs
end

function FrameMethods:GetRegions()
	return unpack(self._regions)
end

function FrameMethods:GetChildren()
	return unpack(self._children)
end

function FrameMethods:SetScript(name, fn)
	self._scripts[name] = fn
	local wow = self._wow
	if name == "OnUpdate" then
		local was = wow.updating[self]
		wow.updating[self] = fn and true or nil
		-- attached during the OnUpdate pass to a frame later in its order: it runs in this pass, as in WoW
		local pass = wow.pass
		if fn and not was and pass and self._made > pass.current then
			local list, i = pass.list, #pass.list
			while i > pass.index and list[i]._made > self._made do
				i = i - 1
			end
			table.insert(list, i + 1, self)
		end
	end
end

function FrameMethods:GetScript(name)
	return self._scripts[name]
end

function FrameMethods:HookScript(name, fn)
	local old = self._scripts[name]
	self:SetScript(name, old and function(...)
		old(...)
		fn(...)
	end or fn)
end

function FrameMethods:RegisterEvent(event)
	self._wow.listeners[event] = self._wow.listeners[event] or {}
	self._wow.listeners[event][self] = true
end

function FrameMethods:RegisterUnitEvent(event)
	self:RegisterEvent(event)
end

function FrameMethods:UnregisterEvent(event)
	local l = self._wow.listeners[event]
	if l then
		l[self] = nil
	end
end

function FrameMethods:UnregisterAllEvents()
	for _, l in pairs(self._wow.listeners) do
		l[self] = nil
	end
end

function FrameMethods:IsEventRegistered(event)
	local l = self._wow.listeners[event]
	return l and l[self] or false
end

function FrameMethods:SetFrameLevel(level)
	self._level = level
end

function FrameMethods:GetFrameLevel()
	return self._level or 0
end

function FrameMethods:SetFrameStrata(strata)
	self._strata = strata
end

function FrameMethods:GetFrameStrata()
	return self._strata or "MEDIUM"
end

function FrameMethods:SetUsingParentLevel(on)
	self._usingParentLevel = on
end

function FrameMethods:SetDrawLayerEnabled(layer, on)
	self._layersOff = self._layersOff or {}
	self._layersOff[layer] = not on
end

function FrameMethods:EnableMouse(on)
	self._mouse = on
end

function FrameMethods:IsMouseEnabled()
	return not not self._mouse
end

function FrameMethods:IsProtected()
	return self._protected == true -- a spec marks a frame protected (bag buttons can be)
end

function FrameMethods:SetClipsChildren(on)
	self._clips = on
end

function FrameMethods:DoesClipChildren()
	return not not self._clips
end

function FrameMethods:EnableMouseWheel(on)
	self._wheel = on
end

function FrameMethods:IsMouseWheelEnabled()
	return not not self._wheel
end

function FrameMethods:RegisterForDrag(...)
	self._drag = { ... }
end

local ButtonMethods = copyInto({}, FrameMethods)

function ButtonMethods:RegisterForClicks(...)
	self._clicks = { ... }
end

-- An edit box: its text, font, letters cap, insets and keyboard focus (one box has it: wow.focus). A spec types with
-- wow:Type(edit, text) (OnTextChanged with userInput) and presses Enter with wow:Enter(edit).
local EditBoxMethods = copyInto({}, FrameMethods)

function EditBoxMethods:SetText(text)
	self._text = text ~= nil and tostring(text) or ""
	local fn = self._scripts.OnTextChanged
	if fn then
		fn(self, false)
	end
end

function EditBoxMethods:GetText()
	return self._text or ""
end

function EditBoxMethods:SetFont(font, size, flags)
	self._font, self._size, self._flags = font, size, flags
	return true
end

function EditBoxMethods:GetFont()
	return self._font, self._size, self._flags
end

function EditBoxMethods:SetTextColor(r, g, b, a)
	self._textColor = { r, g, b, a }
end

function EditBoxMethods:GetTextColor()
	local c = self._textColor or { 1, 1, 1, 1 }
	return c[1], c[2], c[3], c[4]
end

function EditBoxMethods:SetJustifyH(j)
	self._justifyH = j
end

function EditBoxMethods:GetJustifyH()
	return self._justifyH or "LEFT"
end

function EditBoxMethods:SetMaxLetters(n)
	self._maxLetters = n
end

function EditBoxMethods:GetMaxLetters()
	return self._maxLetters or 0
end

function EditBoxMethods:SetTextInsets(l, r, t, b)
	self._insets = { l, r, t, b }
end

function EditBoxMethods:GetTextInsets()
	local i = self._insets or { 0, 0, 0, 0 }
	return i[1], i[2], i[3], i[4]
end

function EditBoxMethods:SetAutoFocus(on)
	self._autoFocus = on
end

function EditBoxMethods:SetFocus()
	local wow = self._wow
	if wow.focus and wow.focus ~= self then
		wow.focus:ClearFocus()
	end
	wow.focus = self
end

function EditBoxMethods:ClearFocus()
	local wow = self._wow
	if wow.focus == self then
		wow.focus = nil
	end
end

function EditBoxMethods:HasFocus()
	return self._wow.focus == self
end

-- Textures ----------------------------------------------------------------------------------------------------------

copyInto(TextureMethods, Region)

function TextureMethods:SetDrawLayer(layer)
	self._layer = layer
end

function TextureMethods:SetColorTexture(r, g, b, a)
	self._color = { r, g, b, a }
	self._texture = nil
end

function TextureMethods:SetTexture(path)
	self._texture = path
	self._color = nil
end

function TextureMethods:SetVertexColor(r, g, b, a)
	self._vertex = { r, g, b, a }
end

function TextureMethods:SetTexCoord(...)
	self._coords = { ... }
end

function TextureMethods:GetTexCoord()
	local c = self._coords
	if not c then
		return 0, 0, 0, 1, 1, 0, 1, 1
	end
	return unpack(c)
end

function TextureMethods:SetAtlas(atlas)
	self._atlas = atlas
	self._texture, self._color, self._coords = nil, nil, nil -- coordinates count within the atlas again
end

function TextureMethods:SetHorizTile(on)
	self._tileH = on
end

function TextureMethods:SetVertTile(on)
	self._tileV = on
end

function TextureMethods:SetSnapToPixelGrid(on)
	self._snap = on
end

function TextureMethods:SetTexelSnappingBias(bias)
	self._snapBias = bias
end

function TextureMethods:AddMaskTexture(mask)
	self._masks = self._masks or {}
	self._masks[mask] = true
end

function TextureMethods:RemoveMaskTexture(mask)
	if self._masks then
		self._masks[mask] = nil
	end
end

copyInto(MaskTextureMethods, Region)

function MaskTextureMethods:SetTexture(path)
	self._texture = path
end

-- Font strings ------------------------------------------------------------------------------------------------------

copyInto(FontStringMethods, Region)

function FontStringMethods:SetDrawLayer(layer)
	self._layer = layer
end

function FontStringMethods:SetFont(font, size, flags)
	self._font, self._size, self._flags = font, size, flags
	return true
end

function FontStringMethods:GetFont()
	return self._font, self._size, self._flags
end

function FontStringMethods:SetShadowOffset(x, y)
	self._shadowX, self._shadowY = x, y
end

function FontStringMethods:GetShadowOffset()
	return self._shadowX or 0, self._shadowY or 0
end

function FontStringMethods:SetShadowColor(r, g, b, a)
	self._shadowColor = { r, g, b, a }
end

function FontStringMethods:GetShadowColor()
	local c = self._shadowColor or { 0, 0, 0, 1 }
	return c[1], c[2], c[3], c[4]
end

function FontStringMethods:SetText(text)
	self._text = text ~= nil and tostring(text) or ""
end

function FontStringMethods:SetFormattedText(fmt, ...)
	self._text = string.format(fmt, ...)
end

function FontStringMethods:GetText()
	return self._text
end

function FontStringMethods:SetJustifyH(j)
	self._justifyH = j
end

function FontStringMethods:SetJustifyV(j)
	self._justifyV = j
end

function FontStringMethods:GetJustifyH()
	return self._justifyH
end

function FontStringMethods:GetJustifyV()
	return self._justifyV
end

function FontStringMethods:SetWordWrap(on)
	self._wrap = on
end

function FontStringMethods:SetNonSpaceWrap(on)
	self._nonSpaceWrap = on
end

function FontStringMethods:SetTextColor(r, g, b, a)
	self._textColor = { r, g, b, a }
end

function FontStringMethods:SetMaxLines(n)
	self._maxLines = n
end

function FontStringMethods:GetLineHeight()
	if not self._size then
		error("FontString: no font set", 2)
	end
	return self._size
end

local function charWidth(self)
	if not self._size then
		error("FontString: no font set", 3)
	end
	return self._size / 2
end

function FontStringMethods:GetUnboundedStringWidth()
	local cw, widest = charWidth(self), 0
	for line in ((self._text or "") .. "\n"):gmatch("([^\n]*)\n") do
		widest = math.max(widest, #line * cw)
	end
	return widest
end

-- The width text wraps at: set, or from two horizontal anchors; nil: no limit.
local function wrapWidth(self)
	if self._wrap == false then
		return nil
	end
	local w = self._w
	if w and w > 0 then
		return w
	end
	local p = self._points
	local hasL = p.TOPLEFT or p.LEFT or p.BOTTOMLEFT
	local hasR = p.TOPRIGHT or p.RIGHT or p.BOTTOMRIGHT
	if hasL and hasR then
		local l, r = rect(self)
		if l then
			return (r - l) / self:GetEffectiveScale()
		end
	end
	return nil
end

-- The lines the text breaks into: widest line and line count.
local function lines(self)
	local cw = charWidth(self)
	local limit = wrapWidth(self)
	local widest, count = 0, 0
	for para in ((self._text or "") .. "\n"):gmatch("([^\n]*)\n") do
		count = count + 1
		if not limit then
			widest = math.max(widest, #para * cw)
		else
			local current = 0
			for word in para:gmatch("%S+") do
				local w = #word * cw
				if current == 0 then
					current = w
				elseif current + cw + w <= limit + 1e-6 then
					current = current + cw + w
				else
					widest = math.max(widest, current)
					count, current = count + 1, w
				end
			end
			widest = math.max(widest, current)
		end
	end
	if limit then
		widest = math.min(widest, limit)
	end
	return widest, count
end

function FontStringMethods:GetStringWidth()
	if (self._text or "") == "" then
		return 0
	end
	return (lines(self))
end

function FontStringMethods:GetStringHeight()
	if (self._text or "") == "" then
		return 0
	end
	local _, count = lines(self)
	return count * self:GetLineHeight()
end

function FontStringMethods:GetNumLines()
	local _, count = lines(self)
	return count
end

-- Font objects (CreateFont)
function FontMethods:SetFont(font, size, flags)
	self._font, self._size, self._flags = font, size, flags
	return true
end

function FontMethods:GetFont()
	return self._font, self._size, self._flags
end

-- Every fake method must be one Forever has.
local CLASSES = {
	Frame = FrameMethods, Button = ButtonMethods, Texture = TextureMethods, FontString = FontStringMethods,
	MaskTexture = MaskTextureMethods, EditBox = EditBoxMethods,
}

-- Every method that can move or resize a region (or its text) starts a new rect generation.
local MUTATORS = { "SetPoint", "SetAllPoints", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale",
	"SetParent", "SetText", "SetFormattedText", "SetFont", "SetWordWrap", "SetNonSpaceWrap", "Show", "Hide",
	"SetShown" }
for _, class in pairs({ Region, FrameMethods, ButtonMethods, TextureMethods, MaskTextureMethods, FontStringMethods,
	EditBoxMethods }) do
	for _, name in ipairs(MUTATORS) do
		local fn = rawget(class, name)
		if fn then
			class[name] = function(self, ...)
				self._wow.gen = self._wow.gen + 1
				return fn(self, ...)
			end
		end
	end
end

local function checkClasses()
	local methods = Dump().methods
	local missing = {}
	for kind, class in pairs(CLASSES) do
		for name in pairs(class) do
			if not methods[kind .. ":" .. name] then
				missing[#missing + 1] = kind .. ":" .. name
			end
		end
	end
	if #missing > 0 then
		table.sort(missing)
		error("fake wow offers what Forever lacks: " .. table.concat(missing, ", "), 0)
	end
end

-- One shared metatable per widget type, holding only that type's dumped methods.
local metas
local function Metas()
	if metas then
		return metas
	end
	checkClasses()
	metas = {}
	for kind, class in pairs(CLASSES) do
		metas[kind] = { __index = class }
	end
	metas.Font = { __index = FontMethods }
	return metas
end

function Wow:NewRegion(kind, parent, layer)
	local r = setmetatable({
		_wow = self, _type = kind, _points = {}, _shown = true, _scale = 1, _alpha = 1, _layer = layer,
		_isRegion = true,
	}, Metas()[kind])
	if kind == "FontString" then
		r._justifyH, r._justifyV, r._text = "CENTER", "MIDDLE", nil
	end
	r:SetParent(parent)
	return r
end

function Wow:NewFrame(kind, name, parent)
	if not CLASSES[kind] or kind == "Texture" or kind == "FontString" or kind == "MaskTexture" then
		error("CreateFrame: the fake has no " .. tostring(kind), 3)
	end
	local f = setmetatable({
		_wow = self, _type = kind, _points = {}, _shown = true, _scale = 1, _alpha = 1, _regions = {},
		_children = {}, _scripts = {},
	}, Metas()[kind])
	f:SetParent(parent)
	if name then
		f._name = name
		self.env[name] = f
	end
	self.allFrames[f] = true
	self.made = self.made + 1
	f._made = self.made
	return f
end

--- Change the screen (physical size, UIParent's scale), as a resolution or UI scale change does: frames whose size
--- changed get OnSizeChanged, then DISPLAY_SIZE_CHANGED and UI_SCALE_CHANGED fire.
---@param physW number
---@param physH number
---@param uiScale number|nil
function Wow:SetScreen(physW, physH, uiScale)
	local before = {}
	for f in pairs(self.allFrames) do
		if f._scripts.OnSizeChanged then
			before[f] = { f:GetWidth(), f:GetHeight() }
		end
	end
	self.physW, self.physH = physW, physH
	self.gen = self.gen + 1
	if uiScale then
		self.env.UIParent._scale = uiScale
	end
	for f, size in pairs(before) do
		local w, h = f:GetWidth(), f:GetHeight()
		if w ~= size[1] or h ~= size[2] then
			self:Call(f._scripts.OnSizeChanged, f, w, h)
		end
	end
	self:Fire("DISPLAY_SIZE_CHANGED")
	self:Fire("UI_SCALE_CHANGED")
end

-- Blizzard's own font objects (GameFontNormal, ...): any the dump has, made on first use at 12 (14 for "Large",
-- 10 for "Small"); the fake doesn't know their real sizes.
function Wow:BlizzardFont(name)
	if type(name) ~= "string" or not Dump().globals[name] then
		return nil
	end
	local size = name:find("Large", 1, true) and 14 or name:find("Small", 1, true) and 10 or 12
	local font = setmetatable({ _type = "Font", _font = "Fonts\\FRIZQT__.TTF", _size = size }, Metas().Font)
	self.env[name] = font
	return font
end

-- Events, frames, time ----------------------------------------------------------------------------------------------

--- Fire a game event on every frame registered for it.
-- The player types `text` into an edit box (its whole text, as after a paste): OnTextChanged with userInput.
-- The cursor, in screen pixels from the bottom left (GetCursorPosition), as WoW gives it.
function Wow:MoveCursor(x, y)
	self.cursorX, self.cursorY = x, y
end

-- The player drags a frame registered for dragging: its OnDragStart, then OnDragStop. Between them a spec moves the
-- cursor and ticks frames.
function Wow:DragStart(frame)
	assert(frame._drag and #frame._drag > 0, "the frame isn't registered for dragging")
	local fn = frame._scripts.OnDragStart
	if fn then
		fn(frame, frame._drag[1])
	end
end

function Wow:DragStop(frame)
	local fn = frame._scripts.OnDragStop
	if fn then
		fn(frame)
	end
end

function Wow:Type(edit, text)
	edit._text = text
	local fn = edit._scripts.OnTextChanged
	if fn then
		fn(edit, true)
	end
end

-- The player presses Enter in an edit box.
function Wow:Enter(edit)
	local fn = edit._scripts.OnEnterPressed
	if fn then
		fn(edit)
	end
end

function Wow:Fire(event, ...)
	local l = self.listeners[event]
	if not l then
		return
	end
	local frames = {}
	for f in pairs(l) do
		frames[#frames + 1] = f
	end
	for _, f in ipairs(frames) do
		local handler = f._scripts.OnEvent
		if handler and l[f] then
			self:Call(handler, f, event, ...)
		end
	end
end

-- Run a script with WoW's error path: the error handler gets errors, the caller goes on.
function Wow:Call(fn, ...)
	-- Lua 5.1's xpcall passes no arguments: a closure carries them (a test, not a hot path)
	local n, args = select("#", ...), { ... }
	local ok, err = xpcall(function()
		return fn(unpack(args, 1, n))
	end, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if not ok then
		self.errorHandler(err)
	end
end

--- One frame: timers due, then every visible frame's OnUpdate.
local MEMORY_CAP_KB = 1024 * 1024 -- 1 GB: a run past it is a runaway (a loop that allocates), never a real load

local function byCreation(a, b)
	return a._made < b._made
end

function Wow:Tick()
	if collectgarbage("count") > MEMORY_CAP_KB then
		collectgarbage("collect")
		if collectgarbage("count") > MEMORY_CAP_KB then
			error("fake wow: over 1 GB of Lua memory after a collection: a runaway", 2)
		end
	end
	self.time = self.time + self.frameTime
	local due = {}
	for i = #self.timers, 1, -1 do
		local t = self.timers[i]
		if t.at <= self.time then
			table.remove(self.timers, i)
			due[#due + 1] = t
		end
	end
	for i = #due, 1, -1 do
		self:Call(due[i].fn, due[i].handle)
	end
	local frames = {}
	for f in pairs(self.updating) do
		frames[#frames + 1] = f
	end
	table.sort(frames, byCreation) -- a fixed order, as WoW's is: creation order
	local pass = { list = frames, index = 0, current = 0 }
	self.pass = pass
	while pass.index < #frames do
		pass.index = pass.index + 1
		local f = frames[pass.index]
		pass.current = f._made
		local fn = f._scripts.OnUpdate
		if fn and f:IsVisible() then
			self:Call(fn, f, self.frameTime)
		end
	end
	self.pass = nil
	self.frames = self.frames + 1
end

-- Addons: loading built ones by their TOCs --------------------------------------------------------------------------

local function parseToc(dir, name)
	local lines = readLines(dir .. "/" .. name .. "/" .. name .. ".toc")
	if not lines then
		return nil
	end
	local toc = { name = name, meta = {}, files = {} }
	for _, line in ipairs(lines) do
		local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
		if key then
			toc.meta[key] = value
		elseif line:match("%S") and not line:match("^#") then
			toc.files[#toc.files + 1] = (line:gsub("\\", "/"):gsub("%s+$", ""))
		end
	end
	return toc
end

--- Load an addon's files in TOC order (each with its name and a table of its own), then fire ADDON_LOADED.
function Wow:LoadAddOn(name)
	local addon = self.addons[name]
	if not addon then
		return false, "MISSING"
	end
	if addon.loaded then
		return true
	end
	addon.loaded = true
	for _, file in ipairs(addon.toc.files) do
		local path = self.dist .. "/" .. name .. "/" .. file
		local chunk, err = loadfile(path)
		if not chunk then
			error(err, 0)
		end
		setfenv(chunk, self.env)
		self:Call(chunk, name, addon.ns)
	end
	self:Fire("ADDON_LOADED", name)
	return true
end

-- The environment addon code runs in --------------------------------------------------------------------------------

-- Lua's own library under the names the dump has (Forever keeps most of Lua 5.1's globals and adds aliases).
local ALIASES = {
	strfind = string.find, strsub = string.sub, strlen = string.len, strlower = string.lower, strupper = string.upper,
	strrep = string.rep, strbyte = string.byte, strchar = string.char, strmatch = string.match, gsub = string.gsub,
	strgsub = string.gsub, gmatch = string.gmatch, format = string.format, tinsert = table.insert,
	tremove = table.remove, tconcat = table.concat, sort = table.sort, floor = math.floor, ceil = math.ceil,
	abs = math.abs, max = math.max, min = math.min, sqrt = math.sqrt, random = math.random, mod = math.fmod,
}

local function strsplit(sep, s, limit)
	local out, start = {}, 1
	while true do
		if limit and #out == limit - 1 then
			out[#out + 1] = s:sub(start)
			break
		end
		local i, j = s:find(sep, start, true)
		if not i then
			out[#out + 1] = s:sub(start)
			break
		end
		out[#out + 1] = s:sub(start, i - 1)
		start = j + 1
	end
	return unpack(out)
end

local function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

function Wow:MakeEnv()
	local d = Dump()
	local env = {}
	local wow = self
	local offered = {}
	local function offer(name, value)
		offered[name] = true
		env[name] = value
	end
	-- Lua's library: only names the dump has
	for name, value in pairs(_G) do
		if d.globals[name] and type(value) ~= "table" then
			env[name] = value
		end
	end
	for name, value in pairs(ALIASES) do
		if d.globals[name] then
			env[name] = value
		end
	end
	-- library tables: the dumped fields Lua has, plus Forever's own the fake makes
	local frozen = setmetatable({}, { __mode = "k" })
	-- table.create sized like Forever's: a constructor with n named fields sizes the hash part for n though they are
	-- nil (and n nils the array part), so memory measured here is the game's
	local makers = {}
	local function create(narr, nhash)
		local key = (narr or 0) .. ":" .. (nhash or 0)
		local make = makers[key]
		if not make then
			local parts = {}
			for _ = 1, narr or 0 do
				parts[#parts + 1] = "nil"
			end
			for i = 1, nhash or 0 do
				parts[#parts + 1] = "k" .. i .. " = nil"
			end
			make = assert(loadstring("return function() return { " .. table.concat(parts, ", ") .. " } end"))()
			makers[key] = make
		end
		return make()
	end
	local forever = {
		table = {
			create = create,
			-- Can't stop writes in plain Lua: frozen tables are only marked (isfrozen), which is what the code reads.
			freeze = function(t)
				frozen[t] = true
				return t
			end,
			isfrozen = function(t)
				return frozen[t] or false
			end,
			wipe = wipe,
			getcountinfo = function(t)
				local entries, integers, maxInteger = 0, 0, 0
				for k in pairs(t) do
					entries = entries + 1
					if type(k) == "number" and k >= 1 and k % 1 == 0 then
						integers = integers + 1
						if k > maxInteger then
							maxInteger = k
						end
					end
				end
				return entries, integers, maxInteger
			end,
		},
		string = { split = strsplit },
	}
	for _, lib in ipairs({ "string", "table", "math", "bit", "coroutine", "os" }) do
		if d.globals[lib] then
			local t = {}
			for name, value in pairs(_G[lib] or {}) do
				if d.namespaces[lib .. "." .. name] then
					t[name] = value
				end
			end
			for name, value in pairs(forever[lib] or {}) do
				t[name] = value
			end
			env[lib] = t
		end
	end
	env._G = env
	-- The addons share the test's Lua state: they may not stop its collector (the bench stops it around timed calls;
	-- with the real one, a long run grows without bound). "count", "collect" and "step" go through.
	env.collectgarbage = function(opt, ...)
		if opt == "stop" or opt == "restart" then
			return 0
		end
		return collectgarbage(opt, ...)
	end
	-- WoW's xpcall passes its extra arguments on (Lua 5.1's doesn't)
	env.xpcall = function(fn, handler, ...)
		local n = select("#", ...)
		if n == 0 then
			return xpcall(fn, handler)
		end
		local args = { ... }
		return xpcall(function()
			return fn(unpack(args, 1, n))
		end, handler)
	end

	-- the client
	self.errorHandler = function(e)
		wow.errors[#wow.errors + 1] = tostring(e)
	end
	offer("geterrorhandler", function()
		return wow.errorHandler
	end)
	offer("seterrorhandler", function(fn)
		wow.errorHandler = fn
	end)
	offer("CreateFrame", function(kind, name, parent)
		return wow:NewFrame(kind, name, parent)
	end)
	offer("CreateFont", function(name)
		local font = setmetatable({ _type = "Font" }, Metas().Font)
		env[name] = font
		return font
	end)
	offer("GetPhysicalScreenSize", function()
		return wow.physW, wow.physH
	end)
	offer("debugprofilestop", function()
		return os.clock() * 1000
	end)
	offer("GetCursorPosition", function()
		return wow.cursorX or 0, wow.cursorY or 0
	end)
	offer("GetTime", function()
		return wow.time
	end)
	offer("GetFramerate", function()
		return 1 / wow.frameTime
	end)
	offer("GetBuildInfo", function()
		return "1.60.1", "70862", "", 16001
	end)
	offer("GetLocale", function()
		return "enUS"
	end)
	offer("GetCVar", function()
		return nil
	end)
	offer("InCombatLockdown", function()
		return wow.combat == true -- a spec sets wow.combat, then fires PLAYER_REGEN_ENABLED when it ends
	end)
	-- a face drawn: the texture remembers whose; wow.faces counts the draws
	wow.faces = 0
	offer("SetPortraitTexture", function(texture, unit)
		texture._portrait = unit
		wow.faces = wow.faces + 1
	end)
	-- every atlas 256 x 128; the one nine-slice layout the theme names
	offer("C_Texture", {
		GetAtlasInfo = function()
			return { width = 256, height = 128 }
		end,
	})
	offer("NineSliceLayouts", { ButtonFrameTemplateNoPortrait = { LeftEdge = { atlas = "UI-Frame-Metal-EdgeLeft" } } })
	offer("issecurevariable", function()
		return false
	end)
	offer("hooksecurefunc", function(t, name, fn)
		if type(t) == "string" then
			t, name, fn = env, t, name
		end
		local old = t[name]
		t[name] = function(...)
			local r = { old(...) }
			fn(...)
			return unpack(r)
		end
	end)
	offer("securecallfunction", function(fn, ...)
		return fn(...)
	end)
	offer("strsplit", strsplit)
	offer("wipe", wipe)
	offer("date", os.date)
	offer("print", function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		wow.printed[#wow.printed + 1] = table.concat(parts, " ")
	end)
	offer("GetZoneText", function()
		return "Fake"
	end)
	offer("GetSubZoneText", function()
		return ""
	end)
	offer("UnitName", function()
		return "Fake"
	end)
	offer("GetRealmName", function()
		return "Fake"
	end)
	-- the player's money: a spec sets wow.money and fires PLAYER_MONEY
	offer("GetMoney", function()
		return wow.money or 0
	end)
	-- the player: a level 10 warrior halfway through the level, no rested experience
	offer("UnitClass", function()
		return "Warrior", "WARRIOR", 1
	end)
	offer("UnitLevel", function()
		return 10
	end)
	offer("UnitXP", function()
		return 500
	end)
	offer("UnitXPMax", function()
		return 1000
	end)
	offer("GetXPExhaustion", function()
		return nil
	end)
	-- two character friends and one Battle.net friend online (of five)
	offer("BNGetNumFriends", function()
		return 5, 1
	end)
	offer("C_FriendList", {
		GetNumOnlineFriends = function()
			return 2
		end,
	})
	offer("C_CurrencyInfo", {
		GetCoinTextureString = function(copper)
			return tostring(copper)
		end,
	})
	offer("STANDARD_TEXT_FONT", "Fonts\\FRIZQT__.TTF")
	offer("SlashCmdList", {})
	offer("C_Timer", {
		After = function(delay, fn)
			wow.timers[#wow.timers + 1] = { at = wow.time + delay, fn = fn }
		end,
		NewTicker = function(delay, fn, iterations)
			local handle = { cancelled = false }
			local n = 0
			local function run()
				if handle.cancelled then
					return
				end
				n = n + 1
				fn(handle)
				if not iterations or n < iterations then
					wow.timers[#wow.timers + 1] = { at = wow.time + delay, fn = run, handle = handle }
				end
			end
			function handle.Cancel(h)
				h.cancelled = true
			end
			wow.timers[#wow.timers + 1] = { at = wow.time + delay, fn = run, handle = handle }
			return handle
		end,
	})
	offer("C_AddOns", {
		GetNumAddOns = function()
			return #wow.order
		end,
		GetAddOnInfo = function(i)
			local addon = type(i) == "number" and wow.addons[wow.order[i]] or wow.addons[i]
			if not addon then
				return nil
			end
			return addon.toc.name, addon.toc.meta.Title
		end,
		GetAddOnMetadata = function(name, key)
			local addon = wow.addons[name]
			return addon and addon.toc.meta[key]
		end,
		IsAddOnLoaded = function(i)
			local addon = type(i) == "number" and wow.addons[wow.order[i]] or wow.addons[i]
			return addon and addon.loaded or false
		end,
		LoadAddOn = function(name)
			return wow:LoadAddOn(name)
		end,
		-- every addon is enabled for every character (2: Enum.AddOnEnableState.All)
		GetAddOnEnableState = function()
			return 2
		end,
		EnableAddOn = function() end,
	})
	-- what the fake offers must be in the dump, like everything else
	local missing = {}
	for name in pairs(offered) do
		if not d.globals[name] then
			missing[#missing + 1] = name
		end
	end
	for _, ns in ipairs({ "C_Timer", "C_AddOns", "C_Texture", "NineSliceLayouts" }) do
		for name in pairs(env[ns]) do
			if not d.namespaces[ns .. "." .. name] then
				missing[#missing + 1] = ns .. "." .. name
			end
		end
	end
	if #missing > 0 then
		table.sort(missing)
		error("fake wow offers what Forever lacks: " .. table.concat(missing, ", "), 0)
	end
	return env
end

--- A client: `dist` the built addons' folder, `addons` their names in load order (the first one loads at login,
--- the rest are there to be loaded on demand). Screen: 2560x1440 physical, UIParent at scale 0.64 (as the bench
--- machine runs).
---@param opts { dist: string, addons: string[], physW: number?, physH: number?, uiScale: number? }
function Fake.New(opts)
	local wow = setmetatable({
		dist = opts.dist, addons = {}, order = {}, listeners = {}, updating = {}, timers = {}, errors = {}, allFrames = setmetatable({}, { __mode = "k" }),
		printed = {}, time = 0, frameTime = 1 / 60, frames = 0, gen = 0, made = 0,
		physW = opts.physW or 2560, physH = opts.physH or 1440,
	}, WowMeta)
	wow.env = wow:MakeEnv()
	local world = wow:NewFrame("Frame", "WorldFrame", nil)
	world._root = true
	local ui = wow:NewFrame("Frame", "UIParent", nil)
	ui._root = true
	ui._scale = opts.uiScale or 0.64
	for _, name in ipairs(opts.addons) do
		local toc = parseToc(opts.dist, name)
		if not toc then
			error("fake wow: no built addon " .. name .. " in " .. opts.dist, 2)
		end
		wow.addons[name] = { toc = toc, ns = {}, loaded = false }
		wow.order[#wow.order + 1] = name
	end
	return wow
end

-- The root regions: their rect is the screen in their own units.
function Wow:Root()
	return self.env.UIParent
end

--- Log in: load the first addon (the others load on demand), then the login events.
function Wow:Login()
	self:LoadAddOn(self.order[1])
	self:Fire("PLAYER_LOGIN")
	self:Fire("PLAYER_ENTERING_WORLD", true, false)
	self:Fire("LOADING_SCREEN_DISABLED")
end

--- Run a slash command as the player typing it.
function Wow:Slash(line)
	local command, rest = line:match("^(/%S+)%s*(.*)$")
	for key, fn in pairs(self.env.SlashCmdList) do
		local i = 1
		while true do
			local alias = self.env["SLASH_" .. key .. i]
			if not alias then
				break
			end
			if alias:lower() == command:lower() then
				self:Call(fn, rest)
				return true
			end
			i = i + 1
		end
	end
	return false
end

return Fake
