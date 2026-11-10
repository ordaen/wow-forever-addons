-- The loop's dev doors (dev builds only): the Ordaen Dev window's live task list.
local _, ns = ...

local Loop, Core = ns.Loop, ns.Core

--- Every live task, for the dev window: one record each, { task, site, state, wait, due, cpu } (`task:Cancel()`
--- ends it). Sorted by spawn site.
---@return table[]
function Core._Tasks()
	local out = {}
	for task in pairs(Loop._Live()) do
		out[#out + 1] = { task = task, site = task.site, state = task.state, wait = task.wait, due = task.due,
			cpu = task.cpu }
	end
	table.sort(out, function(a, b)
		return a.site < b.site
	end)
	return out
end
