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
	it("renders constants and facts when the dump records them, and no file for older dumps", function()
		assert.is_nil(Import.Render(fakeDump(70790))["constants.txt"])
		local dump = fakeDump(70790)
		dump.constants = { NUM_ACTIONBAR_PAGES = 6, NUM_OVERRIDE_BUTTONS = 6, ["bad key"] = 1 }
		dump.facts = { ["C_ActionBar.GetVehicleBarIndex"] = "31" }
		local files = Import.Render(dump)
		assert.equals("NUM_ACTIONBAR_PAGES\t6\nNUM_OVERRIDE_BUTTONS\t6\n", files["constants.txt"])
		assert.equals("C_ActionBar.GetVehicleBarIndex\t31\n", files["facts.txt"])
	end)

	it("names the folder after version and build", function()
		assert.equals("1.60.1-70790", Import.FolderName(fakeDump(70790).meta))
	end)

	it("merges a new dump of the same build into the imported one; the new value wins", function()
		-- the dump keeps only what Blizzard set: a field an addon wrote (Ordaen Chat's isStaticDocked) drops out
		local old = "ChatFrame2.isDocked\tnumber\nChatFrame2.isStaticDocked\tboolean\nFrame:Hide\n"
		local new = "ChatFrame2.isDocked\tboolean\nItemButton:SetItem\nFrame:Hide\n"
		assert.equals("ChatFrame2.isDocked\tboolean\nChatFrame2.isStaticDocked\tboolean\nFrame:Hide\nItemButton:SetItem\n",
			Import.Merge(old, new))
		assert.equals("A\tx\n", Import.Merge(nil, "A\tx\n")) -- the first import of a build
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

	it("leaves out names that aren't identifiers (per-user and per-session noise)", function()
		local dump = fakeDump(70790)
		dump.globals["$HealerMarkerCheckButton"] = "widget"
		dump.globals["101_CutsceneName_Ref"] = "string"
		dump.namespaces.hash_SlashCmdList = { ["/om"] = "string", ["/ordaen"] = "string" }
		dump.namespaces.g_addonCategoriesCollapsed = { ["Чат"] = "boolean", Libraries = "boolean" }
		local files = Import.Render(dump)
		assert.is_nil(files["globals.txt"]:find("$Healer", 1, true))
		assert.is_nil(files["globals.txt"]:find("101_", 1, true))
		assert.is_nil(files["namespaces.txt"]:find("/om", 1, true))
		assert.is_nil(files["namespaces.txt"]:find("Чат", 1, true))
		assert.truthy(files["namespaces.txt"]:find("g_addonCategoriesCollapsed.Libraries\tboolean", 1, true))
		assert.truthy(files["namespaces.txt"]:find("Enum.<skipped>\t6000+", 1, true))
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

	it("counts a file the previous version didn't record instead of listing every line", function()
		local old = Import.Render(fakeDump(70790))
		local dump = fakeDump(71000)
		dump.constants = { NUM_ACTIONBAR_PAGES = 6, NUM_OVERRIDE_BUTTONS = 6 }
		local text = Import.Changes({ "1.60.1-70790", "1.60.1-71000" },
			{ ["1.60.1-70790"] = old, ["1.60.1-71000"] = Import.Render(dump) })
		assert.truthy(text:find("### constants.txt (new, 2 entries)", 1, true))
		assert.falsy(text:find("`+ NUM_ACTIONBAR_PAGES", 1, true))
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
		local fs = require("scripts.fs")
		local tmp = fs.TempDir("api-import")
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
		fs.Remove(tmp)
	end)

	-- The planned dump format from wow-dev-tools: full-depth frame trees and argument defaults.
	describe("deep objects and argument defaults", function()
		local function deepDump()
			local dump = fakeDump(71000)
			dump.globals.MinimapCluster = "widget"
			dump.objects = {
				Minimap = { SetMaskTexture = "function", ZoomIn = "widget" },
				["Minimap.ZoomIn"] = { Show = "function", ["<objectType>"] = "Button" },
				MinimapCluster = { Tracking = "widget", UpdateMinimapConfig = "function" },
				["MinimapCluster.Tracking"] = { Button = "widget" },
				["MinimapCluster.Tracking.Button"] = { Click = "function", ["<objectType>"] = "Button" },
				["MinimapCluster.#3"] = { ["<objectType>"] = "Texture", SetAlpha = "function" },
				["MinimapCluster.Tracking.Parent"] = { ["<ref>"] = "MinimapCluster" },
				UIParent = { ["<truncated>"] = "20000" },
			}
			dump.docs = {
				functions = {
					["C_AddOns.DisableAddOn"] = "(name:uiAddon, character:cstring=) -> ()",
					["C_Map.GetBestMapForUnit"] = "(unitToken:UnitToken) -> (uiMapID:number?)",
					["C_Test.Both"] = "(a:number?=, b:string) -> ()",
				},
				events = { PLAYER_LOGIN = "" },
			}
			return dump
		end

		it("keeps every deep path and marker in the text and the JSON", function()
			local files = Import.Render(deepDump())
			assert.truthy(files["objects.txt"]:find("MinimapCluster.Tracking.Button.Click\tfunction\n", 1, true))
			assert.truthy(files["objects.txt"]:find("MinimapCluster.#3.<objectType>\tTexture\n", 1, true))
			assert.truthy(files["objects.txt"]:find("MinimapCluster.Tracking.Parent.<ref>\tMinimapCluster\n", 1, true))
			local api = Import.Structured(files)
			assert.equals("function", api.objects["MinimapCluster.Tracking.Button"].Click)
			assert.equals("Texture", api.objects["MinimapCluster.#3"]["<objectType>"])
			assert.equals("MinimapCluster", api.objects["MinimapCluster.Tracking.Parent"]["<ref>"])
			assert.equals("20000", api.objects.UIParent["<truncated>"])
		end)

		it("gives luacheck only top-level objects with identifier-safe keys", function()
			local source = Import.Luacheck(Import.Render(deepDump()), "1.60.2-71000")
			assert.is_nil(source:find("#3", 1, true))
			assert.is_nil(source:find("<ref>", 1, true))
			assert.is_nil(source:find("<objectType>", 1, true))
			assert.is_nil(source:find("<truncated>", 1, true))
			local globals = assert(loadstring(source))()
			assert.truthy(globals.MinimapCluster.fields.Tracking)
			assert.truthy(globals.MinimapCluster.fields.UpdateMinimapConfig)
			assert.truthy(globals.Minimap.fields.SetMaskTexture)
		end)

		it("reads argument defaults, and marks the dump as recording them", function()
			local api = Import.Structured(Import.Render(deepDump()))
			assert.is_true(api.meta.docsDefaults)
			local disable = api.functions["C_AddOns.DisableAddOn"].args
			assert.same({ name = "character", type = "cstring", nilable = false, default = true }, disable[2])
			assert.is_false(disable[1].default)
			local both = api.functions["C_Test.Both"].args[1]
			assert.same({ name = "a", type = "number", nilable = true, default = true }, both)
		end)

		it("keeps <forbidden> (a table WoW protects) as a marker: it exists, any member may be there", function()
			local dump = deepDump()
			dump.globals.SecureThing = "table"
			dump.namespaces.SecureThing = { ["<forbidden>"] = "1" }
			dump.globals.ProtectedFrame = "widget"
			dump.objects.ProtectedFrame = { ["<forbidden>"] = "1" }
			local files = Import.Render(dump)
			assert.truthy(files["namespaces.txt"]:find("SecureThing.<forbidden>\t1\n", 1, true))
			assert.truthy(files["objects.txt"]:find("ProtectedFrame.<forbidden>\t1\n", 1, true))
			local api = Import.Structured(files)
			assert.equals("1", api.namespaces.SecureThing["<forbidden>"])
			local globals = assert(loadstring(Import.Luacheck(files, "1.60.2-71000")))()
			assert.same({ other_fields = true }, globals.SecureThing)
			assert.same({ other_fields = true }, globals.ProtectedFrame)
			assert.same({ other_fields = true }, globals.UIParent) -- truncated: members not all known either
			local Lint = dofile("scripts/forever_lint.lua")
			assert.is_nil(Lint.ObjectMembers(api, "ProtectedFrame"))
			local luals = dofile("scripts/luals_defs.lua").Generate(api, "1.60.2-71000")
			assert.truthy(luals["objects.lua"]:find("---@class ProtectedFrameObject\n---@field [string] any", 1, true))
			assert.falsy(luals["functions.lua"]:find("<forbidden>", 1, true))
		end)

		it("doesn't claim 'no default' for dumps that don't record defaults", function()
			local api = Import.Structured(Import.Render(fakeDump(70790)))
			assert.is_false(api.meta.docsDefaults)
		end)

		it("doesn't repeat a node's methods that its widget type has, and luacheck still knows them", function()
			local dump = fakeDump(71000)
			dump.globals.ChatFrame1 = "widget"
			dump.widgets.Button = { "Click", "SetPoint", "Show" }
			dump.objects = {
				ChatFrame1 = {
					["<objectType>"] = "Button",
					Click = "function", -- from the Button type: left out
					Show = "function", -- from the Button type: left out
					AddMessage = "function", -- its own (a mixin method): kept
					editBox = "widget",
				},
				["ChatFrame1.#2"] = { ["<objectType>"] = "Button", SetPoint = "function", OnSpecial = "function" },
			}
			local files = Import.Render(dump)
			assert.is_nil(files["objects.txt"]:find("ChatFrame1.Click\t", 1, true))
			assert.is_nil(files["objects.txt"]:find("ChatFrame1.Show\t", 1, true))
			assert.is_nil(files["objects.txt"]:find("ChatFrame1.#2.SetPoint\t", 1, true))
			assert.truthy(files["objects.txt"]:find("ChatFrame1.AddMessage\tfunction\n", 1, true))
			assert.truthy(files["objects.txt"]:find("ChatFrame1.#2.OnSpecial\tfunction\n", 1, true))
			assert.truthy(files["objects.txt"]:find("ChatFrame1.<objectType>\tButton\n", 1, true))

			local globals = assert(loadstring(Import.Luacheck(files, "1.60.2-71000")))()
			for _, key in ipairs({ "Click", "Show", "SetPoint", "AddMessage", "editBox" }) do
				assert.truthy(globals.ChatFrame1.fields[key], key)
			end
			assert.is_nil(globals.ChatFrame1.fields.NoSuchMethod)

			-- forever-lint still sees the inherited methods through <objectType>.
			local Lint = dofile("scripts/forever_lint.lua")
			local api = Lint.Prepare(Import.Structured(files))
			local found = {}
			for _, f in ipairs(Lint.LintSource(api, "ChatFrame1:Click()\nChatFrame1:AddMessage('x')\nChatFrame1:Nope()\n")) do
				found[#found + 1] = f.code .. "@" .. f.line
			end
			assert.same({ "FL2@3" }, found)
		end)
	end)
end)
