describe("OrdaenMinimap conflicts", function()
	local ns

	before_each(function()
		ns = {}
		assert(loadfile("addons/OrdaenMinimap/Conflicts.lua"))("OrdaenMinimap", ns)
	end)

	describe("FindKnownConflict", function()
		local function loaded(set)
			return function(name)
				return set[name] == true
			end
		end

		it("finds a loaded dedicated minimap addon", function()
			assert.equals("SexyMap", ns.FindKnownConflict(loaded({ SexyMap = true })))
		end)

		it("ignores addons that aren't loaded and ones the user chose to override", function()
			assert.is_nil(ns.FindKnownConflict(loaded({ Details = true })))
			assert.is_nil(ns.FindKnownConflict(loaded({ SexyMap = true }), { SexyMap = "ours" }))
		end)
	end)

	describe("AddonFromStack", function()
		it("names the first foreign addon in the stack", function()
			local stack = table.concat({
				[[[string "@Interface/AddOns/OrdaenMinimap/Map.lua"]:70: in function <...>]],
				"[C]: in function 'SetMaskTexture'",
				[[[string "@Interface/AddOns/SexyMap/Shapes.lua"]:348: in function 'ApplyShape']],
			}, "\n")
			assert.equals("SexyMap", ns.AddonFromStack(stack))
		end)

		it("handles backslashes and odd casing", function()
			local stack = [[interface\addons\EnhanceQoL\EnhanceQoL_Camelot.lua:4325: in function]]
			assert.equals("EnhanceQoL", ns.AddonFromStack(stack))
		end)

		it("returns nil for Blizzard code and for our own addons", function()
			assert.is_nil(ns.AddonFromStack("Interface/AddOns/Blizzard_Minimap/Minimap.lua:120: in function"))
			assert.is_nil(ns.AddonFromStack("Interface/FrameXML/Minimap.lua:120: in function"))
			assert.is_nil(ns.AddonFromStack("Interface/AddOns/OrdaenCore/Core.lua:10: in function"))
			assert.is_nil(ns.AddonFromStack("Interface/AddOns/OrdaenCore_Debug/Debug.lua:10: in function"))
			assert.is_nil(ns.AddonFromStack(nil))
		end)
	end)

	describe("OwnerFromTaint", function()
		it("returns the tainting addon", function()
			assert.equals("EnhanceQoL", ns.OwnerFromTaint(false, "EnhanceQoL"))
		end)

		it("returns nil for secure (Blizzard) and our own definitions", function()
			assert.is_nil(ns.OwnerFromTaint(true, nil))
			assert.is_nil(ns.OwnerFromTaint(false, "OrdaenMinimap"))
			assert.is_nil(ns.OwnerFromTaint(false, nil))
		end)
	end)

	describe("KeepOursAction", function()
		it("disables dedicated minimap addons", function()
			assert.equals("disable", ns.KeepOursAction("SexyMap"))
		end)

		it("overrides multi-purpose and unknown addons instead of disabling them", function()
			assert.equals("override", ns.KeepOursAction("EnhanceQoL"))
			assert.equals("override", ns.KeepOursAction(nil))
		end)
	end)
end)
