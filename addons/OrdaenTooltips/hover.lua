-- The mouse on a part that opens something (a term's explanation, an item, a spell, a unit): the question-mark cursor
-- (design `cursor: help`) and OnLink(link, entered). One pair of handlers per component, made at its setup: the term
-- link is built from its attributes as the mouse enters, and left with the same link.
--   local enter, leave = Hover(self)   -- self.attributes: term, amount, link, OnLink
local HELP_CURSOR = import("cursor")

-- an attribute's value: this file isn't a component, so the build doesn't read its attributes for it
local function Value(attribute)
	if type(attribute) == "table" and attribute.Get then
		return attribute:Get()
	end
	return attribute
end

return function(self)
	local link -- the link the mouse entered, left with it
	local function enter()
		local a = self.attributes
		local fn, term, other = Value(a.OnLink), Value(a.term), Value(a.link)
		if fn and (term or other) then
			link = term and "ordaen:term:" .. term .. ":" .. (Value(a.amount) or "") or other
			SetCursor(HELP_CURSOR)
			fn(link, true)
		end
	end
	local function leave()
		local fn = Value(self.attributes.OnLink)
		if link then
			ResetCursor()
			if fn then
				fn(link, false)
			end
		end
		link = nil
	end
	return enter, leave
end
