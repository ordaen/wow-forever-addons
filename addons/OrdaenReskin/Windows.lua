-- Ordaen Reskin's windows: every Blizzard window and dialog in PACKS is skinned in the theme's look as soon as it
-- exists (at login, or when Blizzard loads its addon): the frame itself (UI.Dress with "window", "portraitWindow"
-- or "dialog": its border above its content, its fill under it), its tabs, close button and every standard control
-- inside it (Kit.lua). Only frame and control art goes; content (parchment, talent art, the map, lists) stays, and
-- so do clicks, scripts and sizes. Which windows and which art: the window inventory of 2026-11-07 (35 windows and
-- tabs, wow-dev-tools' companion /preview/inventory/). Prior art: EllesmereUI's window skin engine (ideas only).
--
-- Each window is skinned in its own protected call: one failing is reported and the rest still skin. A window that
-- shows again is scanned for controls Blizzard made since (lists, tabs added later); the kit dresses each control
-- once. Cost: the skinning runs at login and on ADDON_LOADED; a scan on a window's show (a rare event); nothing per
-- frame.
local _, ns = ...

local Windows = {}
ns.Windows = Windows

-- The packs: global name, kind ("window" or "dialog"), the style of its tabs ("tab" along an edge, "sideTab" for
-- the square icon tabs), and the keys of children that hold content only (not scanned for controls).
local PACKS = {
	{ name = "CharacterFrame", kind = "window", tabs = "sideTab" },
	{ name = "PlayerSpellsFrame", kind = "window", tabs = "tab" },
	{ name = "LFGParentFrame", kind = "window", tabs = "sideTab" },
	{ name = "SocialUIFrame", kind = "window", tabs = "sideTab" },
	{ name = "CommunitiesFrame", kind = "window" },
	{ name = "WorldMapFrame", kind = "window", skip = { "ScrollContainer" } },
	{ name = "ProfessionsFrame", kind = "window", tabs = "sideTab" },
	{ name = "CollectionsJournal", kind = "window", tabs = "sideTab" },
	{ name = "ClassTrainerFrame", kind = "window" },
	{ name = "GossipFrame", kind = "window" },
	{ name = "QuestFrame", kind = "window" },
	{ name = "MailFrame", kind = "window", tabs = "tab" },
	{ name = "MerchantFrame", kind = "window", tabs = "tab" },
	{ name = "SettingsPanel", kind = "window", tabs = "tab" },
	{ name = "AddonList", kind = "window" },
	{ name = "MacroFrame", kind = "window", tabs = "tab" },
	{ name = "GameMenuFrame", kind = "dialog" },
	{ name = "AddFriendFrame", kind = "dialog" },
	{ name = "ChatConfigFrame", kind = "dialog", tabs = "tab" },
	{ name = "StaticPopup1", kind = "dialog" },
	{ name = "StaticPopup2", kind = "dialog" },
	{ name = "StaticPopup3", kind = "dialog" },
	{ name = "StaticPopup4", kind = "dialog" },
}

---@class OrdaenReskinWindow
---@field pack table its PACKS entry
---@field frame Frame
---@field dresses OrdaenUIDress[] every dress made for it (the frame's and its controls')
---@field skip table<table, boolean> children not scanned
---@field skinned boolean|nil
---@field removed boolean|nil its dresses were undressed (its kind turned off)
---@field collect fun(dress: OrdaenUIDress) made once: adds a new dress to `dresses`
local Window = {}
Window.__index = Window

local byName = {} -- name -> Window
local byFrame = setmetatable({}, { __mode = "k" }) -- frame -> Window
local enabled = { window = false, dialog = false }

-- A frame's own border and fill: its NineSlice (or a dialog's Border) and its Bg and top streaks.
local function addFrameArt(frame, art)
	if type(frame) ~= "table" then
		return
	end
	ns.Kit.AddRegions(art, rawget(frame, "NineSlice"))
	ns.Kit.AddRegions(art, rawget(frame, "Border"))
	ns.Kit.Add(art, rawget(frame, "Bg"))
	ns.Kit.Add(art, rawget(frame, "TopTileStreaks"))
end

-- The window's NineSlice, on the frame or in its BorderFrame (the World Map).
local function nineSliceOf(frame)
	local nine = rawget(frame, "NineSlice")
	local borderFrame = rawget(frame, "BorderFrame")
	if not nine and type(borderFrame) == "table" then
		nine = rawget(borderFrame, "NineSlice")
	end
	return nine
end

--- The window's frame art (border and fill), never its content. Some windows keep it in a BorderFrame (the World
--- Map), and some name their fill only as a global (`<name>Bg`).
---@return Texture[]
function Window:Art()
	local frame, art = self.frame, {}
	addFrameArt(frame, art)
	addFrameArt(rawget(frame, "BorderFrame"), art)
	local bg = _G[self.pack.name .. "Bg"]
	for i = 1, #art do
		if art[i] == bg then
			return art
		end
	end
	ns.Kit.Add(art, bg)
	return art
end

--- The theme style the frame wears: "dialog" for dialogs; for windows "portraitWindow" when Blizzard draws a portrait
--- ring on it (its NineSlice's top-left corner is a PortraitMetal one), else "window".
---@return string
function Window:Style()
	if self.pack.kind == "dialog" then
		return "dialog"
	end
	local nine = nineSliceOf(self.frame)
	local corner = type(nine) == "table" and rawget(nine, "TopLeftCorner")
	local atlas = ns.Kit.IsTexture(corner) and corner:GetAtlas()
	if type(atlas) == "string" and atlas:find("Portrait", 1, true) then
		return "portraitWindow"
	end
	return "window"
end

-- The window's tabs: frame.Tabs, or the PanelTemplates globals <name>Tab1..n.
function Window:Tabs()
	local list = rawget(self.frame, "Tabs")
	if type(list) == "table" then
		return list
	end
	list = {}
	for i = 1, 12 do
		local tab = _G[self.pack.name .. "Tab" .. i]
		if type(tab) ~= "table" then
			break
		end
		list[#list + 1] = tab
	end
	return list
end

-- The close button: frame.CloseButton, <name>CloseButton, or the BorderFrame's.
function Window:CloseButton()
	local frame = self.frame
	local close = rawget(frame, "CloseButton") or _G[self.pack.name .. "CloseButton"]
	local borderFrame = rawget(frame, "BorderFrame")
	if not close and type(borderFrame) == "table" then
		close = rawget(borderFrame, "CloseButton")
	end
	return close
end

-- Every new dress made while this window skins goes into its list (so :Remove can undress them).
function Window:Collect(dress)
	self.dresses[#self.dresses + 1] = dress
end

-- The frame's own look, its tabs and close button, then every standard control inside it.
function Window:SkinAll()
	local frame = self.frame
	ns.Kit.Dress(frame, self:Style(), self:Art(), { borderAbove = true })
	local tabs = self:Tabs()
	for i = 1, #tabs do
		if not tabs[i]:IsForbidden() then
			ns.Kit.Tab(tabs[i], self.pack.tabs == "sideTab")
		end
	end
	local close = self:CloseButton()
	if type(close) == "table" and not close:IsForbidden() then
		ns.Kit.CloseButton(close)
	end
	ns.Kit.ControlsIn(frame, self.skip)
end

--- Skin the window (until that has worked once: the kit dresses each control once, so a retry after a failure only
--- does what's left), or scan it again for controls Blizzard made since, or dress it again after :Remove. In its own
--- protected call, so a failure is reported and the other windows still skin.
function Window:Apply()
	if not self.skinned then
		ns.Kit.CollectInto(self.collect, self.SkinAll, self)
		self.skinned = true
		return
	end
	if self.removed then
		self.removed = false
		for i = 1, #self.dresses do
			self.dresses[i]:Apply()
		end
	end
	ns.Kit.CollectInto(self.collect, ns.Kit.ControlsIn, self.frame, self.skip)
end

--- Give the window and its controls Blizzard's look back.
function Window:Remove()
	self.removed = true
	for i = 1, #self.dresses do
		self.dresses[i]:Undress()
	end
end

-- Report a failure the way WoW reports errors (BugSack, Blizzard's frame, our dev catcher), without stopping the
-- caller: each window in its own call.
local function protected(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
	return ok
end

local onShow -- below: it skins through skin(), which comes after newWindow

local function newWindow(pack, frame)
	local window = setmetatable({ pack = pack, frame = frame, dresses = {}, skip = {} }, Window)
	window.collect = function(dress)
		window:Collect(dress)
	end
	for _, key in ipairs(pack.skip or {}) do
		local child = rawget(frame, key)
		if type(child) == "table" then
			window.skip[child] = true
		end
	end
	byName[pack.name], byFrame[frame] = window, window
	frame:HookScript("OnShow", onShow)
	return window
end

-- Skin a window when its kind is on; in combat Blizzard's windows may be protected, so it waits for combat's end.
local function skin(window)
	if not enabled[window.pack.kind] then
		return
	end
	if InCombatLockdown() then
		ns.Addon:AfterCombat(function()
			if enabled[window.pack.kind] then
				protected(window.Apply, window)
			end
		end)
		return
	end
	protected(window.Apply, window)
end

-- Shown again: pick up the controls Blizzard made since (a list's rows, a tab added later), the same way as the first
-- time (after combat when needed). One function for every window, made once.
function onShow(frame)
	local window = byFrame[frame]
	if window then
		skin(window)
	end
end

--- Find the windows of a kind that exist now (at the start, and when an addon loads) and skin them at once.
---@param kind string "window" or "dialog"
function Windows.Watch(kind)
	for _, pack in ipairs(PACKS) do
		if pack.kind == kind and not byName[pack.name] then
			local frame = _G[pack.name]
			if type(frame) == "table" and type(frame.HookScript) == "function" and not frame:IsForbidden() then
				skin(newWindow(pack, frame))
			end
		end
	end
end

--- Turn a kind on: skin its windows that exist, and dress again the ones skinned before.
---@param kind string
function Windows.Enable(kind)
	enabled[kind] = true
	for _, window in pairs(byName) do
		if window.pack.kind == kind then
			skin(window)
		end
	end
	Windows.Watch(kind)
end

--- Turn a kind off: its windows and their controls get Blizzard's look back.
---@param kind string
function Windows.Disable(kind)
	enabled[kind] = false
	for _, window in pairs(byName) do
		if window.pack.kind == kind then
			window:Remove()
		end
	end
end

-- Where a frame is and whether it can be seen (dev dumps only): visible, effective alpha, strata, level, rectangle,
-- and its own textures and children counted.
local function frameState(frame)
	if type(frame) ~= "table" or type(frame.IsVisible) ~= "function" then
		return nil
	end
	local function plain(v)
		return (type(v) == "number" and not issecretvalue(v)) and math.floor(v * 10 + 0.5) / 10 or tostring(v)
	end
	return {
		visible = frame:IsVisible(), alpha = plain(frame:GetEffectiveAlpha()), strata = frame:GetFrameStrata(),
		level = frame:GetFrameLevel(), rect = { plain(frame:GetLeft()), plain(frame:GetBottom()),
			plain(frame:GetWidth()), plain(frame:GetHeight()) },
		regions = select("#", frame:GetRegions()), children = select("#", frame:GetChildren()),
	}
end

--- For "Send state" (dev mode): each window found, its style, how many dresses it has, and for an open window where
--- its own look and that look's children (the border overlay) are and whether they can be seen.
---@return table
function Windows.Describe()
	local out = { enabled = enabled, windows = {} }
	for _, pack in ipairs(PACKS) do
		local window = byName[pack.name]
		local entry = window and {
			kind = pack.kind,
			skinned = window.skinned or false,
			style = window:Style(),
			dresses = #window.dresses,
		} or "not loaded"
		local first = window and window.dresses[1]
		if first and window.frame:IsShown() and type(first.look) == "table" then
			local look = first.look.frame
			entry.look = frameState(look)
			entry.lookChildren = {}
			for _, child in ipairs({ look:GetChildren() }) do
				entry.lookChildren[#entry.lookChildren + 1] = frameState(child)
			end
		end
		out.windows[pack.name] = entry
	end
	return out
end
