-- numbersExample: the Numbers tab's last row (design settings/, the example): how numbers look with the settings above,
-- formatted as every module formats them, beside its title.
--
-- Attributes: `title` (its label).
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local LABEL = { 0.796, 0.725, 0.58, 1 } -- --o-label #cbb994
local INK = { 0.91, 0.863, 0.769, 1 } -- --o-ink #e8dcc4
local TEXT = 15 * PX
local ROW = { columns = { 280 * PX, "1fr" }, gap = 18 * PX, yAlign = "center" }
local SAMPLES = { 1234567.0912, 1795, 12.5, 0.25, 0.004 }

local function Example(game)
	local parts = {}
	for i = 1, #SAMPLES do
		parts[i] = game.Numbers:Format(SAMPLES[i])
	end
	return table.concat(parts, "    ")
end

local function Parts(game, self)
	game.ui:Text({ attributes = { text = self.attributes.title, textColor = LABEL, textSize = TEXT } })
	game.ui:Text({ attributes = { text = Example(game), textColor = INK, textSize = TEXT,
		textFamily = Define.Theme.font.numbers } })
end

return Define.Component({
	Render = function(game)
		game.ui:Box({ attributes = ROW, slots = { default = Parts } })
	end,
})
