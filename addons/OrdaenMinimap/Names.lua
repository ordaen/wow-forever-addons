-- Pure logic, no WoW API: unit-tested by tests/OrdaenMinimap/names_spec.lua.
local _, ns = ...

-- Lua patterns have no alternation, so the regex
-- `MinimapButton|MinimapFrame|MinimapIcon|[-_]Minimap[-_]|Minimap$|^LibDBIcon10_` is a list.
local BUTTON_NAME_PATTERNS = {
	"MinimapButton",
	"MinimapFrame",
	"MinimapIcon",
	"[-_]Minimap[-_]",
	"Minimap$",
	"^LibDBIcon10_",
}

-- Map pins and waypoint arrows live on the minimap too, but belong on it.
local PIN_PATTERNS = {
	"^HandyNotes",
	"^TomTom",
	"^HereBeDragons",
	"^Questie",
	"^GatherMate",
	"^GatherLite",
	"^pin",
	"^Pin",
	"^EasyFind",
}

--- Whether a Minimap child frame with this name looks like an addon's minimap button.
---@param name string|nil
---@return boolean
function ns.IsMinimapButtonName(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	-- TomCats names its buttons after the year ("TomCats-...2026"), so check before the digit rule.
	if name:find("^TomCats%-") then
		return true
	end
	-- Names ending in digits are usually generated (pins, pooled frames), not addon buttons.
	if name:find("%d$") then
		return false
	end
	for _, pattern in ipairs(PIN_PATTERNS) do
		if name:find(pattern) then
			return false
		end
	end
	for _, pattern in ipairs(BUTTON_NAME_PATTERNS) do
		if name:find(pattern) then
			return true
		end
	end
	return false
end

--- The LibDBIcon data object name behind a button name ("LibDBIcon10_Details" -> "Details").
---@param name string|nil
---@return string|nil
function ns.LibDBIconObjectName(name)
	return type(name) == "string" and name:match("^LibDBIcon10_(.+)$") or nil
end

-- Suffixes addons put after their name on a minimap button, longest first.
local BUTTON_SUFFIXES = {
	"[-_]?[Mm]inimap[-_]?[Bb]utton$",
	"[-_]?[Mm]inimap[-_]?[Ii]con$",
	"[-_]?[Mm]inimap[-_]?[Ff]rame$",
	"[-_][Mm]inimap[-_].*$",
	"[-_]?[Mm]inimap$",
}

--- The addon a minimap button belongs to, as written in its name: the LibDBIcon object, else the name without
--- its minimap suffix ("AltoholicMinimapButton" -> "Altoholic", "AutoBiographer_MinimapButton" ->
--- "AutoBiographer"). nil when nothing is left. The drawer matches it against compartment entries, so one
--- addon gets one square.
---@param name string|nil
---@return string|nil
function ns.ButtonAddonName(name)
	local object = ns.LibDBIconObjectName(name)
	if object then
		return object
	end
	if type(name) ~= "string" then
		return nil
	end
	for _, suffix in ipairs(BUTTON_SUFFIXES) do
		local stem, n = name:gsub(suffix, "")
		if n > 0 then
			return stem ~= "" and stem or nil
		end
	end
	return nil
end
