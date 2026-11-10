-- Blizzard's tooltips as the game fills them (design tooltips/: Ordaen Tooltips draws its own in their place):
-- `game.Tooltip.GameTooltip` and ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2. Blizzard's tooltips stay the
-- owners of their content: Blizzard and every addon keep filling them as always (SetOwner, SetBagItem, AddLine...);
-- a module reads what they show and draws its own. While a module takes a tooltip, Ordaen keeps Blizzard's at
-- alpha 0 for every show the module draws (`wants` says which), and gives it back unchanged otherwise.
--   tip.shown        value signal: a number that changes on every show or refill, 0 while hidden (read it to re-run)
--   tip.data         the game's tooltip data for this show (GetTooltipData: type, id, lines), nil when unreadable
--   tip.owner        the frame it belongs to (the button or unit frame hovered), nil when none or unreadable
--   tip.point        Blizzard's anchor point for it ("BOTTOMRIGHT"): a view anchored by the same point to it
--                    follows Blizzard's placement (tip.frame is the game.Frame ref to anchor to)
--   tip:Take(wants)  take it: `wants(tip)` on each show says whether the module draws this one; tip:Release()
-- Safe by refusal: in combat some values are secret and some frames forbidden; anything unreadable and that show
-- stays Blizzard's. Hooks only (hooksecurefunc / HookScript), Blizzard's code untouched; nothing per frame.
local _, ns = ...

local Engine = ns.Engine
local hooksecurefunc, type, pcall = hooksecurefunc, type, pcall

local isSecret = issecretvalue or function()
	return false
end

---@class OrdaenTooltip
---@field shown OrdaenValueSignal
---@field data table|nil
---@field owner table|nil
---@field point string
---@field frame table the game.Frame ref of Blizzard's tooltip
local Tip = {}
local TipMeta = { __index = Tip }

local NATIVES = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }

-- Keep `native` at alpha 0 while we draw it (Blizzard resets the alpha on every show).
local function Hide(tip)
	tip.settingAlpha = true
	tip.native:SetAlpha(0)
	tip.settingAlpha = false
end

local function Restore(tip)
	if tip.drawn then
		tip.drawn = false
		tip.settingAlpha = true
		tip.native:SetAlpha(tip.alpha or 1)
		tip.settingAlpha = false
	end
end

local function Readable(native)
	return not (native.IsForbidden and native:IsForbidden())
end

-- What this show is: its data and owner, read safely; then drawn by the taker or left Blizzard's.
local function Read(tip)
	local native = tip.native
	if not Readable(native) then
		return false
	end
	local ok, data = pcall(native.GetTooltipData, native)
	if not ok or isSecret(data) or type(data) ~= "table" then
		data = nil
	end
	tip.data = data
	local owner = native:GetOwner()
	tip.owner = (owner ~= nil and not isSecret(owner) and type(owner) == "table") and owner or nil
	local point = native:GetPoint(1)
	tip.point = (type(point) == "string" and not isSecret(point)) and point or "TOPLEFT"
	return data ~= nil
end

local function Shown(tip)
	if not tip.wants then
		return
	end
	if Read(tip) and tip.wants(tip) then
		tip.drawn = true
		Hide(tip)
		tip.version = tip.version + 1
		Engine:Handle(tip.shown.Set, tip.shown, tip.version) -- drawn now, in this frame (the flush after it)
	else
		Restore(tip)
		Engine:Handle(tip.shown.Set, tip.shown, 0)
	end
end

local function Hidden(tip)
	tip.alpha = nil -- another addon's fade lasts one show
	if tip.wants then
		Restore(tip)
		Engine:Handle(tip.shown.Set, tip.shown, 0)
	end
end

local function Attach(tip)
	local native = tip.native
	-- addons add lines and Show again in the same frame: every show is read, never per frame
	hooksecurefunc(native, "Show", function()
		Shown(tip)
	end)
	hooksecurefunc(native, "SetShown", function(_, shown)
		if not isSecret(shown) and shown then
			Shown(tip)
		end
	end)
	native:HookScript("OnHide", function()
		Hidden(tip)
	end)
	native:HookScript("OnTooltipCleared", function()
		Hidden(tip)
	end)
	-- another addon's fade goes to our view (the alpha it wanted), Blizzard's stays at 0
	hooksecurefunc(native, "SetAlpha", function(_, alpha)
		if tip.settingAlpha or not tip.drawn then
			return
		end
		if not isSecret(alpha) and type(alpha) == "number" and alpha > 0 then
			tip.alpha = alpha
		end
		Hide(tip)
	end)
	-- Blizzard anchors the comparison tooltips after their show: a new point re-places the view
	hooksecurefunc(native, "SetPoint", function(_, point)
		if tip.drawn and type(point) == "string" and not isSecret(point) and point ~= tip.point then
			tip.point = point
			tip.version = tip.version + 1
			Engine:Handle(tip.shown.Set, tip.shown, tip.version)
		end
	end)
	-- a unit's tooltip fades by resetting the alpha every frame inside the game, where no hook sees it: while ours is
	-- drawn, Blizzard's is hidden at once instead (its OnHide takes ours with it)
	if native.FadeOut then
		hooksecurefunc(native, "FadeOut", function()
			if tip.drawn then
				native:Hide()
			end
		end)
	end
end

--- Take this tooltip: `wants(tip)` on every show says whether the caller draws it (Blizzard's then alpha 0).
---@param wants fun(tip: OrdaenTooltip): boolean
function Tip:Take(wants)
	self.wants = wants
	if not self.attached then
		self.attached = true
		Attach(self)
	end
	if self.native:IsShown() then
		Shown(self)
	end
end

--- Give it back: Blizzard's draws as it always did.
function Tip:Release()
	self.wants = nil
	Restore(self)
	self.shown:Set(0)
end

--- The tooltips, made on first use (game.Tooltip).
function ns.NewTooltips()
	local tooltips = {}
	for _, name in ipairs(NATIVES) do
		local native = _G[name] -- luacheck: ignore 113 (B8: Blizzard's tooltips by their names, listed above)
		if native and Readable(native) then
			tooltips[name] = setmetatable({
				native = native, name = name, frame = { global = name }, shown = ns.NewValue(0), version = 0,
				point = "TOPLEFT", drawn = false,
			}, TipMeta)
		end
	end
	return tooltips
end
