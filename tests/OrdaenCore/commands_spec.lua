-- /ordaen (addons/OrdaenCore/Commands.lua) on the fake client, as built: one slash command, `/ordaen <module>
-- <command> [arguments]`, modules' declared commands, addons' own (OrdaenCore.AddCommands), help, off and unknown.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

local function client()
	local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
	wow:Login()
	return wow, wow.addons.OrdaenCore.ns
end

local function printed(wow)
	return table.concat(wow.printed, "\n")
end

describe("/ordaen", function()
	local wow, ns
	before_each(function()
		wow, ns = client()
	end)

	it("runs an addon's command with the rest of the line as its arguments", function()
		local got
		wow.env.OrdaenCore.AddCommands("debug", { test = { Run = function(arguments)
			got = arguments
		end, help = "runs a test" } })
		assert.is_true(wow:Slash("/ordaen debug test errors  now"))
		assert.are.equal("errors  now", got)
		wow:Slash("/ORDAEN Debug TEST")
		assert.are.equal("", got)
	end)

	it("runs a module's command with its game and root component", function()
		local module = { name = "OrdaenBags", game = {}, root = {} }
		local seen = {}
		ns.Commands.AddModule(module, { list = { Run = function(game, self, arguments)
			seen.game, seen.self, seen.arguments = game, self, arguments
		end } })
		wow:Slash("/ordaen bags list 3")
		assert.are.same({ game = module.game, self = module.root, arguments = "3" }, seen)
	end)

	it("lists the commands for help, a bare module word and a bare /ordaen", function()
		wow.env.OrdaenCore.AddCommands("debug", { test = { Run = function() end, help = "runs a test" } })
		wow:Slash("/ordaen help")
		assert.is_truthy(printed(wow):find("/ordaen debug test: runs a test", 1, true))
		wow.printed = {}
		wow:Slash("/ordaen debug")
		assert.is_truthy(printed(wow):find("/ordaen debug test", 1, true))
		wow.printed = {}
		wow:Slash("/ordaen")
		assert.is_truthy(printed(wow):find("/ordaen debug test", 1, true))
	end)

	it("says a module is off, a module is unknown, or a command is unknown", function()
		ns.Commands.Know("OrdaenMinimap")
		wow:Slash("/ordaen minimap")
		assert.is_truthy(printed(wow):find("Minimap is off.", 1, true))
		wow:Slash("/ordaen nothing")
		assert.is_truthy(printed(wow):find('No module "nothing"', 1, true))
		wow.env.OrdaenCore.AddCommands("debug", {})
		wow:Slash("/ordaen debug nope")
		assert.is_truthy(printed(wow):find('debug has no command "nope"', 1, true))
	end)

	it("refuses a command word that isn't lower case letters, digits and hyphens, or is the Core's", function()
		wow.env.OrdaenCore.AddCommands("debug", { ["Bad Word"] = { Run = function() end },
			help = { Run = function() end }, ok = { Run = function() end } })
		local said = table.concat(wow.errors, "\n")
		assert.is_truthy(said:find('"Bad Word"', 1, true), said)
		assert.is_truthy(said:find('"help"', 1, true), said)
		assert.has_error(function()
			wow.env.OrdaenCore.AddCommands("Debug", {})
		end)
	end)
end)
