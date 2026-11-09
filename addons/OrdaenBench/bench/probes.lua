-- Probes: questions about plain WoW calls for the drawing backend's owner, answered with the bench's measuring
-- (garbage collection kept out, warm-up, medians), after the measured plan so they can't disturb it. Not results:
-- their lines go to OrdaenBenchDB's `probes` list and to the log as `probe|...`, never to the round. Each works on
-- N objects made once, untimed. Dev only: plain WoW calls.
local FONT = import("bench/font")

local N = 1000
local COUNT = 60 -- calls per series (the driver leaves its warm-up out)
local floor = math.floor

local Probes = {}

local function Holder(width, height)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(width, height)
	frame:SetPoint("CENTER")
	return frame
end

--- The probe steps: `measure` stores to the probes list; `bench` gives Show (for the node probe).
function Probes.Steps(measure, bench)
	local steps = {}
	local function add(step)
		steps[#steps + 1] = step
	end
	local function Series(probe, variant, metric, count, fn, options)
		add(measure:Series("probe", probe, variant, metric, count, fn, options))
	end
	local function Nothing() end

	Series("idle", "-", "nothing", COUNT, Nothing)

	-- 0. retention: instances a close leaves referenced. Each scene opened and closed twice with instance tracking
	-- on; after a full collection, what survives unmounted is held from somewhere (OrdaenCore's Bench.dev.lua)
	for _, scene in ipairs({ "grid-large", "reorder", "grow", "deep" }) do
		add(measure:Do(function()
			OrdaenCore._TrackInstances(true)
		end))
		for _ = 1, 2 do
			add(measure:Do(function()
				bench.Show(scene)
			end))
			add(measure:Do(function()
				bench.Show("none")
			end))
		end
		add(measure:Info("probe", "retention", scene, "after 2 opens and closes", function()
			local text = OrdaenCore._SurvivingInstances()
			OrdaenCore._TrackInstances(false)
			return text
		end))
	end

	-- 1. text-measure: N one-line font strings 36 wide, each set to a new number every call
	local texts = {}
	local value = 0
	add(measure:Do(function()
		local holder = Holder(400, 400)
		for i = 1, N do
			local text = holder:CreateFontString(nil, "OVERLAY", FONT)
			text:SetSize(36, 14)
			text:SetPoint("TOPLEFT", (i - 1) % 10 * 38, -floor((i - 1) / 10) % 25 * 15)
			texts[i] = text
		end
		texts.holder = holder
	end))
	local function Next(i)
		value = value + 1
		return (value * 7919 + i * 104729) % 100000 -- numbers of varying width
	end
	local MEASURE = {
		{ "a", "SetFormattedText only", function(t, v)
			t:SetFormattedText("%d", v)
		end },
		{ "b", "+ SetWidth(0), GetStringWidth, GetStringHeight, SetWidth(36)", function(t, v)
			t:SetFormattedText("%d", v)
			t:SetWidth(0)
			t:GetStringWidth()
			t:GetStringHeight()
			t:SetWidth(36)
		end },
		{ "c", "+ GetUnboundedStringWidth", function(t, v)
			t:SetFormattedText("%d", v)
			t:GetUnboundedStringWidth()
		end },
		{ "d", "+ GetUnboundedStringWidth + GetLineHeight", function(t, v)
			t:SetFormattedText("%d", v)
			t:GetUnboundedStringWidth()
			t:GetLineHeight()
		end },
		{ "e", "+ GetStringHeight only", function(t, v)
			t:SetFormattedText("%d", v)
			t:GetStringHeight()
		end },
	}
	for _, m in ipairs(MEASURE) do
		local variant, metric, op = m[1], m[2], m[3]
		Series("text-measure", variant, metric, COUNT, function()
			for i = 1, N do
				op(texts[i], Next(i))
			end
		end)
	end
	add(measure:Do(function()
		texts.holder:Hide()
	end))

	-- 2. font: N font strings sized per string, against one font object
	local fontStrings = { own = {}, object = {} }
	local function MakeFonts(kind)
		return function()
			local holder = Holder(400, 400)
			local list = fontStrings[kind]
			for i = 1, N do
				local text
				if kind == "own" then
					text = holder:CreateFontString(nil, "OVERLAY")
					text:SetFont(STANDARD_TEXT_FONT, 12, "")
				else
					text = holder:CreateFontString(nil, "OVERLAY", FONT)
				end
				text:SetPoint("TOPLEFT", (i - 1) % 10 * 38, -floor((i - 1) / 10) % 25 * 15)
				list[i] = text
			end
			list.holder = holder
		end
	end
	for _, kind in ipairs({ "own", "object" }) do
		local label = kind == "own" and "SetFont per string" or "SetFontObject (one CreateFont)"
		Series("font", kind, "make: " .. label, 1, MakeFonts(kind), { kept = true })
		Series("font", kind, "one text change each: " .. label, COUNT, function()
			local list = fontStrings[kind]
			for i = 1, N do
				list[i]:SetFormattedText("%d", Next(i))
			end
		end)
		add(measure:Do(function()
			fontStrings[kind].holder:Hide()
		end))
	end

	-- 3. attach: N pooled buttons moved between two parents each call
	local parents, buttons, levelled = {}, {}, {}
	add(measure:Do(function()
		parents[1], parents[2] = Holder(400, 400), Holder(400, 400)
		for i = 1, N do
			local button = CreateFrame("Button", nil, parents[1])
			button:SetSize(36, 36)
			button:SetPoint("TOPLEFT", 0, 0)
			buttons[i] = button
			local inheriting = CreateFrame("Button", nil, parents[1])
			inheriting:SetSize(36, 36)
			inheriting:SetPoint("TOPLEFT", 0, 0)
			if inheriting.SetUsingParentLevel then
				inheriting:SetUsingParentLevel(true)
			end
			levelled[i] = inheriting
		end
	end))
	local side = 1
	local ATTACH = {
		{ "a", "SetParent only", buttons, function(b, parent)
			b:SetParent(parent)
		end },
		{ "b", "+ SetFrameLevel(parent + 1)", buttons, function(b, parent)
			b:SetParent(parent)
			b:SetFrameLevel(parent:GetFrameLevel() + 1)
		end },
		{ "c", "+ ClearAllPoints + SetPoint", buttons, function(b, parent)
			b:SetParent(parent)
			b:SetFrameLevel(parent:GetFrameLevel() + 1)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		end },
		{ "d", "+ Show", buttons, function(b, parent)
			b:SetParent(parent)
			b:SetFrameLevel(parent:GetFrameLevel() + 1)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
			b:Show()
		end },
		{ "e", "SetUsingParentLevel(true) at creation, then SetParent only", levelled, function(b, parent)
			b:SetParent(parent)
		end },
	}
	for _, a in ipairs(ATTACH) do
		local variant, metric, list, op = a[1], a[2], a[3], a[4]
		Series("attach", variant, metric, COUNT, function()
			side = 3 - side
			local parent = parents[side]
			for i = 1, N do
				op(list[i], parent)
			end
		end)
	end
	add(measure:Do(function()
		parents[1]:Hide()
		parents[2]:Hide()
	end))

	-- 4. hide: N children under one parent: each child, against the parent
	local hideParent, hideChildren = nil, {}
	add(measure:Do(function()
		hideParent = Holder(400, 400)
		for i = 1, N do
			local child = CreateFrame("Frame", nil, hideParent)
			child:SetSize(36, 36)
			child:SetPoint("TOPLEFT", (i - 1) % 10 * 38, -floor((i - 1) / 10) % 10 * 38)
			local texture = child:CreateTexture(nil, "BACKGROUND")
			texture:SetAllPoints()
			texture:SetColorTexture(0.3, 0.3, 0.35, 1)
			hideChildren[i] = child
		end
	end))
	local function EachChild(method)
		return function()
			for i = 1, N do
				hideChildren[i][method](hideChildren[i])
			end
		end
	end
	Series("hide", "children", "Hide each child", COUNT, EachChild("Hide"), { prepare = EachChild("Show") })
	Series("hide", "children", "Show each child", COUNT, EachChild("Show"), { prepare = EachChild("Hide") })
	Series("hide", "parent", "Hide the parent", COUNT, function()
		hideParent:Hide()
	end, { prepare = function()
		hideParent:Show()
	end })
	Series("hide", "parent", "Show the parent", COUNT, function()
		hideParent:Show()
	end, { prepare = function()
		hideParent:Hide()
	end })
	add(measure:Do(function()
		hideParent:Hide()
	end))

	-- 5. frame-kind: making N of each kind (the cursor part needs a moving mouse: skipped)
	local KINDS = {
		{ "Frame", false }, { "Frame", true }, { "Button", false }, { "Button", true },
	}
	for _, k in ipairs(KINDS) do
		local kind, mouse = k[1], k[2]
		local variant = kind .. (mouse and "+mouse" or "")
		Series("frame-kind", variant, "make " .. N .. " " .. kind .. (mouse and " with EnableMouse(true)" or ""), 1,
			function()
				local holder = Holder(400, 400)
				for i = 1, N do
					local frame = CreateFrame(kind, nil, holder)
					frame:SetSize(36, 36)
					frame:SetPoint("TOPLEFT", (i - 1) % 10 * 38, -floor((i - 1) / 10) % 10 * 38)
					if mouse then
						frame:EnableMouse(true)
					end
				end
				holder:Hide()
			end, { kept = true })
	end

	-- 6. level-cascade: SetFrameLevel on a parent with 0, 10 and 100 children
	for _, children in ipairs({ 0, 10, 100 }) do
		local parent
		add(measure:Do(function()
			parent = Holder(100, 100)
			for _ = 1, children do
				CreateFrame("Frame", nil, parent)
			end
		end))
		Series("level-cascade", tostring(children), "SetFrameLevel x" .. N .. " on a parent with " .. children
			.. " children", COUNT, function()
			for i = 1, N do
				parent:SetFrameLevel(5 + i % 2)
			end
		end)
		add(measure:Do(function()
			parent:Hide()
		end))
	end

	-- 7. draw-layer: N frames each with a texture in one draw layer: Hide/Show it, or switch the layer off/on
	local layerFrames, layerTextures, layerHolder = {}, {}, nil
	add(measure:Do(function()
		layerHolder = Holder(400, 400)
		for i = 1, N do
			local frame = CreateFrame("Frame", nil, layerHolder)
			frame:SetSize(36, 36)
			frame:SetPoint("TOPLEFT", (i - 1) % 10 * 38, -floor((i - 1) / 10) % 10 * 38)
			local texture = frame:CreateTexture(nil, "ARTWORK")
			texture:SetAllPoints()
			texture:SetColorTexture(1, 1, 1, 0.2)
			layerFrames[i], layerTextures[i] = frame, texture
		end
	end))
	local shown = true
	Series("draw-layer", "texture", "Hide/Show each texture", COUNT, function()
		shown = not shown
		for i = 1, N do
			if shown then
				layerTextures[i]:Show()
			else
				layerTextures[i]:Hide()
			end
		end
	end)
	Series("draw-layer", "layer", "SetDrawLayerEnabled on each frame", COUNT, function()
		shown = not shown
		for i = 1, N do
			layerFrames[i]:SetDrawLayerEnabled("ARTWORK", shown)
		end
	end)
	add(measure:Do(function()
		layerHolder:Hide()
	end))

	-- 8. getcountinfo: one backend node's tables after the small grid is drawn (untimed)
	add(measure:Do(function()
		bench.Show("grid-small")
	end))
	for _, kind in ipairs({ "box", "text" }) do
		add(measure:Info("probe", "getcountinfo", kind, "table.getcountinfo of one " .. kind .. " node", function()
			local node = OrdaenCore._ScreenNode(kind)
			if not node then
				return "no " .. kind .. " node on screen"
			end
			local parts = {}
			local function Describe(name, t)
				local ok, a, b, c, d = pcall(table.getcountinfo, t)
				if ok then
					parts[#parts + 1] = string.format("%s=%s/%s/%s/%s", name, tostring(a), tostring(b), tostring(c),
						tostring(d))
				end
			end
			Describe("node", node)
			for key, v in pairs(node) do
				if type(v) == "table" and type(key) == "string" then
					Describe(key, v)
				end
			end
			return table.concat(parts, " ")
		end))
	end
	add(measure:Do(function()
		bench.Show("none")
	end))
	return steps
end

return Probes
