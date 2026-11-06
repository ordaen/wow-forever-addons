-- Capture: our own error catcher (what BugGrabber does), active only in dev mode.
--
-- * Global error handler: every Lua error in the game (any addon, Blizzard UI, our unwrapped code
--   and file-load errors) is recorded, then handed on unchanged to the handler that was there before
--   (BugGrabber, or Blizzard's). If something else keeps the handler to itself (BugGrabber can), we
--   take its errors from its BugGrabber_BugGrabbed callback instead.
-- * Debug.Call / Debug.Wrap use WrapHandler, which records and forwards the same way.
-- * Blocked or forbidden protected actions (taint) are recorded with kind "taint".
-- Repeats only bump a counter before any stack is captured, so an error firing every frame is cheap.
local _, ns = ...
local Store = ns.Store

local Capture = {}
ns.Capture = Capture

local previousHandler -- the handler we replaced, if we managed to install ours
local forwarding = false -- true while we hand an error on, so callbacks don't record it twice

-- level: the erroring frame as seen from the function calling grab (2 inside an error handler).
local function grab(level)
	local stack = debugstack and debugstack(level + 1) or nil
	-- For error("...") that frame is the C function error itself, whose locals are only
	-- temporaries; the caller's locals are one level further down. (Verified in game, 1.60.1.)
	local localsLevel = (stack and stack:find("^%[C%]")) and level + 2 or level + 1
	local locals = debuglocals and debuglocals(localsLevel) or nil
	return stack, locals
end

local function record(message, stack, locals, kind, source)
	pcall(Store.AddError, { message = message, stack = stack, locals = locals, kind = kind, source = source })
end

local function forward(err)
	local handler = previousHandler or (geterrorhandler and geterrorhandler())
	if handler and handler ~= Capture.Handler then
		forwarding = true
		pcall(handler, err)
		forwarding = false
	end
end

--- The global error handler (seterrorhandler), also the xpcall handler of Debug.Call: in both
--- cases the erroring frame is level 2. Records the error, then hands it on.
function Capture.Handler(err)
	if not Store.Repeat(err) then
		local stack, locals = grab(2)
		record(err, stack, locals)
	end
	forward(err)
	return err
end

--- Errors reported by BugGrabber when it keeps the global handler to itself.
function Capture.OnBugGrabbed(_, bug)
	if forwarding or type(bug) ~= "table" or bug.message == nil then
		return
	end
	if not Store.Repeat(bug.message) then
		record(bug.message, bug.stack, bug.locals)
	end
end

--- Record a blocked or forbidden protected action (ADDON_ACTION_BLOCKED / _FORBIDDEN).
function Capture.OnTaint(event, addon, func)
	local verb = event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked"
	local message = string.format("%s: call to %s() was %s", tostring(addon), tostring(func), verb)
	if not Store.Repeat(message) then
		local source = tostring(addon):match("^(Ordaen[%w_]*)$") or "other"
		record(message, debugstack and debugstack(2) or nil, nil, "taint", source)
	end
end

---@return string "handler" | "buggrabber" | "none" how errors outside Debug.Wrap are caught
function Capture.Mode()
	return Capture.mode
end

function Capture.Install()
	Capture.mode = "none"
	if geterrorhandler and seterrorhandler then
		local before = geterrorhandler()
		seterrorhandler(Capture.Handler)
		if geterrorhandler() == Capture.Handler then
			previousHandler = before
			Capture.mode = "handler"
		end
	end
	if Capture.mode == "none" and type(BugGrabber) == "table" and type(BugGrabber.RegisterCallback) == "function" then
		local ok = pcall(BugGrabber.RegisterCallback, Capture, "BugGrabber_BugGrabbed", Capture.OnBugGrabbed)
		if ok then
			Capture.mode = "buggrabber"
		end
	end

	local events = CreateFrame("Frame")
	events:RegisterEvent("ADDON_ACTION_BLOCKED")
	events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	events:SetScript("OnEvent", function(_, event, addon, func)
		Capture.OnTaint(event, addon, func)
	end)
end

Capture.Install()
