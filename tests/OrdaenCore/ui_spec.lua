-- OrdaenCore.UI tooltips (addons/OrdaenCore/UI.lua, Tooltip.lua).
local helpers = require("tests.OrdaenCore.helpers")

-- A GameTooltip that records what is drawn on it.
local function recordingTooltip()
	local tip = { lines = {}, shown = false, owner = nil, setOwnerCalls = 0 }
	function tip:SetOwner(owner, anchor, x, y)
		self.owner, self.anchor, self.x, self.y = owner, anchor, x, y
		self.lines = {}
		self.setOwnerCalls = self.setOwnerCalls + 1
	end
	function tip:ClearLines()
		self.lines = {}
	end
	function tip:AddLine(text, r, g, b, wrap)
		self.lines[#self.lines + 1] = { text = text, color = { r, g, b }, wrap = wrap }
	end
	function tip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
		self.lines[#self.lines + 1] = { text = left .. " | " .. right, color = { lr, lg, lb }, right = { rr, rg, rb } }
	end
	function tip:Show()
		self.shown = true
	end
	function tip:Hide()
		self.shown, self.owner = false, nil
	end
	function tip:IsOwned(owner)
		return self.owner == owner
	end
	function tip:texts()
		local out = {}
		for i, line in ipairs(self.lines) do
			out[i] = line.text
		end
		return out
	end
	return tip
end

describe("OrdaenCore.UI tooltips", function()
	local UI, tip, errors, owner

	before_each(function()
		tip, errors = recordingTooltip(), {}
		helpers.stubGlobals({
			GameTooltip = tip,
			geterrorhandler = function()
				return function(err)
					errors[#errors + 1] = tostring(err)
				end
			end,
		})
		UI = helpers.loadCore().UI
		owner = { name = "Owner" }
	end)

	local content = {
		v = 1,
		title = { text = "Clock", icon = 134400 },
		subtitle = { text = "Server time" },
		{ kind = "row", label = "Invites", value = 2, color = { 1, 0.5, 0 } },
		{ kind = "line", text = "A line" },
		{ kind = "bar", label = "Rested", value = 3, max = 10 },
		{ kind = "separator" },
		{ kind = "hint", text = "Click: open the calendar" },
	}

	describe("without a renderer (plain GameTooltip lines)", function()
		it("draws every v1 slot in order, anchored as asked", function()
			UI.ShowTooltip(owner, content, { anchor = "ANCHOR_LEFT", x = 2, y = -3 })
			assert.equals(owner, tip.owner)
			assert.equals("ANCHOR_LEFT", tip.anchor)
			assert.equals(2, tip.x)
			assert.is_true(tip.shown)
			assert.same({
				"|T134400:0|t Clock",
				"Server time",
				"Invites | 2",
				"A line",
				"Rested: 3 / 10",
				" ",
				"Click: open the calendar",
			}, tip:texts())
			assert.same({ 1, 0.5, 0 }, tip.lines[3].right) -- a meaning color reaches the value
			assert.same({ 0.5, 0.5, 0.5 }, tip.lines[7].color) -- hints are grey
		end)

		it("skips unknown slots, showing their text when they have one", function()
			UI.ShowTooltip(owner, {
				v = 2,
				{ kind = "sparkline", points = { 1, 2 } },
				{ kind = "badge", text = "NEW" },
				{ kind = "line", text = "kept" },
			})
			assert.same({ "NEW", "kept" }, tip:texts())
		end)

		it("redraws in place on refresh, using the changed content table (no copy)", function()
			local live = { v = 1, title = { text = "12:00" } }
			UI.ShowTooltip(owner, live)
			live.title.text = "12:01"
			UI.RefreshTooltip(owner)
			assert.same({ "12:01" }, tip:texts())
			assert.equals(1, tip.setOwnerCalls) -- not re-anchored
		end)

		it("hides only its own tooltip, and refresh does nothing once hidden", function()
			UI.ShowTooltip(owner, content)
			local other = { name = "Other" }
			UI.HideTooltip(other)
			assert.is_true(tip.shown)
			UI.HideTooltip(owner)
			assert.is_false(tip.shown)
			UI.RefreshTooltip(owner)
			assert.is_false(tip.shown)
		end)

		it("leaves the tooltip alone when someone else took it over", function()
			UI.ShowTooltip(owner, content)
			tip:SetOwner({ name = "Blizzard" })
			UI.HideTooltip(owner)
			assert.is_nil(tip.lines[1])
			assert.is_true(tip.owner ~= nil)
		end)
	end)

	describe("with a renderer", function()
		local calls, renderer

		before_each(function()
			calls = {}
			renderer = {
				formatVersion = 1,
				Show = function(o, c, opts)
					calls[#calls + 1] = { "Show", o, c, opts }
				end,
				Hide = function(o)
					calls[#calls + 1] = { "Hide", o }
				end,
				Refresh = function(o, c)
					calls[#calls + 1] = { "Refresh", o, c }
				end,
			}
			UI.RegisterRenderer("tooltip", renderer)
		end)

		it("hands over the caller's own tables, and the Core draws nothing", function()
			local opts = { anchor = "ANCHOR_TOP" }
			UI.ShowTooltip(owner, content, opts)
			UI.RefreshTooltip(owner)
			UI.HideTooltip(owner)
			assert.same({ "Show", "Refresh", "Hide" }, { calls[1][1], calls[2][1], calls[3][1] })
			assert.equals(content, calls[1][3])
			assert.equals(opts, calls[1][4])
			assert.equals(content, calls[2][3])
			assert.is_false(tip.shown)
		end)

		it("hands over content newer than the renderer knows", function()
			UI.ShowTooltip(owner, { v = 9 })
			assert.equals(9, calls[1][3].v)
		end)

		it("falls back to plain lines when the renderer errors, and reports the error", function()
			renderer.Show = function()
				error("renderer bug")
			end
			UI.ShowTooltip(owner, content)
			assert.is_true(tip.shown)
			assert.equals("|T134400:0|t Clock", tip.lines[1].text)
			assert.equals(1, #errors)
			assert.truthy(errors[1]:find("renderer bug", 1, true))
			-- from then on this tooltip is ours: hide goes to GameTooltip, not the renderer
			UI.HideTooltip(owner)
			assert.is_false(tip.shown)
		end)

		it("falls back on a failing refresh too", function()
			UI.ShowTooltip(owner, content)
			renderer.Refresh = function()
				error("refresh bug")
			end
			UI.RefreshTooltip(owner)
			assert.is_true(tip.shown)
			assert.equals(1, #errors)
			assert.equals("Hide", calls[#calls][1]) -- the renderer's half-drawn tooltip is hidden first
		end)

		it("is replaced by a later registration; a tooltip already shown is hidden by its own renderer", function()
			UI.ShowTooltip(owner, content)
			local second = { Show = function() end, Hide = function() end, Refresh = function() end }
			UI.RegisterRenderer("tooltip", second)
			UI.HideTooltip(owner)
			assert.equals("Hide", calls[#calls][1])
		end)
	end)

	describe("RegisterRenderer", function()
		it("rejects a tooltip renderer that lacks a function", function()
			assert.has_error(function()
				UI.RegisterRenderer("tooltip", { Show = function() end, Hide = function() end })
			end, "OrdaenCore.UI.RegisterRenderer: a tooltip renderer needs a Refresh function")
		end)

		it("rejects bad arguments", function()
			assert.has_error(function()
				UI.RegisterRenderer(nil, {})
			end)
		end)

		it("accepts kinds this Core doesn't draw yet (a newer renderer addon on an older Core)", function()
			UI.RegisterRenderer("window", { Open = function() end })
		end)
	end)

	it("publishes the API on the global OrdaenCore", function()
		assert.equals(UI, rawget(_G, "OrdaenCore").UI)
		for _, name in ipairs({ "ShowTooltip", "HideTooltip", "RefreshTooltip", "RegisterRenderer" }) do
			assert.is_function(UI[name], name)
		end
	end)
end)
