-- Conflict handling, WoW side: checks at login, reacts to foreign changes reported by Map.lua,
-- re-checks a few seconds after login, and asks the user which addon to keep.
local addonName, ns = ...

local Guard = {}
ns.Guard = Guard

local L = ns.L
local POPUP = "ORDAEN_MINIMAP_CONFLICT"
local VERIFY_DELAY = 5

local db
local asked = {} -- addon (or "?") -> true once asked this session
local onResolved -- re-apply callback from Core.lua

--- True while we have stepped aside for an unresolved conflict; settings changes must not re-apply.
Guard.blocked = false

local function isLoaded(name)
	return C_AddOns.IsAddOnLoaded(name) and true or false
end

local function title(name)
	if not name then
		return L.UNKNOWN_ADDON
	end
	local t = C_AddOns.GetAddOnMetadata(name, "Title")
	-- Titles may carry color codes; strip them for the popup text.
	return t and t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or name
end

local function choiceFor(other)
	return db.conflictChoice and db.conflictChoice[other or "?"]
end

local function remember(other, choice)
	db.conflictChoice = db.conflictChoice or {}
	db.conflictChoice[other or "?"] = choice
end

-- C_AddOns.DisableAddOn is not confirmed on Forever yet; fall back to the old global, then to asking
-- the user to do it in the AddOns list.
local function disableAddOn(name)
	local disable = C_AddOns.DisableAddOn or _G.DisableAddOn
	if type(disable) ~= "function" then
		ns.Debug.Logf("conflict: no DisableAddOn API, asking the user to disable %s", name)
		ns.Print(L.CONFLICT_DISABLE_MANUALLY:format(title(name)))
		return false
	end
	disable(name)
	return true
end

local function keepOurs(other)
	if ns.KeepOursAction(other) == "disable" then
		ns.Debug.Logf("conflict: disabling %s and reloading", other)
		if disableAddOn(other) then
			ReloadUI()
		end
		return
	end
	remember(other, "ours")
	Guard.blocked = false
	ns.Debug.Logf("conflict: overriding %s", tostring(other))
	ns.Print(L.CONFLICT_OVERRIDE_HINT:format(title(other)))
	if onResolved then
		onResolved()
	end
end

local function keepOther(other)
	ns.Debug.Logf("conflict: keeping %s, disabling %s and reloading", tostring(other), addonName)
	if disableAddOn(addonName) then
		ReloadUI()
	end
end

local function decideLater(other)
	ns.Debug.Logf("conflict: decide later (%s)", tostring(other))
	ns.Print(L.CONFLICT_LATER_HINT)
end

local function definePopup()
	if StaticPopupDialogs[POPUP] then
		return
	end
	StaticPopupDialogs[POPUP] = {
		text = "%s",
		button1 = L.CONFLICT_KEEP_OURS,
		button2 = L.CONFLICT_KEEP_OTHER,
		button3 = L.CONFLICT_LATER,
		OnAccept = function(_, data)
			keepOurs(data)
		end,
		OnCancel = function(_, data, reason)
			-- OnCancel also runs when the popup is closed by other means; only button2 keeps the other.
			if reason == "clicked" then
				keepOther(data)
			end
		end,
		OnAlt = function(_, data)
			decideLater(data)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = false,
		showAlert = true,
		preferredIndex = 3,
	}
end

--- Report a conflict: step aside and ask the user (once per addon per session).
---@param other string|nil the conflicting addon, nil when unknown
---@param reason string what was detected, for the debug log
function Guard.Conflict(other, reason)
	if choiceFor(other) == "ours" then
		return false
	end
	ns.Debug.Logf("conflict with %s: %s", tostring(other), reason)
	Guard.blocked = true
	ns.Map.StepAside()
	if asked[other or "?"] then
		return true
	end
	asked[other or "?"] = true
	definePopup()
	local text = other and L.CONFLICT_TEXT:format(title(other)) or L.CONFLICT_TEXT_UNKNOWN
	StaticPopupDialogs[POPUP].button2 = other and L.CONFLICT_KEEP_OTHER:format(title(other))
		or L.CONFLICT_DISABLE_OURS
	StaticPopup_Show(POPUP, text, nil, other)
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
	C_Timer.After(VERIFY_DELAY, ns.Debug.Wrap(function()
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

--- Set up conflict handling. Call once at PLAYER_LOGIN, before applying the map.
---@param savedDb table OrdaenMinimapDB
---@param reapply fun() applies the map (used after the user keeps ours)
---@return boolean true when the map may be applied now
function Guard.Start(savedDb, reapply)
	db = savedDb
	onResolved = reapply
	ns.Map.onForeignChange = onForeignChange
	if Guard.CheckAtLogin() then
		return false
	end
	verifyLater()
	return true
end
