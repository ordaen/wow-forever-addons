-- scripts/api_import.lua, against a fake in-game dump in the format ApiDump.lua writes.
local Import = dofile("scripts/api_import.lua")

local function fakeDump(build, extra)
	local dump = {
		meta = { version = "1.60.1", build = tostring(build), date = "Oct 1 2026", interface = 16001, locale = "ruRU" },
		globals = {
			CreateFrame = "function",
			C_AddOns = "table",
			Minimap = "widget",
			UIParent = "widget",
			RAID_CLASS_COLORS = "table",
			SETTINGS = "string",
			Enum = "table",
		},
		namespaces = {
			C_AddOns = { GetAddOnMetadata = "function", IsAddOnLoaded = "function" },
			RAID_CLASS_COLORS = { WARRIOR = "table" },
			Enum = { ["<skipped>"] = "6000+" },
		},
		widgets = {
			Frame = { "IsMouseOver", "SetPoint", "Show" },
			Texture = { "SetTexture" },
			Line = false,
		},
		objects = {
			Minimap = { SetMaskTexture = "function", ZoomIn = "widget" },
			["Minimap.ZoomIn"] = { Show = "function" },
		},
	}
	for k, v in pairs(extra or {}) do
		dump.globals[k] = v
	end
	return dump
end

describe("api_import", function()
	it("names the folder after version and build", function()
		assert.equals("1.60.1-70790", Import.FolderName(fakeDump(70790).meta))
	end)

	it("renders sorted, one-entry-per-line files", function()
		local files = Import.Render(fakeDump(70790))
		assert.truthy(files["globals.txt"]:find("CreateFrame\tfunction\n", 1, true))
		assert.truthy(files["namespaces.txt"]:find("C_AddOns.IsAddOnLoaded\tfunction\n", 1, true))
		assert.truthy(files["widgets.txt"]:find("Frame:IsMouseOver\n", 1, true))
		assert.truthy(files["widgets.txt"]:find("Line\tunavailable\n", 1, true))
		assert.truthy(files["objects.txt"]:find("Minimap.SetMaskTexture\tfunction\n", 1, true))
		assert.truthy(files["meta.txt"]:find("build=70790\n", 1, true))
		assert.is_nil(files["docs.txt"])
		-- sorted
		local previous = ""
		for line in files["globals.txt"]:gmatch("[^\n]+") do
			assert.is_true(previous < line, line)
			previous = line
		end
	end)

	it("diffs two versions", function()
		local added, removed = Import.Diff("a\nb\n", "b\nc\n")
		assert.same({ "c" }, added)
		assert.same({ "a" }, removed)
	end)

	it("orders versions by build number", function()
		assert.same({ "1.60.1-9", "1.60.1-70790", "1.61.0-71000" },
			Import.SortVersions({ "1.61.0-71000", "1.60.1-9", "1.60.1-70790" }))
	end)

	it("writes CHANGES.md newest first, with what each version added and removed", function()
		local old = Import.Render(fakeDump(70790, { MouseIsOver = "function" }))
		local new = Import.Render(fakeDump(71000, { C_NewThing = "table" }))
		local text = Import.Changes({ "1.60.1-70790", "1.60.1-71000" },
			{ ["1.60.1-70790"] = old, ["1.60.1-71000"] = new })
		assert.truthy(text:find("## 1.60.1-71000", 1, true) < text:find("## 1.60.1-70790", 1, true))
		assert.truthy(text:find("`+ C_NewThing\ttable`", 1, true))
		assert.truthy(text:find("`- MouseIsOver\tfunction`", 1, true))
		assert.truthy(text:find("First dump.", 1, true))
	end)

	describe("luacheck globals", function()
		local globals

		before_each(function()
			local source = Import.Luacheck(Import.Render(fakeDump(70790)), "1.60.1-70790")
			globals = assert(loadstring(source))()
		end)

		it("lists namespaces with their exact functions", function()
			assert.same({}, globals.C_AddOns.fields.IsAddOnLoaded)
			assert.is_nil(globals.C_AddOns.fields.DisableAddOn) -- so luacheck flags it
		end)

		it("lets table members and huge tables have any fields", function()
			assert.same({ other_fields = true }, globals.RAID_CLASS_COLORS.fields.WARRIOR)
			assert.same({ other_fields = true }, globals.Enum)
		end)

		it("gives dumped objects their real members and other widgets any field", function()
			assert.truthy(globals.Minimap.fields.SetMaskTexture)
			assert.is_nil(globals.Minimap.fields.NoSuchMethod)
			assert.same({ other_fields = true }, globals.UIParent)
		end)

		it("lists plain functions and constants, and nothing that isn't there", function()
			assert.same({}, globals.CreateFrame)
			assert.same({}, globals.SETTINGS)
			assert.is_nil(globals.MouseIsOver)
		end)
	end)

	it("imports a SavedVariables file end to end", function()
		local tmp = os.tmpname()
		os.remove(tmp)
		os.execute('mkdir -p "' .. tmp .. '"')
		local saved = tmp .. "/OrdaenCore_Debug.lua"
		local serialize
		serialize = function(v)
			if type(v) == "table" then
				local parts = {}
				for k, item in pairs(v) do
					local key = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
					parts[#parts + 1] = key .. " = " .. serialize(item)
				end
				return "{" .. table.concat(parts, ", ") .. "}"
			elseif type(v) == "string" then
				return string.format("%q", v)
			end
			return tostring(v)
		end
		local f = assert(io.open(saved, "w"))
		f:write("OrdaenCoreDebugDB = " .. serialize({ session = 3, apiDump = fakeDump(70790) }) .. "\n")
		f:close()

		Import.Main(saved, tmp)

		local function read(path)
			local h = assert(io.open(tmp .. "/api/forever/" .. path))
			local content = h:read("*a")
			h:close()
			return content
		end
		assert.equals("1.60.1-70790\n", read("CURRENT"))
		assert.truthy(read("1.60.1-70790/globals.txt"):find("CreateFrame", 1, true))
		assert.truthy(read("CHANGES.md"):find("First dump.", 1, true))
		assert.is_table(assert(loadstring(read("luacheck.lua")))())
		os.execute('rm -rf "' .. tmp .. '"')
	end)
end)
