local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore_Debug channel test", function()
	local Channel, chat, shots, logging

	before_each(function()
		chat, shots, logging = {}, 0, false
		helpers.stubGlobals({
			DEFAULT_CHAT_FRAME = {
				AddMessage = function(_, msg)
					chat[#chat + 1] = msg
				end,
			},
			Screenshot = function()
				shots = shots + 1
			end,
			LoggingChat = function(on)
				if on ~= nil then
					logging = on
				end
				return logging
			end,
		})
		helpers.loadCore(true)
		Channel = helpers.debugNs.Channel
	end)

	it("matches the companion's shared test vector", function()
		-- Same vector as ordaen-companion src/pixel.rs, test shared_test_vector.
		local bytes = Channel.Encode(Channel.KIND_PROBE, 258, Channel.ProbePayload(258))
		assert.are.same({ 0x11, 0x01, 0x02, 0x0E, 0x2D, 0x4C, 0x6B, 0x8A, 0xA9, 0xC8, 0xE7, 0x4D }, bytes)
		local first = Channel.CellColors(bytes)[1]
		assert.are.same({ 17 / 255, 17 / 255, 0 }, first)
	end)

	it("encodes every nibble level within 0..1", function()
		local cells = Channel.CellColors(Channel.Encode(15, 65535, { 255, 255, 255, 255, 255, 255, 255, 255 }))
		assert.are.equal(Channel.DATA_CELLS, #cells)
		for _, cell in ipairs(cells) do
			for _, v in ipairs(cell) do
				assert.is_true(v >= 0 and v <= 1)
			end
		end
	end)

	it("runs for its duration: pixel frames, chat lines, two screenshots, then cleans up", function()
		Channel.Start()
		assert.is_true(Channel.IsRunning())
		assert.is_true(logging)
		-- Drive the strip's OnUpdate at 60 fps until the test stops itself.
		local strip
		for _, frame in pairs(helpers.created or {}) do
			if frame.scripts.OnUpdate then
				strip = frame
			end
		end
		assert.is_not_nil(strip, "no OnUpdate script")
		local steps = 0
		while Channel.IsRunning() and steps < 60 * 40 do
			strip.scripts.OnUpdate(strip, 1 / 60)
			steps = steps + 1
		end
		assert.is_false(Channel.IsRunning())
		assert.is_nil(strip.scripts.OnUpdate)
		assert.is_false(logging) -- restored
		assert.are.equal(2, shots)
		local lines = 0
		for _, msg in ipairs(chat) do
			if msg:find("^%[OD%] probe seq=%d+$") then
				lines = lines + 1
			end
		end
		assert.is_true(lines >= 29 and lines <= 31, "chat lines: " .. lines)
		assert.truthy(chat[#chat]:find("channel test done", 1, true))
	end)
end)
