-- Ordaen Core: modules (Modules.lua). Every other Ordaen addon is a load-on-demand module that Ordaen loads while
-- it's on; Ordaen's own parts (OrdaenCore_UI, the dev addon) and other addons aren't modules.
local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore modules", function()
	local Core, addons, loads

	before_each(function()
		-- name, load on demand, what LoadAddOn answers (true, or false and Blizzard's reason)
		addons = {
			{ "OrdaenCore", false }, { "OrdaenCore_UI", true }, { "OrdaenCore_Debug", true },
			{ "OrdaenBags", true }, { "OrdaenPanel", true, "DISABLED" }, { "Baganator", true }, { "OrdaenOld", false },
		}
		loads = {}
		helpers.stubGlobals({
			C_AddOns = {
				GetAddOnMetadata = function(_, field)
					return field == "Version" and "1.2.3" or nil
				end,
				GetNumAddOns = function()
					return #addons
				end,
				GetAddOnInfo = function(i)
					return addons[i][1]
				end,
				IsAddOnLoadOnDemand = function(i)
					return addons[i][2]
				end,
				IsAddOnLoaded = function(name)
					return loads[name] == true
				end,
				LoadAddOn = function(name)
					for _, a in ipairs(addons) do
						if a[1] == name then
							if a[3] then
								return false, a[3]
							end
							loads[name] = true
							return true
						end
					end
					return false, "MISSING"
				end,
			},
		})
		Core = helpers.loadCore()
	end)

	it("are the installed Ordaen<Name> addons that load on demand, not Ordaen's own parts", function()
		assert.same({ "OrdaenBags", "OrdaenPanel" }, Core.Modules.List())
	end)

	it("load while on, and say why one didn't", function()
		assert.is_true(Core.Modules.IsOn("OrdaenBags"), "a module is on until the player turns it off")
		Core.Modules.LoadEnabled()
		assert.is_true(loads.OrdaenBags)
		assert.is_nil(loads.OrdaenCore_UI, "Ordaen's own load-on-demand part loads when it's needed, not here")
		assert.is_nil(loads.Baganator, "other addons are never loaded")
		assert.equals("DISABLED", Core.Modules.Why("OrdaenPanel"), "turned off in Blizzard's AddOns list")
		assert.is_nil(Core.Modules.Why("OrdaenBags"))
	end)

	it("start when loaded, though their own ADDON_LOADED doesn't reach them inside Ordaen's", function()
		local started = false
		local A = Core.NewAddon("OrdaenBags", {}, {}) -- what the module's file does while LoadAddOn runs it
		A:OnLoad(function()
			started = true
		end)
		Core.Modules.LoadEnabled() -- the fake LoadAddOn fires no ADDON_LOADED, as the game did (2026-11-07)
		assert.is_true(started)
	end)
end)
