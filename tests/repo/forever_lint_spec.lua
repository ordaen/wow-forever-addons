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
end)
