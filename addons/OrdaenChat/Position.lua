-- The chat's place: bottom left, above any Ordaen panel at the bottom of the screen (and right of one on the left),
-- found from the panels themselves (OrdaenCore.UI ScreenInset), so it follows the panel's size and edge without
-- numbers of our own. The window keeps the size Edit Mode gives it; with the setting at "Edit Mode" its place is
-- Edit Mode's too. Blizzard places the chat window from several places (Edit Mode's layout, the chat windows'
-- saved positions): a hook on the window's SetPoint notes Blizzard's new place and puts it back above the panels
-- (hooking only Edit Mode's ApplySystemAnchor misses the other path and leaves the chat at x 30). We never
-- call Edit Mode's code: it also places protected frames (action bars), and our calls would taint it.
-- Cost: no events and nothing per frame. A callback when a panel's inset changes, a hook on Edit Mode placing the
-- chat window.
local _, ns = ...

local Position = {}
ns.Position = Position

local UI = OrdaenCore.UI

-- Between the chat's background and the screen edge (none: flush) and the panel.
local MARGIN_LEFT, MARGIN_BOTTOM = 0, 0
-- Flush with the screen's left edge and sitting on the panel (or the bottom edge): no border on those sides, as if the
-- metal ran on (open sides). The bottom only while the input sits over the chat; below it, the
-- input is the chat's bottom.
local OPEN_DOCKED = { left = true, bottom = true }
local OPEN_LEFT = { left = true }

local on = false
local placing = false
local editModePoints -- where Edit Mode had the chat before we moved it: given back when the feature goes off
-- Blizzard clamps the chat to the screen with insets that keep room for its button column on the left (FCF, set
-- again in FCF_UpdateButtonSide): that column is empty (Input.lua), but its room would push the chat 30 UI units off
-- the left edge. Ours leave only the background's own reach; Blizzard's come back when the feature goes
-- off.
local blizzardClamp -- { left, right, top, bottom } before ours
local hooked = false

-- How far the chat's background and input reach past the window frame, to the left and below (both move with it).
local function reach(chat)
	local left, bottom = chat:GetLeft(), chat:GetBottom()
	if not (left and bottom) then
		return 0, 0
	end
	local minLeft, minBottom = left, bottom
	-- Blizzard's background, the input, and our background (it reaches past Blizzard's by the chat's padding).
	for _, region in ipairs({ ChatFrame1Background, chat.editBox, ns.Look.Cover(chat) or false }) do
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
	local left, right, top, bottom = chat:GetClampRectInsets()
	if not blizzardClamp then
		blizzardClamp = { left, right, top, bottom }
	end
	chat:SetClampRectInsets(-outLeft, right, top, bottom)
	local x = UI.ScreenInset("left") + MARGIN_LEFT + outLeft
	local y = UI.ScreenInset("bottom") + MARGIN_BOTTOM + outBottom
	chat:ClearAllPoints()
	chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	ns.Look.SetOpen(chat, ns.Input.IsOverlaid() and OPEN_DOCKED or OPEN_LEFT)
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
		-- Blizzard placing the chat (Edit Mode's layout, the saved chat positions): its new place, then ours again.
		hooksecurefunc(ChatFrame1, "SetPoint", function()
			if on and not placing then
				editModePoints = nil
				place()
			end
		end)
		EventRegistry:RegisterCallback("OrdaenUI.InsetsChanged", onInsetsChanged, Position)
		-- The text size changed: so did the chat's padding, and with it how far its background reaches.
		EventRegistry:RegisterCallback("OrdaenUI.ThemeChanged", onInsetsChanged, Position)
		-- Blizzard sets its clamp insets again (the button side changed): ours again.
		hooksecurefunc("FCF_UpdateButtonSide", function(frame)
			if frame == ChatFrame1 and on and not placing then
				blizzardClamp = nil
				place()
			end
		end)
	end
	place()
end

--- Place it again (the input moved over or under the chat: its bottom changed).
function Position.Refresh()
	place()
end

--- Leave the place to Edit Mode again.
function Position.Disable()
	on = false
	local chat = ChatFrame1
	ns.Look.SetOpen(chat, nil)
	placing = true
	if blizzardClamp then
		chat:SetClampRectInsets(blizzardClamp[1], blizzardClamp[2], blizzardClamp[3], blizzardClamp[4])
	end
	if editModePoints then
		chat:ClearAllPoints()
		for _, p in ipairs(editModePoints) do
			chat:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
	end
	placing = false
end

--- What the dev-mode dump records.
function Position.Describe()
	local chat = ChatFrame1
	return { on = on, left = chat:GetLeft() or false, bottom = chat:GetBottom() or false,
		insetBottom = UI.ScreenInset("bottom"), insetLeft = UI.ScreenInset("left") }
end
