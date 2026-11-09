-- Save the last OrdaenBench round (/obench in game, then /reload) to bench/results/<date>_<time>.json and rewrite
-- bench/README.md: the latest round, framework against hand-written code with the source size of each, and the
-- change against the round before. Run from the repo root: ordaen lua scripts/bench_save.lua [SavedVariables dir]
--
-- A round's file holds what the game recorded (bench/driver.lua's structured lines), the builds the game ran
-- (dist/<Addon>/build.json: commit, branch, uncommitted changes) and the size of each scenario's code on both sides
-- (code lines and characters without comments, blank lines or indentation). Rounds are never rewritten: the folder
-- is the history of improvements and regressions.
local scriptDir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local json = dofile(scriptDir .. "json.lua")
local fs = dofile(scriptDir .. "fs.lua")

local DEFAULT_WTF = "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account"
local BENCH = "addons/OrdaenBench"
local RESULTS = "bench/results"

local function Read(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

local function Write(path, text)
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
end

--- The newest OrdaenBench.lua among the accounts' SavedVariables.
local function FindSaved(dir)
	if dir then
		return dir:gsub("[/\\]+$", "") .. "/OrdaenBench.lua"
	end
	local best, bestTime
	local lfs = require("lfs")
	for _, account in ipairs(fs.List(DEFAULT_WTF)) do
		local path = DEFAULT_WTF .. "/" .. account .. "/SavedVariables/OrdaenBench.lua"
		local time = lfs.attributes(path, "modification")
		if time and (not bestTime or time > bestTime) then
			best, bestTime = path, time
		end
	end
	return best
end

local function Split(line)
	local fields = {}
	for field in (line .. "|"):gmatch("([^|]*)|") do
		fields[#fields + 1] = field
	end
	return fields
end

--- Code lines and characters of one Lua file: no comments, blank lines or indentation.
local function Size(path)
	local text = Read(path) or ""
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "") -- block comments
	local lines, chars = 0, 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local code = line:gsub("%-%-.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if code ~= "" then
			lines = lines + 1
			chars = chars + #code
		end
	end
	return lines, chars
end

--- A scenario's code: components/<name>*.lua on the framework, baseline/<name>.lua by hand at its best,
--- typical/<name>.lua as a typical addon writes it.
local function Source(scenario)
	local function Sum(files)
		local out = { files = json.array({}), lines = 0, chars = 0 }
		for _, path in ipairs(files) do
			local lines, chars = Size(path)
			out.lines, out.chars = out.lines + lines, out.chars + chars
			out.files[#out.files + 1] = path
		end
		return out
	end
	local framework = {}
	for _, name in ipairs(fs.List(BENCH .. "/components")) do
		if name:sub(1, #scenario) == scenario and name:match("%.lua$") and not name:match("%.test%.lua$") then
			framework[#framework + 1] = BENCH .. "/components/" .. name
		end
	end
	local function One(folder)
		local path = BENCH .. "/" .. folder .. "/" .. scenario .. ".lua"
		return Read(path) and { path } or {}
	end
	return { framework = Sum(framework), baseline = Sum(One("baseline")), typical = Sum(One("typical")) }
end

local function Build(addon)
	local text = Read("dist/" .. addon .. "/build.json")
	return text and json.decode(text) or nil
end

local function Load(path)
	local chunk = assert(loadfile(path))
	local env = {}
	setfenv(chunk, env)
	chunk()
	local db = env.OrdaenBenchDB
	local saved = db and db.module and db.module.results
	assert(saved and saved[1], "no round in " .. path .. ": run /obench, then /reload")
	return saved
end

local function Parse(lines)
	local head = Split(lines[1])
	assert(head[1] == "round", "the first line isn't a round header")
	local round = { date = head[2], client = head[3], fps = tonumber(head[4]), luaHeapKb = tonumber(head[5]),
		number = tonumber(head[6]) }
	local results = json.array({})
	for i = 2, #lines do
		local f = Split(lines[i])
		if f[1] == "settings" then
			round.settings = {}
			for j = 2, #f do
				local k, v = f[j]:match("^([^=]+)=(.*)$")
				if k then
					round.settings[k] = v
				end
			end
		elseif f[1] == "addons" then
			round.addons = json.array({})
			for name in (f[2] or ""):gmatch("[^,]+") do
				round.addons[#round.addons + 1] = name
			end
		else
			results[#results + 1] = {
			scenario = f[1], size = f[2], impl = f[3], metric = f[4],
			luaMs = tonumber(f[5]), luaP95 = tonumber(f[6]), frameMs = tonumber(f[7]), frameP95 = tonumber(f[8]),
			kb = tonumber(f[9]), n = tonumber(f[10]), check = f[11] ~= "" and f[11] or nil,
			}
		end
	end
	return round, results
end

-- The README ------------------------------------------------------------------------------------------------------

local function Key(r)
	return r.scenario .. "|" .. r.size .. "|" .. r.metric
end

local function Rounds()
	local list = {}
	for _, name in ipairs(fs.List(RESULTS)) do
		if name:match("%.json$") then
			list[#list + 1] = name
		end
	end
	table.sort(list) -- names are dates: oldest first
	return list
end

local function Ms(r, field)
	return r and r[field] and string.format("%.3f", r[field]) or ""
end

local function Factor(a, b, field)
	if not (a and b and a[field] and b[field] and b[field] > 0) then
		return ""
	end
	return string.format("%.1f", a[field] / b[field])
end

--- The frame with nothing to do: the mean of the round's idle series (start and end).
local function Idle(round)
	local sum, n = 0, 0
	for _, r in ipairs(round.results) do
		if r.scenario == "idle" and r.frameMs then
			sum, n = sum + r.frameMs, n + 1
		end
	end
	return n > 0 and sum / n or 0
end

--- A row's frame time above the idle frame.
local function AboveIdle(r, idle)
	if not (r and r.frameMs) then
		return nil
	end
	return math.max(r.frameMs - idle, 0)
end

local function Readme(round, newest)
	local rounds = Rounds()
	local previous
	for i = #rounds, 1, -1 do
		if rounds[i] ~= newest then
			previous = json.decode(Read(RESULTS .. "/" .. rounds[i]))
			break
		end
	end
	local before, sides = {}, { baseline = {}, typical = {} }
	if previous then
		for _, r in ipairs(previous.results) do
			before[r.impl .. "|" .. Key(r)] = r
		end
	end
	for _, r in ipairs(round.results) do
		if sides[r.impl] then
			sides[r.impl][Key(r)] = r
		end
	end
	local idle, oldIdle = Idle(round), previous and Idle(previous) or 0
	local out = {}
	local function add(line)
		out[#out + 1] = line
	end
	add("# Bench")
	add("")
	add("Generated by `scripts/bench_save.lua` from the newest round in `results/` (one file per round: the history).")
	add("Each scenario (`addons/OrdaenBench`) on the framework, by hand at its best (`baseline/`) and, where it differs,")
	add("as a typical addon writes it (`typical/`). Medians in ms, per call or per frame as the metric says:")
	add("")
	add("- **Lua:** the step's own time (debugprofilestop). It misses what WoW defers to drawing.")
	add("- **Frame:** from one frame to the next, the deferred work included, minus the idle frame (the `idle` rows:")
	add("  a frame with nothing to do, measured at the start and end of the round).")
	add("- **KB:** Lua heap growth per call, the garbage players pay for later.")
	add("- **Change:** the framework's Lua and frame medians against the round before.")
	add("")
	add("Reading it:")
	add("")
	add("- **grid close and open+close:** the framework unmounts and mounts again (the MVP has no hidden attribute);")
	add("  hand code hides and shows. Both are real costs, not the same operation, so they have no factor.")
	add("- **grid steady:** the grid on screen with nothing changing: what drawing it costs every frame.")
	add("- **make:** hand code always makes its frames new (one round per /reload); the framework's pools may already")
	add("  hold frames from an earlier scenario of the same round (the large grid reuses the small grid's).")
	add("- **deep, value through 100 levels:** the framework hands the value down as an attribute through every level;")
	add("  hand code sets the one text directly. Intended: it shows what passing attributes costs.")
	add("")
	add(string.format("Newest round: %s (round %s), client %s, %s fps, idle frame %.2f ms; Core %s.", round.round.date,
		tostring(round.round.number), round.round.client, tostring(round.round.fps), idle,
		round.builds.OrdaenCore and round.builds.OrdaenCore.commit or "?"))
	local settings = round.round.settings
	if settings then
		-- capped: the cap's toggle on (useMaxFPS; maxFPS keeps its value while it's off), or vsync
		local capped = settings.useMaxFPS == "1" or settings.vsync == "1"
		add(string.format("Run with: collector %s, useMaxFPS %s (maxFPS %s), vsync %s.%s", settings.collector or "?",
			settings.useMaxFPS or "?", settings.maxFPS or "?", settings.vsync or "?",
			capped and " **Frame times are capped (maxFPS or vsync): don't trust them.**" or ""))
	end
	local addons = round.round.addons
	if addons then
		add(string.format("Loaded addons (%d): %s.", #addons, table.concat(addons, ", ")))
	end
	if previous then
		add(string.format("Compared with: %s (Core %s).", previous.round.date,
			previous.builds.OrdaenCore and previous.builds.OrdaenCore.commit or "?"))
	end
	add("")
	add("| Scenario | Size | Metric | Framework Lua | Frame | Best Lua | Frame | Typical Lua | Frame "
		.. "| × best Lua | × best frame | × typical Lua | Framework KB | Change Lua | Change frame | Check |")
	add("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
	local failed = 0
	for _, r in ipairs(round.results) do
		if r.impl == "baseline" or r.impl == "typical" then
			if r.check and r.check:match("^FAIL") then
				failed = failed + 1
				add(string.format("| %s | %s | %s (%s) | | | | | | | | | | | | | %s |", r.scenario, r.size, r.metric, r.impl,
					r.check))
			end
		elseif r.impl:match("^framework") or r.scenario == "idle" then
			local key = Key(r)
			local best, typical, old = sides.baseline[key], sides.typical[key], before[r.impl .. "|" .. key]
			local metric = r.impl:match("^framework%-") and (r.metric .. " (" .. r.impl .. ")") or r.metric
			local frame = { frameMs = AboveIdle(r, idle) }
			local bestFrame, typicalFrame = { frameMs = AboveIdle(best, idle) }, { frameMs = AboveIdle(typical, idle) }
			if r.scenario == "idle" then
				frame = r
			end
			local function Change(new, was)
				return new and was and was > 0 and string.format("%+.0f%%", (new - was) / was * 100) or ""
			end
			if r.check and r.check:match("^FAIL") then
				failed = failed + 1
			end
			add(string.format("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %.1f | %s | %s | %s |",
				r.scenario, r.size, metric, Ms(r, "luaMs"), Ms(frame, "frameMs"), Ms(best, "luaMs"),
				Ms(bestFrame, "frameMs"), Ms(typical, "luaMs"), Ms(typicalFrame, "frameMs"), Factor(r, best, "luaMs"),
				Factor(frame, bestFrame, "frameMs"), Factor(r, typical, "luaMs"), r.kb or 0,
				Change(r.luaMs, old and old.luaMs),
				Change(frame.frameMs, old and AboveIdle(old, oldIdle)), r.check or ""))
		end
	end
	add("")
	add("Failed checks: " .. failed .. ".")
	add("")
	add("## By hand only")
	add("")
	add("Hand-written rows with no framework row of the same name (hide and show against unmount and remount).")
	add("")
	add("| Scenario | Size | Metric | Side | Lua | Frame |")
	add("| --- | --- | --- | --- | ---: | ---: |")
	local framework = {}
	for _, r in ipairs(round.results) do
		if r.impl:match("^framework") then
			framework[Key(r)] = true
		end
	end
	for _, r in ipairs(round.results) do
		if (r.impl == "baseline" or r.impl == "typical") and not framework[Key(r)] then
			add(string.format("| %s | %s | %s | %s | %s | %s |", r.scenario, r.size, r.metric, r.impl, Ms(r, "luaMs"),
				Ms({ frameMs = AboveIdle(r, idle) }, "frameMs")))
		end
	end
	add("")
	add("## Source size")
	add("")
	add("Code lines and characters, without comments, blank lines or indentation.")
	add("")
	add("| Scenario | Framework lines | Best lines | Typical lines | Framework chars | Best chars | Typical chars |")
	add("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
	local names = {}
	for name in pairs(round.source) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local s = round.source[name]
		local typical = s.typical or { lines = 0, chars = 0 }
		add(string.format("| %s | %d | %d | %s | %d | %d | %s |", name, s.framework.lines, s.baseline.lines,
			typical.lines > 0 and tostring(typical.lines) or "", s.framework.chars, s.baseline.chars,
			typical.chars > 0 and tostring(typical.chars) or ""))
	end
	add("")
	return table.concat(out, "\n")
end

-- Main -------------------------------------------------------------------------------------------------------------

local path = FindSaved(arg and arg[1])
assert(path, "no OrdaenBench.lua under " .. DEFAULT_WTF)
local round, results = Parse(Load(path))
local source = {}
for _, r in ipairs(results) do
	if not source[r.scenario] then
		source[r.scenario] = Source(r.scenario)
	end
end
local saved = {
	round = round,
	builds = { OrdaenCore = Build("OrdaenCore"), OrdaenBench = Build("OrdaenBench") },
	source = source,
	results = results,
}
fs.MakeDirs(RESULTS)
local name = round.date:gsub(" ", "_"):gsub(":", "") .. ".json"
local file = RESULTS .. "/" .. name
if Read(file) then
	print("already saved: " .. file)
else
	Write(file, json.encode(saved))
	print("saved: " .. file)
end
Write("bench/README.md", Readme(json.decode(Read(file)), name))
print("wrote bench/README.md")
