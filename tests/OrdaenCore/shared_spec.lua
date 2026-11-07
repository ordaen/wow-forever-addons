-- Ordaen Core: shared items (Shared.lua). One Ordaen addon at a time shows the zone name or the time: turning it on
-- in one turns it off in the others, both ways; the owners are saved in OrdaenCoreDB.sharedOwners.
local helpers = require("tests.OrdaenCore.helpers")

-- The saved owners (OrdaenCoreDB.sharedOwners), read without touching the global by name (luacheck).
local function owners()
	return rawget(_G, "OrdaenCoreDB").sharedOwners
end

describe("OrdaenCore shared items", function()
	local Core, loaded, minimap, panel, events

	-- Two addons taking part, each switching only its own setting when Core tells it.
	local function addons()
		events = {}
		local function holder(name, fallback)
			local A = Core.NewAddon(name, {}, {})
			local state = { on = false }
			state.hold = A:Shared("zone", {
				lost = function()
					state.on = false
					events[#events + 1] = name .. " lost"
				end,
				regained = function()
					state.on = true
					events[#events + 1] = name .. " regained"
				end,
				fallback = fallback,
			})
			return state
		end
		minimap = holder("OrdaenMinimap", true)
		panel = holder("OrdaenPanel", false)
	end

	before_each(function()
		loaded = { OrdaenMinimap = true, OrdaenPanel = true }
		helpers.stubGlobals({
			C_AddOns = {
				GetAddOnMetadata = function(_, field)
					return field == "Version" and "1.2.3" or nil
				end,
				IsAddOnLoaded = function(name)
					return loaded[name] == true
				end,
			},
		})
		Core = helpers.loadCore()
		Core._Shared._Clear()
		rawset(_G, "OrdaenCoreDB", { sharedOwners = {} })
		addons()
	end)

	it("turns the other addon's item off when one claims it, both ways", function()
		minimap.on = minimap.hold:Sync(true) -- fresh: the minimap shows the zone name
		assert.equals("OrdaenMinimap", minimap.hold:Owner())

		panel.on = true -- the player puts the zone name in the panel
		panel.hold:Claim()
		assert.same({ "OrdaenMinimap lost" }, events)
		assert.is_false(minimap.on)
		assert.equals("OrdaenPanel", owners().zone)

		minimap.on = true -- and turns the minimap's back on
		minimap.hold:Claim()
		assert.same({ "OrdaenMinimap lost", "OrdaenPanel lost" }, events)
		assert.is_false(panel.on)
		assert.equals("OrdaenMinimap", owners().zone)

		minimap.hold:Claim() -- again: nothing happens
		assert.equals(2, #events)
	end)

	it("forgets the owner when its setting goes off; nobody shows it then", function()
		panel.hold:Claim()
		panel.hold:Release()
		assert.is_nil(owners().zone)
		minimap.hold:Release() -- not the owner: nothing
		assert.is_nil(minimap.hold:Owner())
	end)

	it("at login keeps the recorded owner when both settings are on, whichever syncs first", function()
		owners().zone = "OrdaenPanel"
		assert.is_false(minimap.hold:Sync(true))
		assert.is_true(panel.hold:Sync(true))
		assert.same({ "OrdaenMinimap lost" }, events)

		-- the other order
		Core._Shared._Clear()
		addons()
		assert.is_true(panel.hold:Sync(true))
		assert.is_false(minimap.hold:Sync(true))
		assert.same({ "OrdaenMinimap lost" }, events)
	end)

	it("gives the item back to the fallback when its owner isn't loaded any more", function()
		owners().zone = "OrdaenPanel"
		loaded.OrdaenPanel = false -- removed or disabled
		Core._Shared._Clear()
		local A = Core.NewAddon("OrdaenMinimap", {}, {})
		local regained = false
		local hold = A:Shared("zone", {
			regained = function()
				regained = true
			end,
			fallback = true,
		})
		assert.is_true(hold:Sync(false)) -- its setting was off (the panel had it)
		assert.is_true(regained)
		assert.equals("OrdaenMinimap", owners().zone)
	end)

	it("doesn't give it to a non-fallback addon, and an owner whose setting is off lets go", function()
		owners().zone = "OrdaenMinimap"
		loaded.OrdaenMinimap = false
		assert.is_false(panel.hold:Sync(false))
		assert.equals("OrdaenMinimap", owners().zone)

		loaded.OrdaenMinimap = true
		assert.is_false(minimap.hold:Sync(false)) -- the owner's own setting is off: nobody shows it
		assert.is_nil(owners().zone)
	end)
end)
