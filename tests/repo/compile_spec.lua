-- Every addon file compiles under Lua 5.1, as the game compiles it. Lua 5.1 refuses what later versions take: a
-- function with more than 60 upvalues (Ordaen Panel's build() broke at 61 and the whole panel didn't load,
-- 2026-11-07), more than 200 locals, a `goto`. luacheck parses with its own parser and doesn't enforce those limits.
describe("addon files", function()
	it("all compile under Lua 5.1", function()
		local failed = {}
		for _, path in ipairs(require("scripts.fs").Files("addons", "%.lua$")) do
			local ok, err = loadfile(path)
			if not ok then
				failed[#failed + 1] = err
			end
		end
		assert.same({}, failed)
	end)
end)
