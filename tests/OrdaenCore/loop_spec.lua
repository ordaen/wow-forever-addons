-- An effect that writes what it reads (addons/OrdaenCore/Signal.lua, the scheduler's cap) is stopped for the flush
-- and reported with what to fix: its kind, its module and component, and the values it reads.
local Fake = require("tests.fake.wow")

describe("a looping effect", function()
	it("is reported with its component and the values it reads", function()
		local wow = Fake.New({ dist = ".ordaen/check/dist", addons = { "OrdaenCore" } })
		wow:Login()
		local ns = wow.addons.OrdaenCore.ns
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		ns.App.currentModule, ns.App.currentFile = module, "components/counter"
		local Counter = ns.Define.Component({
			Setup = function(_, self)
				ns.Define.Ephemeral({ total = { type = "number", default = 0 } })
				self:Watch(function()
					local total = self.state.ephemeral.total
					total:Set(total:Get() + 1) -- writes what it reads
				end)
			end,
		})
		ns.App.currentModule, ns.App.currentFile = nil, nil
		ns.Engine:Mount(nil, Counter, 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
		local said = table.concat(wow.errors, "\n")
		assert.is_truthy(said:find("the watch of OrdaenSpec/counter, reading total", 1, true), said)
	end)
end)
