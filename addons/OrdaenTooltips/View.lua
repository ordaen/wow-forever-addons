-- Ordaen Tooltips, drawing: one OrdaenCore.UI block per native tooltip, built once, its fields refilled from the
-- Reader's model on each show. The first line is the title; its colour (an item's quality, a unit's reaction) is
-- the tooltip's accent. Every other line is a row: left text, and right text when there is one. A blank line is a
-- small gap before the next row. The unit health bar is a bar element.
--
-- This is the generic view, for every tooltip: other addons' lines and simple native tooltips. Items, units and
-- spells get layouts of their own later (docs/roadmap.md).
local _, ns = ...

local View = {}
ns.View = View

local UI = OrdaenCore.UI
local Reader = ns.Reader

---@class OrdaenTooltipsView
---@field component OrdaenUIComponent
---@field title OrdaenUIText
---@field rows table[] row blocks, { block, left, right }
---@field bar OrdaenUIBar
local ViewMethods = {}
local ViewMeta = { __index = ViewMethods }

--- A view for one native tooltip. Nil when OrdaenCore_UI can't load (the player was told).
---@param name string global frame name, e.g. "OrdaenTooltipsGameTooltip"
---@return OrdaenTooltipsView|nil
function View.New(name)
	local title = { text = "", style = "title" }
	local spec = { name = name, parent = UIParent, strata = "TOOLTIP", style = "tooltip", title }
	local rows = {}
	for i = 2, Reader.MAX_ROWS do
		local left = { text = "", style = "body" }
		local right = { text = "", style = "value", align = "right", hidden = true }
		local block = { columns = { "1fr", "auto" }, gap = { "lg", 0 }, hidden = true, left, right }
		rows[i] = { block = block, left = left, right = right }
		spec[#spec + 1] = block
	end
	local bar = { bar = 0, hidden = true }
	spec[#spec + 1] = bar
	local component = UI.Block(spec)
	if not component then
		return nil
	end
	component:SetClampedToScreen(true)
	component:Hide()
	return setmetatable({ component = component, title = title, rows = rows, bar = bar }, ViewMeta)
end

-- Spacing before a row that follows a blank line (other addons separate their sections with one).
local GAP_BEFORE = { "sm", 0, 0, 0 }

--- Fill the blocks from `model` and redraw.
---@param model OrdaenTooltipsModel
function ViewMethods:Fill(model)
	local first = model.rows[1]
	local block = self.component.block
	self.title.text = first and first.left or ""
	self.title.color = first and first.leftColor or nil
	block.accent = first and first.leftColor or nil
	local gap = false
	for i = 2, Reader.MAX_ROWS do
		local view = self.rows[i]
		local row = i <= model.count and model.rows[i]
		if not row or row.blank then
			view.block.hidden = true
			gap = row and row.blank and i > 2 or gap
		else
			view.block.hidden = false
			view.block.padding = gap and GAP_BEFORE or nil
			gap = false
			local hasRight = row.right ~= ""
			view.left.text = row.left
			view.left.color = row.leftColor or nil
			view.left.colSpan = hasRight and 1 or 2
			view.right.hidden = not hasRight
			view.right.text = row.right
			view.right.color = row.rightColor or nil
		end
	end
	self.bar.hidden = not model.bar
	self.bar.bar = model.bar or 0
	self.bar.color = model.bar and model.barColor or nil
	self.component:Refresh()
end

--- Put the view where the native tooltip is: the same corner on the same point, so it grows the same way.
---@param native GameTooltip
function ViewMethods:Follow(native)
	local point = native:GetPoint(1)
	local c = self.component
	c:ClearAllPoints()
	if type(point) == "string" then
		c:SetPoint(point, native, point)
	else
		c:SetPoint("CENTER", native, "CENTER")
	end
end

function ViewMethods:Show()
	self.component:Show()
end

function ViewMethods:Hide()
	self.component:Hide()
end

---@return boolean
function ViewMethods:IsShown()
	return self.component:IsShown()
end

function ViewMethods:SetAlpha(alpha)
	self.component:SetAlpha(alpha)
end
