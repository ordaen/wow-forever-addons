-- The game's damage meter in the theme. Like Ordaen Tooltips we restyle in place and never redraw: the meter's
-- numbers are secret in combat, so only Blizzard's code may show them, and we only hook (hooksecurefunc), never
-- replace Blizzard's methods (that would taint the meter). Each session window gets the theme's panel under it
-- (UI.Dress: Blizzard's background hidden), its header texts the theme's fonts (UI.DressFont), and each bar, as
-- Blizzard sets it up, the bar texture (UI.DressBar: the theme's, or the barTexture setting) and fonts. Sizes,
-- positions, bar height and spacing stay Blizzard's and Edit Mode's.
-- Cost: no events and nothing per frame. Post-hooks on each window's InitEntry/SetupEntry (a bar shown, or reused
-- from its pool) and on DamageMeter:SetupSessionWindow (a new window); each window and bar is dressed once, and
-- its texts are looked up once.
local _, ns = ...

local Look = {}
ns.Look = Look

local UI = OrdaenCore.UI

local on = false
local barAsset -- the barTexture setting: a bar asset id
local hookedMeter = false
local windows = {} -- session window -> its dress
local bars = {} -- bar frame -> its bar dress, or false (no status bar)
local hookedWindow = {} -- session window -> true once its SetupEntry carries our hook
local texts = 0 -- texts dressed (for the dump)

local function dressText(text, style)
	if type(text) == "table" and text:IsObjectType("FontString") then
		UI.DressFont(text, style)
		texts = texts + 1
	end
end

-- Every FontString of a frame and of its child frames (a bar's name and value), once per frame.
local function dressTexts(frame, style)
	if not frame:IsObjectType("Frame") then
		return -- a texture: no texts
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") then
			UI.DressFont(region, style)
			texts = texts + 1
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		dressTexts(child, style)
	end
end

local function dressBar(bar)
	if not on or type(bar) ~= "table" or bars[bar] ~= nil then
		return
	end
	local statusBar = bar.GetStatusBar and bar:GetStatusBar()
	bars[bar] = statusBar and UI.DressBar(statusBar, barAsset) or false
	dressTexts(bar, "body")
end

-- Blizzard set up a bar for a source (the hook's first argument is the window).
local function onSetupEntry(_, bar)
	dressBar(bar)
end

-- Add a texture, or a frame's textures, to the art our panel covers.
local function addArt(art, piece)
	if type(piece) ~= "table" then
		return
	end
	if piece:IsObjectType("Texture") then
		art[#art + 1] = piece
		return
	end
	for _, region in ipairs({ piece:GetRegions() }) do
		if region:IsObjectType("Texture") then
			art[#art + 1] = region
		end
	end
end

-- Blizzard's window art under our panel: its background and its header strip (both textures on Forever).
local function windowArt(window)
	local art = {}
	addArt(art, window:GetBackground())
	addArt(art, window:GetHeader())
	return art
end

-- The header's texts: the meter type (a dropdown's label), the session timer, the "not active" line.
local function dressHeader(window)
	local dropdown = window:GetDamageMeterTypeDropdown()
	if type(dropdown) == "table" then
		dressText(dropdown.TypeName, "label")
	end
	dressText(window:GetSessionTimerFontString(), "label")
	dressText(window:GetNotActiveFontString(), "body")
end

local function dressWindow(window)
	if not on or type(window) ~= "table" then
		return
	end
	if not windows[window] then
		local dress = UI.Dress(window, { style = "panel", size = "frame", art = windowArt(window) })
		if not dress then
			return -- OrdaenCore_UI can't load (the player was told)
		end
		windows[window] = dress
		dressHeader(window)
	end
	if not hookedWindow[window] then
		-- Both run per bar (which one Blizzard's scroll box calls isn't in the API dump); dressing is once per bar.
		hookedWindow[window] = true
		hooksecurefunc(window, "InitEntry", onSetupEntry)
		hooksecurefunc(window, "SetupEntry", onSetupEntry)
	end
	window:ForEachEntryFrame(dressBar)
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
	for _, dress in pairs(windows) do
		dress:Apply()
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
	for _, dress in pairs(windows) do
		dress:Undress()
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
	for _ in pairs(windows) do
		nWindows = nWindows + 1
	end
	for _, dress in pairs(bars) do
		if dress then
			nBars = nBars + 1
		end
	end
	return { on = on, meter = _G.DamageMeter ~= nil, available = available, reason = reason, windows = nWindows,
		bars = nBars, texts = texts, barTexture = barAsset }
end
