-- What a side shows, compared between sides: after a side's measured series, the bench takes a snapshot of its root
-- frame (untimed), and after the block every side's snapshot is compared with the hand-written baseline's. Both sides
-- ran the same seeded actions, so they must end on the same screen; a side that skips work or draws something else
-- fails here, whatever its time.
--
-- A snapshot lists every visible text (its text and where its glyphs sit: the font string's box moved by its
-- justification, so a cell-sized centred string and a natural-width one placed in the centre read the same) and,
-- where the scenario asks, every visible texture's rect. Positions are in screen pixels relative to the content's
-- top-left (the first text's, or the first texture's when there are no texts), so a side's own window padding
-- doesn't count. Dev only: it reads WoW frames directly.
local floor, sort, format, abs = math.floor, table.sort, string.format, math.abs

local Screen = {}

-- How far apart the same text or texture may sit on two sides: 2 screen pixels. The framework snaps every rect to a
-- whole pixel and rounds a centring offset, hand code keeps fractions: each is up to a pixel off the exact spot, and
-- positions are read relative to the first text, which carries its own pixel. A list that drifts further fails, and
-- uneven steps fail Screen.Even.
local _, physicalHeight = GetPhysicalScreenSize()
local TOLERANCE = 2 * UIParent:GetHeight() / physicalHeight

local H = { LEFT = 0, CENTER = 0.5, RIGHT = 1 }
local V = { TOP = 0, MIDDLE = 0.5, BOTTOM = 1 }

local function Collect(frame, out, textures)
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local region = regions[i]
		if region:IsVisible() then
			local kind = region:GetObjectType()
			local scale = region:GetEffectiveScale()
			local left, top = region:GetLeft(), region:GetTop()
			if left and top then
				if kind == "FontString" then
					local text = region:GetText()
					if text and text ~= "" then
						local w, h = region:GetWidth(), region:GetHeight()
						local sw, sh = region:GetStringWidth(), region:GetStringHeight()
						local x = left + (w - sw) * (H[region:GetJustifyH()] or 0)
						local y = top - (h - sh) * (V[region:GetJustifyV()] or 0)
						out[#out + 1] = { kind = "text", text = text, x = x * scale, y = y * scale,
							how = format("box %.1f,%.1f %.1fx%.1f, string %.1fx%.1f, %s %s, scale %.3f", left, top, w, h,
								sw, sh, tostring(region:GetJustifyH()), tostring(region:GetJustifyV()), scale) }
					end
				elseif kind == "Texture" and textures then
					out[#out + 1] = { kind = "texture", text = "", x = left * scale, y = top * scale,
						w = region:GetWidth() * scale, h = region:GetHeight() * scale }
				end
			end
		end
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		if children[i]:IsVisible() then
			Collect(children[i], out, textures)
		end
	end
end

local function Before(a, b)
	if a.kind ~= b.kind then
		return a.kind > b.kind -- texts first
	end
	local ay, by = floor(-a.y + 0.5), floor(-b.y + 0.5)
	if ay ~= by then
		return ay < by
	end
	local ax, bx = floor(a.x + 0.5), floor(b.x + 0.5)
	if ax ~= bx then
		return ax < bx
	end
	if a.text ~= b.text then
		return a.text < b.text
	end
	local aw, bw = floor((a.w or 0) + 0.5), floor((b.w or 0) + 0.5)
	if aw ~= bw then
		return aw < bw
	end
	return floor((a.h or 0) + 0.5) < floor((b.h or 0) + 0.5)
end

--- The snapshot of `root` (nil root: nothing shown). `textures`: include visible textures' rects.
---@param root table|nil
---@param textures boolean|nil
---@return table[]
function Screen.Of(root, textures)
	local out = {}
	if not root or not root:IsVisible() then
		return out
	end
	Collect(root, out, textures)
	local ox, oy
	for i = 1, #out do
		local r = out[i]
		if r.kind == "text" then
			ox, oy = math.min(ox or r.x, r.x), math.max(oy or r.y, r.y)
		end
	end
	if not ox then
		for i = 1, #out do
			ox, oy = math.min(ox or out[i].x, out[i].x), math.max(oy or out[i].y, out[i].y)
		end
	end
	for i = 1, #out do
		out[i].x, out[i].y = out[i].x - ox, out[i].y - oy
	end
	sort(out, Before)
	return out
end

local function Describe(r)
	if not r then
		return "nothing"
	end
	if r.kind == "text" then
		return format("%q at %.1f,%.1f (%s)", r.text, r.x, -r.y, r.how or "")
	end
	return format("texture %.1fx%.1f at %.1f,%.1f", r.w, r.h, r.x, -r.y)
end

local function Near(a, b)
	return a == nil and b == nil or a ~= nil and b ~= nil and abs(a - b) <= TOLERANCE
end

local function Only(list, kind)
	local out = {}
	for i = 1, #list do
		if list[i].kind == kind then
			out[#out + 1] = list[i]
		end
	end
	return out
end

-- The first difference between two lists of one kind, or nil.
local function FirstDifference(side, reference, kind)
	for i = 1, math.max(#side, #reference) do
		local a, b = side[i], reference[i]
		if not a or not b or a.text ~= b.text or not Near(a.x, b.x) or not Near(a.y, b.y) or not Near(a.w, b.w)
			or not Near(a.h, b.h) then
			return format("%d %ss, the baseline %d; #%d shows %s where the baseline shows %s", #side, kind,
				#reference, i, Describe(a), Describe(b))
		end
	end
end

local EVEN = 0.1 -- the most consecutive lines of a list may differ in distance

--- Whether a list's lines are evenly spaced: where every text sits in one column (a list), the distances between
--- consecutive lines may differ by at most EVEN (lines alternating 11 and 12 px apart fail, though each is within
--- the comparison's tolerance). Snapshots with texts in several columns pass.
---@param snapshot table[]
---@return boolean, string|nil
function Screen.Even(snapshot)
	local texts = Only(snapshot, "text")
	if #texts < 3 then
		return true
	end
	for i = 2, #texts do
		if abs(texts[i].x - texts[1].x) > 0.5 then
			return true
		end
	end
	local least, most = math.huge, -math.huge
	for i = 2, #texts do
		local d = texts[i - 1].y - texts[i].y
		least, most = math.min(least, d), math.max(most, d)
	end
	return most - least <= EVEN, format("lines %.2f to %.2f apart", least, most)
end

--- Whether `side` shows what `reference` does; else false and the first difference in its texts and the first in
--- its textures (both, so one run shows every kind of difference).
---@param side table[]
---@param reference table[]
---@return boolean, string|nil
function Screen.Same(side, reference)
	local texts = FirstDifference(Only(side, "text"), Only(reference, "text"), "text")
	local textures = FirstDifference(Only(side, "texture"), Only(reference, "texture"), "texture")
	if texts or textures then
		return false, (texts or "texts match") .. " // " .. (textures or "textures match")
	end
	return true
end

return Screen
