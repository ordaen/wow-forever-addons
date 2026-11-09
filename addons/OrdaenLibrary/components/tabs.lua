-- Tabs (design controls/page-tabs): a page's tabs along its top, 4 px apart, over a 1 px line: each tab's name in the
-- dim colour, lighter with a shade under the cursor; the picked one white on a darker shade, outlined in #3e2f1d with
-- a 2 px light along its top inside. Left-click picks a tab. The tabs' 3 px rounded top corners are drawn square.
--
-- Attributes: `tabs` (the names, in order), `selected` (the picked one's index), `OnSelect(index)`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local LINE = { 0.243, 0.184, 0.114, 1 } -- #3e2f1d

local STRIP_LINE = { attributes = { position = "absolute", left = 0, right = 0, bottom = 0, height = 1 * PX,
	background = LINE } }
-- the strip's columns: one auto track per tab and the rest, made once per count
local columns = setmetatable({}, { __index = function(t, n)
	local list = {}
	for i = 1, n do
		list[i] = "auto"
	end
	list[n + 1] = "1fr"
	t[n] = list
	return list
end })

local function Strip(game, self)
	game.ui:Box(STRIP_LINE)
	for i = 1, #self.attributes.tabs do
		game.ui:Tab({ key = i, attributes = { label = self.attributes.tabs[i], selected = i == self.attributes.selected,
			OnPick = self.picks[i] } })
	end
end

return Define.Component({
	Setup = function(_, self)
		-- a click per tab, made once
		local picks = setmetatable({}, { __index = function(t, i)
			local function Pick()
				local fn = self.attributes.OnSelect
				if fn then
					fn(i)
				end
			end
			t[i] = Pick
			return Pick
		end })
		return { picks = picks }
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { columns = columns[#self.attributes.tabs], gap = 4 * PX }, slots = { default = Strip } })
	end,
})
