-- Ordaen Panel: when the panel shows, like Bartender's visibility settings. Pure logic: the WoW side gathers the
-- state from events (combat, vehicle, pet battle, resting, mouseover, the custom condition's result) and fades the
-- panel to what this says. "Hidden" is a fade to the faded alpha with the mouse off, never Hide(): the panel holds
-- Blizzard's buttons, and hiding those in combat could be blocked.
local _, ns = ...

local Visibility = {}
ns.Visibility = Visibility

---@class OrdaenPanelVisibilityState
---@field combat boolean
---@field vehicle boolean
---@field petBattle boolean
---@field resting boolean
---@field hover boolean the mouse is over the panel
---@field condition string|nil the custom condition's result ("show", "hide"), nil when there is none

--- Whether the panel should be shown now.
--- The custom condition, when set, decides alone ("hide" hides, anything else shows), as in Bartender. Otherwise:
--- "never" hides; then combat, vehicle, pet battle and resting rules can hide it; "mouseover" shows it only while
--- the mouse is over it.
---@param v table the `visibility` settings (show, combat, vehicle, petBattle, resting, condition)
---@param s OrdaenPanelVisibilityState
---@return boolean
function Visibility.Shown(v, s)
	if v.condition ~= nil and v.condition ~= "" and s.condition ~= nil then
		return s.condition ~= "hide"
	end
	if v.show == "never" then
		return false
	end
	if (v.combat == "hide" and s.combat) or (v.combat == "only" and not s.combat) then
		return false
	end
	if (v.vehicle and s.vehicle) or (v.petBattle and s.petBattle) or (v.resting and s.resting) then
		return false
	end
	if v.show == "mouseover" and not s.hover then
		return false
	end
	return true
end

--- The events whose change can change Shown, for the settings in use (register only these).
---@param v table the `visibility` settings
---@param out string[] filled (and cut to length): reused, no table per call
---@return string[] out
function Visibility.Events(v, out)
	local n = 0
	local function add(event)
		n = n + 1
		out[n] = event
	end
	local custom = v.condition ~= nil and v.condition ~= ""
	if custom or v.combat ~= "any" then
		add("PLAYER_REGEN_DISABLED")
		add("PLAYER_REGEN_ENABLED")
	end
	if custom or v.vehicle then
		add("UNIT_ENTERED_VEHICLE")
		add("UNIT_EXITED_VEHICLE")
	end
	if custom or v.petBattle then
		add("PET_BATTLE_OPENING_START")
		add("PET_BATTLE_CLOSE")
	end
	if custom or v.resting then
		add("PLAYER_UPDATE_RESTING")
	end
	if custom then
		-- what macro conditions commonly test besides the above
		add("MODIFIER_STATE_CHANGED")
		add("PLAYER_TARGET_CHANGED")
		add("ZONE_CHANGED_NEW_AREA")
		add("UPDATE_SHAPESHIFT_FORM")
		add("GROUP_ROSTER_UPDATE")
	end
	for i = #out, n + 1, -1 do
		out[i] = nil
	end
	return out
end
