-- Ordaen Core's theme assets (themes.jsonc, built into dist/OrdaenCore/themes.json) against the real Forever API:
-- a frame's `layout` must be one of Blizzard's NineSliceLayouts, or the border just doesn't draw in game.
local json = dofile("scripts/json.lua")

local function read(path)
	local f = assert(io.open(path, "rb"), path .. " (run ordaen build)")
	local text = f:read("*a")
	f:close()
	return text
end

describe("theme assets", function()
	local themes, namespaces

	setup(function()
		themes = json.decode(read("dist/OrdaenCore/themes.json"))
		local current = read("api/forever/CURRENT"):match("[^\r\n]+")
		namespaces = json.decode(read("api/forever/" .. current .. "/api.json")).namespaces
	end)

	it("names only nine-slice layouts the game has", function()
		local layouts = namespaces.NineSliceLayouts
		assert.is_table(layouts, "NineSliceLayouts missing from the API dump")
		local count = 0
		for id, frame in pairs(themes.assets.frame) do
			if frame.layout then
				count = count + 1
				assert.equals("table", layouts[frame.layout], ("frame %q: no NineSliceLayouts.%s on Forever"):format(id,
					frame.layout))
			end
		end
		assert.is_true(count > 0)
	end)

	it("gives every background an atlas or a file, or nothing (none)", function()
		for id, bg in pairs(themes.assets.background) do
			local n = (bg.atlas and 1 or 0) + (bg.file and 1 or 0)
			assert.is_true(n <= 1, ("background %q: an atlas or a file, not both"):format(id))
			assert.is_true(n == 1 or id == "none", ("background %q: no atlas or file"):format(id))
		end
	end)
end)
