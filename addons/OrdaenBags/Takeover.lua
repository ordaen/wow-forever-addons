-- Ordaen Bags, taking over the bags: the bag key, the bag buttons, a vendor or the mailbox opening the bags all go
-- through Blizzard's functions (ToggleAllBags, OpenAllBags, ToggleBackpack, OpenBag, ...), which show Blizzard's bag
-- frames. Those frames are parked on a hidden frame, so they never show, and after each of those functions our
-- window follows them: open while any of Blizzard's bag frames is open, closed when none is. No Blizzard function
-- is replaced (hooks only, after the original: no taint), and closing our window closes Blizzard's bags, so both
-- stay in step. If our window can't open (the framework missing, an error), Blizzard's frames come back for the
-- session: the player is never left without bags.
--
-- Cost: one hook per Blizzard bag function (they run when the player opens or closes bags), each a loop over the
-- dozen bag frames.
local _, ns = ...

local Takeover = {}
ns.Takeover = Takeover

-- Blizzard's bag functions: after each, the window follows Blizzard's frames.
local BAG_FUNCTIONS = {
	"OpenAllBags", "CloseAllBags", "ToggleAllBags", "OpenBackpack", "CloseBackpack", "ToggleBackpack",
	"OpenBag", "CloseBag", "ToggleBag",
}

local frames = {} ---@type Frame[] Blizzard's bag frames
local homes = {} ---@type table<Frame, Frame> frame -> its parent before we parked it
local parking ---@type Frame|nil
local active = false -- parking Blizzard's frames and following them
local hooked = false

local function findFrames()
	if #frames > 0 then
		return
	end
	local combined = _G.ContainerFrameCombinedBags
	if combined then
		frames[#frames + 1] = combined
	end
	for i = 1, NUM_CONTAINER_FRAMES or 0 do
		local frame = _G["ContainerFrame" .. i]
		if frame then
			frames[#frames + 1] = frame
		end
	end
end

-- Blizzard (or another addon) gave a parked frame another parent: park it again.
local function repark(frame)
	if active and parking and frame:GetParent() ~= parking then
		frame:SetParent(parking)
	end
end

local function park()
	if not parking then
		parking = CreateFrame("Frame")
		parking:Hide()
	end
	for _, frame in ipairs(frames) do
		if frame:GetParent() ~= parking then
			homes[frame] = frame:GetParent() or UIParent
			frame:SetParent(parking)
		end
	end
end

local reparkHooked = {}

local function unpark()
	for _, frame in ipairs(frames) do
		local home = homes[frame]
		if home and frame:GetParent() == parking then
			frame:SetParent(home)
		end
	end
end

local function anyOpen()
	for _, frame in ipairs(frames) do
		if frame:IsShown() then
			return true
		end
	end
	return false
end

-- Our window couldn't open: Blizzard's bags for the rest of the session.
local function giveBack(reason)
	active = false
	unpark()
	ns.Addon.Debug:Warnf("bags: Blizzard's bags are back for this session (%s)", tostring(reason))
end

local function follow()
	if not active then
		return
	end
	if anyOpen() then
		local ok, err = pcall(ns.View.Open)
		if not ok or not ns.View.IsOpen() then
			giveBack(err or "the window didn't open")
		end
	else
		ns.View.Close()
	end
end

--- Take the bags over (at login, while the feature is on).
function Takeover.Start()
	findFrames()
	if #frames == 0 then
		ns.Addon.Debug:Warn("bags: none of Blizzard's bag frames found; nothing taken over")
		return
	end
	active = true
	park()
	for _, frame in ipairs(frames) do
		if not reparkHooked[frame] then
			reparkHooked[frame] = true
			hooksecurefunc(frame, "SetParent", repark)
		end
	end
	if not hooked then
		hooked = true
		for _, name in ipairs(BAG_FUNCTIONS) do
			if not ns.Addon:Hook(name, follow) then
				ns.Addon.Debug:Warnf("bags: no %s on this client", name)
			end
		end
	end
	ns.Addon.Debug:Logf("bags: %d of Blizzard's bag frames parked", #frames)
end

--- Give the bags back (the feature went off, or a bag addon it conflicts with is loaded).
function Takeover.Stop()
	if active then
		active = false
		ns.View.Close()
		unpark()
	end
end

--- Our window closed (Escape, its close button, or Blizzard's bags closing): close Blizzard's too, so the next
--- press of the bag key opens them again.
function Takeover.WindowHidden()
	if active and anyOpen() then
		CloseAllBags()
	end
end
