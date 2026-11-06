-- The input group: the chat input and Blizzard's chat menu button (the speech bubble: emotes, languages) drawn as
-- one block, the button on the input's left. The input's own art goes (alpha 0); OrdaenCore.UI draws the group's
-- surface in the theme's "panel" role. The button stays Blizzard's (its menu works unchanged); we only place it, and
-- put it back when Blizzard's layout code moves it (hooks on SetPoint/SetParent, no replaced methods: no taint).
-- Cost: no events and nothing per frame; hooks on rarely called functions (an input shown, a window opened).
local _, ns = ...

local Input = {}
ns.Input = Input

local UI = OrdaenCore.UI

local GAP = 2
local ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" } -- <EditBox name> .. part, all dumped

local on = false
local yielded = false -- another addon took the input: going off leaves the button where that addon put it
local current -- the input the group sits on (the last one shown)
local surfaces = {} -- input -> its UI block (the group's surface)
local hiddenArt = {} -- texture -> true: input art we set to alpha 0
local placing = false
local home -- where the menu button was: { parent, point... } to give it back when the feature goes off
local neighbors = {} -- Blizzard buttons anchored to the menu button, re-anchored where it was

local function button()
	return _G.ChatFrameMenuButton
end

local function size(input)
	local b = button()
	local surface = surfaces[input]
	if not (surface and b) then
		return
	end
	surface.block.width = input:GetWidth() + b:GetWidth() + GAP
	surface.block.height = math.max(input:GetHeight(), b:GetHeight())
	surface:Refresh()
end

-- Put the menu button on the left of `current`, inside the group.
local function place()
	local b = button()
	if not (on and current and b) or placing then
		return
	end
	placing = true
	b:SetParent(current)
	b:ClearAllPoints()
	b:SetPoint("RIGHT", current, "LEFT", -GAP, 0)
	placing = false
end

local function onInputShown(input)
	current = input
	place()
	size(input)
end

local function dress(input)
	if surfaces[input] or not input then
		return
	end
	local name = input:GetName()
	for _, part in ipairs(ART) do
		local texture = name and _G[name .. part]
		if texture then
			hiddenArt[texture] = true
			if on then
				texture:SetAlpha(0)
			end
		end
	end
	local surface = UI.Block({ parent = input, style = "panel", width = 1, height = 1 })
	if not surface then
		return -- OrdaenCore_UI can't load (the player was told)
	end
	surface:SetPoint("RIGHT", input, "RIGHT", 0, 0)
	surface:SetFrameLevel(math.max(0, input:GetFrameLevel() - 1))
	surfaces[input] = surface
	input:HookScript("OnShow", onInputShown)
	input:HookScript("OnSizeChanged", size)
	if on and input:IsShown() then
		onInputShown(input)
	end
end

local function dressWindow(frame)
	if frame then
		dress(frame.editBox)
	end
end

-- Buttons Blizzard anchored to the menu button (they'd follow it to the input): anchor them where it was.
local function freeNeighbors(b)
	local point, relativeTo, relativePoint, x, y = b:GetPoint(1)
	for _, name in ipairs({ "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
		"ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton", "TextToSpeechButtonFrame" }) do
		local other = _G[name]
		if other and other:GetNumPoints() > 0 then
			local p, rel, rp, ox, oy = other:GetPoint(1)
			if rel == b then
				neighbors[other] = { p, rel, rp, ox, oy }
				other:ClearAllPoints()
				other:SetPoint(p, relativeTo, rp, ox, oy)
				ns.Debug:Logf("input: %s was anchored to the chat menu button, now to %s", name,
					relativeTo and relativeTo.GetName and relativeTo:GetName() or "?")
			end
		end
	end
	return { b:GetParent(), point, relativeTo, relativePoint, x, y }
end

local hooked = false

--- Start the input group: the "inputGroup" feature's OnEnable.
function Input.Enable()
	local b = button()
	on = true
	for texture in pairs(hiddenArt) do
		texture:SetAlpha(0)
	end
	for _, surface in pairs(surfaces) do
		surface:Show()
	end
	if b and not home then
		home = freeNeighbors(b)
	end
	if not hooked then
		hooked = true
		for i = 1, NUM_CHAT_WINDOWS do
			dressWindow(_G["ChatFrame" .. i])
		end
		-- Whisper tabs are windows opened later.
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			for i = NUM_CHAT_WINDOWS + 1, NUM_CHAT_WINDOWS + 40 do
				local frame = _G["ChatFrame" .. i]
				if not frame then
					break
				end
				dressWindow(frame)
			end
		end)
		if b then
			hooksecurefunc(b, "SetPoint", place)
			hooksecurefunc(b, "SetParent", place)
		end
	end
	current = current or ChatFrame1.editBox
	place()
	size(current)
end

--- Stop: Blizzard's input art and the button's place come back.
function Input.Disable()
	on = false
	for texture in pairs(hiddenArt) do
		texture:SetAlpha(1)
	end
	for _, surface in pairs(surfaces) do
		surface:Hide()
	end
	local b = button()
	if b and home and not yielded then
		placing = true
		b:SetParent(home[1])
		b:ClearAllPoints()
		if home[2] then
			b:SetPoint(home[2], home[3], home[4], home[5], home[6])
		end
		placing = false
		for other, p in pairs(neighbors) do
			other:ClearAllPoints()
			other:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
		neighbors, home = {}, nil
	end
end

--- Another addon took the input or the chat menu button (a conflict): when the feature goes off, put the input's
--- art back but leave the button to that addon.
function Input.StepAside()
	yielded = true
end

--- What the dev-mode dump records.
function Input.Describe()
	local b = button()
	local dressed = {}
	for input in pairs(surfaces) do
		dressed[#dressed + 1] = input:GetName() or "?"
	end
	return {
		on = on,
		yielded = yielded,
		current = current and current:GetName() or false,
		button = b and { parent = b:GetParent() and b:GetParent():GetName() or false, shown = b:IsShown() } or false,
		dressed = dressed,
	}
end
