-- The input group: the chat input and Blizzard's chat buttons drawn as one block. From the input leftwards: the chat
-- menu (the speech bubble: emotes, languages), the channels button (join, leave, voice), and the voice mute and
-- deafen buttons while Blizzard shows them. UI.Dress draws the input (style "panel", reaching left over the
-- buttons) and each button (style "iconButton", Blizzard's own icon); Blizzard's frames keep their clicks and menus.
-- We only place the buttons, and put them back when Blizzard's layout code moves them (hooks on SetPoint/SetParent,
-- no replaced methods: no taint). The social button isn't ours: Ordaen Panel takes it.
-- Cost: no events and nothing per frame; hooks on rarely called functions (an input or a voice button shown, a
-- window opened, Blizzard re-placing a button).
local _, ns = ...

local Input = {}
ns.Input = Input

local UI = OrdaenCore.UI

local GAP = 2
local ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" } -- <EditBox name> .. part, all dumped
-- Nearest the input first. All dumped globals.
local BUTTONS = {
	"ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceMuteButton",
	"ChatFrameToggleVoiceDeafenButton",
}

local on = false
local yielded = false -- another addon took the input: going off leaves the buttons where that addon put them
local current -- the input the group sits on (the last one shown)
local inputs = {} -- input -> its dress
local buttons = {} -- name -> { frame, dress, home = { parent, point... } }
local placing = false

-- Blizzard's icon of a button, for our look of it: its normal texture's atlas or file.
local function iconOf(frame)
	local texture = frame.GetNormalTexture and frame:GetNormalTexture()
	if not texture then
		return nil, nil
	end
	local atlas = texture:GetAtlas()
	if atlas then
		return nil, atlas
	end
	return texture:GetTexture(), nil
end

-- Width the group needs left of the input: every shown button and its gap.
local function leftWidth()
	local width = 0
	for _, name in ipairs(BUTTONS) do
		local b = buttons[name]
		if b and b.frame:IsShown() then
			width = width + b.frame:GetWidth() + GAP
		end
	end
	return width
end

-- Put the shown buttons in a row on the left of `current`, and the input's look over them.
local function place()
	if not (on and current) or placing then
		return
	end
	placing = true
	local anchor = current
	for _, name in ipairs(BUTTONS) do
		local b = buttons[name]
		-- Looked up by name from the literal list, so the build claims these calls (claims.rs).
		local frame = _G[name]
		if b and frame then
			frame:SetParent(current)
			frame:ClearAllPoints()
			frame:SetPoint("RIGHT", anchor, "LEFT", -GAP, 0)
			if b.dress then
				b.dress:Apply() -- our look follows the new parent (shown and hidden with the input)
			end
			if frame:IsShown() then
				anchor = frame
			end
		end
	end
	local dress = inputs[current]
	if dress then
		dress.opts.extend[1] = leftWidth()
		dress:Apply()
	end
	placing = false
end

local function onInputShown(input)
	current = input
	place()
end

local function dressInput(input)
	if not input or inputs[input] then
		return
	end
	local name = input:GetName()
	local art = {}
	for _, part in ipairs(ART) do
		local texture = name and _G[name .. part]
		if texture then
			art[#art + 1] = texture
		end
	end
	local dress = UI.Dress(input, { style = "panel", size = "frame", art = art, extend = { 0, 0, 0, 0 } })
	if not dress then
		return -- OrdaenCore_UI can't load (the player was told)
	end
	inputs[input] = dress
	UI.DressFont(input, "body")
	local header = name and _G[name .. "Header"]
	if header then
		UI.DressFont(header, "body")
	end
	input:HookScript("OnShow", onInputShown)
end

local function dressInputs()
	for i = 1, NUM_CHAT_WINDOWS + 40 do
		local frame = _G["ChatFrame" .. i]
		if not frame then
			if i > NUM_CHAT_WINDOWS then
				break
			end
		else
			dressInput(frame.editBox)
		end
	end
end

local function takeButtons()
	for _, name in ipairs(BUTTONS) do
		local frame = _G[name]
		if frame and not buttons[name] then
			local icon, atlas = iconOf(frame)
			local b = { frame = frame, home = { frame:GetParent() } }
			if frame:GetNumPoints() > 0 then
				local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
				b.home[2], b.home[3], b.home[4], b.home[5], b.home[6] = point, relativeTo, relativePoint, x, y
			end
			b.dress = UI.Dress(frame, { icon = icon, atlas = atlas })
			buttons[name] = b
			hooksecurefunc(frame, "SetPoint", place)
			hooksecurefunc(frame, "SetParent", place)
			-- The voice buttons come and go with voice chat: the row closes up.
			frame:HookScript("OnShow", place)
			frame:HookScript("OnHide", place)
		elseif buttons[name] and buttons[name].dress then
			buttons[name].dress:Apply()
		end
	end
end

local hooked = false

--- Start the input group: the "inputGroup" feature's OnEnable.
function Input.Enable()
	on = true
	for _, dress in pairs(inputs) do
		dress:Apply()
	end
	takeButtons()
	if not hooked then
		hooked = true
		dressInputs()
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			if on then
				dressInputs()
			end
		end)
	end
	current = current or ChatFrame1.editBox
	place()
end

--- Stop: Blizzard's input art and the buttons' places and looks come back.
function Input.Disable()
	on = false
	for _, dress in pairs(inputs) do
		dress:Undress()
	end
	for _, b in pairs(buttons) do
		if b.dress then
			b.dress:Undress()
		end
		if not yielded then
			local home = b.home
			placing = true
			b.frame:SetParent(home[1])
			b.frame:ClearAllPoints()
			if home[2] then
				b.frame:SetPoint(home[2], home[3], home[4], home[5], home[6])
			end
			placing = false
		end
	end
end

--- Another addon took the input or a chat button (a conflict): when the feature goes off, put Blizzard's look
--- back but leave the buttons where that addon put them.
function Input.StepAside()
	yielded = true
end

--- What the dev-mode dump records.
function Input.Describe()
	local placed = {}
	for name, b in pairs(buttons) do
		local parent = b.frame:GetParent()
		placed[name] = { parent = parent and parent:GetName() or false, shown = b.frame:IsShown() }
	end
	local dressed = {}
	for input in pairs(inputs) do
		dressed[#dressed + 1] = input:GetName() or "?"
	end
	return { on = on, yielded = yielded, current = current and current:GetName() or false, buttons = placed,
		dressed = dressed }
end
