-- Button drawer, pure part (no WoW API at load time, so specs can load it): grid layout and
-- merging addon compartment entries.
local _, ns = ...

local function stripColors(text)
	if type(text) ~= "string" then
		return nil
	end
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function key(text)
	local plain = stripColors(text)
	return plain and plain:lower():gsub("%s+", "") or nil
end
ns.CompartmentKey = key

--- Offsets of `count` slots in a grid, from the drawer's anchor corner.
---@param count integer
---@param columns integer
---@param size number slot size in px
---@param gap number space between slots in px
---@param growLeft boolean columns go right-to-left
---@param growUp boolean rows go bottom-to-top
---@return table offsets list of {x, y}, number width, number height
function ns.DrawerGrid(count, columns, size, gap, growLeft, growUp)
	local offsets = {}
	local cols = math.max(1, math.min(columns, count))
	local rows = math.ceil(count / math.max(1, columns))
	for i = 1, count do
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		local x = col * (size + gap)
		local y = row * (size + gap)
		offsets[i] = { growLeft and -x or x, growUp and y or -y }
	end
	local width = count > 0 and cols * size + (cols - 1) * gap or 0
	local height = count > 0 and rows * size + (rows - 1) * gap or 0
	return offsets, width, height
end

--- Merge addon compartment entries into one list for the drawer.
---   toc      entries read from TOC metadata: {addon, title, ...}
---   runtime  AddonCompartmentFrame.registeredAddons infos: {text, ...}
---   shownIcons  set of CompartmentKey(name) for LibDBIcon buttons that are collected and shown
--- Runtime entries Blizzard created from a TOC (same title) are dropped in favor of the TOC entry,
--- and an entry whose addon already has a visible minimap button in the drawer is hidden.
---@return table list of {kind = "toc"|"runtime", entry = <original>}
function ns.MergeCompartmentEntries(toc, runtime, shownIcons)
	shownIcons = shownIcons or {}
	local out, titles = {}, {}
	for _, entry in ipairs(toc or {}) do
		titles[key(entry.title) or ""] = true
		if not shownIcons[key(entry.addon) or ""] and not shownIcons[key(entry.title) or ""] then
			out[#out + 1] = { kind = "toc", entry = entry }
		end
	end
	for _, info in ipairs(runtime or {}) do
		local k = key(info.text)
		if k and not titles[k] and not shownIcons[k] then
			out[#out + 1] = { kind = "runtime", entry = info }
		end
	end
	return out
end
