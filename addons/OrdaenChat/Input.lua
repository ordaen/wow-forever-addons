-- The input group: the chat input and Blizzard's chat buttons as one block, the width of the chat window. The
-- input keeps Blizzard's place and size; the buttons sit inside its left end, squares as tall as the input, and its
-- text (with the "Say:" header) starts after them. From the text leftwards: the chat menu (our speech bubble icon),
-- the channels list (our hash icon), and the voice mute and deafen buttons while Blizzard shows them (their own
-- icons). UI.Dress draws the input (style "panel") and each button (style "iconButton"); Blizzard's frames keep
-- their clicks and menus. We place the buttons and put them back when Blizzard's layout moves them (hooks on
-- SetPoint/SetParent, no replaced methods: no taint). We never call Blizzard's chat input code (ChatEdit_*): the
-- input runs secure slash commands, and our calls would taint it. Blizzard's social button is hidden until Ordaen
-- Panel, which takes it, is installed; the column left of the chat where the buttons were is left empty.
-- Cost: no events and nothing per frame; hooks on rarely called functions (an input or a voice button shown, the
-- input's header updated, a window opened, Blizzard re-placing a button).
local _, ns = ...

local Input = {}
ns.Input = Input

local UI = OrdaenCore.UI

local GAP = 2
local PADDING = 4 -- the "iconButton" style's padding around the icon (Theme.lua)
local MEDIA = "Interface\\AddOns\\OrdaenCore\\media\\"
local ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" } -- <EditBox name> .. part, all dumped
-- Nearest the text first. All dumped globals.
local BUTTONS = {
	"ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceMuteButton",
	"ChatFrameToggleVoiceDeafenButton",
}
-- The same buttons from the input's left end to its text: the order they're placed in.
local ROW = {
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "ChatFrameChannelButton",
	"ChatFrameMenuButton",
}
-- Our glyphs (art/icons.py, tinted by the theme's color.icon); the others keep Blizzard's own icon.
local OUR_ICONS = { ChatFrameMenuButton = MEDIA .. "icon-chat", ChatFrameChannelButton = MEDIA .. "icon-channels" }

local on = false
local yielded = false -- another addon took the input: going off leaves the buttons where that addon put them
local current ---@type EditBox|nil the input the group sits on (the last one shown)
local inputs = {} -- input -> its dress
local headers = {} -- input -> { header = FontString, point = Blizzard's point }
local added = {} -- input -> the left text inset we added on top of Blizzard's
local buttons = {} -- name -> { frame, dress, home = { parent, point... } }
local placing = false
local hiddenParent -- holds Blizzard's social button while Ordaen Panel isn't there to take it
local socialHome

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

-- Width of the button row inside the input: every shown button and its gap.
local function rowWidth()
	local width = 0
	for _, name in ipairs(BUTTONS) do
		local b = buttons[name]
		if b and b.frame:IsShown() then
			width = width + b.frame:GetWidth() + GAP
		end
	end
	return width
end

-- The input's text and header start after the button row (or where Blizzard put them, when off).
local function shiftText(input)
	if not input then
		return
	end
	local width = on and rowWidth() or 0
	local h = headers[input]
	if h and h.point then
		local p = h.point
		h.header:ClearAllPoints()
		h.header:SetPoint(p[1], p[2], p[3], p[4] + width, p[5])
	end
	local left, right, top, bottom = input:GetTextInsets()
	local blizzards = (left or 0) - (added[input] or 0)
	input:SetTextInsets(blizzards + width, right or 0, top or 0, bottom or 0)
	added[input] = width
end

-- Blizzard set the input's insets for its header ("Say:", "To Name:"), from scratch: add ours again on top.
local function onHeaderUpdated(input)
	if inputs[input] then
		added[input] = 0
		if on then
			shiftText(input)
		end
	end
end

-- Put the shown buttons in a row inside the left end of `current`, the text after them.
local function place()
	if not (on and current) or placing then
		return
	end
	placing = true
	local anchor, point = current, "LEFT"
	for _, name in ipairs(ROW) do
		local b = buttons[name]
		-- Looked up by name from the literal list, so the build claims these calls (claims.rs).
		local frame = _G[name]
		if b and frame then
			frame:SetParent(current)
			frame:ClearAllPoints()
			frame:SetPoint("LEFT", anchor, point, GAP, 0)
			if b.dress then
				b.dress:Apply() -- our look follows the new parent (shown and hidden with the input)
			end
			if frame:IsShown() then
				anchor, point = frame, "RIGHT"
			end
		end
	end
	shiftText(current)
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
	local dress = UI.Dress(input, { style = "panel", size = "frame", art = art })
	if not dress then
		return -- OrdaenCore_UI can't load (the player was told)
	end
	inputs[input] = dress
	UI.DressFont(input, "body")
	local header = name and _G[name .. "Header"]
	if header then
		UI.DressFont(header, "body")
		local entry = { header = header }
		if header:GetNumPoints() > 0 then
			entry.point = { header:GetPoint(1) }
		end
		headers[input] = entry
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

local function takeButtons(height)
	local iconSize = math.max(12, height - 2 * PADDING)
	for _, name in ipairs(BUTTONS) do
		local frame = _G[name]
		if frame and not buttons[name] then
			---@type string|number|nil, string|nil
			local icon, atlas = OUR_ICONS[name], nil
			if not icon then
				icon, atlas = iconOf(frame)
			end
			local b = { frame = frame, home = { frame:GetParent() } }
			if frame:GetNumPoints() > 0 then
				local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
				b.home[2], b.home[3], b.home[4], b.home[5], b.home[6] = point, relativeTo, relativePoint, x, y
			end
			b.dress = UI.Dress(frame, { icon = icon, atlas = atlas, iconSize = iconSize,
				iconColor = OUR_ICONS[name] and "color.icon" or nil })
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

-- Blizzard's social button: Ordaen Panel takes it. Until that addon is installed it's hidden, not left alone in
-- the empty column beside the chat.
local function hideSocial()
	local social = _G.QuickJoinToastButton
	if not social or C_AddOns.IsAddOnLoaded("OrdaenPanel") then
		return
	end
	if not hiddenParent then
		hiddenParent = CreateFrame("Frame")
		hiddenParent:Hide()
	end
	socialHome = socialHome or social:GetParent()
	social:SetParent(hiddenParent)
end

local function showSocial()
	local social = _G.QuickJoinToastButton
	if social and socialHome and social:GetParent() == hiddenParent then
		social:SetParent(socialHome)
	end
end

local hooked = false

--- Start the input group: the "inputGroup" feature's OnEnable.
function Input.Enable()
	on = true
	for _, dress in pairs(inputs) do
		dress:Apply()
	end
	if not hooked then
		hooked = true
		dressInputs()
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			if on then
				dressInputs()
			end
		end)
		hooksecurefunc("ChatEdit_UpdateHeader", onHeaderUpdated)
	end
	current = current or ChatFrame1.editBox --[[@as EditBox]]
	takeButtons(current:GetHeight())
	hideSocial()
	place()
end

--- Stop: Blizzard's input art, text insets and the buttons' places and looks come back.
function Input.Disable()
	on = false
	for input, dress in pairs(inputs) do
		dress:Undress()
		shiftText(input)
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
	showSocial()
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
		dressed = dressed, row = rowWidth(), socialHidden = hiddenParent ~= nil and socialHome ~= nil }
end
