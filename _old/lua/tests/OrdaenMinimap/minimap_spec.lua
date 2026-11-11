-- Ordaen Minimap on the fake client, as built: Blizzard's cluster and the dev addon's own minimap button are hidden
-- (the Ordaen button on the ring takes its place), and another addon's minimap button goes into the drawer, off the
-- map.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("Ordaen Minimap", function()
	local wow, addonButton

	setup(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenMinimap" } })
		local env = wow.env
		local cluster = env.CreateFrame("Frame", "MinimapCluster", env.UIParent)
		env.CreateFrame("Minimap", "Minimap", cluster)
		cluster.Tracking = env.CreateFrame("Frame", nil, cluster)
		cluster.Tracking.Button = env.CreateFrame("Button", nil, cluster.Tracking)
		env.CreateFrame("Button", "OrdaenDevButton", env.Minimap)
		addonButton = env.CreateFrame("Button", "LibDBIcon10_SomeAddon", env.Minimap)
		addonButton:SetSize(31, 31)
		wow:Login()
		wow:Tick()
		wow:Tick()
	end)

	it("raises no Lua errors", function()
		assert.are.same({}, wow.errors)
	end)

	it("hides Blizzard's minimap cluster", function()
		assert.is_false(wow.env.MinimapCluster:IsShown())
	end)

	it("hides the dev addon's own minimap button", function()
		assert.is_false(wow.env.OrdaenDevButton:IsShown())
	end)

	it("takes other addons' minimap buttons off the map", function()
		assert.are_not.equal(wow.env.Minimap, addonButton:GetParent())
	end)
end)
