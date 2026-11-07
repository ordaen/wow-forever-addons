-- The input group: the chat input and Blizzard's chat buttons as one block, the width of the chat window. The input
-- keeps Blizzard's size; its look (UI.Dress, style "panel") is one row we draw: a cell per button, squares as tall as
-- the input, then the text area. The engine collapses the borders where cells touch each other and the row's edge,
-- so neighbours share one line (no double borders, no gaps). From the text leftwards: the chat menu (our speech
-- bubble icon), the channels list (our hash icon), and the voice mute and deafen buttons while Blizzard shows them
-- (their own icons). Each Blizzard button keeps its clicks and menus: its art is hidden (UI.Dress, style "none") and
-- it sits invisibly over its cell (placed from the row's "render" event), and while it's hovered its cell lights.
-- We place the buttons and put them back when Blizzard's layout moves them (hooks on SetPoint/SetParent, no replaced
-- methods: no taint). We never call Blizzard's chat input code (ChatEdit_*): the input runs secure slash commands,
-- and our calls would taint it. Blizzard's social button is hidden until Ordaen Panel, which takes it, is
-- installed; the column left of the chat where the buttons were is left empty.
-- Cost: no events and nothing per frame; hooks on rarely called functions (an input or a voice button shown, its
-- insets set, a window opened, Blizzard re-placing a button, a button hovered).
local _, ns = ...

local Input = {}
ns.Input = Input

local UI = OrdaenCore.UI

local PADDING = 4 -- the "iconButton" style's padding around the icon (Theme.lua)
local MEDIA = "Interface\\AddOns\\OrdaenCore\\media\\"
local ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" } -- <EditBox name> .. part, all dumped
-- Nearest the text first. All dumped globals.
local BUTTONS = {
	"ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceMuteButton",
	"ChatFrameToggleVoiceDeafenButton",
}
-- The same buttons from the input's left end to its text: the order of the row's cells.
local ROW = {
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "ChatFrameChannelButton",
	"ChatFrameMenuButton",
}
-- Our glyphs (art/icons.py, tinted by the theme's color.icon); the others keep Blizzard's own icon.
local OUR_ICONS = { ChatFrameMenuButton = MEDIA .. "icon-chat", ChatFrameChannelButton = MEDIA .. "icon-channels" }

local on = false
local yielded = false -- another addon took the input: going off leaves the buttons where that addon put them
local current ---@type EditBox|nil the input the group sits on (the last one shown)
local inputs = {} -- input -> its dress (its look is the row)
local cells = {} -- input -> name -> the cell block for that button
local headers = {} -- input -> { header = FontString, point = Blizzard's point }
local added = {} -- input -> the left text inset we added on top of Blizzard's
local buttons = {} -- name -> { frame, dress, home = { parent, point... }, icon, atlas }
local placing = false
local insetting = false -- our own SetTextInsets call (the hook leaves it alone)
local anchoring = false -- our own SetPoint calls on an input
local overlaid = false -- the input sits over the chat (setting inputOverlay)
local blizzardPoints = {} -- input -> its points under the chat window, given back when the overlay goes off
local size = 32 -- the input's height when the buttons were taken: the cells' size
local hiddenParent -- holds Blizzard's social button while Ordaen Panel isn't there to take it
local socialHome
local buttonsSeen = true -- the row's Blizzard buttons are seen and take the mouse (false: over the chat, not typing)
local settingAlpha = false -- our own SetAlpha calls on those buttons (the hook leaves them alone)

-- Over the chat the input only shows while typing, but Blizzard's IM style just fades it: its buttons stayed under
-- the mouse while invisible, and Blizzard's chat fade (mouse over the chat) blinked them (2026-11-07). They follow
-- the typing instead: seen and clickable while the input has the keyboard focus, else alpha 0 and no mouse. The
-- faded input itself took clicks meant for the chat under it (the scroll-to-bottom button opened it): it gets the
-- mouse only while typing too.
local function showButtons()
	local seen = not overlaid or (current ~= nil and current:HasFocus()) or false
	buttonsSeen = seen
	settingAlpha = true
	for _, b in pairs(buttons) do
		b.frame:SetAlpha(seen and 1 or 0)
		b.frame:EnableMouse(seen)
	end
	settingAlpha = false
	for input in pairs(inputs) do
		input:EnableMouse(not overlaid or input:HasFocus())
	end
end

-- Blizzard fading a button (its chat fade): our alpha again.
local function onButtonAlpha(frame)
	if on and not settingAlpha then
		settingAlpha = true
		frame:SetAlpha(buttonsSeen and 1 or 0)
		settingAlpha = false
	end
end

-- Dev mode: what draws over what while typing (the chat's text showed over the input's background, 2026-11-07).
local function logLayers(input)
	if ns.Debug:IsEnabled() then
		local window = input.chatFrame or input:GetParent()
		local lines = window and window.FontStringContainer
		local dress = inputs[input]
		local look = dress and dress.look.frame
		ns.Debug:Logf("input: layers input %s/%d a%.2f (parent %s), row %s/%d a%.2f shown %s (parent %s), "
			.. "lines %s/%d, window %s/%d",
			input:GetFrameStrata(), input:GetFrameLevel(), input:GetEffectiveAlpha(),
			tostring(input:GetParent() and input:GetParent():GetName()),
			look and look:GetFrameStrata() or "-", look and look:GetFrameLevel() or -1,
			look and look:GetEffectiveAlpha() or -1, tostring(look and look:IsShown()),
			tostring(look and look:GetParent() and look:GetParent():GetName()),
			lines and lines:GetFrameStrata() or "-", lines and lines:GetFrameLevel() or -1,
			window and window:GetFrameStrata() or "-", window and window:GetFrameLevel() or -1)
	end
end

local function onFocusGained(input)
	current = input
	showButtons()
	logLayers(input)
end

local function onFocusLost()
	showButtons()
end

-- Blizzard's icon of a button, for its cell: its normal texture's atlas or file.
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

-- Width of the button cells shown in the row.
local function rowWidth()
	local width = 0
	for _, name in ipairs(ROW) do
		local b = buttons[name]
		if b and b.frame:IsShown() then
			width = width + size
		end
	end
	return width
end

-- The input's text and header start after the button cells (or where Blizzard put them, when off).
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
	insetting = true
	input:SetTextInsets(blizzards + width, right or 0, top or 0, bottom or 0)
	insetting = false
	added[input] = width
end

-- Blizzard set the input's insets for its header ("Say:", "To Name:"), from scratch: add ours again on top. A hook on
-- the input's own SetTextInsets, so every path counts (Forever updates the header in the input's UpdateHeader
-- method, not the old global ChatEdit_UpdateHeader: the caret sat under "Say:", 2026-11-06).
local function onInsetsSet(input)
	if insetting or not inputs[input] then
		return
	end
	added[input] = 0
	if on then
		shiftText(input)
	end
end

-- Over the chat: the input on the bottom of its window's background, over the last lines, instead of below the
-- window. Blizzard's own "IM" chat style shows it only while typing (Enter) and hides it after.
local function overlay(input)
	local h = blizzardPoints[input]
	if not h then
		h = {}
		for i = 1, input:GetNumPoints() do
			h[i] = { input:GetPoint(i) }
		end
		blizzardPoints[input] = h
	end
	local window = input.chatFrame or input:GetParent()
	local background = window and _G[(window:GetName() or "") .. "Background"]
	if not background then
		return
	end
	anchoring = true
	input:ClearAllPoints()
	input:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", 0, 0)
	input:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 0, 0)
	anchoring = false
	-- Above the chat's lines, with our look between them and the input (the text showed through the input's
	-- background, 2026-11-06).
	local lines = window.FontStringContainer
	if lines and input:GetFrameLevel() <= lines:GetFrameLevel() + 1 then
		input:SetFrameLevel(lines:GetFrameLevel() + 3)
		local dress = inputs[input]
		if dress and dress.dressed then
			dress:Apply()
		end
	end
end

local function underChat(input)
	local h = blizzardPoints[input]
	if not h then
		return
	end
	anchoring = true
	input:ClearAllPoints()
	for _, p in ipairs(h) do
		input:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
	anchoring = false
end

-- Blizzard placing an input again: note its place, then over the chat again.
local function onInputPlaced(input)
	if anchoring or not (on and overlaid and inputs[input]) then
		return
	end
	blizzardPoints[input] = nil
	overlay(input)
end

-- The row of `input` drawn: each Blizzard button exactly over its cell, invisible, getting the clicks.
local function onRowDrawn(input)
	if input ~= current or not on then
		return
	end
	local look = inputs[input].look
	placing = true
	for _, name in ipairs(ROW) do
		local cell = cells[input][name]
		-- Looked up by name from the literal list, so the build claims these calls (claims.rs).
		local frame = _G[name]
		local x, y, w, h = look:RectOf(cell)
		if frame and buttons[name] and x then
			frame:SetParent(input)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", look.frame, "TOPLEFT", x, -y)
			frame:SetSize(w, h)
		end
	end
	placing = false
end

-- Show the cells of the buttons Blizzard shows on `current`'s row, draw it (the buttons follow), shift the text.
local function place()
	if not (on and current) or placing then
		return
	end
	local row = cells[current]
	if not row then
		return
	end
	for _, name in ipairs(ROW) do
		local b = buttons[name]
		row[name].hidden = not (b and b.frame:IsShown())
	end
	inputs[current].look:Refresh()
	shiftText(current)
end

local function onInputShown(input)
	current = input
	place()
end

-- The row: a cell per button (hidden until its button is there), then the text area taking the rest.
local function rowFor(input)
	local row = { columns = {}, gap = 0, padding = 0 }
	local mine = {}
	for i, name in ipairs(ROW) do
		local b = buttons[name]
		---@type OrdaenUIImage
		local icon = { image = b and b.icon, atlas = b and b.atlas, size = math.max(12, size - 2 * PADDING),
			color = OUR_ICONS[name] and "color.icon" or nil, align = "center", valign = "center" }
		local cell = { style = "iconButton", width = size, height = size, hidden = true, icon }
		mine[name] = cell
		row.columns[i] = "auto"
		row[i] = cell
	end
	row.columns[#ROW + 1] = "1fr"
	row[#ROW + 1] = {} -- the text area (the input's own text, drawn by Blizzard)
	cells[input] = mine
	return row
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
	local dress = UI.Dress(input, { style = "chatInput", size = "frame", art = art, block = rowFor(input),
		focus = overlaid })
	if not dress then
		return -- OrdaenCore_UI can't load (the player was told)
	end
	inputs[input] = dress
	dress.look:On("render", function()
		onRowDrawn(input)
	end) -- once per input
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
	input:HookScript("OnEditFocusGained", onFocusGained)
	input:HookScript("OnEditFocusLost", onFocusLost)
	hooksecurefunc(input, "SetTextInsets", onInsetsSet)
	hooksecurefunc(input, "SetPoint", onInputPlaced)
	if on and overlaid then
		overlay(input)
	end
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

-- Its cell lights while Blizzard's button is hovered (the button is invisible over it).
local function lightCell(frame, lit)
	local row = current and cells[current]
	if not (on and row) then
		return
	end
	for name, b in pairs(buttons) do
		if b.frame == frame then
			row[name].highlight = lit
			inputs[current].look:Refresh()
			return
		end
	end
end

local function onButtonEnter(frame)
	lightCell(frame, true)
end

local function onButtonLeave(frame)
	lightCell(frame, false)
end

local function takeButtons()
	for _, name in ipairs(BUTTONS) do
		local frame = _G[name]
		if frame and not buttons[name] then
			local b = { frame = frame, home = { frame:GetParent() } }
			if frame:GetNumPoints() > 0 then
				local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
				b.home[2], b.home[3], b.home[4], b.home[5], b.home[6] = point, relativeTo, relativePoint, x, y
			end
			b.size = { frame:GetWidth(), frame:GetHeight() }
			b.icon = OUR_ICONS[name]
			if not b.icon then
				b.icon, b.atlas = iconOf(frame)
			end
			-- Only Blizzard's art hidden: the row draws its cell.
			b.dress = UI.Dress(frame, { style = "none", size = "frame" })
			buttons[name] = b
			hooksecurefunc(frame, "SetPoint", place)
			hooksecurefunc(frame, "SetParent", place)
			-- The voice buttons come and go with voice chat: the row closes up.
			frame:HookScript("OnShow", place)
			frame:HookScript("OnHide", place)
			frame:HookScript("OnEnter", onButtonEnter)
			frame:HookScript("OnLeave", onButtonLeave)
			hooksecurefunc(frame, "SetAlpha", onButtonAlpha)
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
	current = current or ChatFrame1.editBox --[[@as EditBox]]
	if not hooked then
		size = math.floor(current:GetHeight() + 0.5)
	end
	takeButtons() -- first: the rows show their icons
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
	end
	for input in pairs(inputs) do
		if overlaid then
			overlay(input)
		end
	end
	hideSocial()
	place()
	showButtons()
end

--- Stop: Blizzard's input art, text insets and the buttons' places, sizes and looks come back.
function Input.Disable()
	on = false
	for input, dress in pairs(inputs) do
		dress:Undress()
		shiftText(input)
		underChat(input)
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
			b.frame:SetSize(b.size[1], b.size[2])
			placing = false
		end
		b.frame:SetAlpha(1)
		b.frame:EnableMouse(true)
	end
	for input in pairs(inputs) do
		input:EnableMouse(true)
	end
	showSocial()
end

--- Whether the input sits over the chat (setting inputOverlay).
---@return boolean
function Input.IsOverlaid()
	return overlaid
end

--- The input over the chat, shown only while typing (setting inputOverlay), or under the window (Blizzard's place).
--- Sets Blizzard's own chat style option ("IM": the input shows on Enter) when turned on; the player can change that
--- option in Blizzard's settings.
---@param on_ boolean
function Input.SetOverlay(on_)
	overlaid = on_
	for _, dress in pairs(inputs) do
		dress.opts.focus = on_ -- over the chat: seen only while typing
		if dress.dressed then
			dress:Apply()
		end
	end
	if on_ then
		C_CVar.SetCVar("chatStyle", "im")
		ns.Debug:Logf("input: over the chat, chatStyle now %s", tostring(C_CVar.GetCVar("chatStyle")))
	end
	for input in pairs(inputs) do
		if on and on_ then
			overlay(input)
		else
			underChat(input)
		end
	end
	if on then
		showButtons()
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
		dressed = dressed, row = rowWidth(), cell = size, socialHidden = hiddenParent ~= nil and socialHome ~= nil }
end
