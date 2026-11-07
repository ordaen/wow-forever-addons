-- Ordaen Reskin's windows: each Blizzard window or dialog below is dressed in the theme's look (OrdaenCore.UI,
-- UI.Dress with style "window", "portraitWindow" or "dialog"; its inner pane, frame.Inset, with "inset"). Only its
-- frame art goes: the border (NineSlice, or the dialog's Border) and the fill (Bg, the top streaks); our border is
-- drawn above the window's content (borderAbove), as Blizzard's is. Its content (parchment, talent art, the map,
-- lists) stays, and so do its clicks, scripts and size. Which windows and which art: the window inventory of
-- 2026-11-07 (35 windows and tabs, wow-dev-tools' companion /preview/inventory/).
--
-- Cost: nothing until a window is first shown. Each window gets one OnShow hook when it exists (load-on-demand
-- windows when Blizzard loads them: Watch on ADDON_LOADED, a rare event, looks up a fixed list of names); the
-- dress is made on its first show, once.
local _, ns = ...

local UI = OrdaenCore.UI

local Skins = {}
ns.Skins = Skins

---@class OrdaenReskinSkin
---@field name string the window's global name
---@field kind string "window" or "dialog": the theme style it's dressed in
---@field frame Frame
---@field dress OrdaenUIDress|nil made on the first show
---@field insetDress OrdaenUIDress|nil its inner pane's dress (frame.Inset), when it has one
---@field failed boolean|nil the UI framework couldn't load (the player was told): never tried again
local Skin = {}
Skin.__index = Skin

local byFrame = {} -- frame -> Skin
local byName = {} -- name -> Skin
local enabled = { window = false, dialog = false }

-- Every texture of a container frame (a NineSlice, a dialog's Border) into `art`.
local function addRegions(container, art)
	if type(container) ~= "table" or type(container.GetRegions) ~= "function" then
		return
	end
	for _, region in ipairs({ container:GetRegions() }) do
		if region:IsObjectType("Texture") then
			art[#art + 1] = region
		end
	end
end

local function addTexture(texture, art)
	if type(texture) == "table" and type(texture.IsObjectType) == "function" and texture:IsObjectType("Texture") then
		art[#art + 1] = texture
	end
end

-- A frame's own border and fill: its NineSlice (or a dialog's Border) and its Bg and top streaks.
local function addFrameArt(frame, art)
	if type(frame) ~= "table" then
		return
	end
	addRegions(rawget(frame, "NineSlice"), art)
	addRegions(rawget(frame, "Border"), art)
	addTexture(rawget(frame, "Bg"), art)
	addTexture(rawget(frame, "TopTileStreaks"), art)
end

--- The window's frame art (border and fill), never its content. Some windows keep it in a BorderFrame (the World
--- Map), and some name their fill only as a global (`<name>Bg`).
---@return Texture[]
function Skin:Art()
	local frame, art = self.frame, {}
	addFrameArt(frame, art)
	addFrameArt(rawget(frame, "BorderFrame"), art)
	local bg = _G[self.name .. "Bg"]
	for i = 1, #art do
		if art[i] == bg then
			return art
		end
	end
	addTexture(bg, art)
	return art
end

-- The window's NineSlice, on the frame or in its BorderFrame.
local function nineSliceOf(frame)
	local nine = rawget(frame, "NineSlice")
	local borderFrame = rawget(frame, "BorderFrame")
	if not nine and type(borderFrame) == "table" then
		nine = rawget(borderFrame, "NineSlice")
	end
	return nine
end

--- The theme style the window wears: "dialog" for dialogs; for windows "portraitWindow" when Blizzard draws a portrait
--- ring on it (its NineSlice's top-left corner is a PortraitMetal one), else "window".
---@return string
function Skin:Style()
	if self.kind == "dialog" then
		return "dialog"
	end
	local nine = nineSliceOf(self.frame)
	local corner = type(nine) == "table" and rawget(nine, "TopLeftCorner")
	local atlas = type(corner) == "table" and type(corner.GetAtlas) == "function" and corner:GetAtlas()
	if type(atlas) == "string" and atlas:find("Portrait", 1, true) then
		return "portraitWindow"
	end
	return "window"
end

-- The window's inner pane (frame.Inset, Blizzard's InsetFrameTemplate) when it has its own border; nil otherwise.
local function insetOf(frame)
	local inset = rawget(frame, "Inset")
	if type(inset) == "table" and type(inset.GetRegions) == "function" and rawget(inset, "NineSlice") then
		return inset
	end
	return nil
end

--- Dress the window (the first time) or dress it again (after :Remove). Its border goes above its content
--- (borderAbove), as Blizzard's does; its inner pane gets the theme's inset.
function Skin:Apply()
	if self.failed then
		return
	end
	if self.dress then
		self.dress:Apply()
		if self.insetDress then
			self.insetDress:Apply()
		end
		return
	end
	local style = self:Style()
	self.dress = UI.Dress(self.frame, { style = style, size = "frame", art = self:Art(), borderAbove = true })
	if not self.dress then
		self.failed = true
		return
	end
	local inset = insetOf(self.frame)
	if inset then
		local art = {}
		addFrameArt(inset, art)
		self.insetDress = UI.Dress(inset, { style = "inset", size = "frame", art = art, borderAbove = true })
	end
end

--- Give the window Blizzard's look back.
function Skin:Remove()
	if self.dress then
		self.dress:Undress()
	end
	if self.insetDress then
		self.insetDress:Undress()
	end
end

-- Shown: dress it if its kind is on and it isn't dressed yet. One function for every window, made once.
local function onShow(frame)
	local skin = byFrame[frame]
	if skin and enabled[skin.kind] and not skin.dress then
		skin:Apply()
	end
end

-- Blizzard's windows by kind, by global name. Load-on-demand ones (spellbook and talents, communities, collections,
-- professions, trainer, macros) exist once Blizzard loads them.
local WINDOWS = {
	window = {
		"CharacterFrame", "PlayerSpellsFrame", "LFGParentFrame", "SocialUIFrame", "CommunitiesFrame",
		"WorldMapFrame", "ProfessionsFrame", "CollectionsJournal", "ClassTrainerFrame", "GossipFrame", "MailFrame",
		"MerchantFrame", "SettingsPanel", "AddonList", "MacroFrame",
	},
	dialog = { "GameMenuFrame", "AddFriendFrame", "ChatConfigFrame" },
}

--- Find the windows of a kind that exist now (at the start, and when an addon loads) and hook their first show.
--- A window that is already open is dressed at once.
---@param kind string "window" or "dialog"
function Skins.Watch(kind)
	for _, name in ipairs(WINDOWS[kind]) do
		if not byName[name] then
			local frame = _G[name]
			if type(frame) == "table" and type(frame.HookScript) == "function" then
				local skin = setmetatable({ name = name, kind = kind, frame = frame }, Skin)
				byName[name], byFrame[frame] = skin, skin
				frame:HookScript("OnShow", onShow)
				if enabled[kind] and frame:IsShown() then
					skin:Apply()
				end
			end
		end
	end
end

--- Turn a kind on: watch for its windows and dress the ones already dressed once or open now.
---@param kind string
function Skins.Enable(kind)
	enabled[kind] = true
	Skins.Watch(kind)
	for _, skin in pairs(byName) do
		if skin.kind == kind and (skin.dress or skin.frame:IsShown()) then
			skin:Apply()
		end
	end
end

--- Turn a kind off: its windows get Blizzard's look back.
---@param kind string
function Skins.Disable(kind)
	enabled[kind] = false
	for _, skin in pairs(byName) do
		if skin.kind == kind then
			skin:Remove()
		end
	end
end

--- For "Send state" (dev mode): each window found, and whether it is dressed.
---@return table
function Skins.Describe()
	local out = { enabled = enabled, windows = {} }
	for kind, names in pairs(WINDOWS) do
		for _, name in ipairs(names) do
			local skin = byName[name]
			out.windows[name] = skin and {
				kind = kind,
				dressed = skin.dress ~= nil,
				style = skin.dress and skin:Style() or nil,
				inset = skin.insetDress ~= nil,
				failed = skin.failed,
				art = skin.dress and #skin:Art() or nil,
			} or "not loaded"
		end
	end
	return out
end
