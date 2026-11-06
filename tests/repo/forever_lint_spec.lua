-- scripts/forever_lint.lua against deliberately wrong code, using the REAL current Forever API
-- (api/forever/CURRENT), so a pass here means the checks fire on what Forever actually has.
local Lint = dofile("scripts/forever_lint.lua")
local forever = require("tests.repo.forever_api")

describe("forever-lint", function()
	if not forever.Current() then
		pending("no API dump imported yet")
		return
	end
	local api = Lint.LoadApi(".")

	local function codes(source)
		local out = {}
		for _, f in ipairs(Lint.LintSource(api, source)) do
			out[#out + 1] = f.code .. "@" .. f.line
		end
		return out
	end

	it("passes correct code", function()
		assert.same({}, codes([[
local f = CreateFrame("Frame", "X", UIParent, "BackdropTemplate")
f:RegisterEvent("PLAYER_LOGIN")
f:SetBackdrop({})
f.icon = f:CreateTexture(nil, "ARTWORK")
f.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
local label = f:CreateFontString(nil, "OVERLAY")
label:SetText("hi")
C_Timer.After(1, function() end)
local name = C_AddOns.GetAddOnMetadata("OrdaenCore", "Title")
C_AddOns.DisableAddOn(name)
]]))
	end)

	it("FL1: flags an event Forever doesn't document", function()
		assert.same({ "FL1@2" }, codes([[
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGN")
]]))
	end)

	it("FL2: flags a method the widget type doesn't have", function()
		assert.same({ "FL2@2", "FL2@4", "FL2@6" }, codes([[
local t = CreateFrame("Frame"):CreateTexture()
t:SetText("textures have no text")
local f = CreateFrame("Frame")
f:SetBackdrop({}) -- no BackdropTemplate
f.icon = f:CreateTexture()
f.icon:SetText("nor here")
]]))
	end)

	it("FL2: trusts templates it can't see into, and stops guessing after a reassignment", function()
		assert.same({}, codes([[
local b = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
b:SetSomethingFromTheTemplate()
local t = CreateFrame("Frame"):CreateTexture()
t = getSomethingElse()
t:SetText("unknown now")
]]))
	end)

	it("FL2: checks methods on dumped Blizzard objects, at any depth", function()
		local deep = Lint.Prepare({
			meta = {},
			widgets = { Button = { "Click", "SetPoint" } },
			objects = {
				Minimap = { SetMaskTexture = "function", ZoomIn = "widget" },
				["MinimapCluster.Tracking.Button"] = { ["<objectType>"] = "Button", menu = "table" },
				["MinimapCluster.Tracking.Alias"] = { ["<ref>"] = "MinimapCluster.Tracking.Button" },
				UIParent = { ["<truncated>"] = "20000" },
			},
		})
		local found = {}
		for _, f in ipairs(Lint.LintSource(deep, [[
Minimap:SetMaskTexture("x")
Minimap:SetMaskTextureTypo("x")
MinimapCluster.Tracking.Button:SetPoint("CENTER")
MinimapCluster.Tracking.Button:Bogus()
MinimapCluster.Tracking.Alias:Bogus()
UIParent:AnythingGoes()
local Minimap = getMyOwnTable()
Minimap:Whatever()
]])) do
			found[#found + 1] = f.code .. "@" .. f.line
		end
		assert.same({ "FL2@2", "FL2@4", "FL2@5" }, found)
	end)

	it("FL3: checks too few arguments only once the dump records defaults", function()
		local function prepared(withDefaults)
			return Lint.Prepare({
				meta = { docsDefaults = withDefaults },
				widgets = {},
				functions = {
					["C_AddOns.DisableAddOn"] = { args = {
						{ name = "name", type = "uiAddon", nilable = false, default = false },
						{ name = "character", type = "cstring", nilable = false, default = withDefaults or nil },
					} },
					["C_AddOns.GetAddOnMetadata"] = { args = {
						{ name = "name", type = "uiAddon", nilable = false, default = false },
						{ name = "variable", type = "cstring", nilable = false, default = false },
					} },
				},
			})
		end
		local source = 'C_AddOns.DisableAddOn("X")\nC_AddOns.GetAddOnMetadata("X")\nC_AddOns.GetAddOnMetadata(f())\n'
		local withDefaults = {}
		for _, f in ipairs(Lint.LintSource(prepared(true), source)) do
			withDefaults[#withDefaults + 1] = f.code .. "@" .. f.line
		end
		assert.same({ "FL3@2" }, withDefaults) -- line 1: character has a default; line 3: f() may return two
		assert.same({}, Lint.LintSource(prepared(false), source))
	end)

	it("FL3: flags too many arguments, but not a trailing call that may return several", function()
		assert.same({ "FL3@1" }, codes([[
C_Timer.After(1, function() end, "extra")
C_Timer.After(f())
UnitClass(unpack(list))
]]))
	end)

	it("FL4: flags literals of the wrong kind", function()
		assert.same({ "FL4@1", "FL4@2" }, codes([[
C_Timer.After("1", function() end)
UnitClass(42)
C_AddOns.IsAddOnLoaded(3) -- an addon index is fine
]]))
	end)

	it("FL5: flags an unknown frame type", function()
		assert.same({ "FL5@1" }, codes([[
local f = CreateFrame("Buton")
]]))
	end)

	it("FL6: flags debug kit methods called with '.', on any form of the kit", function()
		assert.same({ "FL6@2", "FL6@3", "FL6@4", "FL6@5" }, codes([[
local ns, A = {}, {}
Debug.Log("x")
ns.Debug.Wrap(fn)
debug().Logf("%d", 1)
A.Debug.TraceEnabled()
Debug:Log("fine")
debug():Logf("fine")
ns.Map.Log("not the kit")
string.format("%d", 1)
]]))
	end)

	it("honors forever-lint: ignore comments", function()
		assert.same({ "FL1@3" }, codes([[
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGN") -- forever-lint: ignore FL1
f:RegisterEvent("PLAYER_LOGN") -- forever-lint: ignore FL2
f:RegisterEvent("PLAYER_LOGN") -- forever-lint: ignore
]]))
	end)

	it("reports positions as line and column", function()
		local findings = Lint.LintSource(api, 'local f = CreateFrame("Frame")\n  f:RegisterEvent("NOPE")\n')
		assert.equals(2, findings[1].line)
		assert.equals(19, findings[1].column) -- the opening quote of "NOPE"
	end)

	it("finds nothing in our addons", function()
		local p = io.popen("find addons -name '*.lua' | sort")
		local problems = {}
		for file in p:lines() do
			local h = assert(io.open(file, "rb"))
			for _, f in ipairs(Lint.LintSource(api, h:read("*a"))) do
				problems[#problems + 1] = string.format("%s:%d %s %s", file, f.line, f.code, f.message)
			end
			h:close()
		end
		p:close()
		assert.same({}, problems)
	end)
end)

describe("json", function()
	local json = dofile("scripts/json.lua")

	it("round-trips what the importer writes, with sorted keys", function()
		local value = { b = { 1, 2, { x = "q\"uote\n" } }, a = true, c = json.array({}), d = {}, e = 1.5 }
		local text = json.encode(value)
		assert.truthy(text:find('"a": true', 1, true) < text:find('"b": [', 1, true))
		assert.truthy(text:find('"c": []', 1, true))
		assert.truthy(text:find('"d": {}', 1, true))
		local back = json.decode(text)
		assert.same({ 1, 2, { x = "q\"uote\n" } }, back.b)
		assert.equals(1.5, back.e)
		assert.is_true(back.a)
	end)

	it("decodes escapes and null", function()
		local v = json.decode('{"s": "a\\u00e9\\t", "n": null, "list": [1, -2.5e1]}')
		assert.equals("a\195\169\t", v.s)
		assert.is_nil(v.n)
		assert.same({ 1, -25 }, v.list)
	end)
end)
