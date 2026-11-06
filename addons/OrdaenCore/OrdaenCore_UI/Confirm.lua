-- OrdaenCore.UI confirmation dialogs: a message and a row of buttons, centred near the top of the screen like
-- Blizzard's popups. One dialog surface for every addon; a second confirm while one is open waits its turn.
-- Escape closes it as "cancel". Addons don't call this file: they make confirm objects with OrdaenCore.UI.Confirm
-- (UI.lua), whose :Show lands here once the framework is loaded.
--
-- Built once: the surface (a block with the text and room for the buttons) and a pool of push buttons; showing a
-- confirm only changes their fields. Nothing runs while no dialog is shown.
local _, ns = ...

local Component, Theme = ns.Component, ns.Theme

local Confirm = {}
ns.Confirm = Confirm

local NAME = "OrdaenUIConfirm"
local MAX_BUTTONS = 4
local TOP_OFFSET = -135 -- below the top edge, where Blizzard's StaticPopups appear

local surface -- component: the dialog box
local message, buttonRow -- elements of the surface's block
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
	buttonRow = { height = 0 } -- room for the buttons, sized per show
	surface = Component.Block({
		name = NAME,
		parent = UIParent,
		strata = "DIALOG",
		style = "dialog",
		message,
		buttonRow,
	})
	surface:SetPoint("TOP", UIParent, "TOP", 0, TOP_OFFSET)
	surface:SetClampedToScreen(true)
	surface.frame:EnableMouse(true) -- clicks on the dialog don't go through to the world
	surface.frame:HookScript("OnHide", onSurfaceHidden)
	surface:Hide()
	table.insert(UISpecialFrames, NAME) -- Escape closes it
	for i = 1, MAX_BUTTONS do
		local label = { text = "", style = "normal", align = "center" }
		local b = Component.Button({ parent = surface.frame, style = "pushButton", label })
		indexOf[b] = i
		b:On("click", press)
		b:Hide()
		buttons[i] = b
	end
end

local function playSound(token)
	local name = OrdaenCore._SettingsStore and OrdaenCore._SettingsStore.Token(token)
	local id = type(name) == "string" and name ~= "" and SOUNDKIT and SOUNDKIT[name]
	if id then
		PlaySound(id)
	end
end

-- Lay the buttons out in one centred row at the bottom of the surface.
local function placeButtons(count)
	local gap = Theme.Space("md")
	local minWidth = 7 * Theme.size.body
	local total, height = 0, 0
	for i = 1, count do
		local b = buttons[i]
		b.block.minWidth = minWidth
		b:Refresh()
		total = total + b:GetWidth() + (i > 1 and gap or 0)
		height = math.max(height, b:GetHeight())
	end
	buttonRow.height = height
	surface:Refresh()
	local pad = Theme.BlockStyle("dialog")
	local bottom = type(pad.padding) == "table" and pad.padding[3] or pad.padding or 0
	local x = -total / 2
	for i = 1, count do
		local b = buttons[i]
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", surface.frame, "BOTTOM", x, bottom)
		x = x + b:GetWidth() + gap
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
	for i = 1, MAX_BUTTONS do
		local b = buttons[i]
		local entry = i <= count and confirm.buttons[i]
		if entry then
			b.block[1].text = entry.text -- its label element
			b:Show()
		else
			b:Hide()
		end
	end
	surface.block.width = 26 * Theme.size.body
	placeButtons(count)
	surface:Show()
	playSound("sound.open")
end

--- Show `confirm`, or queue it while another is open. Showing the one already shown redraws it.
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
	if current then
		queue[#queue + 1] = confirm
	else
		present(confirm)
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
