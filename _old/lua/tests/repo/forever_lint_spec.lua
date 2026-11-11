-- scripts/forever_lint.lua against deliberately wrong code, with the real current Forever API (api/forever/CURRENT).
local Lint = dofile("scripts/forever_lint.lua")

describe("forever-lint", function()
	local api = Lint.LoadApi(".")

	local function codes(source)
		local out = {}
		for _, f in ipairs(Lint.LintSource(api, source)) do
			out[#out + 1] = f.code .. "@" .. f.line
		end
		return out
	end

	it("FL10: flags a slash command of an addon's own (Ordaen has one, /ordaen)", function()
		assert.same({ "FL10@1", "FL10@2", "FL10@3" }, codes([[
SLASH_ODEV1 = "/odev"
SlashCmdList.ODEV = function() end
SlashCmdList["ODEV2"] = function() end
local commands = { toggle = {} }
]]))
	end)

	it("FL11: flags a wait inside a function passed to pcall, xpcall or table.sort", function()
		assert.same({ "FL11@1", "FL11@2", "FL11@3" }, codes([[
pcall(function() await.frame() end)
xpcall(function() checkpoint() end, print)
table.sort(list, function(a, b) await.delay(1) return a < b end)
self:Spawn(function() await.frame() checkpoint() end)
]]))
	end)

	it("FL12: flags a restricted function called in a task after a wait, not before", function()
		api.functions.ProtectedThing = { args = {}, returns = {}, restricted = true }
		assert.same({ "FL12@4" }, codes([[
self:Spawn(function(game, self)
	ProtectedThing()
	await.frame()
	ProtectedThing()
end)
]]))
		api.functions.ProtectedThing = nil
	end)
end)
