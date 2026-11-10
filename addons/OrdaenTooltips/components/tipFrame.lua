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
-- beside another, a little narrower), `charge` (0 to STEPS, or nil: no bar), `locked`, `OnClose`.
local Define = import("@ordaen/define")
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
local RULE = { width = 1 * PX, sides = { "top" }, color = { 0.839, 0.647, 0.420, 0.18 } } -- --rule rgba(214, 165, 107, .18)
local LABEL = { 0.796, 0.725, 0.58, 1 } -- --label #cbb994
local QUIET = { 0.522, 0.478, 0.4, 1 } -- --quiet #857a66
local QUIET_VALUE = { 0.639, 0.596, 0.514, 1 } -- --quiet-value #a39883
local BODY = { 0.953, 0.906, 0.8, 1 } -- .txt-body #f3e7cc
local FREE = { 0.902, 0.863, 0.776, 1 } -- .free #e6dcc6
local BLACK = { 0, 0, 0, 1 }
local RIM = { width = 1 * PX, color = { 0.424, 0.333, 0.208, 1 } } -- the icon's bronze ring
local TITLE_COLUMNS = { ICON, "1fr" }
local format, concat = string.format, table.concat
local STEPS = 20 -- the charge's steps (the module's)
-- the lock's bar: 2 px in the bottom padding, 2 px up, bronze to gold; its width the charge (a string per step, made once)
local BAR_FILL = { from = { 0.561, 0.416, 0.227, 1 }, to = { 0.91, 0.765, 0.353, 1 }, direction = "horizontal" }
local BAR_WIDTHS = {}
for i = 0, STEPS do
	BAR_WIDTHS[i] = (i * 100 / STEPS) .. "%"
end
local CLOSE_ART = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" -- the game's red X

-- parts joined with « · », each in its colour (|c codes: a FontString has one colour)
local joined = {}
local function Join(list)
	for i = 1, list.n do
		local part = list[i]
		local c = part.color
		joined[i] = c and format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, part.text) or part.text
	end
	for i = list.n + 1, #joined do
		joined[i] = nil
	end
	return concat(joined, " · ")
end

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
	if calls.desc.attributes.text then
		game.ui:Text(calls.desc)
	end
	if calls.info.attributes.text then
		game.ui:Text(calls.info)
	end
end

local function Head(game, self)
	local calls = self.calls
	if calls.icon.attributes.background then
		game.ui:Box(calls.icon)
	elseif calls.face.attributes.portrait then
		game.ui:Box(calls.face)
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
end

local function BarWidth(_, self)
	return BAR_WIDTHS[self.attributes.charge or 0]
end
local function Close(_, self)
	return self.attributes.OnClose
end

-- the lock's parts over the sections: the bar while charging, the close button once locked
local function Lock(game, self)
	if self.attributes.locked then
		game.ui:Box({ attributes = { position = "absolute", right = 2 * PX, top = 2 * PX, width = 24 * PX, height = 24 * PX,
			background = CLOSE_ART, OnClick = Close(game, self) } })
	elseif (self.attributes.charge or 0) > 0 then
		game.ui:Box({ attributes = { position = "absolute", left = 0, bottom = 2 * PX, height = 2 * PX,
			width = BarWidth(game, self), background = BAR_FILL } })
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
	calls.icon.attributes.background = m.icon
	calls.face.attributes.portrait = not m.icon and m.portrait or nil
	head.columns = hasIcon and TITLE_COLUMNS or 1
	calls.name.attributes.text, calls.name.attributes.textColor = m.name, m.nameColor
	calls.desc.attributes.text = m.desc.n > 0 and Join(m.desc) or nil
	calls.info.attributes.text = m.info.n > 0 and Join(m.info) or nil

	calls.nCols = m.cols.n
	for i = 1, m.cols.n do
		-- the cells never wrap: equal shares, or the widest one's, and the tooltip grows to them
		local a, cell = Calls(calls.cols, i), m.cols[i]
		a.text, a.color, a.glyph, a.tint = cell.text, cell.color or BODY, GlyphOf(cell.glyph), cell.tint
	end
	calls.colsBox.attributes.columns = m.cols.n

	calls.nBody = m.body.n
	for i = 1, m.body.n do
		local row = m.body[i]
		local a = Calls(calls.body, i)
		a.left, a.right = row.left, row.right
		a.leftColor = row.color or (row.right and BODY or FREE)
		a.rightColor = row.rightColor or row.color or BODY
		a.size = row.right and 16 * PX or 14 * PX
	end
	calls.nFoot = m.foot.n
	for i = 1, m.foot.n do
		local row = m.foot[i]
		local a = Calls(calls.foot, i)
		a.left, a.right, a.size = row.left, row.right, 14 * PX
		a.leftColor = (row.valueColor and not row.right) and row.valueColor or QUIET
		a.rightColor = row.valueColor or QUIET_VALUE
	end
	calls.nKeys = m.keys.n
	for i = 1, m.keys.n do
		local a = Calls(calls.keys, i)
		a.left, a.right, a.leftColor, a.size = m.keys[i].text, nil, QUIET, 14 * PX
	end

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
			head = { attributes = { gap = 10 * PX, yAlign = "center", padding = { 0, 0, SECTION, 0 } },
				slots = { default = Head } },
			icon = { attributes = { width = ICON, height = ICON, border = RIM } },
			face = { attributes = { width = ICON, height = ICON, border = RIM, background = BLACK } },
			-- the title's lines never wrap: the tooltip grows to them
			name = { attributes = { textSize = 18 * PX, wrap = false, textFamily = Define.Theme.font.header } },
			desc = { attributes = { textColor = LABEL, textSize = 14 * PX, wrap = false } },
			info = { attributes = { textColor = QUIET, textSize = 14 * PX, wrap = false } },
			colsBox = { attributes = { padding = { SECTION, 0, SECTION, 0 }, gap = 10 * PX }, slots = { default = Cols } },
			bodyBox = Section(Body), footBox = Section(Foot), keysBox = Section(Keys),
			cols = {}, body = {}, foot = {}, keys = {}, nCols = 0, nBody = 0, nFoot = 0, nKeys = 0,
			-- the header: the windows' title style, a groove under it (a fixed height: compared titles line up)
			header = { attributes = { columns = 1, gap = 6 * PX, padding = { 0, 0, 12 * PX, 0 } },
				slots = { default = Header } },
			headerText = { attributes = { textColor = HEADING, textSize = 15 * PX, textAlign = "center", wrap = false } },
		}
		self.box = { attributes = { width = WIDTH, columns = 1, padding = 12 * PX, border = Define.Theme.frame.small,
			background = Define.Theme.window.wood, artOrigin = true }, slots = { default = Frame } }
	end,

	Render = function(game, self)
		local _ = self.attributes.version -- read: a new show draws again
		Fill(self.calls, self.attributes.model)
		self.box.attributes.width = self.attributes.side and SIDE_WIDTH or WIDTH
		game.ui:Box(self.box)
	end,
})
