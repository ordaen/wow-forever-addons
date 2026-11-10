-- One Ordaen tooltip's frame (design tooltips/, Tooltip.vue): the small metal frame round the windows' wood, 12 px
-- inside, and the sections in the one order, each left out when empty: the header (above the title: «Надето»), the
-- title (the icon beside three lines: the name; the description; the info line, dimmed), the columns (one cell per
-- fact, its glyph before it), the body (rows and free text), the footer (label and value lines, quiet), the hotkeys.
-- A rule only between two present sections, none between the title and the body. As wide as its title and columns
-- (never wrapped), at least 314 px; the body wraps at that width.
-- Drawn from a model (read.lua) whenever `version` changes; the calls are this frame's own tables, refilled then (no
-- tables per show after the first): a call's attributes table changes in place and the draw sets what differs.
--
-- Tooltips in tooltips: while `charge` counts up (steps of the module's 1 s), a gold bar runs along the bottom
-- padding; `locked`, the bar is gone and the game's red X sits in the top-right padding (OnClose).
--
-- Attributes: `model` (Read's model), `version` (a number that changes with each refill), `side` (true: a tooltip
-- beside another, a little narrower), `charge` (a signal of 0 to STEPS, or nil: no bar; read by the bar's width
-- alone, so a step redraws nothing else), `locked`, `OnClose`, `OnLink` (its rows'
-- links: set while the tooltip is locked).
local Define = import("@ordaen/define")
local L = import("locales")
local GLYPHS = import("glyphs")
local GLYPH_FILE = import("assets/glyphs.tga")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale
-- the minimum, or as wide as the title and the columns need (they never wrap); the body wraps at that
local WIDTH = { min = 314 * PX, fit = "min" }
local SIDE_WIDTH = { min = 264 * PX, fit = "min" }
local HEADING = { 1, 0.82, 0, 1 } -- the windows' title colour (#ffd100)
local GROOVE = { width = 1 * PX, sides = { "top", "bottom" }, color = { 0, 0, 0, 0.85 } }
local ICON = 60 * PX
local SECTION = 8 * PX
local HEADER_HEIGHT = 35 * PX -- the «Надето» header (view.lua lines the hovered item's title up by it)
local HEAD_PADDING = { 0, 0, SECTION, 0 } -- under the title, when something follows it
local RULE = { width = 1 * PX, sides = { "top" }, color = { 0.839, 0.647, 0.420, 0.18 } } -- --rule rgba(214, 165, 107, .18)
local LABEL = { 0.796, 0.725, 0.58, 1 } -- --label #cbb994
local QUIET = { 0.522, 0.478, 0.4, 1 } -- --quiet #857a66
local QUIET_VALUE = { 0.639, 0.596, 0.514, 1 } -- --quiet-value #a39883
local BODY = { 0.953, 0.906, 0.8, 1 } -- .txt-body #f3e7cc
local FREE = { 0.902, 0.863, 0.776, 1 } -- .free #e6dcc6
local BLACK = { 0, 0, 0, 1 }
local RIM = { width = 1 * PX, color = { 0.424, 0.333, 0.208, 1 } } -- the icon's bronze ring
local TITLE_COLUMNS = { ICON, "1fr" }
local STEPS = 100 -- the charge's steps (the module's: per cent)
-- the lock's bar: 2 px in the bottom padding, 2 px up, bronze to gold; its width the charge (a string per step, made once)
-- the lock's bar: the tooltip's last section, 8 px under the content: a dark track, gold filling it as it charges
local TRACK = { 0, 0, 0, 0.45 }
local BAR_GOLD = { 0.91, 0.765, 0.353, 1 } -- --o-gold #e8c35a
local BAR_HEIGHT = 3
local BAR_WIDTHS = {}
for i = 0, STEPS do
	BAR_WIDTHS[i] = (i * 100 / STEPS) .. "%"
end
local CLOSE_ART = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" -- the game's red X

-- a glyph's background: one part of the glyph atlas, a table per glyph made once
local glyphs = {}
local function GlyphOf(name)
	local cell = name and GLYPHS[name]
	if not cell then
		return nil
	end
	local glyph = glyphs[name]
	if not glyph then
		local cols, rows = GLYPHS.size[1], GLYPHS.size[2]
		glyph = { file = GLYPH_FILE, coords = { cell[1] / cols, (cell[1] + 1) / cols, cell[2] / rows,
			(cell[2] + 1) / rows } }
		glyphs[name] = glyph
	end
	return glyph
end

-- a call per line, kept: calls[i] for the i-th line of a section
local function Calls(list, i, size)
	local call = list[i]
	if not call then
		call = { attributes = { size = size } }
		list[i] = call
	end
	return call.attributes
end

local function Title(game, self)
	local calls = self.calls
	game.ui:Text(calls.name)
	if calls.desc.attributes.parts.n > 0 then
		game.ui:PartsLine(calls.desc)
	end
	if calls.info.attributes.parts.n > 0 then
		game.ui:PartsLine(calls.info)
	end
end

-- the icon (or a unit's face) inside its ring: bronze, a black line inside it (design TooltipTitle .icon)
local function Picture(game, self)
	local calls = self.calls
	game.ui:Box(calls.iconImage.attributes.background and calls.iconImage or calls.faceImage)
end

local function Head(game, self)
	local calls = self.calls
	if calls.iconImage.attributes.background or calls.faceImage.attributes.portrait then
		game.ui:Box(calls.icon)
	end
	game.ui:Box({ attributes = { columns = 1, gap = 2 * PX, yAlign = "center" }, slots = { default = Title } })
end

local function Cols(game, self)
	local calls = self.calls
	for i = 1, calls.nCols do
		game.ui:Cell(nil, calls.cols[i], i)
	end
end

local function Body(game, self)
	local calls = self.calls
	for i = 1, calls.nBody do
		game.ui:Row(nil, calls.body[i], i)
	end
end

local function Foot(game, self)
	local calls = self.calls
	for i = 1, calls.nFoot do
		game.ui:Row(nil, calls.foot[i], i)
	end
end

local function Keys(game, self)
	local calls = self.calls
	for i = 1, calls.nKeys do
		game.ui:Row(nil, calls.keys[i], i)
	end
end

local function Header(game, self)
	game.ui:Text(self.calls.headerText)
	game.ui:Box({ attributes = { height = 2 * PX, border = GROOVE } })
end

local function BarWidth(_, self)
	return BAR_WIDTHS[self.attributes.charge:Get()]
end

local function BarFill(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 0, top = 0, bottom = 0, width = BarWidth(game, self),
		background = BAR_GOLD } })
end
-- the track shows once the charge starts (its row's room is there from the show on: nothing moves)
local function TrackColor(_, self)
	return (self.attributes.locked or self.attributes.charge:Get() > 0) and TRACK or nil
end
local function Track(game, self)
	game.ui:Box({ attributes = { height = BAR_HEIGHT * PX, background = TrackColor(game, self) },
		slots = { default = BarFill } })
end
-- once locked, the bar gives way to what the player can do now, in the footer's quiet colour
local function Hint(game)
	game.ui:Text({ attributes = { text = L.LOCKED_HINT, textColor = QUIET, textSize = 13 * PX } })
end
local function BarOrHint(game, self)
	if self.attributes.locked then
		Hint(game)
	else
		Track(game, self)
	end
end
local BAR = { attributes = { columns = 1, padding = { SECTION, 0, 0, 0 } }, slots = { default = BarOrHint } }

local function Sections(game, self)
	local calls = self.calls
	if calls.headerText.attributes.text then
		game.ui:Box(calls.header)
	end
	if calls.head.attributes.shown then
		game.ui:Box(calls.head)
	end
	if calls.nCols > 0 then
		game.ui:Box(calls.colsBox)
	end
	if calls.nBody > 0 then
		game.ui:Box(calls.bodyBox)
	end
	if calls.nFoot > 0 then
		game.ui:Box(calls.footBox)
	end
	if calls.nKeys > 0 then
		game.ui:Box(calls.keysBox)
	end
	if self.attributes.charge then -- the main tooltip: the lock's bar
		game.ui:Box(BAR)
	end
end

local function Close(_, self)
	return self.attributes.OnClose
end

-- the lock's parts over the sections: the bar while charging, the close button once locked
local function Lock(game, self)
	if self.attributes.locked then
		game.ui:Box({ attributes = { position = "absolute", right = 2 * PX, top = 2 * PX, width = 24 * PX, height = 24 * PX,
			background = CLOSE_ART, OnClick = Close(game, self) } })
	end
end

local function Frame(game, self)
	Sections(game, self)
	Lock(game, self)
end

-- a section's box: rows 2 px apart, 8 px above and below, a rule on top when something is above it
local function Section(slot)
	return { attributes = { columns = 1, gap = 2 * PX, padding = { SECTION, 0, SECTION, 0 } },
		slots = { default = slot } }
end

-- the model into the calls: what this show draws
local function Fill(calls, m)
	calls.headerText.attributes.text = m.header
	local head = calls.head.attributes
	head.shown = m.name ~= nil
	-- the item's or spell's icon, else a unit's face: each its own box (never one turned into the other)
	local hasIcon = m.icon ~= nil or m.portrait ~= nil
	calls.iconImage.attributes.background = m.icon
	calls.faceImage.attributes.portrait = not m.icon and m.portrait or nil
	head.columns = hasIcon and TITLE_COLUMNS or 1
	calls.name.attributes.text, calls.name.attributes.textColor = m.name, m.nameColor
	calls.desc.attributes.parts, calls.info.attributes.parts = m.desc, m.info

	calls.nCols = m.cols.n
	for i = 1, m.cols.n do
		-- the cells never wrap: equal shares, or the widest one's, and the tooltip grows to them
		local a, cell = Calls(calls.cols, i), m.cols[i]
		a.text, a.color, a.glyph, a.tint = cell.text, cell.color or BODY, GlyphOf(cell.glyph), cell.tint
		a.term, a.amount, a.link = cell.term, cell.amount, cell.link
		a.divider = i > 1
		a.last = m.body.n == 0 and m.foot.n == 0 and m.keys.n == 0 -- the band ends the tooltip: no padding under it
	end
	calls.colsBox.attributes.columns = m.cols.n

	calls.nBody = m.body.n
	for i = 1, m.body.n do
		local row = m.body[i]
		local a = Calls(calls.body, i)
		a.left, a.right, a.term, a.amount, a.link, a.valueLink = row.left, row.right, row.term, nil, row.link, nil
		a.indent = row.indent
		a.leftColor = row.color or ((row.right or row.desc) and BODY or FREE)
		a.rightColor = row.rightColor or row.color or BODY
		-- a stat row 16 px, a description 15 (larger than the footer's 14), other free lines 14
		a.size = row.indent and 14 * PX or row.right and 16 * PX or row.desc and 15 * PX or 14 * PX
	end
	calls.nFoot = m.foot.n
	for i = 1, m.foot.n do
		local row = m.foot[i]
		local a = Calls(calls.foot, i)
		a.left, a.right, a.size, a.term, a.amount, a.link = row.left, row.right, 14 * PX, row.term, row.amount, row.link
		a.valueLink = row.valueLink
		a.leftColor = (row.valueColor and not row.right) and row.valueColor or QUIET
		a.rightColor = row.valueColor or QUIET_VALUE
	end
	calls.nKeys = m.keys.n
	for i = 1, m.keys.n do
		local a = Calls(calls.keys, i)
		a.left, a.right, a.leftColor, a.size = m.keys[i].text, nil, QUIET, 14 * PX
	end

	-- the title alone (a sign): no padding under it
	head.padding = (m.cols.n + m.body.n + m.foot.n + m.keys.n > 0 or m.header) and HEAD_PADDING or nil
	-- a rule only between two present sections; none between the title and the body
	local above = head.shown
	calls.colsBox.attributes.border = above and RULE or nil
	above = above or m.cols.n > 0
	calls.bodyBox.attributes.border = (m.cols.n > 0) and RULE or nil
	above = above or m.body.n > 0
	calls.footBox.attributes.border = above and RULE or nil
	above = above or m.foot.n > 0
	calls.keysBox.attributes.border = above and RULE or nil
end

return Define.Component({
	Setup = function(_, self)
		self.calls = {
			head = { attributes = { gap = 10 * PX, yAlign = "center", padding = HEAD_PADDING },
				slots = { default = Head } },
			icon = { attributes = { width = ICON, height = ICON, border = RIM, padding = 1 * PX, background = BLACK,
				columns = 1 }, slots = { default = Picture } },
			iconImage = { attributes = { width = "100%", height = "100%" } },
			faceImage = { attributes = { width = "100%", height = "100%", background = BLACK } },
			-- the title's lines never wrap: the tooltip grows to them
			-- the title's lines have fixed heights (20, 18, 18, 2 apart): the icon is exactly as tall as the three
			name = { attributes = { textSize = 18 * PX, wrap = false, textFamily = Define.Theme.font.header, height = 20 * PX,
				textYAlign = "center" } },
			desc = { attributes = { color = LABEL, size = 14 * PX } },
			info = { attributes = { color = QUIET, size = 14 * PX } },
			-- the band: one row of cells, each padded, a rule between neighbours (design TooltipColumns)
			colsBox = { attributes = { gap = 0 }, slots = { default = Cols } },
			bodyBox = Section(Body), footBox = Section(Foot), keysBox = Section(Keys),
			cols = {}, body = {}, foot = {}, keys = {}, nCols = 0, nBody = 0, nFoot = 0, nKeys = 0,
			-- the header: the windows' title style, a groove under it (a fixed height: compared titles line up)
			-- a fixed height (15 + 6 + 2 + 12 = 35 px, design .header): the compared item lines its title up by it
			header = { attributes = { columns = 1, gap = 6 * PX, padding = { 0, 0, 12 * PX, 0 }, height = HEADER_HEIGHT },
				slots = { default = Header } },
			headerText = { attributes = { textColor = HEADING, textSize = 15 * PX, textAlign = "center", wrap = false } },
		}
		self.box = { attributes = { width = WIDTH, columns = 1, padding = 12 * PX, border = Define.Theme.frame.small,
			background = Define.Theme.window.wood, artOrigin = true }, slots = { default = Frame } }
	end,

	Render = function(game, self)
		local _ = self.attributes.version -- read: a new show draws again
		local calls = self.calls
		Fill(calls, self.attributes.model)
		local link = self.attributes.OnLink
		for i = 1, calls.nBody do
			calls.body[i].attributes.OnLink = link
		end
		for i = 1, calls.nFoot do
			calls.foot[i].attributes.OnLink = link
		end
		for i = 1, calls.nCols do
			calls.cols[i].attributes.OnLink = link
		end
		local version = self.attributes.version
		calls.desc.attributes.OnLink, calls.desc.attributes.version = link, version
		calls.info.attributes.OnLink, calls.info.attributes.version = link, version
		self.box.attributes.width = self.attributes.side and SIDE_WIDTH or WIDTH
		game.ui:Box(self.box)
	end,
})
