-- units: one operation done 1000 times per call (100 for offsets, 5000 for the wide flush), the shape around it held
-- still, so its row is that operation's cost: a time in ms per 1000 is µs each. Framework rows (and the engine alone
-- on the stub where something is drawn), no hand side: they say where the framework's time goes, not how it compares.
--   text, box     take 1000 text or box nodes into a fixed box (Show(true)), release them (Show(false))
--   look          1000 boxes switch background colour (no layout)
--   size          1000 boxes, each alone in a fixed 40x40 cell, switch width 20 / 30 (layout stops at the cell)
--   textFixed     1000 texts in fixed 36x36 cells get a new 4-digit number (measuring, no layout change)
--   textClimb     1000 texts in 3 content-sized boxes switch 1 / 5 digits (the change climbs 3 levels)
--   offset        100 absolute boxes move
--   unchanged     1000 child components called again with nothing changed (the backend should do nothing)
--   writes        1000 writes to 1000 values nothing reads
--   runs          1000 times: a write and a flush, one watch reading it
--   wide          5000 values each read by its own watch, all written, one flush
local Define = import("@ordaen/define")

local N, OFFSETS, WIDE = 1000, 100, 5000

local SURFACE, BORDER = Define.Theme.color.surface, Define.Theme.color.border

-- built here: the units need thousands of values (module code declares state as a literal table)
local function Values(count)
	local spec = { on = { type = "boolean", default = false } }
	for i = 1, count do
		spec["v" .. i] = { type = "number", default = 0 }
	end
	return spec
end
local SPECS = { writes = Values(N), wide = Values(WIDE) }
local ON = { on = { type = "boolean", default = false } }

local ROOT = { columns = 25, gap = 1, position = "absolute", left = 10, top = 10, width = 1200, height = 900 }

local function Children(game, self)
	local unit, calls = self.unit, self.calls
	if unit == "writes" or unit == "runs" or unit == "wide" then
		return -- nothing drawn: these units measure the engine alone
	end
	local on = self.state.ephemeral.on:Get() -- the drawn units re-render on Flip and Show
	if unit == "text" then
		if on then
			for i = 1, N do
				game.ui:Text(calls[i])
			end
		end
	elseif unit == "box" then
		if on then
			for i = 1, N do
				game.ui:Box(calls[i])
			end
		end
	elseif unit == "look" then
		local background = on and SURFACE or BORDER
		for i = 1, N do
			local call = calls[i]
			call.attributes.background = background
			game.ui:Box(call)
		end
	elseif unit == "size" then
		local width = on and 30 or 20
		for i = 1, N do
			local cell = calls[i]
			cell.inner.attributes.width = width
			game.ui:Box(cell)
		end
	elseif unit == "textFixed" or unit == "textClimb" then
		local base = unit == "textFixed" and (on and 2000 or 1000) or (on and 10000 or 0)
		for i = 1, N do
			local cell = calls[i]
			cell.arguments[1] = unit == "textFixed" and (base + i) or (on and (base + i) or (i % 10))
			game.ui:Box(cell)
		end
	elseif unit == "offset" then
		local shift = on and 5 or 0
		for i = 1, OFFSETS do
			local call = calls[i]
			call.attributes.left = 10 + (i - 1) % 10 * 40 + shift
			game.ui:Box(call)
		end
	elseif unit == "unchanged" then
		for i = 1, N do
			game.ui:UnitsItem(calls[i])
		end
	end
end

return Define.Component({
	Setup = function(game, self)
		local unit = self.attributes.unit:Peek()
		Define.Ephemeral(SPECS[unit] or ON) -- one declaration: the unit's values, if any, and its switch
		local on = self.state.ephemeral.on
		local calls = {}
		if unit == "text" then
			for i = 1, N do
				calls[i] = { key = i, attributes = { text = "%d", arguments = { i } } }
			end
		elseif unit == "box" or unit == "look" then
			for i = 1, N do
				calls[i] = { key = i, attributes = { width = 20, height = 20, background = BORDER } }
			end
		elseif unit == "size" then
			for i = 1, N do
				local inner = { key = 1, attributes = { width = 20, height = 20, background = BORDER } }
				calls[i] = { key = i, inner = inner, attributes = { width = 40, height = 40 },
					slots = { default = function(g)
						g.ui:Box(inner)
					end } }
			end
		elseif unit == "textFixed" or unit == "textClimb" then
			local fixed = unit == "textFixed"
			for i = 1, N do
				local arguments = { 0 }
				local text = { key = 1, attributes = { text = "%d", arguments = arguments } }
				local child = text
				if fixed then
					calls[i] = { key = i, arguments = arguments,
						attributes = { width = 36, height = 36, xAlign = "center", yAlign = "center" },
						slots = { default = function(g)
							g.ui:Text(text)
						end } }
				else
					for level = 1, 3 do -- three content-sized boxes around the text
						local inside = child
						local isText = level == 1
						child = { key = 1, attributes = { width = "auto", padding = 1 }, slots = { default = function(g)
							if isText then
								g.ui:Text(inside)
							else
								g.ui:Box(inside)
							end
						end } }
					end
					child.key, child.arguments = i, arguments
					calls[i] = child
				end
			end
		elseif unit == "offset" then
			for i = 1, OFFSETS do
				calls[i] = { key = i, attributes = { position = "absolute", left = 10 + (i - 1) % 10 * 40,
					top = 10 + math.floor((i - 1) / 10) * 40, width = 30, height = 30, background = BORDER } }
			end
		elseif unit == "unchanged" then
			for i = 1, N do
				calls[i] = { key = i, attributes = { value = i } }
			end
		end
		local functions = {
			Show = function(shown)
				on:Set(shown)
			end,
			Flip = function()
				on:Set(not on:Peek())
			end,
		}
		local store = self.state.ephemeral
		if unit == "writes" then
			local values = {}
			for i = 1, N do
				values[i] = store["v" .. i]
			end
			functions.WriteAll = function()
				for i = 1, N do
					local value = values[i]
					value:Set(value:Peek() + 1)
				end
			end
			functions.Sum = function() -- the bench's check: every write landed
				local sum = 0
				for i = 1, N do
					sum = sum + values[i]:Peek()
				end
				return sum
			end
		elseif unit == "runs" then
			local runs = 0
			self:Watch(function()
				local _ = on:Get()
				runs = runs + 1
			end)
			functions.Runs = function() -- the bench's check: the watch ran once per flush
				return runs
			end
		elseif unit == "wide" then
			local values, runs = {}, 0
			for i = 1, WIDE do
				local value = store["v" .. i]
				values[i] = value
				self:Watch(function()
					local _ = value:Get()
					runs = runs + 1
				end)
			end
			functions.Runs = function() -- the bench's check: every watch ran once per flush
				return runs
			end
			functions.WriteAll = function()
				for i = 1, WIDE do
					local value = values[i]
					value:Set(value:Peek() + 1)
				end
			end
		end
		return {
			unit = unit, calls = calls,
			root = { attributes = ROOT, slots = { default = Children } },
			public = { functions = functions },
		}
	end,

	Render = function(game, self)
		game.ui:Box(self.root)
	end,
})
