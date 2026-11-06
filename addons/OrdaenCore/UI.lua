-- OrdaenCore.UI: our UI framework. Addons declare what they want (a tooltip; later buttons, windows) in our
-- own format and never learn who draws it. A renderer addon registers for one kind and draws every thing of
-- that kind; without one, the Core draws what Blizzard's own UI can. See CLAUDE.md, "UI framework".
-- Names here are forever (Core API rule): add, never change or remove.
local _, ns = ...

local UI = {}
ns.UI = UI
ns.Core.UI = UI

-- kind -> renderer. Private to the Core; kinds the Core doesn't know yet are still stored, so a newer
-- renderer addon can register on an older Core without errors.
local renderers = {}
ns.renderers = renderers

-- Functions a renderer must have, per kind the Core draws.
local REQUIRED = {
	tooltip = { "Show", "Hide", "Refresh" },
}

--- Make `renderer` draw every thing of `kind` from now on (one per kind; registering again replaces it).
---@param kind string e.g. "tooltip"
---@param renderer table for "tooltip": { formatVersion = n, Show = fn(owner, content, opts), Hide = fn(owner),
---  Refresh = fn(owner, content) }
function UI.RegisterRenderer(kind, renderer)
	if type(kind) ~= "string" or type(renderer) ~= "table" then
		error("usage: OrdaenCore.UI.RegisterRenderer(kind, renderer)", 2)
	end
	for _, name in ipairs(REQUIRED[kind] or {}) do
		if type(renderer[name]) ~= "function" then
			error("OrdaenCore.UI.RegisterRenderer: a " .. kind .. " renderer needs a " .. name .. " function", 2)
		end
	end
	renderers[kind] = renderer
end
