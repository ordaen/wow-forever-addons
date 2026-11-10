-- A line of the title made of parts joined with « · » (the description, the info line: design TooltipTitle), each
-- part in its colour and a TermText (its term underlined and opened once the tooltip is locked). Never wrapped: the
-- tooltip grows to it.
--
-- Attributes: `parts` (Read's list: `.n`, each { text, color, term, link }), `version` (changes with each refill), `color`
-- (the line's colour, for parts without their own), `size` (text size, UI units), `OnLink`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2
local SEPARATOR = " · "
-- the row's columns: a part, then a separator and a part for each further one (one table per count)
local COLUMNS = {}
for n = 1, 12 do
	local list = {}
	for i = 1, 2 * n - 1 do
		list[i] = "auto"
	end
	COLUMNS[n] = list
end

local function Parts(game, self)
	local _ = self.attributes.version -- read: a refill draws again
	local parts, calls, dots = self.attributes.parts, self.calls, self.dots
	local color, size, link = self.attributes.color, self.attributes.size, self.attributes.OnLink
	for i = 1, math.min(parts.n, #COLUMNS) do
		if i > 1 then
			local dot = dots[i]
			if not dot then
				dot = { attributes = { text = SEPARATOR, wrap = false } }
				dots[i] = dot
			end
			dot.attributes.textColor, dot.attributes.textSize = color, size
			game.ui:Text(nil, dot, -i)
		end
		local call = calls[i]
		if not call then
			call = { attributes = {} }
			calls[i] = call
		end
		local a, part = call.attributes, parts[i]
		a.text, a.color, a.size, a.term, a.OnLink = part.text, part.color or color, size, part.term, link
		a.link = part.link
		game.ui:TermText(nil, call, i)
	end
end

return Define.Component({
	Setup = function(_, self)
		self.calls, self.dots = {}, {}
		-- 18 px high (the title's second and third lines: design TooltipTitle .desc)
		self.box = { attributes = { columns = COLUMNS[1], gap = 0, yAlign = "center", height = 18 * PX },
			slots = { default = Parts } }
	end,

	Render = function(game, self)
		local _ = self.attributes.version -- read: a refill draws again
		self.box.attributes.columns = COLUMNS[math.min(self.attributes.parts.n, #COLUMNS)] or COLUMNS[1]
		game.ui:Box(self.box)
	end,
})
