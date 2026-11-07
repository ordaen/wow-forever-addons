-- Ordaen Tooltips, drawing: one OrdaenCore.UI block per native tooltip, built once, its fields refilled from the
-- Reader's model and the Layouts' decisions on each show.
--   header   the theme's header band: an icon when the kind has one (items, spells), the title (the first line, in
--            its colour: an item's quality, a unit's reaction, which is also the tooltip's accent), a subtitle
--   stats    a spell's cost, range, cast time and cooldown in columns, values only (Layouts)
--   rows     the other lines: left text, and right text when there is one; a blank line is a small gap; a divider
--            before the lines other addons added
--   bar      the unit health bar
local _, ns = ...

local View = {}
ns.View = View

local UI = OrdaenCore.UI
local Reader, Layouts, Owner, SpellStats = ns.Reader, ns.Layouts, ns.Owner, ns.SpellStats

local isSecret = issecretvalue or function()
	return false
end

local ICON_SIZE = 32
local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }
local NO_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

---@class OrdaenTooltipsRowView
---@field block OrdaenUIBlock
---@field divider OrdaenUISeparator
---@field left OrdaenUIText
---@field right OrdaenUIText

---@class OrdaenTooltipsView
---@field component OrdaenUIComponent
---@field header OrdaenUIHeader
---@field rows OrdaenTooltipsRowView[]
---@field bar OrdaenUIBar
---@field stats OrdaenUIStats the spell section
local ViewMethods = {}
local ViewMeta = { __index = ViewMethods }

--- A view for one native tooltip. Nil when OrdaenCore_UI can't load (the player was told).
---@param name string global frame name, e.g. "OrdaenTooltipsGameTooltip"
---@return OrdaenTooltipsView|nil
function View.New(name)
	local header = UI.Header({ title = "", subtitle = "", icon = NO_ICON, iconSize = ICON_SIZE, texCoord = ICON_CROP })
	local spec = { name = name, parent = UIParent, strata = "TOOLTIP", style = "tooltip", header }
	-- The columns as tall as the section (their lines the same height), each value in its middle: one value may
	-- wrap to two lines (a long cost).
	local stats = UI.Stats(#SpellStats.ORDER)
	spec[#spec + 1] = stats
	local rows = {}
	for i = 2, Reader.MAX_ROWS do
		local divider = { separator = "divider", colSpan = 2, hidden = true }
		local left = { text = "", style = "body" }
		local right = { text = "", style = "value", align = "right", hidden = true }
		local block = { columns = { "1fr", "auto" }, gap = { "lg", 0 }, hidden = true, divider, left, right }
		rows[i] = { block = block, divider = divider, left = left, right = right }
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
	return setmetatable({ component = component, header = header, rows = rows, bar = bar, stats = stats },
		ViewMeta)
end

-- Spacing before a row that follows a blank line (other addons separate their sections with one).
local GAP_BEFORE = { "sm", 0, 0, 0 }
-- The theme's section gap before the first row of text (as a "section" block has).
local SECTION_GAP = { "lg", 0, 0, 0 }

local function fillHeader(self, model, layout, owner)
	local first = model.rows[1]
	local header = self.header
	local title = first and first.left or ""
	-- A micro button's title carries its binding ("Character Info (C)"): the key goes to the hotkey, at the bottom.
	local text, titleKey = Owner.SplitTitle(title)
	header.titleText.text = text or title
	self.component.block.hotkey = owner and Owner.Hotkey(owner) or titleKey
	header.titleText.color = first and first.leftColor or nil
	-- The title wears its colour (a unit's reaction, an item's quality); only an item's also tints the tooltip.
	local accent = layout.tint and first and first.leftColor or nil
	header.accent = accent
	self.component.block.accent = accent
	header.subtitleText.text = layout.subtitle or ""
	header.subtitleText.hidden = not layout.subtitle
	local iconColumn = header[1]
	if layout.icon then
		header.iconImage.image = layout.icon
		iconColumn.hidden = false
	else
		iconColumn.hidden = true
	end
end

--- Fill the blocks from `model` and redraw.
---@param model OrdaenTooltipsModel
---@param owner table|nil the frame hovered (Owner.Of): its key binding is shown as the hotkey
function ViewMethods:Fill(model, owner)
	local layout = Layouts.Decide(model)
	fillHeader(self, model, layout, owner)
	local stats = self.stats
	stats:Clear()
	for _, stat in ipairs(SpellStats.ORDER) do
		local s = layout.stats[stat]
		if s.shown then
			stats:Add(s.arg, nil, s.format)
		end
	end
	local gap = false
	local first = true -- the first text row after the title (and numbers) starts a section
	for i = 2, Reader.MAX_ROWS do
		local view = self.rows[i]
		local row = i <= model.count and model.rows[i]
		if not row or row.blank or layout.skip[i] then
			view.block.hidden = true
			gap = row and row.blank and i > 2 or gap
		else
			view.block.hidden = false
			view.divider.hidden = i ~= layout.extrasFrom
			view.block.padding = (first and SECTION_GAP) or (gap and i ~= layout.extrasFrom and GAP_BEFORE) or nil
			gap, first = false, false
			local hasRight = row.right ~= ""
			view.left.text = row.left
			view.left.color = row.leftColor or nil
			view.left.style = i == model.priceRow and "label" or "body"
			view.left.colSpan = hasRight and 1 or 2
			view.right.hidden = not hasRight
			view.right.text = row.right
			view.right.color = row.rightColor or nil
		end
	end
	-- A divider on a row that was skipped would be lost: put it on the next shown row instead.
	local from = layout.extrasFrom
	if from and self.rows[from] and self.rows[from].block.hidden then
		for i = from + 1, Reader.MAX_ROWS do
			if not self.rows[i].block.hidden then
				self.rows[i].divider.hidden = false
				break
			end
		end
	end
	self.bar.hidden = not model.bar
	self.bar.bar = model.bar or 0
	self.bar.color = model.bar and model.barColor or nil
	self.component:Refresh()
end

--- Put the view where the native tooltip is. A native anchored to another native we draw (the comparison tooltips
--- next to GameTooltip) goes edge to edge with that one's view, on the same side; otherwise the view
--- takes the native's own corner, so it grows the same way.
--- With `beside` (a micro or action button, setting "beside buttons"), it goes next to that button instead: above it
--- in the lower half of the screen, below it in the upper half.
---@param native GameTooltip
---@param viewOf fun(native: table): OrdaenTooltipsView|nil
---@param beside table|nil
function ViewMethods:Follow(native, viewOf, beside)
	local point, relativeTo, _, x, y = native:GetPoint(1)
	local c = self.component
	c:ClearAllPoints()
	if beside then
		local _, centerY = beside:GetCenter()
		if centerY and not isSecret(centerY) then
			local gap = UI.Space("sm")
			if centerY < UIParent:GetHeight() / 2 then
				c:SetPoint("BOTTOM", beside, "TOP", 0, gap)
			else
				c:SetPoint("TOP", beside, "BOTTOM", 0, -gap)
			end
			return
		end
	end
	if isSecret(point) or isSecret(relativeTo) or isSecret(x) or isSecret(y) then
		point, relativeTo = nil, nil -- in combat the anchor can be hidden: centre on the native tooltip
	end
	local other = relativeTo and viewOf(relativeTo)
	if type(point) == "string" and other and other ~= self then
		-- A comparison tooltip: Blizzard's offsets come from the natives' widths (ours differ, and the view it hangs
		-- from may sit beside a button instead), so copying them overlapped the views (the user, 2026-11-07). Ours
		-- goes edge to edge with that view, tops aligned, on the side Blizzard chose (from the natives' centres).
		local myX = native:GetCenter()
		local otherX = relativeTo:GetCenter()
		local left = not (isSecret(myX) or isSecret(otherX)) and myX and otherX and myX < otherX
		if left then
			c:SetPoint("TOPRIGHT", other.component.frame, "TOPLEFT", 0, 0)
		else
			c:SetPoint("TOPLEFT", other.component.frame, "TOPRIGHT", 0, 0)
		end
	elseif type(point) == "string" then
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
