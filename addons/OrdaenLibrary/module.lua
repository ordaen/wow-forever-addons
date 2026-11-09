-- Ordaen Library: the components every module draws by name (design: development/framework/library): controls,
-- windows, sections. A module's `game.ui:<Name>` that its own components/ don't have comes from here. Load on
-- demand: Ordaen Core loads it at the first such call, so a player whose modules draw none never loads it. Never
-- mounted and never in the module list; a component's state lives in the module that draws it. A module's own
-- components/<name> can't share a name with one here (build check B14).
local Define = import("@ordaen/define")

return Define.Library({
	title = "Ordaen Library",
})
