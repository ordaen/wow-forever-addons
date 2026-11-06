-- Channel test (dev mode): for DURATION seconds, send numbered messages through three candidate
-- real-time channels to the Ordaen Companion app, which measures them (`ordaen-companion probe`):
--   1. a pixel strip in the bottom-left corner of the screen (protocol below)
--   2. chat log lines "[OD] probe seq=N" (chat logging is switched on for the test, then restored)
--   3. two screenshots taken with Screenshot()
-- Nothing runs outside a test: the strip and its textures are created on first use, and the
-- OnUpdate script exists only while the test runs.
--
-- Pixel protocol v1, keep in sync with ordaen-companion src/pixel.rs:
-- * Cells of CELL_SIZE UI units in a row from the screen's bottom-left corner. Cell 0 magenta,
--   cell 1 cyan (markers), then DATA_CELLS cells of 12 bits each: one nibble per color channel
--   (R, G, B), drawn as nibble * 17.
-- * 12 bytes, sent as nibbles high-first: [1] = version << 4 | kind, [2..3] = sequence number
--   (big-endian), [4..11] = payload, [12] = checksum = (sum of bytes 1..11) % 256 xor 0xA5.
local _, ns = ...

local Channel = {}
ns.Channel = Channel

Channel.VERSION = 1
Channel.KIND_PROBE = 1
Channel.KIND_SCREENSHOT = 2
Channel.DATA_CELLS = 8
Channel.CELL_SIZE = 8 -- UI units; the companion measures the real pixel size from the markers
Channel.DURATION = 30
Channel.PIXEL_INTERVAL = 0.1
Channel.CHAT_INTERVAL = 1
Channel.SCREENSHOTS_AT = { 5, 20 } -- seconds into the test
Channel.SCREENSHOT_HOLD = 0.5 -- how long the screenshot frame stays on the strip

local floor = math.floor

-- 8-bit xor without the bit library (not confirmed on Forever).
local function xor8(a, b)
	local result, place = 0, 1
	for _ = 1, 8 do
		local x, y = a % 2, b % 2
		if x ~= y then
			result = result + place
		end
		a, b, place = (a - x) / 2, (b - y) / 2, place * 2
	end
	return result
end

--- The 12 bytes for a frame. payload: 8 bytes (missing ones are 0).
---@return table bytes 1-indexed
function Channel.Encode(kind, seq, payload)
	local bytes = { Channel.VERSION * 16 + kind, floor(seq / 256) % 256, seq % 256 }
	for i = 1, 8 do
		bytes[3 + i] = payload[i] or 0
	end
	local sum = 0
	for i = 1, 11 do
		sum = sum + bytes[i]
	end
	bytes[12] = xor8(sum % 256, 0xA5)
	return bytes
end

--- Colors (0..1) of the data cells for 12 bytes, as { r, g, b } per cell.
function Channel.CellColors(bytes)
	local nibbles = {}
	for i = 1, 12 do
		nibbles[#nibbles + 1] = floor(bytes[i] / 16)
		nibbles[#nibbles + 1] = bytes[i] % 16
	end
	local cells = {}
	for c = 1, Channel.DATA_CELLS do
		local base = (c - 1) * 3
		cells[c] = { nibbles[base + 1] * 17 / 255, nibbles[base + 2] * 17 / 255, nibbles[base + 3] * 17 / 255 }
	end
	return cells
end

--- Payload of probe frame `seq`, so the companion can check every frame it decodes.
function Channel.ProbePayload(seq)
	local payload = {}
	for i = 0, 7 do
		payload[i + 1] = (seq * 7 + i * 31) % 256
	end
	return payload
end

local strip -- created on first use

local function buildStrip()
	local size = Channel.CELL_SIZE
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(10000)
	f:SetSize((2 + Channel.DATA_CELLS) * size, size)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	f.cells = {}
	for i = 0, 1 + Channel.DATA_CELLS do
		local t = f:CreateTexture(nil, "OVERLAY")
		t:SetSize(size, size)
		t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", i * size, 0)
		f.cells[i] = t
	end
	f.cells[0]:SetColorTexture(1, 0, 1)
	f.cells[1]:SetColorTexture(0, 1, 1)
	f:Hide()
	return f
end

local function draw(kind, seq, payload)
	local cells = Channel.CellColors(Channel.Encode(kind, seq, payload))
	for i, color in ipairs(cells) do
		strip.cells[1 + i]:SetColorTexture(color[1], color[2], color[3])
	end
end

local function chat(text)
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

local state -- the running test, or nil

function Channel.IsRunning()
	return state ~= nil
end

function Channel.Stop()
	if not state then
		return
	end
	strip:SetScript("OnUpdate", nil)
	strip:Hide()
	if LoggingChat then
		LoggingChat(state.wasLogging and true or false)
	end
	chat(string.format("|cff33ff99Ordaen Dev:|r channel test done: %d pixel frames, %d chat lines, %d screenshots.",
		state.seq, state.chatLines, state.shots))
	state = nil
end

local function onUpdate(_, elapsed)
	local s = state
	s.total = s.total + elapsed
	s.sincePixel = s.sincePixel + elapsed
	if s.total >= Channel.DURATION then
		Channel.Stop()
		return
	end

	local shotAt = Channel.SCREENSHOTS_AT[s.shots + 1]
	if shotAt and s.total >= shotAt then
		s.shots = s.shots + 1
		draw(Channel.KIND_SCREENSHOT, s.seq, { s.shots })
		s.holdUntil = s.total + Channel.SCREENSHOT_HOLD
		if Screenshot then
			pcall(Screenshot)
		end
	elseif s.total >= s.holdUntil and s.sincePixel >= Channel.PIXEL_INTERVAL then
		s.sincePixel = 0
		s.seq = s.seq + 1
		draw(Channel.KIND_PROBE, s.seq, Channel.ProbePayload(s.seq))
	end

	if s.total >= s.nextChat then
		s.nextChat = s.nextChat + Channel.CHAT_INTERVAL
		s.chatLines = s.chatLines + 1
		chat("[OD] probe seq=" .. s.seq)
	end
end

--- Start the channel test (ignored while one is running).
function Channel.Start()
	if state then
		return
	end
	strip = strip or buildStrip()
	state = {
		total = 0,
		sincePixel = Channel.PIXEL_INTERVAL, -- draw the first frame at once
		seq = 0,
		nextChat = 0,
		chatLines = 0,
		shots = 0,
		holdUntil = 0,
		wasLogging = LoggingChat and LoggingChat() or false,
	}
	if LoggingChat then
		LoggingChat(true)
	end
	chat(string.format("|cff33ff99Ordaen Dev:|r channel test running for %d s.", Channel.DURATION))
	strip:Show()
	strip:SetScript("OnUpdate", onUpdate)
end
