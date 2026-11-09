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
		number = tonumber(head[6]), orders = json.array({}) }
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
		elseif f[1] == "order" then
			local sides = json.array({})
			for name in (f[4] or ""):gmatch("[^,]+") do
				sides[#sides + 1] = name
			end
			round.orders[#round.orders + 1] = { scenario = f[2], size = f[3], sides = sides }
		else
			results[#results + 1] = {
				scenario = f[1], size = f[2], impl = f[3], metric = f[4],
				luaMs = tonumber(f[5]), luaP95 = tonumber(f[6]), frameMs = tonumber(f[7]), frameP95 = tonumber(f[8]),
				kb = tonumber(f[9]), n = tonumber(f[10]), check = f[11] ~= "" and f[11] or nil,
				keptKb = tonumber(f[12]),
			}
		end
	end
	return round, results
end

-- The README ------------------------------------------------------------------------------------------------------

local LUA_FLOOR = 0.01 -- ms: below it a Lua time is timer noise, so it shows as "<0.01" and gives no factor

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

--- Rounds compare only when both ran clean builds on the same display.
local function Comparable(a, b)
	local function Clean(round)
		for _, build in pairs(round.builds or {}) do
			if build.dirty then
				return false
			end
		end
		return true
	end
	local sa, sb = a.round.settings or {}, b.round.settings or {}
	return Clean(a) and Clean(b) and sa.physical == sb.physical and sa.renderScale == sb.renderScale
end

--- Each row's idle: the idle series of its block (the nearest one before it), as { median, noise }; noise is the
--- idle frames' p95 above their median.
local function Idles(results)
	local idle, out = { frameMs = 0, frameP95 = 0 }, {}
	for i, r in ipairs(results) do
		if r.impl == "-" then
			idle = r
		end
		out[i] = { median = idle.frameMs or 0, noise = math.max((idle.frameP95 or 0) - (idle.frameMs or 0), 0) }
	end
	return out
end

local function Lua(ms)
	if not ms then
		return ""
	end
	if ms < LUA_FLOOR then
		return "<" .. LUA_FLOOR
	end
	return string.format("%.3f", ms)
end

--- A frame time above its block's idle, or "≈ idle" within the idle frames' noise.
local function Frame(ms, idle)
	if not ms then
		return "", nil
	end
	local above = ms - idle.median
	if above <= idle.noise then
		return "≈ idle", nil
	end
	return string.format("%.3f", above), above
end

local function Factor(a, b, floor)
	if not (a and b) or b < floor then
		return ""
	end
	return string.format("%.1f", a / b)
end

local function Readme(round, newest)
	local rounds = Rounds()
	local previous
	for i = #rounds, 1, -1 do
		if rounds[i] ~= newest then
			local candidate = json.decode(Read(RESULTS .. "/" .. rounds[i]))
			if Comparable(round, candidate) then
				previous = candidate
				break
			end
		end
	end
	local idles = Idles(round.results)
	local before = {}
	if previous then
		local oldIdles = Idles(previous.results)
		for i, r in ipairs(previous.results) do
			before[r.impl .. "|" .. Key(r)] = { r = r, idle = oldIdles[i] }
		end
	end
	local others = { baseline = {}, typical = {}, ["framework-engine"] = {} }
	for i, r in ipairs(round.results) do
		if others[r.impl] then
			others[r.impl][Key(r)] = { r = r, idle = idles[i] }
		end
	end

	local out = {}
	local function add(line)
		out[#out + 1] = line
	end
	add("# Bench")
	add("")
	add("Generated by `scripts/bench_save.lua` from the newest round in `results/` (one file per round: the history).")
	add("Each scenario (`addons/OrdaenBench`) on the framework, by hand at its best (`baseline/`) and, where it differs,")
	add("as a typical addon writes it (`typical/`); with drawing, also on the framework with a stub backend that draws")
	add("nothing (the engine alone). Medians in ms, per call or per frame as the metric says.")
	add("")
	add("- **Lua:** the call's own time (debugprofilestop). Below " .. LUA_FLOOR .. " ms it is timer noise: no factor.")
	add("- **Frame:** from the call's start to the next frame, the work WoW defers to drawing included, minus the")
	add("  block's idle frame (each block starts with one). \"≈ idle\" is within the idle frames' own spread (p95")
	add("  above median): no factor.")
	add("- **Engine / backend:** the framework row's Lua time on the stub backend (the engine alone) and the rest")
	add("  (the drawing backend's share).")
	add("- **Net KB:** Lua heap growth per call with the collector stopped (it can be negative: a call that frees).")
	add("  **Kept KB** (make rows): what stays after a full collection. The Lua heap only: WoW frames' own memory is")
	add("  invisible to every side.")
	add("- **Change:** against the newest earlier round with clean builds on the same display.")
	add("")
	add("Reading it:")
	add("")
	add("- **One /obench:** a cold block first (the large grid opened on every side while the session is fresh), then")
	add("  the whole plan untracked (one-time costs: fonts, first textures, Blizzard code), then the whole plan measured.")
	add("- **make (pool warm):** the framework opened again after closing, its frames back from the pools; hand code")
	add("  makes new frames every time. **make (cold)** compares the first opening on every side.")
	add("- **grid close and open+close:** the framework unmounts and mounts again (the MVP has no hidden attribute);")
	add("  hand code hides and shows (\"By hand only\" below). Not the same operation: no factor.")
	add("- **grid steady:** the grid on screen with nothing changing. \"≈ idle\" means the CPU pays nothing for")
	add("  drawing it at this frame rate (the GPU may); not that drawing is free on every machine.")
	add("- **deep, value through 100 levels:** the framework hands the value down as an attribute through every level;")
	add("  hand code sets the one text directly. Intended: it shows what passing attributes costs.")
	add("")
	add(string.format("Newest round: %s (round %s), client %s, %s fps; Core %s, Bench %s.", round.round.date,
		tostring(round.round.number), round.round.client, tostring(round.round.fps),
		round.builds.OrdaenCore and (round.builds.OrdaenCore.commit .. (round.builds.OrdaenCore.dirty and " (dirty)" or "")) or "?",
		round.builds.OrdaenBench and (round.builds.OrdaenBench.commit .. (round.builds.OrdaenBench.dirty and " (dirty)" or "")) or "?"))
	local settings = round.round.settings
	if settings then
		local capped = settings.useMaxFPS == "1" or settings.vsync == "1"
		add(string.format("Run with: collector %s, useMaxFPS %s (maxFPS %s), vsync %s, screen %s (UI %s), render scale %s.%s",
			settings.collector or "?", settings.useMaxFPS or "?", settings.maxFPS or "?", settings.vsync or "?",
			settings.physical or "?", settings.ui or "?", settings.renderScale or "?",
			capped and " **Frame times are capped (maxFPS or vsync): don't trust them.**" or ""))
	end
	local addons = round.round.addons
	if addons then
		add(string.format("Loaded addons (%d): %s.", #addons, table.concat(addons, ", ")))
	end
	if previous then
		add(string.format("Compared with: %s (Core %s).", previous.round.date,
			previous.builds.OrdaenCore and previous.builds.OrdaenCore.commit or "?"))
	else
		add("Compared with: no earlier round with clean builds on the same display.")
	end
	add("")
	add("| Scenario | Size | Metric | Framework Lua | Engine | Backend | Frame | Best Lua | Frame | Typical Lua "
		.. "| Frame | × best Lua | × best frame | × typical Lua | Net KB | Kept KB | Change Lua | Change frame | Check |")
	add("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: "
		.. "| ---: | ---: | --- |")
	local failed = 0
	for i, r in ipairs(round.results) do
		if r.check and r.check:match("^FAIL") then
			failed = failed + 1
		end
		if r.impl:match("^framework") and r.impl ~= "framework-engine" then
			local key = Key(r)
			local best, typical, engine = others.baseline[key], others.typical[key], others["framework-engine"][key]
			local old = before[r.impl .. "|" .. key]
			local metric = r.impl == "framework" and r.metric or (r.metric .. " (" .. r.impl .. ")")
			local frameText, frame = Frame(r.frameMs, idles[i])
			local bestFrameText, bestFrame = "", nil
			if best then
				bestFrameText, bestFrame = Frame(best.r.frameMs, best.idle)
			end
			local typicalFrameText = typical and Frame(typical.r.frameMs, typical.idle) or ""
			local engineLua = engine and engine.r.luaMs
			local backendLua = engineLua and math.max(r.luaMs - engineLua, 0)
			local changeLua, changeFrame = "", ""
			if old and old.r.luaMs and old.r.luaMs >= LUA_FLOOR then
				changeLua = string.format("%+.0f%%", (r.luaMs - old.r.luaMs) / old.r.luaMs * 100)
				local _, oldFrame = Frame(old.r.frameMs, old.idle)
				if frame and oldFrame then
					changeFrame = string.format("%+.0f%%", (frame - oldFrame) / oldFrame * 100)
				end
			end
			add(string.format("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %.1f | %s | %s | %s | %s |",
				r.scenario, r.size, metric, Lua(r.luaMs), Lua(engineLua), Lua(backendLua), frameText,
				best and Lua(best.r.luaMs) or "", bestFrameText, typical and Lua(typical.r.luaMs) or "", typicalFrameText,
				Factor(r.luaMs, best and best.r.luaMs, LUA_FLOOR), Factor(frame, bestFrame, 0.001),
				Factor(r.luaMs, typical and typical.r.luaMs, LUA_FLOOR), r.kb or 0,
				r.keptKb and string.format("%.0f", r.keptKb) or "", changeLua, changeFrame, r.check or ""))
		elseif r.check and r.check:match("^FAIL") then
			add(string.format("| %s | %s | %s (%s) | | | | | | | | | | | | | | | | %s |", r.scenario, r.size, r.metric,
				r.impl, r.check))
		end
	end
	add("")
	add("Failed checks: " .. failed .. ".")
	add("")

	add("## By hand only")
	add("")
	add("Hand-written rows with no framework row of the same name (hide and show against unmount and remount).")
	add("")
	add("| Scenario | Size | Metric | Side | Lua | Frame | Kept KB |")
	add("| --- | --- | --- | --- | ---: | ---: | ---: |")
	local framework = {}
	for _, r in ipairs(round.results) do
		if r.impl:match("^framework") then
			framework[Key(r)] = true
		end
	end
	for i, r in ipairs(round.results) do
		if (r.impl == "baseline" or r.impl == "typical") and not framework[Key(r)] then
			add(string.format("| %s | %s | %s | %s | %s | %s | %s |", r.scenario, r.size, r.metric, r.impl, Lua(r.luaMs),
				(Frame(r.frameMs, idles[i])), r.keptKb and string.format("%.0f", r.keptKb) or ""))
		end
	end
	add("")

	add("## Order of the sides")
	add("")
	add("Which side of each block ran first, second, ... in this round (it rotates with each round).")
	add("")
	for _, o in ipairs(round.round.orders or {}) do
		add(string.format("- %s %s: %s", o.scenario, o.size, table.concat(o.sides, ", ")))
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
		if name ~= "idle" then
			names[#names + 1] = name
		end
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
