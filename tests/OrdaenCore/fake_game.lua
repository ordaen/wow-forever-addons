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
function IMPL.GetScale()
	return 1
end
function IMPL.GetAlpha(self)
	return self._alpha or 1
end
function IMPL.SetAlpha(self, a)
	self._alpha = a
end
function IMPL.IsProtected()
	return false
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
local CREATES = { CreateTexture = "Texture", CreateFontString = "FontString" }
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
	_G.CreateFrame = function(kind, _, parent)
		return new(kind, parent)
	end
	_G.GetPhysicalScreenSize = function()
		return 1280, 720
	end
	_G.InCombatLockdown = function()
		return false
	end
	_G.hooksecurefunc = noop
	_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
	local frozen = setmetatable({}, { __mode = "k" })
	table.create = table.create or function()
		return {}
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

return Fake
