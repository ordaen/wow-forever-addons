-- OrdaenCore_Debug/ApiDump.lua: what "Dump game API" records.
local helpers = require("tests.OrdaenCore.helpers")

describe("ApiDump", function()
	local ApiDump

	before_each(function()
		helpers.stubGlobals({
			-- Blizzard names are secure; anything named Addon* was made by an addon.
			issecurevariable = function(_, key)
				return not tostring(key):find("^Addon"), "SomeAddon"
			end,
			time = function()
				return 1000
			end,
		})
		rawset(_G, "OrdaenCoreDebugDB", {})
		rawset(_G, "C_Fake", { DoThing = function() end, AddonExtra = function() end, Count = 3 })
		rawset(_G, "AddonGlobal", function() end)
		local huge = {}
		for i = 1, 5001 do
			huge["k" .. i] = i
		end
		rawset(_G, "HugeTable", huge)
		local ns = {}
		assert(loadfile("addons/OrdaenCore/OrdaenCore_Debug/ApiDump.lua"))("OrdaenCore_Debug", ns)
		ApiDump = ns.ApiDump
	end)

	after_each(function()
		for _, name in ipairs({ "C_Fake", "AddonGlobal", "HugeTable", "OrdaenCoreDebugDB" }) do
			rawset(_G, name, nil)
		end
	end)

	it("records Blizzard globals with their types and leaves out addon globals", function()
		local dump = ApiDump.Run()
		assert.equals("table", dump.globals.C_Fake)
		assert.equals("function", dump.globals.CreateFrame)
		assert.is_nil(dump.globals.AddonGlobal)
		assert.is_true(dump.meta.addonGlobals >= 1)
		assert.equals(dump, OrdaenCoreDebugDB.apiDump)
	end)

	it("records namespace members one level deep, Blizzard keys only, names and types", function()
		local dump = ApiDump.Run()
		assert.same({ DoThing = "function", Count = "number" }, dump.namespaces.C_Fake)
	end)

	it("skips huge tables instead of dumping them", function()
		local dump = ApiDump.Run()
		assert.same({ ["<skipped>"] = "5001+" }, dump.namespaces.HugeTable)
	end)

	it("records client facts and whether API docs were available", function()
		local dump = ApiDump.Run()
		assert.equals(16001, dump.meta.interface)
		assert.is_string(dump.meta.docs)
	end)

	it("clears the dump", function()
		ApiDump.Run()
		assert.is_true(ApiDump.Exists())
		ApiDump.Clear()
		assert.is_false(ApiDump.Exists())
	end)
end)
