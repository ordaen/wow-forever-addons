-- Conflict handling, WoW side: checks at login, reacts to foreign changes reported by Map.lua (and to the Core's
-- findings, forwarded by Core.lua), re-checks a few seconds after login, and asks the player which addon to keep.
local addonName, ns = ...

local Guard = {}
ns.Guard = Guard

local L = ns.L
local UI = OrdaenCore.UI
local VERIFY_DELAY = 5

local db
local asked = {} -- addon (or "?") -> true once asked this session
local onResolved -- re-checks the features (Core.lua): the map goes on or off with Guard.blocked

--- True while we have stepped aside for an unresolved conflict: the map feature stays off.
Guard.blocked = false

local function isLoaded(name)
	return C_AddOns.IsAddOnLoaded(name) and true or false
end

local function title(name)
	if not name then
		return L.UNKNOWN_ADDON
	end
	local t = C_AddOns.GetAddOnMetadata(name, "Title")
	-- Titles may carry color codes; strip them for the dialog text.
	return t and t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or name
end

local function choiceFor(other)
	return db.conflictChoice and db.conflictChoice[other or "?"]
end

local function remember(other, choice)
	db.conflictChoice = db.conflictChoice or {}
	db.conflictChoice[other or "?"] = choice
end

local function resolved()
	Guard.blocked = false
	if onResolved then
		onResolved()
	end
end

-- The dialog: made once, its text and buttons changed per conflict (one conflict asked at a time).
local current -- the addon the dialog asks about (nil: unknown)
local keepOurs = { text = L.CONFLICT_KEEP_OURS }
local keepOther = { text = L.CONFLICT_DISABLE_OURS, macro = "/reload" }
local keepBoth = { text = L.CONFLICT_KEEP_BOTH }
local dialog

-- The reloading buttons carry `macro = "/reload"`: Forever blocks ReloadUI from addon code, even in a click
-- (CLAUDE.md, "Preventing bugs" 7). onClick runs first, in the same click, and turns the addon off.
function keepOurs.onClick()
	if keepOurs.macro then
		ns.Debug:Logf("conflict: disabling %s and reloading", current)
		C_AddOns.DisableAddOn(current)
		return
	end
	remember(current, "ours")
	ns.Debug:Logf("conflict: overriding %s", tostring(current))
	ns.Print(L.CONFLICT_OVERRIDE_HINT:format(title(current)))
	resolved()
end

function keepOther.onClick()
	ns.Debug:Logf("conflict: keeping %s, disabling %s and reloading", tostring(current), addonName)
	C_AddOns.DisableAddOn(addonName)
end

function keepBoth.onClick()
	remember(current, "both")
	ns.Debug:Logf("conflict: keeping both (%s)", tostring(current))
	ns.Print(L.CONFLICT_OVERRIDE_HINT:format(title(current)))
	resolved()
end

-- Escape: nothing decided. We stay aside for this session and ask again at the next login.
local function later()
	ns.Debug:Logf("conflict: decide later (%s)", tostring(current))
	ns.Print(L.CONFLICT_LATER_HINT)
end

local function ask(other)
	current = other
	dialog = dialog or UI.Confirm({ text = "", buttons = {}, onCancel = later })
	local buttons = dialog.buttons
	if other then
		-- A dedicated minimap addon is turned off (reload); a multi-purpose one is overridden (remembered).
		keepOurs.macro = ns.KeepOursAction(other) == "disable" and "/reload" or nil
		keepOther.text = L.CONFLICT_KEEP_OTHER:format(title(other))
		dialog.text = L.CONFLICT_TEXT:format(title(other))
		buttons[1], buttons[2], buttons[3] = keepOurs, keepOther, keepBoth
	else
		-- Unknown addon: nothing to turn off or remember by name. Keep ours on top, or turn ours off.
		keepOurs.macro = nil
		keepOther.text = L.CONFLICT_DISABLE_OURS
		dialog.text = L.CONFLICT_TEXT_UNKNOWN
		buttons[1], buttons[2], buttons[3] = keepOurs, keepOther, nil
	end
	dialog:Show() -- UI.Confirm waits for the loading screen by itself
end

--- Report a conflict: step aside and ask the player (once per addon per session).
---@param other string|nil the conflicting addon, nil when unknown
---@param reason string what was detected, for the debug log
---@return boolean true when we stepped aside
function Guard.Conflict(other, reason)
	local choice = choiceFor(other)
	if choice == "ours" or choice == "both" then
		return false
	end
	ns.Debug:Logf("conflict with %s: %s", tostring(other), reason)
	Guard.blocked = true
	if onResolved then
		onResolved() -- the map feature goes off: its OnDisable steps aside
	end
	if asked[other or "?"] then
		return true
	end
	asked[other or "?"] = true
	ask(other)
	return true
end

--- Check for conflicts before taking over the minimap.
---@return boolean true when there is one (the map must not be applied)
function Guard.CheckAtLogin()
	local known = ns.FindKnownConflict(isLoaded, db.conflictChoice)
	if known then
		return Guard.Conflict(known, "known minimap addon loaded")
	end
	if GetMinimapShape and GetMinimapShape ~= ns.Map.ShapeFunction then
		local owner = ns.OwnerFromTaint(issecurevariable("GetMinimapShape"))
		if owner then
			return Guard.Conflict(owner, "GetMinimapShape defined by " .. owner)
		end
	end
	return false
end

-- Map.lua calls this when something we own was changed outside our code.
local function onForeignChange(what, stack)
	local other = ns.AddonFromStack(stack)
	if not other then
		return -- Blizzard code; Map re-applies
	end
	Guard.Conflict(other, what .. " changed by " .. other)
end

local function verifyLater()
	C_Timer.After(VERIFY_DELAY, ns.Debug:Wrap(function()
		local problems = ns.Map.Verify()
		if #problems == 0 then
			return
		end
		local owner
		if GetMinimapShape ~= ns.Map.ShapeFunction then
			owner = ns.OwnerFromTaint(issecurevariable("GetMinimapShape"))
		end
		Guard.Conflict(owner, "delayed check: " .. table.concat(problems, ", "))
	end))
end

--- Use these SavedVariables (OnLoad and after a reset; the Core's findings can come before OnLogin).
---@param savedDb table OrdaenMinimapDB
function Guard.Init(savedDb)
	db = savedDb
end

--- Set up conflict handling. Call once in OnLogin: the features start after it, with Guard.blocked decided.
---@param refresh fun() re-checks the features (the map is on while Guard.blocked is false)
function Guard.Start(refresh)
	ns.Map.onForeignChange = onForeignChange
	if not Guard.CheckAtLogin() then
		verifyLater()
	end
	onResolved = refresh
end
