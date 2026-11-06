-- The chat's place: bottom left, above any Ordaen panel at the bottom of the screen (and right of one on the left),
-- found from the panels themselves (OrdaenCore.UI ScreenInset), so it follows the panel's size and edge without
-- numbers of our own. The window keeps the size Edit Mode gives it; with the setting at "Edit Mode" its place is
-- Edit Mode's too. Edit Mode applying its layout puts the chat where Edit Mode keeps it: we put it back after (a
-- hook). We never call Edit Mode's code: it also places protected frames (action bars), and our calls would taint it.
-- Cost: no events and nothing per frame. A callback when a panel's inset changes, a hook on Edit Mode placing the
-- chat window.
local _, ns = ...

local Position = {}
ns.Position = Position

local UI = OrdaenCore.UI

local MARGIN = 4 -- between the chat's background and the screen edge or panel

local on = false
local placing = false
local editModePoints -- where Edit Mode had the chat before we moved it: given back when the feature goes off
local hooked = false

-- How far the chat's background and input reach past the window frame, to the left and below (both move with it).
local function reach(chat)
	local left, bottom = chat:GetLeft(), chat:GetBottom()
	if not (left and bottom) then
		return 0, 0
	end
	local minLeft, minBottom = left, bottom
	for _, region in ipairs({ ChatFrame1Background, chat.editBox }) do
		local l, b = region and region:GetLeft(), region and region:GetBottom()
		if l and l < minLeft then
			minLeft = l
		end
		if b and b < minBottom then
			minBottom = b
		end
	end
	return left - minLeft, bottom - minBottom
end

local function place()
	if not on or placing then
		return
	end
	placing = true
	local chat = ChatFrame1
	if not editModePoints then
		editModePoints = {}
		for i = 1, chat:GetNumPoints() do
			editModePoints[i] = { chat:GetPoint(i) }
		end
	end
	local outLeft, outBottom = reach(chat)
	local x = UI.ScreenInset("left") + MARGIN + outLeft
	local y = UI.ScreenInset("bottom") + MARGIN + outBottom
	chat:ClearAllPoints()
	chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	placing = false
	ns.Debug:Logf("position: chat at %d, %d (panel insets bottom %d, left %d)", x, y, UI.ScreenInset("bottom"),
		UI.ScreenInset("left"))
end

local function onInsetsChanged()
	place()
end

--- Put the chat bottom left above the panels: the "position" feature's OnEnable.
function Position.Enable()
	on = true
	if not hooked then
		hooked = true
		-- Edit Mode placing the chat (its layout loaded or changed): Edit Mode's new place, then back above the panels.
		hooksecurefunc(ChatFrame1, "ApplySystemAnchor", function()
			if not placing then
				editModePoints = nil
				place()
			end
		end)
		EventRegistry:RegisterCallback("OrdaenUI.InsetsChanged", onInsetsChanged, Position)
	end
	place()
end

--- Leave the place to Edit Mode again.
function Position.Disable()
	on = false
	local chat = ChatFrame1
	if editModePoints then
		placing = true
		chat:ClearAllPoints()
		for _, p in ipairs(editModePoints) do
			chat:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
		placing = false
	end
end

--- What the dev-mode dump records.
function Position.Describe()
	local chat = ChatFrame1
	return { on = on, left = chat:GetLeft() or false, bottom = chat:GetBottom() or false,
		insetBottom = UI.ScreenInset("bottom"), insetLeft = UI.ScreenInset("left") }
end
