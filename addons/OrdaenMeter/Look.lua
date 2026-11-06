-- The game's damage meter in the theme. Like Ordaen Tooltips we restyle in place and never redraw: the meter's
-- numbers are secret in combat, so only Blizzard's code may show them, and we only hook (hooksecurefunc), never
-- replace Blizzard's methods or write Blizzard's fields (that would taint the meter). Bar height and spacing stay
-- Edit Mode's for the same reason: they feed Blizzard's own layout of the bars.
--
-- Each session window gets a WindowLook:
--   the header: one row drawn over Blizzard's header strip (UI.Dress with a block, as Ordaen Chat's input row): a
--     dropdown cell, the title area (meter type, session timer), then the session, settings and minimize cells, all
--     as tall as the strip; touching cells share one line. Blizzard's buttons keep working: their art is hidden and
--     each sits invisibly over its cell (placed after every draw), and its cell lights while it's hovered.
--   the body: the theme's panel under the bars (on Blizzard's container, so it hides when the window is minimized).
--   the bars: the bar texture (UI.DressBar: the theme's, or the barTexture setting), the theme's fonts.
-- Cost: no events and nothing per frame. Post-hooks on each window's InitEntry/SetupEntry (a bar shown, or reused
-- from its pool), SetMinimized, and DamageMeter:SetupSessionWindow (a new window); the header is drawn again only
-- when it changes (resize, hover, minimize). Each window and bar is dressed once.
local _, ns = ...

local Look = {}
ns.Look = Look

local UI = OrdaenCore.UI

local ICON = "Interface\\AddOns\\OrdaenCore\\media\\icon-"
local PAD = 6 -- between the header's texts and its cells

local on = false
local barAsset -- the barTexture setting: a bar asset id
local hookedMeter = false
local looks = {} -- session window -> its WindowLook
local bars = {} -- bar frame -> its bar dress, or false (no status bar)
local texts = 0 -- texts dressed (for the dump)
local windowOf = {} -- a header look or a Blizzard control -> its session window (never a field on theirs)

local function dressText(text, style)
	if type(text) == "table" and text:IsObjectType("FontString") then
		UI.DressFont(text, style)
		texts = texts + 1
	end
end

local function dressBar(bar)
	if not on or type(bar) ~= "table" or bars[bar] ~= nil then
		return
	end
	local statusBar = bar.GetStatusBar and bar:GetStatusBar()
	bars[bar] = statusBar and UI.DressBar(statusBar, barAsset) or false
	if statusBar then
		dressText(statusBar.Name, "body")
		dressText(statusBar.Value, "value")
	end
end

-- Blizzard set up a bar for a source (the hook's first argument is the window).
local function onSetupEntry(_, bar)
	dressBar(bar)
end

-- Where a region is anchored now, to give it back (points, size).
local function home(region)
	local saved = { width = region:GetWidth(), height = region:GetHeight() }
	for i = 1, region:GetNumPoints() do
		saved[i] = { region:GetPoint(i) }
	end
	return saved
end

local function goHome(region, saved)
	region:ClearAllPoints()
	for _, p in ipairs(saved) do
		region:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
	if region.SetSize then
		region:SetSize(saved.width, saved.height)
	end
end

-- WindowLook -------------------------------------------------------------------------------------------------------

---@class OrdaenMeterWindowLook
---@field window table the DamageMeterSessionWindow
---@field size number the header strip's height: every cell's
---@field buttons table[] Blizzard's controls, left to right: type dropdown, session, settings, minimize
---@field cells table[] their cells in the header row, in the same order
---@field title table the title area (Blizzard's type name and session timer go over it)
---@field row table the header row (our block)
---@field head OrdaenUIDress the header's look over Blizzard's strip
---@field body OrdaenUIDress|nil the panel under the bars
---@field dresses table<table, OrdaenUIDress> each control's dress (its art hidden)
---@field homes table<table, table> each moved control or text -> where Blizzard put it
---@field typeName FontString
---@field timer FontString
local WindowLook = {}
local WindowLookMeta = { __index = WindowLook }

-- A control's cell: as tall as the header, `width` wide, its glyph at half the height (none: Blizzard's text).
local function iconCell(width, height, image)
	return { style = "iconButton", width = width, height = height, padding = 0, rowAlign = "center",
		edges = { top = false, bottom = false },
		{ image = image and (ICON .. image), size = math.floor(height * 0.5), color = "color.icon", align = "center",
			valign = "center" } }
end

local function hoverOn(button)
	local look = looks[windowOf[button]]
	if look then
		look:Light(button, true)
	end
end

local function hoverOff(button)
	local look = looks[windowOf[button]]
	if look then
		look:Light(button, false)
	end
end

local function onDrawn(dressLook)
	local look = looks[windowOf[dressLook]]
	if look then
		look:Place()
	end
end

local function onMinimized(window)
	local look = looks[window]
	if look then
		look:Minimized()
	end
end

--- The look of one session window (created once per window).
---@param window table DamageMeterSessionWindow
---@return OrdaenMeterWindowLook|nil
function WindowLook.New(window)
	local header = window:GetHeader()
	local size = math.floor(header:GetHeight() + 0.5)
	local self = setmetatable({ window = window, size = size, homes = {}, dresses = {} }, WindowLookMeta)
	-- The controls, left to right, and their cells.
	self.buttons = { window:GetDamageMeterTypeDropdown(), window:GetSessionDropdown(), window:GetSettingsDropdown(),
		window:GetMinimizeButton() }
	self.cells = { iconCell(size, size, "dropdown"), iconCell(size + 12, size, nil),
		iconCell(size, size, "settings"), iconCell(size, size, "minimize") }
	self.title = {} -- the title area: Blizzard's type name and session timer, over it
	self.row = { columns = { "auto", "1fr", "auto", "auto", "auto" }, gap = 0, padding = 0, edges = { bottom = false },
		self.cells[1], self.title, self.cells[2], self.cells[3], self.cells[4] }
	self.head = UI.Dress(window, { style = "panel", size = "frame", cover = header, art = { header }, block = self.row })
	if not self.head then
		return nil -- OrdaenCore_UI can't load (the player was told)
	end
	local container = window:GetMinimizeContainer()
	self.body = UI.Dress(container, { style = "panel", size = "frame", extend = { 0, 0, -size, 0 },
		art = { window:GetBackground() } })
	windowOf[self.head.look] = window
	self.head.look:On("render", onDrawn)
	for _, button in ipairs(self.buttons) do
		windowOf[button] = window
		self.homes[button] = home(button)
		self.dresses[button] = UI.Dress(button, { style = "none", size = "frame" })
		button:HookScript("OnEnter", hoverOn)
		button:HookScript("OnLeave", hoverOff)
	end
	self.typeName = self.buttons[1].TypeName
	self.timer = window:GetSessionTimerFontString()
	for _, text in ipairs({ self.typeName, self.timer }) do
		self.homes[text] = home(text)
	end
	dressText(self.typeName, "label")
	dressText(self.timer, "label")
	dressText(window:GetSessionName(), "label")
	dressText(window:GetNotActiveFontString(), "body")
	hooksecurefunc(window, "InitEntry", onSetupEntry)
	hooksecurefunc(window, "SetupEntry", onSetupEntry)
	hooksecurefunc(window, "SetMinimized", onMinimized)
	looks[window] = self -- before the first draw: its "render" listener finds the look through the window
	self:Minimized()
	return self
end

--- Put Blizzard's controls over their cells and the header's texts into the title area (after each draw).
function WindowLook:Place()
	if not on then
		return
	end
	local look = self.head.look
	for i, button in ipairs(self.buttons) do
		local x, y, w, h = look:RectOf(self.cells[i])
		if x then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", look.frame, "TOPLEFT", x, -y)
			button:SetSize(w, h)
		end
	end
	local x, y, w, h = look:RectOf(self.title)
	if x then
		local middle = -(y + h / 2)
		self.timer:ClearAllPoints()
		self.timer:SetPoint("RIGHT", look.frame, "TOPLEFT", x + w - PAD, middle)
		self.typeName:ClearAllPoints()
		self.typeName:SetPoint("LEFT", look.frame, "TOPLEFT", x + PAD, middle)
		self.typeName:SetPoint("RIGHT", self.timer, "LEFT", -PAD, 0)
	end
end

--- Light a control's cell while Blizzard's (invisible) button is hovered.
function WindowLook:Light(button, lit)
	for i, b in ipairs(self.buttons) do
		if b == button and self.cells[i].highlight ~= lit then
			self.cells[i].highlight = lit
			self.head:Refresh()
		end
	end
end

--- Blizzard minimized or expanded the window: the minimize cell's glyph, and the header closes its own bottom line
--- while the body (with its top line) is hidden.
function WindowLook:Minimized()
	local minimized = self.window:IsMinimized() and true or false
	self.cells[4][1].image = ICON .. (minimized and "expand" or "minimize")
	self.row.edges.bottom = minimized
	self.head:Refresh()
end

function WindowLook:Apply()
	self.head:Apply()
	if self.body then
		self.body:Apply()
	end
	for _, dress in pairs(self.dresses) do
		dress:Apply()
	end
	self:Minimized()
	self:Place()
end

--- Blizzard's look back: our looks hidden, its art shown, its controls and texts where Blizzard put them.
function WindowLook:Undress()
	self.head:Undress()
	if self.body then
		self.body:Undress()
	end
	for _, dress in pairs(self.dresses) do
		dress:Undress()
	end
	for region, saved in pairs(self.homes) do
		goHome(region, saved)
	end
end

-- The meter --------------------------------------------------------------------------------------------------------

local function dressWindow(window)
	if not on or type(window) ~= "table" then
		return
	end
	if not looks[window] then
		looks[window] = WindowLook.New(window) or false -- false: OrdaenCore_UI can't load
	end
	if looks[window] then
		window:ForEachEntryFrame(dressBar)
	end
end

local function dressWindows()
	local meter = _G.DamageMeter
	if on and meter then
		meter:ForEachSessionWindow(dressWindow)
	end
end

--- Hook the meter once it exists (at Enable, or when Blizzard_DamageMeter loads later), and dress what it has.
function Look.Hook()
	local meter = _G.DamageMeter
	if not meter then
		return
	end
	if not hookedMeter then
		hookedMeter = true
		hooksecurefunc(meter, "SetupSessionWindow", dressWindows) -- a window was added
	end
	dressWindows()
end

--- Dress the meter (and whatever it shows later). `asset`: the barTexture setting.
---@param asset string|nil
function Look.Enable(asset)
	on = true
	barAsset = asset
	for _, look in pairs(looks) do
		if look then
			look:Apply()
		end
	end
	for _, dress in pairs(bars) do
		if dress then
			dress:SetAsset(asset)
			dress:Apply()
		end
	end
	Look.Hook()
end

--- The barTexture setting changed.
---@param asset string|nil
function Look.SetBarTexture(asset)
	barAsset = asset
	for _, dress in pairs(bars) do
		if dress then
			dress:SetAsset(asset)
		end
	end
end

--- Give the meter Blizzard's look back (the fonts stay the theme's until a /reload).
function Look.Disable()
	on = false
	for _, look in pairs(looks) do
		if look then
			look:Undress()
		end
	end
	for _, dress in pairs(bars) do
		if dress then
			dress:Undress()
		end
	end
end

--- What the dev-mode dump records: whether the game's meter is there and on, and what we dressed.
function Look.Describe()
	local available, reason
	if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable then
		available, reason = C_DamageMeter.IsDamageMeterAvailable()
	end
	local nWindows, nBars = 0, 0
	local header
	for window, look in pairs(looks) do
		if look then
			nWindows = nWindows + 1
			local x, y, w, h = look.head.look:RectOf(look.title)
			header = { size = look.size, minimized = window:IsMinimized() and true or false,
				title = x and { x, y, w, h } or nil }
		end
	end
	for _, dress in pairs(bars) do
		if dress then
			nBars = nBars + 1
		end
	end
	return { on = on, meter = _G.DamageMeter ~= nil, available = available, reason = reason, windows = nWindows,
		bars = nBars, texts = texts, barTexture = barAsset, header = header }
end
