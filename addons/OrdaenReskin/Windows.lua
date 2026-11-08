-- Ordaen Reskin's windows: every Blizzard window and dialog in PACKS is skinned in the theme's look as soon as it
-- exists (at login, or when Blizzard loads its addon): the frame itself (UI.Dress with "window", "portraitWindow"
-- or "dialog": its border above its content, its fill under it), its tabs, close button and every standard control
-- inside it (Kit.lua). Only frame and control art goes; content (parchment, talent art, the map, lists) stays, and
-- so do clicks, scripts and sizes. Which windows and which art: the window inventory (35 windows and
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
-- the square icon tabs), the keys of children that hold content only (not scanned for controls), and `spacing`: a
-- spacing token (the theme's scale) for a window Blizzard lays out with a layout frame. Our controls' art fills them
-- edge to edge, so the space between them is the container's (no margin in textures).
-- `newLabels`: keys of Blizzard's floating «new» labels, which it anchors to a control while that control holds
-- something new: hidden, and the control's dress shows the theme's new marker instead (a gem).
-- `accent`: Blizzard's global strings whose buttons wear the accent push button (the
-- game menu's exit buttons in red). Matched by text, since the menu's pooled buttons have no names.
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
	{ name = "GameMenuFrame", kind = "dialog", spacing = "xs",
		newLabels = { "NewOptionsFrame", "NewExternalEventFrame" },
		accent = { "LOG_OUT", "LOGOUT", "EXIT_GAME", "QUIT" } },
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
---@field marked OrdaenUIDress[]|nil dresses showing the new marker (MarkNew)
---@field markedNow OrdaenUIDress[]|nil MarkNew's scratch list, reused
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

-- Blizzard's title plate on a dialog (the game menu's Header: three plate pieces and the text): the plate goes with
-- the rest of the art and the text becomes the look's engraved title (preview
-- title.html B). Nil when the frame has none.
local PLATE_PIECES = { "LeftBG", "CenterBG", "RightBG" }

---@return table|nil text Blizzard's title FontString
function Window:Title(art)
	local header = rawget(self.frame, "Header")
	local text = type(header) == "table" and rawget(header, "Text")
	if type(text) ~= "table" then
		return nil
	end
	for i = 1, #PLATE_PIECES do
		ns.Kit.Add(art, rawget(header, PLATE_PIECES[i]))
	end
	return text
end

-- The frame's own look, its tabs and close button, then every standard control inside it.
function Window:SkinAll()
	local frame = self.frame
	local art = self:Art()
	local title = self:Title(art)
	ns.Kit.Dress(frame, self:Style(), art, { borderAbove = true, title = title })
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
	local Debug = ns.Addon.Debug
	if Debug:IsEnabled() and self.pack.kind == "dialog" then
		-- a dialog's children that aren't buttons (the game menu's «new» label hangs somewhere here): name, type,
		-- shown, and what its first point is anchored to
		for _, child in ipairs({ frame:GetChildren() }) do
			if child:GetObjectType() ~= "Button" then
				local _, relative = child:GetPoint(1)
				Debug:Logf("dialog %s child %s %s shown %s anchored to %s", self.pack.name, child:GetDebugName(),
					child:GetObjectType(), tostring(child:IsShown()),
					relative and relative.GetDebugName and relative:GetDebugName() or "nothing")
			end
		end
	end
end

--- Skin the window (until that has worked once: the kit dresses each control once, so a retry after a failure only
--- does what's left), or scan it again for controls Blizzard made since, or dress it again after :Remove. In its own
--- protected call, so a failure is reported and the other windows still skin.
function Window:Apply()
	if not self.skinned then
		ns.Kit.CollectInto(self.collect, self.SkinAll, self)
		self:Space(true)
		self.skinned = true
		self:Accent()
		self:MarkNew()
		return
	end
	if self.removed then
		self.removed = false
		for i = 1, #self.dresses do
			self.dresses[i]:Apply()
			ns.Kit.Label(self.dresses[i].frame, true)
		end
		self:Space(true)
	end
	ns.Kit.CollectInto(self.collect, ns.Kit.ControlsIn, self.frame, self.skip)
	self:Accent()
	self:MarkNew()
end

--- Give the window and its controls Blizzard's look back.
function Window:Remove()
	self.removed = true
	for i = 1, #self.dresses do
		self.dresses[i]:Undress()
		ns.Kit.Label(self.dresses[i].frame, false)
	end
	self:Space(false)
	for i = 1, #(self.marked or {}) do
		self.marked[i]:SetNew(false)
		self.marked[i] = nil
	end
	for _, key in ipairs(self.pack.newLabels or {}) do
		local label = rawget(self.frame, key)
		if type(label) == "table" then
			label:SetAlpha(1)
		end
	end
end

local accentTexts -- pack -> { [text] = true }, made on first use
local ACCENTABLE = { pushButton = true, pushButtonAccent = true }

--- Dress the pack's accent buttons (by their text) in the accent role and every other dressed button in the plain
--- one; a pooled button can change its text between shows. Runs after each skin and show.
function Window:Accent()
	local names = self.pack.accent
	if not names then
		return
	end
	accentTexts = accentTexts or setmetatable({}, { __mode = "k" })
	local texts = accentTexts[self.pack]
	if not texts then
		texts = {}
		for i = 1, #names do
			local text = rawget(_G, names[i])
			if type(text) == "string" then
				texts[text] = true
			end
		end
		accentTexts[self.pack] = texts
	end
	for _, child in ipairs({ self.frame:GetChildren() }) do
		local dress = ns.Kit.DressOf(child)
		if dress and ACCENTABLE[dress.opts.style] then
			local text = child.GetText and child:GetText()
			dress:SetStyle(type(text) == "string" and texts[text] and "pushButtonAccent" or "pushButton")
		end
	end
end

--- The dress of the control a floating label marks: the control it's anchored to when that's a dressed control,
--- else (Blizzard anchors the game menu's labels to the menu itself, with an offset) the dressed button among the
--- window's children whose vertical centre is nearest the label's. Never the window's own dress.
---@param label table
---@return OrdaenUIDress|nil
function Window:ControlUnder(label)
	local _, to = label:GetPoint(1)
	if type(to) == "table" and to ~= self.frame then
		local dress = ns.Kit.DressOf(to)
		if dress then
			return dress
		end
	end
	local _, labelY = label:GetCenter()
	if not labelY then
		return nil
	end
	local best, bestDistance
	for _, child in ipairs({ self.frame:GetChildren() }) do
		local dress = child:IsShown() and ns.Kit.DressOf(child)
		if dress then
			local _, y = child:GetCenter()
			local distance = y and math.abs(y - labelY)
			if distance and (not bestDistance or distance < bestDistance) then
				best, bestDistance = dress, distance
			end
		end
	end
	return best
end

--- Follow Blizzard's «new» labels (pack.newLabels): each one shown and anchored to a control we dressed is hidden
--- (alpha 0) and that control's dress shows the new marker; controls marked last time and not now lose it (the game
--- menu reuses its pooled buttons). Runs after each skin and show, when Blizzard has placed its labels.
function Window:MarkNew()
	local keys = self.pack.newLabels
	if not keys then
		return
	end
	local marked = self.marked or {}
	self.marked = marked
	local now = self.markedNow or {}
	self.markedNow = now
	for i = #now, 1, -1 do
		now[i] = nil
	end
	for i = 1, #keys do
		local label = rawget(self.frame, keys[i])
		local Debug = ns.Addon.Debug
		if Debug:IsEnabled() and type(label) == "table" then
			local _, to = label:GetPoint(1)
			Debug:Logf("new label %s shown %s anchored to %s, dressed %s", keys[i], tostring(label:IsShown()),
				type(to) == "table" and to.GetDebugName and to:GetDebugName() or tostring(to),
				tostring(type(to) == "table" and ns.Kit.DressOf(to) ~= nil))
		end
		if type(label) == "table" and label:IsShown() then
			local dress = self:ControlUnder(label)
			if dress then
				label:SetAlpha(0)
				dress:SetNew(true)
				now[#now + 1] = dress
			end
		end
	end
	for i = 1, #marked do
		local dress, still = marked[i], false
		for j = 1, #now do
			still = still or now[j] == dress
		end
		if not still then
			dress:SetNew(false)
		end
	end
	for i = #marked, 1, -1 do
		marked[i] = nil
	end
	for i = 1, #now do
		marked[i] = now[i]
	end
end

local spacingBefore = setmetatable({}, { __mode = "k" }) -- frame -> Blizzard's spacing, while ours is set

--- The pack's spacing on a layout frame's `spacing` (the gap Blizzard's layout puts between its children), or
--- Blizzard's own back; the frame lays itself out again. Only frames that have that field (the game menu).
---@param on boolean
function Window:Space(on)
	local token, frame = self.pack.spacing, self.frame
	if not token or type(rawget(frame, "spacing")) ~= "number" then
		return
	end
	if on then
		if spacingBefore[frame] == nil then
			spacingBefore[frame] = rawget(frame, "spacing")
		end
		frame.spacing = OrdaenCore.UI.Space(token)
	elseif spacingBefore[frame] ~= nil then
		frame.spacing = spacingBefore[frame]
		spacingBefore[frame] = nil
	else
		return
	end
	if type(frame.MarkDirty) == "function" then
		frame:MarkDirty()
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
			entry.art = first:DescribeArt() -- the border pieces as drawn (to find a broken edge)
			entry.lookChildren = {}
			for _, child in ipairs({ look:GetChildren() }) do
				entry.lookChildren[#entry.lookChildren + 1] = frameState(child)
			end
		end
		out.windows[pack.name] = entry
	end
	return out
end
