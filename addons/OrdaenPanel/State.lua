-- Ordaen Panel: the game state the visibility rules look at (Visibility.lua), read on the events Visibility.Events
-- lists. `hover` is set by the drawing code (Panel.lua) on enter/leave.
local _, ns = ...

---@class OrdaenPanelState : OrdaenPanelVisibilityState
local State = { combat = false, vehicle = false, petBattle = false, resting = false, hover = false, condition = nil }
ns.State = State

--- Read the state after `event` (nil: read everything, at start).
---@param event string|nil
---@param condition string|nil the custom macro condition ("" or nil: none)
function State.Read(event, condition)
	-- InCombatLockdown is still false while PLAYER_REGEN_DISABLED is handled: the event itself says it
	if event == "PLAYER_REGEN_DISABLED" then
		State.combat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		State.combat = false
	elseif event == nil then
		State.combat = InCombatLockdown() and true or false
	end
	State.vehicle = (UnitInVehicle("player") or UnitHasVehicleUI("player")) and true or false
	State.petBattle = C_PetBattles.IsInBattle() and true or false
	State.resting = IsResting() and true or false
	if condition and condition ~= "" then
		State.condition = SecureCmdOptionParse(condition)
	else
		State.condition = nil
	end
end
