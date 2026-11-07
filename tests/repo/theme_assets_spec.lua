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

	-- A control's art (themes.jsonc, "Controls"): the states each role draws, and the shape of a piece.
	local CONTROL_STATES = {
		tab = { "normal", "selected" },
		sideTab = { "normal", "selected" },
		pushButton = { "normal" },
		closeButton = { "normal" },
		checkbox = { "normal", "checked" },
		dropdown = { "normal", "arrow" },
		input = { "normal" },
		scrollTrack = { "normal" },
		scrollThumb = { "normal" },
		scrollStepper = { "back", "forward" },
		slot = { "background" },
	}
	local NOT_STATES = { label = true, size = true }
	local SLICES = { { "left", "center", "right" }, { "top", "middle", "bottom" } }

	-- nil when `piece` is an atlas name, { atlas | file, ... } or slices of those; else what's wrong
	local function badPiece(piece, sliced)
		if type(piece) == "string" then
			if piece == "" then
				return "an empty atlas name"
			end
			return nil
		end
		if type(piece) ~= "table" then
			return "not an atlas name or a table"
		end
		if piece.atlas or piece.file then
			if piece.atlas and piece.file then
				return "an atlas or a file, not both"
			end
			return nil
		end
		if sliced then
			return "a slice must be an atlas or a file"
		end
		for _, names in ipairs(SLICES) do
			if piece[names[1]] then
				for _, name in ipairs(names) do
					local bad = piece[name] == nil and "slice " .. name .. " missing" or badPiece(piece[name], true)
					if bad then
						return bad
					end
				end
				return nil
			end
		end
		return "no atlas, file or slices"
	end

	it("gives every control the states its role draws, each a piece of art", function()
		for kind, states in pairs(CONTROL_STATES) do
			local assets = themes.assets[kind]
			assert.is_table(assets, ("no %s assets"):format(kind))
			for id, asset in pairs(assets) do
				for _, state in ipairs(states) do
					assert.is_not_nil(asset[state], ("%s %q: no %s"):format(kind, id, state))
				end
				for key, piece in pairs(asset) do
					if not NOT_STATES[key] then
						local bad = badPiece(piece)
						assert.is_nil(bad, ("%s %q.%s: %s"):format(kind, id, key, tostring(bad)))
					end
				end
			end
		end
	end)

	it("gives every background an atlas or a file, or nothing (none)", function()
		for id, bg in pairs(themes.assets.background) do
			local n = (bg.atlas and 1 or 0) + (bg.file and 1 or 0)
			assert.is_true(n <= 1, ("background %q: an atlas or a file, not both"):format(id))
			assert.is_true(n == 1 or id == "none", ("background %q: no atlas or file"):format(id))
		end
	end)
end)
