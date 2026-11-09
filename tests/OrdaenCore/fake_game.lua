-- A fake WoW for the drawing backend's specs: widgets whose methods are exactly the API dump's (api/forever/CURRENT,
-- widgets.txt), so a method Forever lacks is nil here too. The methods the backend reads back (sizes, points, parent,
-- level, shown, text measures) keep state; every other dumped method does nothing. Text measures: 6 units a
-- character, a line is the font size. Also Forever's Lua extensions the backend uses: table.create, table.freeze and
-- table.isfrozen (a frozen table refuses writes through the table library's fake only; Lua 5.1 can't refuse a plain
-- assignment, so specs check frozen tables by isfrozen, as the backend does).
local Fake = {}

local CHAR = 6

local function readDump()
	local f = assert(io.open("api/forever/CURRENT", "rb"))
	local current = f:read("*l"):gsub("%s+$", "")
	f:close()
	local methods = {}
	for line in io.lines("api/forever/" .. current .. "/widgets.txt") do
		local kind, method = line:match("^([%w_]+):([%w_]+)")
		if kind then
			methods[kind] = methods[kind] or {}
			methods[kind][method] = true
		end
	end
	return methods
end
local DUMP = readDump()

local function noop() end

-- What the backend reads back, per widget.
local IMPL = {}
function IMPL.SetSize(self, w, h)
	self._w, self._h = w, h
end
function IMPL.SetWidth(self, w)
	self._w = w
end
function IMPL.SetTexCoord(self, ...)
	self._coords = { ... }
end
function IMPL.SetAtlas(self, atlas)
	self._atlas = atlas
end
function IMPL.SetHeight(self, h)
	self._h = h
end
function IMPL.GetWidth(self)
	return self._w or 0
end
function IMPL.GetHeight(self)
	return self._h or 0
end
function IMPL.SetPoint(self, point, rel, relPoint, x, y)
	self._points = self._points or {}
	self._points[1] = { point, rel, relPoint, x, y }
end
function IMPL.ClearAllPoints(self)
	self._points = {}
end
function IMPL.GetNumPoints(self)
	return self._points and #self._points or 0
end
function IMPL.GetPoint(self, i)
	local p = self._points and self._points[i]
	if p then
		return p[1], p[2], p[3], p[4], p[5]
	end
end
function IMPL.SetAllPoints(self, rel)
	self._points = { { "ALL", rel } }
end
function IMPL.SetParent(self, parent)
	self._parent = parent
end
function IMPL.GetParent(self)
	return self._parent
end
function IMPL.SetFrameLevel(self, level)
	self._level = level
end
function IMPL.GetFrameLevel(self)
	return self._level or 1
end
function IMPL.Show(self)
	self._shown = true
end
function IMPL.Hide(self)
	self._shown = false
end
function IMPL.IsShown(self)
	return self._shown ~= false
end
function IMPL.SetScript(self, name, fn)
	self._scripts = self._scripts or {}
	self._scripts[name] = fn
end
function IMPL.GetScale(self)
	return self._scale or 1
end
function IMPL.GetAlpha(self)
	return self._alpha or 1
end
function IMPL.SetAlpha(self, a)
	self._alpha = a
end
function IMPL.IsProtected(self)
	return self._protected == true -- a spec marks a frame protected
end
function IMPL.SetShown(self, shown)
	self._shown = shown and true or false
end
function IMPL.SetScale(self, scale)
	self._scale = scale
end
function IMPL.SetFont(self, _, size)
	self._size = size
end
function IMPL.SetText(self, text)
	self._text = text
end
function IMPL.SetFormattedText(self, fmt, ...)
	self._text = fmt:format(...)
end
function IMPL.GetUnboundedStringWidth(self)
	local widest = 0
	for line in ((self._text or "") .. "\n"):gmatch("([^\n]*)\n") do
		widest = math.max(widest, #line * CHAR)
	end
	return widest
end
IMPL.GetStringWidth = IMPL.GetUnboundedStringWidth
function IMPL.GetLineHeight(self)
	return self._size or 12
end
function IMPL.GetStringHeight(self)
	local _, breaks = (self._text or ""):gsub("\n", "")
	return (breaks + 1) * (self._size or 12)
end

local Widget = {}
Widget.__index = function(self, key)
	local kind = rawget(self, "_kind")
	if DUMP[kind] and DUMP[kind][key] then
		return IMPL[key] or noop
	end
	return nil
end

local function new(kind, parent)
	assert(DUMP[kind], "no widget type " .. tostring(kind) .. " in the API dump")
	return setmetatable({ _kind = kind, _parent = parent }, Widget)
end
local CREATES = { CreateTexture = "Texture", CreateFontString = "FontString", CreateMaskTexture = "MaskTexture" }
for method, kind in pairs(CREATES) do
	IMPL[method] = function(self)
		return new(kind, self)
	end
end

---Install the globals the backend reads; returns the fake UIParent. Screen: 1280 x 720 physical pixels, UIParent
---`uiHeight` units high (768 by default: UI scale 1, one pixel is 768 / 720 units).
function Fake.Install(uiHeight)
	local ui = new("Frame")
	ui._h = uiHeight or 768
	ui._w = ui._h * 16 / 9
	_G.UIParent = ui
	Fake.created = {} -- every frame CreateFrame made, in order
	_G.CreateFrame = function(kind, _, parent)
		local frame = new(kind, parent)
		Fake.created[#Fake.created + 1] = frame
		return frame
	end
	_G.GetPhysicalScreenSize = function()
		return 1280, 720
	end
	Fake.combat = false
	_G.InCombatLockdown = function()
		return Fake.combat
	end
	-- as WoW's: hooksecurefunc(object, method, fn) or hooksecurefunc(globalName, fn), fn after the original
	_G.hooksecurefunc = function(target, name, fn)
		if type(target) == "string" then
			local original = _G[target]
			_G[target] = function(...)
				original(...)
				name(...)
			end
			return
		end
		local original = target[name]
		rawset(target, name, function(...)
			original(...)
			fn(...)
		end)
	end
	_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
	-- a face drawn: the texture remembers whose (Fake.faces counts the draws)
	Fake.faces = 0
	_G.SetPortraitTexture = function(texture, unit)
		texture._portrait = unit
		Fake.faces = Fake.faces + 1
	end
	-- art: every atlas 256 x 128; the one nine-slice layout the theme names
	_G.C_Texture = {
		GetAtlasInfo = function()
			return { width = 256, height = 128 }
		end,
	}
	_G.NineSliceLayouts = { GenericMetal = { LeftEdge = { atlas = "UI-Frame-GenericMetal-EdgeLeft" } } }
	local frozen = setmetatable({}, { __mode = "k" })
	-- sized like Forever's: a constructor with n named fields sizes the hash part for n even though they are nil, so
	-- memory measured on the fake matches the game's
	local makers = {}
	table.create = table.create or function(narr, nhash)
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
	table.freeze = function(t)
		frozen[t] = true
		return t
	end
	table.isfrozen = function(t)
		return frozen[t] == true
	end
	return ui
end

---Load the backend (Theme, Layout, Backend) into a fresh namespace; returns it.
function Fake.LoadBackend()
	local ns = {}
	for _, file in ipairs({ "Theme", "Layout", "Backend" }) do
		assert(loadfile("addons/OrdaenCore/Backend/" .. file .. ".lua"))("OrdaenCore", ns)
	end
	return ns
end

---Send `event` to every frame made with an OnEvent script (what the backend registered isn't tracked: the specs
---send only events that frame waits for).
function Fake.Fire(event, ...)
	for _, frame in ipairs(Fake.created) do
		local script = frame._scripts and frame._scripts.OnEvent
		if script then
			script(frame, event, ...)
		end
	end
end

return Fake
