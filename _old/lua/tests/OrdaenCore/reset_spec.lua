-- A module's reset (design development/framework/app, «Reset»): a module mounted, used and turned off leaves the
-- client as one where it never ran: the same frames shown and anchored (Blizzard's given back), the same events
-- registered, the same OnUpdate scripts running, the same timers waiting, nothing of it in Ordaen's commands or the
-- placing mode; turned on again, it is as on its first mount. A difference is a leak, named in the failure.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

-- The modules, each with the Blizzard frames it takes over (what the game has before any addon runs).
local MODULES = {
	OrdaenPanel = function(env)
		local home = env.CreateFrame("Frame", "BagsBar", env.UIParent)
		for _, name in ipairs({ "MainMenuBarBackpackButton", "CharacterBag0Slot" }) do
			env.CreateFrame("Button", name, home):SetSize(45, 45)
		end
		env.CreateFrame("Frame", "MicroMenuContainer", env.UIParent)
		env.CreateFrame("Frame", "MicroMenu", env.MicroMenuContainer)
	end,
	OrdaenMinimap = function(env)
		local cluster = env.CreateFrame("Frame", "MinimapCluster", env.UIParent)
		env.CreateFrame("Minimap", "Minimap", cluster)
		cluster.Tracking = env.CreateFrame("Frame", nil, cluster)
		cluster.Tracking.Button = env.CreateFrame("Button", nil, cluster.Tracking)
	end,
	OrdaenTooltips = function() end,
}

-- 5 seconds of frames: what was started runs out (timers, retries)
local function settle(wow)
	for _ = 1, 300 do
		wow:Tick()
	end
end

local function client(folder, off)
	local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", folder },
		saved = off and { OrdaenCoreDB = { off = { [folder] = true } } } or nil })
	MODULES[folder](wow.env)
	wow:Login()
	settle(wow)
	return wow
end

local function nameOf(f)
	local name = f:GetName()
	if name then
		return name
	end
	local parent = f:GetParent()
	return (parent and nameOf(parent) or "?") .. ">" .. f:GetObjectType()
end

-- A frame that puts something on the screen: visible, with a shown texture or text of its own, or made by the module
-- (not by Ordaen: its layers and scheduler frame are made once and draw nothing).
local function draws(f)
	if not (f.IsVisible and f:IsVisible()) then
		return false
	end
	if f._addon and f._addon ~= "OrdaenCore" then
		return true
	end
	for _, r in ipairs(f._regions or {}) do
		if r._shown then
			return true
		end
	end
	return false
end

-- What the client shows and runs, as sorted lines: frames (every named one, and every unnamed one that draws: hidden
-- ones sit in pools), events registered, OnUpdate scripts on frames that draw, timers, and Ordaen's records.
local function snapshot(wow)
	local lines = {}
	for f in pairs(wow.allFrames) do
		-- Blizzard's frames (made by the test, as the game makes them) always; an addon's only while they draw: WoW
		-- never destroys a frame, so one it named (a secure action button) stays, hidden, for its next mount
		local blizzard = f._addon == nil
		if f.GetName and ((blizzard and f:GetName()) or draws(f)) then
			local parent = f.GetParent and f:GetParent()
			lines[#lines + 1] = string.format("frame %s shown=%s parent=%s points=%d size=%dx%d", nameOf(f),
				tostring(f.IsShown and f:IsShown()), parent and nameOf(parent) or "-",
				f.GetNumPoints and f:GetNumPoints() or 0, math.floor((f.GetWidth and f:GetWidth() or 0) + 0.5),
				math.floor((f.GetHeight and f:GetHeight() or 0) + 0.5))
		end
	end
	for event, frames in pairs(wow.listeners) do
		local n = 0
		for _ in pairs(frames) do
			n = n + 1
		end
		if n > 0 then
			lines[#lines + 1] = "event " .. event .. " x" .. n
		end
	end
	local updating = 0
	for f in pairs(wow.updating) do
		if draws(f) then
			updating = updating + 1
		end
	end
	lines[#lines + 1] = "onupdate running x" .. updating
	lines[#lines + 1] = "timers x" .. #wow.timers
	local ns = wow.addons.OrdaenCore.ns
	for id in pairs(ns.Placing.Parts()) do
		lines[#lines + 1] = "part " .. id
	end
	table.sort(lines)
	return lines
end

-- The lines only one side has, both ways.
local function diff(want, got)
	local count = {}
	for _, l in ipairs(want) do
		count[l] = (count[l] or 0) + 1
	end
	for _, l in ipairs(got) do
		count[l] = (count[l] or 0) - 1
	end
	local out = {}
	for l, n in pairs(count) do
		if n > 0 then
			out[#out + 1] = "missing: " .. l .. (n > 1 and (" (x" .. n .. ")") or "")
		elseif n < 0 then
			out[#out + 1] = "leaked:  " .. l .. (n < -1 and (" (x" .. -n .. ")") or "")
		end
	end
	table.sort(out)
	return out
end

local function entry(wow, folder)
	for _, e in ipairs(wow.addons.OrdaenCore.ns.App.modules) do
		if e.folder == folder then
			return e
		end
	end
	error("no module entry " .. folder)
end

for folder in pairs(MODULES) do
	describe("resetting " .. folder, function()
		it("leaves the client as one where it never ran", function()
			local never = snapshot(client(folder, true))
			local wow = client(folder, false)
			assert.is_true(entry(wow, folder).loaded:Peek(), "it didn't mount:\n" .. table.concat(wow.errors, "\n"))
			entry(wow, folder):Enable(false)
			settle(wow)
			assert.are.same({}, wow.errors)
			local leaks = diff(never, snapshot(wow))
			assert(#leaks == 0, #leaks .. " differences from a client where it never ran:\n" .. table.concat(leaks, "\n"))
		end)

		it("mounts again as on its first mount", function()
			local first = client(folder, false)
			local wow = client(folder, false)
			entry(wow, folder):Enable(false)
			settle(wow)
			entry(wow, folder):Enable(true)
			settle(wow)
			assert.are.same({}, wow.errors)
			local leaks = diff(snapshot(first), snapshot(wow))
			assert(#leaks == 0, #leaks .. " differences from its first mount:\n" .. table.concat(leaks, "\n"))
		end)
	end)
end
