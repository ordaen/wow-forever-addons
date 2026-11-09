-- The component library (addons/OrdaenLibrary, Define.Library) on the fake client, as built: a `game.ui:<Name>`
-- that the module's own components/ don't have loads the library (once, at that first call) and draws its
-- component; until then it isn't loaded; a name neither has fails as before.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("the component library", function()
	local wow, ns

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenLibrary" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
		-- a component of the library's, as its build would register components/probe.lua
		wow.addons.OrdaenLibrary.ns["components/probe"] = function(import)
			local Define = import("@ordaen/define")
			return Define.Component({
				Render = function(game, self)
					game.ui:Text(1, { attributes = { text = "from the library" } })
				end,
			})
		end
	end)

	local function texts()
		local out = {}
		local function walk(node)
			if node.kind == "text" then
				out[#out + 1] = node.fs:GetText()
			end
			for i = 1, node.count or 0 do
				walk(node.children[i])
			end
		end
		walk(ns.Game.Layer.Screen.node)
		return out
	end

	local function mount(render)
		local module = { name = "OrdaenSpec", ns = {}, cache = {} }
		module.Import = function(_, path)
			error("OrdaenSpec has no file " .. path, 2)
		end
		ns.Engine:Mount(nil, ns.Define.Component({ Render = render }), 0, {}, ns.Game.Layer.Screen, module,
			ns.Game.ForModule(module))
		ns.Scheduler.Flush()
	end

	it("isn't loaded until a module draws one of its components, then draws it", function()
		assert.is_false(wow.env.C_AddOns.IsAddOnLoaded("OrdaenLibrary"))
		mount(function(game)
			game.ui:Probe(1, {})
		end)
		assert.is_true(wow.env.C_AddOns.IsAddOnLoaded("OrdaenLibrary"))
		assert.are.same({ "from the library" }, texts())
		assert.are.same({}, wow.errors)
	end)

	it("fails a name neither the module nor the library has", function()
		mount(function(game)
			game.ui:Nothing(1, {})
		end)
		assert.is_truthy(table.concat(wow.errors, "\n"):find("has no file components/nothing", 1, true))
	end)
end)
