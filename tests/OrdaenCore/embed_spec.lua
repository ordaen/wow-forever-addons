-- game.ui:Embed and game.ui:Frame from one call site in a loop (addons/OrdaenCore/Draw.lua), on the fake client as
-- built: each Blizzard frame is its own entry (keyed by the frame itself), so several from one site never take each
-- other's place, keep their place when the loop reorders, and the one the loop drops goes back as it was.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("Draw: Blizzard frames from one call site in a loop", function()
	local wow, ns, env, blizzard, frames, version, kind, embedded

	local function ref(frame)
		return { Get = function()
			return frame
		end }
	end

	before_each(function()
		embedded = { attributes = { width = 30, height = 30 } }
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns, env = wow.addons.OrdaenCore.ns, wow.env
		blizzard = env.CreateFrame("Frame", nil, env.UIParent) -- where Blizzard keeps its buttons
		frames = {}
		for i = 1, 3 do
			local f = env.CreateFrame("Button", nil, blizzard)
			f:SetSize(10, 10)
			f:SetPoint("TOPLEFT", blizzard, "TOPLEFT", i * 10, 0)
			frames[i] = { name = "B" .. i, frame = f, ref = ref(f) }
		end
		version = ns.NewValue(0)
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		local game = ns.Game.ForModule(module)
		local Component = ns.Define.Component({
			Render = function(g)
				version:Get() -- re-runs when the spec changes the list
				local box = { attributes = { columns = 3, width = 120, height = 40 } }
				g.ui:Box(1, box)
				for _, b in ipairs(frames) do
					if kind == "embed" then
						g.ui:Embed(2, b.ref, embedded)
					else
						g.ui:Frame(3, b.ref, { attributes = { opacity = 0.5 } })
					end
				end
			end,
		})
		ns.Engine:Mount(nil, Component, 0, {}, ns.Game.Layer.Screen, module, game)
	end)

	local function rerun(list)
		frames = list
		version:Set(version:Peek() + 1)
		ns.Scheduler.Flush()
	end

	it("embeds every frame, keeps each through a reorder, and gives back the one dropped", function()
		kind = "embed"
		rerun(frames)
		local a, b, c = frames[1], frames[2], frames[3]
		local ours = a.frame:GetParent()
		assert.are_not.equal(blizzard, ours)
		for _, x in ipairs({ a, b, c }) do
			assert.are.equal(ours, x.frame:GetParent(), x.name .. " embedded")
			assert.is_true(x.frame:IsShown(), x.name .. " shown")
		end
		rerun({ c, a, b }) -- reordered: still all three, none replaced
		for _, x in ipairs({ a, b, c }) do
			assert.are.equal(ours, x.frame:GetParent(), x.name .. " still embedded")
		end
		rerun({ c, a }) -- b dropped: back where Blizzard had it
		assert.are.equal(blizzard, b.frame:GetParent())
		assert.are.equal(ours, a.frame:GetParent())
		assert.are.equal(ours, c.frame:GetParent())
		assert.are.same({}, wow.errors)
	end)

	it("keeps an embedded frame's opacity when Blizzard sets its alpha, and gives Blizzard's back", function()
		kind, embedded = "embed", { attributes = { width = 30, height = 30, opacity = 0 } }
		rerun(frames)
		local a = frames[1]
		assert.are.equal(0, a.frame:GetAlpha())
		a.frame:SetAlpha(0.5) -- a micro button's OnDisable
		assert.are.equal(0, a.frame:GetAlpha())
		rerun({ frames[2], frames[3] }) -- dropped: Blizzard's last alpha
		assert.are.equal(0.5, a.frame:GetAlpha())
		assert.are.same({}, wow.errors)
	end)

	it("takes every frame over and gives back the one dropped", function()
		kind = "frame"
		rerun(frames)
		local a, b, c = frames[1], frames[2], frames[3]
		for _, x in ipairs({ a, b, c }) do
			assert.are.equal(0.5, x.frame:GetAlpha(), x.name .. " taken")
		end
		rerun({ a, c })
		assert.are.equal(1, b.frame:GetAlpha())
		assert.are.equal(0.5, a.frame:GetAlpha())
		assert.are.equal(0.5, c.frame:GetAlpha())
		assert.are.same({}, wow.errors)
	end)
end)
