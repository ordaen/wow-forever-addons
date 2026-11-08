-- OrdaenCore.UI confirmation dialogs: a message and a row of buttons, centred near the top of the screen like
-- Blizzard's popups. One dialog surface for every addon; a second confirm while one is open waits its turn.
-- Escape closes it as "cancel". Addons don't call this file: they make confirm objects with OrdaenCore.UI.Confirm
-- (UI.lua), whose :Show lands here once the framework is loaded.
--
-- Built once: the surface, a block with the message and a row of push buttons embedded in it ({ embed = button }),
-- so the layout sizes the dialog to whichever is wider, the text or the buttons. Showing a confirm only changes
-- fields. Nothing runs while no dialog is shown.
local _, ns = ...

local Component, Theme = ns.Component, ns.Theme

local Confirm = {}
ns.Confirm = Confirm

local NAME = "OrdaenUIConfirm"
local MAX_BUTTONS = 4
local TOP_OFFSET = -135 -- below the top edge, where Blizzard's StaticPopups appear

local surface -- component: the dialog box
local message, buttonRow -- elements of the surface's block
local cells = {} -- the row's embed elements, one per button

-- The row's columns for n buttons: the buttons at their own width, centred by a share of space on each side.
local COLUMNS = {}
for n = 1, MAX_BUTTONS do
	local columns = { "1fr" }
	for i = 1, n do
		columns[i + 1] = "auto"
	end
	columns[n + 2] = "1fr"
	COLUMNS[n] = columns
end
local buttons = {} -- pool of push button components
local indexOf = {} -- button component -> its position
local current -- the confirm object shown
local queue = {} -- confirm objects waiting
local closing = false -- a button press or Hide is closing it (not Escape)

-- Button `i` was pressed: close, then run its function (so a function may show another confirm).
local function press(button)
	local entry = current and current.buttons[indexOf[button]]
	closing = true
	Confirm.Close()
	closing = false
	if entry and entry.onClick then
		entry.onClick()
	end
end

-- Secure macros on buttons (`macro = "/reload"`). On Forever, reloading the interface is allowed only from secure
-- code, not from any addon code, not even right in a click.
-- So a button with a macro gets one of Blizzard's secure action buttons over it: its PreClick runs the entry's
-- onClick (addon code: turn an addon off), then the secure click runs the macro, in the same click; PostClick
-- closes the dialog. Secure frames can only be made, set up, shown and hidden out of combat: a confirm shown in
-- combat gets no overlay, and its button runs onClick only (the caller tells the player to /reload later).
local overlays = {} -- position -> its secure overlay (made on first need)
local overlayIndex = {} -- overlay -> position

local function overlayPreClick(overlay)
	local entry = current and current.buttons[overlayIndex[overlay]]
	if entry and entry.onClick then
		entry.onClick()
	end
end

local function overlayPostClick()
	closing = true
	Confirm.Close()
	closing = false
end

local function overlayEnter(overlay)
	buttons[overlayIndex[overlay]]:LockHighlight()
end

local function overlayLeave(overlay)
	buttons[overlayIndex[overlay]]:UnlockHighlight()
end

local function overlayFor(i)
	local overlay = overlays[i]
	if not overlay then
		local frame = buttons[i].frame
		overlay = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
		overlay:SetAllPoints(frame)
		overlay:SetFrameLevel(frame:GetFrameLevel() + 2)
		overlay:SetAttribute("type1", "macro")
		overlay:HookScript("PreClick", overlayPreClick)
		overlay:HookScript("PostClick", overlayPostClick)
		overlay:HookScript("OnEnter", overlayEnter)
		overlay:HookScript("OnLeave", overlayLeave)
		overlays[i], overlayIndex[overlay] = overlay, i
	end
	return overlay
end

-- Set the overlays for the confirm being shown (out of combat only; in combat they keep their state, and a hidden
-- dialog hides them with it).
local function setOverlays(confirm, count)
	if InCombatLockdown() then
		return
	end
	for i = 1, MAX_BUTTONS do
		local entry = i <= count and confirm.buttons[i]
		local macro = entry and entry.macro
		if macro then
			local overlay = overlayFor(i)
			-- A secure button acts on the press the player's "ActionButtonUseKeyDown" setting names (down by
			-- default); registered for the other half only, its PreClick runs but the macro never does.
			-- Like DialogueUI's macro buttons: register exactly that half.
			if C_CVar.GetCVarBool("ActionButtonUseKeyDown") then
				overlay:RegisterForClicks("LeftButtonDown")
			else
				overlay:RegisterForClicks("LeftButtonUp")
			end
			overlay:SetAttribute("macrotext", macro)
			overlay:Show()
		elseif overlays[i] then
			overlays[i]:Hide()
		end
	end
end

local function onSurfaceHidden()
	if current and not closing then
		-- Escape (UISpecialFrames) or something else hid it: that's "cancel".
		local cancelled = current
		current = nil
		if cancelled.onCancel then
			cancelled.onCancel()
		end
		Confirm.Next()
	end
end

local function build()
	message = { text = "", style = "body", align = "center" }
	surface = Component.Block({ name = NAME, parent = UIParent, strata = "DIALOG", style = "dialog", message })
	surface:SetPoint("TOP", UIParent, "TOP", 0, TOP_OFFSET)
	surface:SetClampedToScreen(true)
	surface.frame:EnableMouse(true) -- clicks on the dialog don't go through to the world
	surface.frame:HookScript("OnHide", onSurfaceHidden)
	surface:Hide()
	table.insert(UISpecialFrames, NAME) -- Escape closes it
	-- The row: a spacer, the buttons, a spacer (the spacers take the fr columns on both sides).
	buttonRow = { columns = COLUMNS[MAX_BUTTONS], gap = { "md", 0 }, { text = "" } }
	for i = 1, MAX_BUTTONS do
		local label = { text = "", style = "normal", align = "center" }
		local b = Component.Button({ parent = surface.frame, style = "pushButton", label })
		indexOf[b] = i
		b:On("click", press)
		b:Hide()
		buttons[i] = b
		cells[i] = { embed = b, hidden = true }
		buttonRow[#buttonRow + 1] = cells[i]
	end
	buttonRow[#buttonRow + 1] = { text = "" }
	surface.block[#surface.block + 1] = buttonRow
end

local function playSound(token)
	local name = OrdaenCore._SettingsStore and OrdaenCore._SettingsStore.Token(token)
	local id = type(name) == "string" and name ~= "" and SOUNDKIT and SOUNDKIT[name]
	if id then
		PlaySound(id)
	end
end


local function present(confirm)
	Theme.Ensure() -- sizes below come from the design scale
	if not surface then
		build()
	end
	current = confirm
	message.text = confirm.text or ""
	local count = math.min(#confirm.buttons, MAX_BUTTONS)
	local minWidth = 7 * Theme.size.body
	local gap = Theme.Space("md")
	local rowWidth = 0
	for i = 1, MAX_BUTTONS do
		local b = buttons[i]
		local entry = i <= count and confirm.buttons[i]
		cells[i].hidden = not entry
		if entry then
			b.block[1].text = entry.text -- its label element
			b.block.minWidth = minWidth
			b:Refresh() -- its own size first: the dialog's layout reads it
			rowWidth = rowWidth + b:GetWidth() + (i > 1 and gap or 0)
		end
	end
	buttonRow.columns = COLUMNS[math.max(count, 1)]
	-- At least 26 ems wide (a short message still reads as a dialog), wider for long button rows; the message wraps
	-- at the width the buttons need.
	local look = Theme.BlockStyle("dialog")
	local pad = type(look.padding) == "table" and (look.padding[2] + look.padding[4]) or 2 * (look.padding or 0)
	surface.block.minWidth = 26 * Theme.size.body
	surface.block.maxWidth = math.max(40 * Theme.size.body, rowWidth + pad)
	surface:Refresh()
	setOverlays(confirm, count)
	surface:Show()
	playSound("sound.open")
end

-- The framework, not each caller, waits for the loading screen: a dialog shown under it (at login, the first
-- load after enabling an addon) may be gone when it ends. Confirms shown then
-- wait in the queue; the first one appears when the loading screen is gone.
local waitingForLoad = false

local function afterLoading()
	waitingForLoad = false
	if not current then
		Confirm.Next()
	end
end

--- Show `confirm`, or queue it while another is open or the loading screen is up. Showing the one already shown
--- redraws it.
function Confirm.Show(confirm)
	if current == confirm then
		present(confirm)
		return
	end
	for _, waiting in ipairs(queue) do
		if waiting == confirm then
			return
		end
	end
	queue[#queue + 1] = confirm
	if not current and not waitingForLoad then
		waitingForLoad = true
		OrdaenCore._AfterLoadingScreen(afterLoading) -- right away when no loading screen is up
	end
end

--- Close the dialog shown (without cancelling it), then show the next waiting one.
function Confirm.Close()
	if not current then
		return
	end
	current = nil
	closing = true
	surface:Hide()
	closing = false
	playSound("sound.close")
	Confirm.Next()
end

function Confirm.Next()
	local nextConfirm = table.remove(queue, 1)
	if nextConfirm then
		present(nextConfirm)
	end
end

--- Hide `confirm`: close it if shown, forget it if waiting.
function Confirm.Hide(confirm)
	if current == confirm then
		Confirm.Close()
		return
	end
	for i, waiting in ipairs(queue) do
		if waiting == confirm then
			table.remove(queue, i)
			return
		end
	end
end

function Confirm.IsShown(confirm)
	return current == confirm
end
