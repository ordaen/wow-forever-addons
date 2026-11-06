-- OrdaenCore.UI dressing: one of Blizzard's buttons in our look, without taking it over. Blizzard's frame keeps its
-- clicks, menus and scripts and stays on top; its own art goes to alpha 0 and our block (style "iconButton" by
-- default) is drawn underneath. :Undress() gives the art back.
--
--   local dress = UI.Dress(CharacterMicroButton, { atlas = "UI-HUD-MicroMenu-CharacterInfo-Up" })
--   dress:SetIcon(nil, "UI-HUD-MicroMenu-Guild-Up")
--
-- Cost: the regions and their alphas are walked once per dress (and on :Refresh, for art Blizzard adds later);
-- the enter/leave hooks are shared functions, set once per Blizzard button.
local _, ns = ...

local Component = ns.Component

local ICON = 20 -- the "iconButton" style's padding (4 each side) around it makes the gear button's 28 px

---@class OrdaenUIDressOpts
---@field icon string|number|nil texture path or file ID of the icon
---@field atlas string|nil atlas of the icon (instead of `icon`)
---@field iconSize number|nil default 20
---@field style string|nil default "iconButton"
---@field clickable Frame|nil the frame that gets the mouse: default its `.Button` (modern clients), else the frame

---@class OrdaenUIDress
---@field frame Frame Blizzard's frame
---@field clickable Frame the frame that gets the mouse
---@field look OrdaenUIComponent our block, under Blizzard's frame
---@field icon OrdaenUIImage the icon element of `look`
---@field alphas table<table, number> each hidden region's alpha before dressing
---@field size number[] Blizzard's frame size before dressing
---@field dressed boolean
local Dress = {}
local DressMeta = { __index = Dress }

local byClickable = {} -- Blizzard's clickable frame -> its dress
local hooked = {} -- clickable frames whose OnEnter/OnLeave carry our hooks (HookScript can't be undone)

-- Blizzard's button gets the hover, so ours shows its highlight on request.
local function onEnter(clickable)
	local dress = byClickable[clickable]
	if dress and dress.dressed then
		dress.look:LockHighlight()
	end
end

local function onLeave(clickable)
	local dress = byClickable[clickable]
	if dress and dress.dressed then
		dress.look:UnlockHighlight()
	end
end

local hideChildren

local function hideRegions(alphas, ...)
	for i = 1, select("#", ...) do
		local region = select(i, ...)
		if alphas[region] == nil then
			alphas[region] = region:GetAlpha()
		end
		region:SetAlpha(0)
	end
end

function hideChildren(alphas, ...)
	for i = 1, select("#", ...) do
		local child = select(i, ...)
		hideRegions(alphas, child:GetRegions())
		hideChildren(alphas, child:GetChildren())
	end
end

local function hideArt(self)
	local frame = self.frame
	hideRegions(self.alphas, frame:GetRegions())
	hideChildren(self.alphas, frame:GetChildren())
end

local function childButton(frame)
	local button = rawget(frame, "Button")
	if type(button) == "table" and button.GetObjectType then
		return button
	end
	return nil
end

--- Put the look on (again, after :Undress): hide Blizzard's art, show ours under the frame.
function Dress:Apply()
	local frame, look = self.frame, self.look
	self.dressed = true
	look:SetParent(frame:GetParent())
	look:ClearAllPoints()
	look:SetPoint("CENTER", frame, "CENTER")
	look:SetFrameStrata(frame:GetFrameStrata())
	look:Show()
	local width, height = look:GetWidth(), look:GetHeight()
	frame:SetSize(width, height)
	if self.clickable ~= frame then
		self.clickable:ClearAllPoints()
		self.clickable:SetAllPoints(frame)
	end
	local level = frame:GetFrameLevel()
	look:SetFrameLevel(level > 1 and level - 1 or 1)
	if level < 2 then
		frame:SetFrameLevel(2)
	end
	hideArt(self)
end

--- Hide art Blizzard added since dressing (a new texture, a re-created child) and redraw our look.
function Dress:Refresh()
	if not self.dressed then
		return
	end
	self.look:Refresh()
	hideArt(self)
end

--- Change the icon: a texture path or file ID, or an atlas.
---@param icon string|number|nil
---@param atlas string|nil
function Dress:SetIcon(icon, atlas)
	local el = self.icon
	el.image, el.atlas = icon, atlas
	self.look:Refresh()
end

--- Give Blizzard's frame its own look back: its art's alphas and its size. Our block is hidden; :Apply() dresses
--- it again.
function Dress:Undress()
	if not self.dressed then
		return
	end
	self.dressed = false
	self.look:UnlockHighlight()
	self.look:Hide()
	for region, alpha in pairs(self.alphas) do
		region:SetAlpha(alpha)
		self.alphas[region] = nil
	end
	self.frame:SetSize(self.size[1], self.size[2])
end

--- Dress one of Blizzard's buttons in our look. The same frame dressed twice returns the first dress.
---@param frame Frame
---@param opts OrdaenUIDressOpts|nil
---@return OrdaenUIDress
function Dress.New(frame, opts)
	opts = opts or {}
	local clickable = opts.clickable or childButton(frame) or frame
	local existing = byClickable[clickable]
	if existing then
		if not existing.dressed then
			existing:Apply()
		end
		return existing
	end
	---@type OrdaenUIImage
	local icon = { image = opts.icon, atlas = opts.atlas, size = opts.iconSize or ICON }
	local look = Component.Block({ style = opts.style or "iconButton", parent = frame:GetParent(), icon })
	local self = setmetatable({
		frame = frame,
		clickable = clickable,
		look = look,
		icon = icon,
		alphas = {},
		size = { frame:GetWidth(), frame:GetHeight() },
		dressed = false,
	}, DressMeta)
	byClickable[clickable] = self
	if not hooked[clickable] then
		hooked[clickable] = true
		clickable:HookScript("OnEnter", onEnter)
		clickable:HookScript("OnLeave", onLeave)
	end
	self:Apply()
	return self
end

ns.Dress = Dress
