-- The drawing backend's inspector (dev mode): what it tells of the box behind a frame.
local Fake = require("tests.fake.wow")

describe("Core._Inspect", function()
	it("describes a box behind its frame, and nothing for a frame that isn't ours", function()
		local wow = Fake.New({ dist = ".ordaen/check/dist", addons = { "OrdaenCore" } })
		wow:Login()
		local ns = wow.addons.OrdaenCore.ns
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local box = Backend:Create("box")
		Backend:Set(box, { position = "absolute", left = 10, top = 20, width = 30, height = 40,
			background = { 1, 0, 0, 1 } })
		Backend:SetChildren(layer, { box }, 1)
		Backend:Flush()
		local info = ns.Core._Inspect(box.frame)
		assert.are.equal("box", info.kind)
		assert.is_truthy(info.attributes:find("width=30", 1, true), info.attributes)
		assert.is_truthy(info.layout:find("pos=absolute", 1, true), info.layout) -- sizes snap to pixels
		assert.is_truthy(info.frame:find("TOPLEFT", 1, true), info.frame)
		assert.is_nil(ns.Core._Inspect(wow.env.CreateFrame("Frame")))
		assert.are.same({}, wow.errors)
	end)
end)
