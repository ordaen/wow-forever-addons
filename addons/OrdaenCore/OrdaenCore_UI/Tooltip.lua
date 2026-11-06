-- OrdaenCore.UI tooltips: a top-level block with the "tooltip" role, shown on hover next to its owner.
-- One shared surface for all of them (like Blizzard's GameTooltip): only one is shown at a time, hovering
-- creates nothing new. Passive: the mouse goes through it. On the tooltip layer and clamped to the screen.
-- Addons don't call this file: they make tooltip objects with OrdaenCore.UI.Tooltip (UI.lua), whose methods
-- land here once the framework is loaded.
local _, ns = ...

local Render, Component = ns.Render, ns.Component
local Tooltip = {}
ns.Tooltip = Tooltip

local GAP = 4 -- between the owner and the tooltip

-- side -> our point, the owner's point, x and y direction of the gap
local SIDES = {
	right = { "TOPLEFT", "TOPRIGHT", 1, 0 },
	left = { "TOPRIGHT", "TOPLEFT", -1, 0 },
	below = { "TOP", "BOTTOM", 0, -1 },
	above = { "BOTTOM", "TOP", 0, 1 },
}

local surface
local current = { block = nil, owner = nil }

local function surfaceFrame()
	if not surface then
		surface = CreateFrame("Frame", "OrdaenUITooltip", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		surface:SetFrameStrata("TOOLTIP")
		surface:SetClampedToScreen(true)
		surface:EnableMouse(false)
		surface:Hide()
	end
	return surface
end

local function anchor(frame, owner, opts)
	local sideName = opts and opts.side or "right"
	frame:ClearAllPoints()
	if sideName == "default" then
		-- Not next to its owner: where Blizzard puts tooltips that are anchored to nothing. The player moves
		-- that spot in Edit Mode ("HUD Tooltip"), which positions GameTooltipDefaultContainer.
		frame:SetPoint("BOTTOMRIGHT", GameTooltipDefaultContainer, "BOTTOMRIGHT", 0, 0)
		return
	end
	local side = SIDES[sideName] or SIDES.right
	local x = (opts and opts.x or 0) + side[3] * GAP
	local y = (opts and opts.y or 0) + side[4] * GAP
	frame:SetPoint(side[1], owner, side[2], x, y)
end

--- Show tooltip `block` next to `owner`, replacing any tooltip that is shown.
function Tooltip.Show(block, owner, opts)
	local frame = surfaceFrame()
	current.block, current.owner = block, owner
	Render.Draw(frame, block, nil)
	anchor(frame, owner, opts)
	frame:Show()
end

--- Hide `block` if it is the tooltip shown (and, when `owner` is given, shown for that owner).
function Tooltip.Hide(block, owner)
	if surface and current.block == block and (owner == nil or current.owner == owner) then
		surface:Hide()
		current.block, current.owner = nil, nil
	end
end

--- Redraw `block` from its (changed) fields, if it is the tooltip shown.
function Tooltip.Refresh(block)
	if surface and current.block == block and surface:IsShown() then
		Render.Draw(surface, block, nil)
	end
end

--- Whether `block` is the tooltip shown.
function Tooltip.IsShown(block)
	return surface ~= nil and current.block == block and surface:IsShown()
end

--- The last tooltip as measured and drawn (dev-mode dumps).
function Tooltip.Describe()
	if not surface then
		return false
	end
	return Render.Describe(surface, current.block or nil)
end

-- Hand the implementation to Ordaen Core's always-loaded entry point (addons/OrdaenCore/UI.lua).
OrdaenCore.UI._Provide({
	Describe = Tooltip.Describe,
	ShowTooltip = Tooltip.Show,
	HideTooltip = Tooltip.Hide,
	RefreshTooltip = Tooltip.Refresh,
	TooltipShown = Tooltip.IsShown,
	Block = Component.Block,
	Button = Component.Button,
})
