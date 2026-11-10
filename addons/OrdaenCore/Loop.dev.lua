-- The loop's dev doors (dev builds only): the Ordaen Dev window's live task list.
local _, ns = ...

local Loop, Core = ns.Loop, ns.Core

-- What holds a task, as the dev window names it: "<module folder>/<component>" for an instance, "core" for none
local function ownerOf(owner)
	if type(owner) ~= "table" then
		return "core"
	end
	local module = owner.module
	local declaration = owner._declaration
	return (module and module.folder or "?") .. "/" .. (declaration and declaration.name or "?")
end

--- Every live task, for the dev window: one record each, { task, owner, site, state, wait, due, cpu }
--- (`task:Cancel()` ends it). Sorted by owner, then spawn site.
---@return table[]
function Core._Tasks()
	local out = {}
	for task in pairs(Loop._Live()) do
		out[#out + 1] = { task = task, owner = ownerOf(task.owner), site = task.site, state = task.state,
			wait = task.wait, due = task.due, cpu = task.cpu }
	end
	table.sort(out, function(a, b)
		if a.owner ~= b.owner then
			return a.owner < b.owner
		end
		return a.site < b.site
	end)
	return out
end
