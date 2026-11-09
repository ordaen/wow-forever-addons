-- Save the last OrdaenBench round to bench/results/<date>_<time>.json, then rewrite bench/report.json (every round,
-- computed: tables, changes, improvements and regressions) and bench/README.md (the newest round). The round is the
-- newer of the last one sent over the strip (the companion's records, when the debug addon is on) and the last one in
-- the SavedVariables (written at a /reload). Run from the repo root: ordaen lua scripts/bench_save.lua
-- [SavedVariables dir] (a dir given: that SavedVariables only).
-- A round with a failed check is refused: it isn't saved, and the history keeps only rounds that measured working
-- code.
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

--- Code lines and characters of one Lua file: no comments, blank lines or indentation, and none of the code between
--- `-- bench: begin` and `-- bench: end` (what only the bench needs: its checks' hooks, the measured variants; not
--- what an addon would write).
local function Size(path)
	local text = Read(path) or ""
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "") -- block comments
	local lines, chars, bench = 0, 0, false
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local marker = line:match("^%s*%-%- bench: (%a+)%s*$")
		if marker then
			bench = marker == "begin"
		end
		local code = line:gsub("%-%-.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if code ~= "" and not bench then
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
	local chunk = path and loadfile(path)
	if not chunk then
		return nil
	end
	local env = {}
	setfenv(chunk, env)
	chunk()
	local db = env.OrdaenBenchDB
	local saved = db and db.module and db.module.results
	return saved and saved[1] and saved or nil
end

--- The newest complete run the bench sent over the strip (module.lua: the dev addon's record channel, filed by the
--- companion as %LOCALAPPDATA%/OrdaenCompanion/records/<date>.jsonl, domain "bench", in parts): its lines, or nil.
local function LoadRecords()
	local base = os.getenv("LOCALAPPDATA")
	if not base then
		return nil
	end
	local dir = base:gsub("\\", "/") .. "/OrdaenCompanion/records"
	local files = {}
	for _, name in ipairs(fs.List(dir)) do
		if name:match("%.jsonl$") then
			files[#files + 1] = name
		end
	end
	table.sort(files)
	local runs, newest = {}, nil
	for _, name in ipairs(files) do
		for line in (Read(dir .. "/" .. name) or ""):gmatch("[^\n]+") do
			if line:find('"domain":"bench"', 1, true) then
				local ok, record = pcall(json.decode, line)
				local data = ok and record and record.data
				if data and data.run and data.part and data.parts and data.lines then
					local run = runs[data.run]
					if not run then
						run = { parts = data.parts, got = 0, chunks = {} }
						runs[data.run] = run
					end
					if not run.chunks[data.part] then
						run.chunks[data.part] = data.lines
						run.got = run.got + 1
					end
					if run.got == run.parts and (not newest or data.run > newest) then
						newest = data.run -- "round|<date time>|...|<session run>": newer sorts later
					end
				end
			end
		end
	end
	if not newest then
		return nil
	end
	local lines, run = {}, runs[newest]
	for part = 1, run.parts do
		for _, l in ipairs(run.chunks[part]) do
			lines[#lines + 1] = l
		end
	end
	return lines
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
		elseif f[1] == "build" then
			round.build = {}
			for j = 2, #f do
				local k, v = f[j]:match("^([^=]+)=(.*)$")
				if k then
					round.build[k] = v
				end
			end
		elseif f[1] == "gc" then
			-- a series whose frames held a collection step outside our code (bench/driver.lua)
			round.gc = round.gc or json.array({})
			round.gc[#round.gc + 1] = { scenario = f[2], size = f[3], impl = f[4], metric = f[5], frames = tonumber(f[6]) }
		elseif f[1] == "mode" then
			round.mode = f[2]
		elseif f[1] == "session" then
			round.sessionRun = tonumber(f[2]) -- 1: the session's first run, with the cold block
		elseif f[1] == "errors" then
			round.errors = { count = tonumber(f[2]) or 0, first = f[3] or "" }
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

-- The report ------------------------------------------------------------------------------------------------------
-- Each round becomes one entry of bench/report.json: its header, its tables as display cells, and its changes against
-- the newest earlier comparable round, sorted into improvements and regressions. bench/README.md (the newest round)
-- and the design site's bench page (every round) both render these entries, so neither formats a number itself.

local LUA_FLOOR = 0.01 -- ms: below it a Lua time is timer noise: shown as "<0.01", no factor, no change
local CHANGE = 0.10 -- a change smaller than 10% is neither an improvement nor a regression

local COLUMNS = {
	"Scenario", "Size", "Metric", "Framework Lua", "Engine", "Backend", "Frame", "Best Lua", "Frame", "Typical Lua",
	"Frame", "× best Lua", "× best frame", "× typical Lua", "Net", "Engine net", "Kept",
	"Engine kept", "Change Lua", "Change frame", "Check",
}
local HAND_COLUMNS = { "Scenario", "Size", "Metric", "Side", "Lua", "Frame", "Kept" }
local SOURCE_COLUMNS = { "Scenario", "Framework lines", "Best lines", "Typical lines", "Framework chars", "Best chars",
	"Typical chars" }

local NOTES = {
	"**Lua:** the call's own time (debugprofilestop). Below " .. LUA_FLOOR .. " ms it is timer noise: no factor.",
	"**Frame:** from the call's start to the next frame, the work WoW defers to drawing included, minus the block's"
		.. " idle frame (each block starts with one). \"≈ idle\" is within the idle frames' own spread (p95 above"
		.. " median): no factor.",
	"**Engine / backend:** the framework row's Lua time on the stub backend (the engine alone) and the rest (the"
		.. " drawing backend's share). Lua only: the stub draws nothing, so its frame times mean nothing. The stub's"
		.. " empty calls (about 0.1 ms per 1000) count as engine time, so the backend's share reads slightly low.",
	"**Net KB:** Lua heap growth per call (negative: a call that frees, such as a table shrinking). No Lua time"
		.. " holds collector work: the collector is stopped right before every timed call. Frame time can, where WoW"
		.. " stepped the collector between frames: those frame values carry ᵍ, and the round lists in how many of the"
		.. " series' frames (a few: the median likely holds, the p95 likely doesn't). What collecting a scenario's"
		.. " garbage costs is a bench of its own. **Kept KB** (make"
		.. " rows): what stays after a full collection. The Lua heap only: WoW frames' own memory is invisible to every"
		.. " side. **Engine net KB / Engine kept KB:** the same on the stub backend (the engine alone, plus the"
		.. " stub's bookkeeping); the rest is the drawing backend's.",
	"**¹** a single sample (a first opening, a hand make): its frame time is one frame's, not a median.",
	"**Built as players run it:** every round is on the bench profile (release stripping, the bench's dev hooks kept);"
		.. " bench_save refuses any other. A round run with the debug addon loaded (started by the companion, the addon"
		.. " quiet while it ran) is marked so and compared only with rounds marked alike.",
	"**Engine / backend, read with care:** the stub run touches less memory, so the engine runs with warmer caches"
		.. " there and the backend's share reads slightly high. Hand-written drawing leaves its text layout to WoW's"
		.. " drawing, so compare the backend with best's frame column, not its Lua column.",
	"**Change:** against the newest earlier comparable round (clean builds), on the rows both ran. Only within one"
		.. " plan shape (the same series with the same calls: what runs before a row is part of its conditions) does a"
		.. " change count as an improvement or a regression: a change of " .. CHANGE * 100 .. "% or more beyond the noise (the row's own spread, p95"
		.. " above median, in either round; for frame also the idle spread); single samples (¹) and frame values with"
		.. " collector work (ᵍ) in either round never count. Same"
		.. " graphics quality and spot in the world (zone and subzone) only; stand in the same place facing the"
		.. " same way, since the world drawn is in every frame time.",
}
local READING = {
	"**One /obench:** a cold block first (the large grid's first open on every side while the session is fresh), then"
		.. " the whole plan measured; each series' first calls stay out of its numbers. `/obench variants` adds the"
		.. " framework's variants.",
	"**open, close, first open:** each side its own way: the framework mounts from its pools and unmounts; hand code"
		.. " shows and hides the frames it made once, or rebuilds and drops the state it has instead of frames. **first"
		.. " open** is every side's first opening in a fresh session.",
	"**framework-naive** (variants rounds): grid and ticker written as code reads without the build's lifting and"
		.. " hoisting: new tables and a new slot function every call. Its rows include lost skipping (a new slot function"
		.. " re-renders the child), not only allocation.",
	"**chain, diamond, cascade:** there for their checks (each watch runs once per change, no stale reads): a few"
		.. " calls, not a timing series.",
	"**grid steady:** the grid on screen with nothing changing. \"≈ idle\" means drawing it adds nothing to the main"
		.. " thread's frame (what an addon costs players' frames); WoW's render threads can still do work their slack"
		.. " hides, so not that drawing is free.",
	"**Same as baseline:** after each block, what every side ended on (its texts and where their glyphs sit; the"
		.. " textures' rects where the scenario draws shapes; a checksum of every watch's result where nothing is"
		.. " drawn) is compared with the baseline's. Both ran the same seeded actions, so a side that skipped work or"
		.. " drew something else fails, whatever its time.",
	"**deep, value through 100 levels:** the framework hands the value down as an attribute through every level;"
		.. " hand code sets the one text directly. Intended: it shows what passing attributes costs.",
	"**rows, filter, tooltip, sections:** the framework releases the nodes of what goes away and takes them (from its"
		.. " pools) for what comes back; hand code hides and shows frames it keeps. That difference is in their rows.",
	"**hover:** the bench calls the cells' frames' OnLeave and OnEnter scripts; WoW finding the frame under the cursor"
		.. " (hit testing) is the same on every side and isn't measured. No engine side: the stub draws no frames.",
	"**scheduler:** two ways to start the engine's flush, 1000 minimal schedulers each (a row's ms is µs per"
		.. " scheduler). Framework column: the engine's way, the OnUpdate attached on a frame's first write and removed"
		.. " by the flush. Best column: the proposed way, the OnUpdate always attached and returning when nothing is"
		.. " pending. Writes are in the Lua column; the OnUpdates (attach's removal, always's call every frame) only"
		.. " in the frame column.",
}

local function Key(r)
	return r.scenario .. "|" .. r.size .. "|" .. r.metric
end

local function RoundFiles()
	local list = {}
	for _, name in ipairs(fs.List(RESULTS)) do
		if name:match("%.json$") then
			list[#list + 1] = name
		end
	end
	table.sort(list) -- names are dates: oldest first
	return list
end

local function Clean(saved)
	for _, build in pairs(saved.builds or {}) do
		if build.dirty then
			return false
		end
	end
	return true
end

-- A round's plan shape: every series it ran (scenario, size, side, task) with its number of calls, in order. What runs
-- before a row (other scenarios' frames, pools, hidden WoW objects) is part of its conditions, so rounds compare only
-- within one shape: a change of the bench never reads as a change of the framework.
local function Shape(saved)
	local list = {}
	for _, r in ipairs(saved.results) do
		-- a check alone (no time, no memory) runs outside the measured series, so it doesn't change their conditions
		if not (r.luaMs == 0 and r.frameMs == 0 and (r.kb or 0) == 0 and r.check) then
			list[#list + 1] = r.scenario .. "|" .. r.size .. "|" .. r.impl .. "|" .. r.metric .. "|" .. tostring(r.n)
		end
	end
	return table.concat(list, "\n")
end

--- Rounds compare only when both ran clean builds of the same plan shape, at the same graphics settings and spot,
--- both with the debug addon or both without (every round runs at the same resolution and render scale, so those
--- aren't recorded).
local function Comparable(a, b)
	local ba, bb = a.round.build or {}, b.round.build or {}
	return Clean(a) and Clean(b) and ba.graphics ~= nil and ba.graphics == bb.graphics
		and ba.zone == bb.zone and ba.subzone == bb.subzone and (a.round.debug or false) == (b.round.debug or false)
end

--- Each row's idle: its block's idle series (the nearest before it), as { median, noise }.
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
		return "<" .. LUA_FLOOR .. " ms"
	end
	return string.format("%.2f ms", ms)
end

--- Lua heap KB as people read it: MB from 1 MB, else KB; two decimals, its unit.
local function Memory(kb)
	if not kb then
		return ""
	end
	if math.abs(kb) >= 1024 then
		return string.format("%.2f MB", kb / 1024)
	end
	return string.format("%.2f KB", kb)
end

--- A frame time above its block's idle (text, number), or "≈ idle" within the idle frames' spread (number nil).
local function Frame(ms, idle)
	if not ms then
		return "", nil
	end
	local above = ms - idle.median
	if above <= idle.noise then
		return "≈ idle", nil
	end
	return string.format("%.2f ms", above), above
end

local function Factor(a, b, floor)
	if not (a and b) or b < floor then
		return ""
	end
	return string.format("%.1f×", a / b)
end

local function Percent(new, old)
	return string.format("%+.0f%%", (new - old) / old * 100)
end

local function Commit(build)
	if not build then
		return "?"
	end
	return build.commit .. (build.dirty and " (dirty)" or "")
end

--- One round's entry: header lines, tables of display cells, and changes against `previous` (or nil).
local function Model(id, saved, previous)
	local round, results = saved.round, saved.results
	local idles = Idles(results)
	local entry = {
		id = id, date = round.date, number = round.number, clean = Clean(saved),
		header = json.array({}), notes = NOTES, reading = READING,
		columns = COLUMNS, rows = json.array({}),
		hand = { columns = HAND_COLUMNS, rows = json.array({}) },
		orders = json.array({}),
		source = { columns = SOURCE_COLUMNS, rows = json.array({}) },
		improvements = json.array({}), regressions = json.array({}), failed = 0,
		-- the series whose measured frames held a collection step WoW ran between frames (bench/driver.lua)
		gc = json.array({}),
	}
	local gcSeries, oldGc = {}, {}
	for _, g in ipairs(previous and previous.saved.round.gc or {}) do
		oldGc[g.impl .. "|" .. g.scenario .. "|" .. g.size .. "|" .. g.metric] = true
	end
	local measured = {}
	for _, r in ipairs(results) do
		measured[r.impl .. "|" .. Key(r)] = r.n
	end
	for _, g in ipairs(round.gc or {}) do
		local series = g.impl .. "|" .. g.scenario .. "|" .. g.size .. "|" .. g.metric
		gcSeries[series] = g.frames
		entry.gc[#entry.gc + 1] = string.format("%s %s %s (%s): the collector stepped in %d of %s measured frame%s",
			g.scenario, g.size, g.metric, g.impl, g.frames, tostring(measured[series] or "?"),
			measured[series] == 1 and "" or "s")
	end
	local function head(line)
		entry.header[#entry.header + 1] = line
	end
	head(string.format("Round %s, %s; client %s, %s fps; Core %s, Bench %s.", tostring(round.number), round.date,
		tostring(round.client), tostring(round.fps), Commit(saved.builds.OrdaenCore), Commit(saved.builds.OrdaenBench)))
	local settings = round.settings
	if settings then
		local capped = settings.useMaxFPS == "1" or settings.vsync == "1"
		head(string.format("Run with: collector %s, useMaxFPS %s (maxFPS %s), vsync %s.%s",
			settings.collector or "?", settings.useMaxFPS or "?", settings.maxFPS or "?", settings.vsync or "?",
			capped and " **Frame times are capped (maxFPS or vsync): don't trust them.**" or ""))
	end
	local build = round.build
	if build then
		-- the graphics settings in short: how many are 0 (off or lowest), and the others by name; rounds compare on
		-- the full list
		local zero, others = 0, {}
		for name, value in (build.graphics or ""):gmatch("([^:,]+):([^,]*)") do
			if value == "0" then
				zero = zero + 1
			else
				others[#others + 1] = name:gsub("^graphics", "") .. " " .. value
			end
		end
		local graphics = build.graphics and (zero .. " settings at 0" .. (#others > 0 and (", " .. table.concat(others, ", "))
			or "")) or build.graphicsQuality or "?"
		head(string.format("Built: Core %s, Bench %s (profiles). Where: %s%s. Graphics: %s.", build.core or "?",
			build.bench or "?", build.zone or "?", (build.subzone or "") ~= "" and (", " .. build.subzone) or "", graphics))
	end
	if round.addons then
		head(string.format("Loaded addons (%d): %s.", #round.addons, table.concat(round.addons, ", ")))
	end
	if round.debug then
		head("**Debug addon loaded** (the companion started the round): compared only with rounds run the same way.")
	end
	if #entry.gc > 0 then
		head("Frame values marked ᵍ hold collector work WoW ran between frames: " .. table.concat(entry.gc, "; ") .. ".")
	end
	if previous then
		entry.comparedWith = previous.id
		head(string.format("Compared with: round %s, %s (Core %s)%s", tostring(previous.saved.round.number),
			previous.saved.round.date, Commit(previous.saved.builds.OrdaenCore), previous.judged and "."
				or "; another plan shape: the rows both ran are compared, but no change counts as an improvement or a"
				.. " regression (what ran before a row differs)."))
	else
		head("Compared with: no earlier comparable round.")
	end

	local before = {}
	if previous then
		local oldIdles = Idles(previous.saved.results)
		for i, r in ipairs(previous.saved.results) do
			before[r.impl .. "|" .. Key(r)] = { r = r, idle = oldIdles[i] }
		end
	end
	local others = { baseline = {}, typical = {}, ["framework-engine"] = {} }
	for i, r in ipairs(results) do
		if others[r.impl] then
			others[r.impl][Key(r)] = { r = r, idle = idles[i] }
		end
	end

	for i, r in ipairs(results) do
		local failed = r.check and r.check:match("^FAIL") and true or false
		if failed then
			entry.failed = entry.failed + 1
		end
		if r.impl:match("^framework") and r.impl ~= "framework-engine" then
			local key = Key(r)
			local best, typical = others.baseline[key], others.typical[key]
			-- the stub runs the plain framework side only: its engine time is no other variant's
			local engine = r.impl == "framework" and others["framework-engine"][key] or nil
			local old = before[r.impl .. "|" .. key]
			local metric = r.impl == "framework" and r.metric or (r.metric .. " (" .. r.impl .. ")")
			if r.n == 1 then
				metric = metric .. " ¹"
			end
			local frameText, frame = Frame(r.frameMs, idles[i])
			if gcSeries[r.impl .. "|" .. key] then
				frameText = frameText .. " ᵍ"
			end
			local bestFrameText, bestFrame = "", nil
			if best then
				bestFrameText, bestFrame = Frame(best.r.frameMs, best.idle)
			end
			local typicalFrameText, typicalFrame = "", nil
			if typical then
				typicalFrameText, typicalFrame = Frame(typical.r.frameMs, typical.idle)
			end
			local engineLua = engine and engine.r.luaMs
			local backendLua = engineLua and math.max(r.luaMs - engineLua, 0)
			local changeLua, changeFrame, verdict = "", "", nil
			-- a single sample (¹) has no spread to tell a change from noise: shown, never an improvement or regression
			if old and r.n > 1 and (old.r.n or 0) > 1 then
				local judged = previous.judged
				if old.r.luaMs and old.r.luaMs >= LUA_FLOOR and r.luaMs >= LUA_FLOOR then
					changeLua = Percent(r.luaMs, old.r.luaMs)
					local ratio = (r.luaMs - old.r.luaMs) / old.r.luaMs
					-- beyond the row's own spread (p95 above median) in either round, as frame changes are beyond
					-- the idle spread: same code measured twice moves within it
					local spread = math.max((r.luaP95 or r.luaMs) - r.luaMs, (old.r.luaP95 or old.r.luaMs) - old.r.luaMs)
					local beyond = math.abs(r.luaMs - old.r.luaMs) > spread
					if judged and beyond and ratio <= -CHANGE then
						verdict = "improvement"
					elseif judged and beyond and ratio >= CHANGE then
						verdict = "regression"
					end
				end
				local _, oldFrame = Frame(old.r.frameMs, old.idle)
				local collected = gcSeries[r.impl .. "|" .. key] or oldGc[r.impl .. "|" .. key]
				if frame and oldFrame and not collected then
					changeFrame = Percent(frame, oldFrame)
					local ratio = (frame - oldFrame) / oldFrame
					-- beyond the idle frames' spread and the row's own frame spread (p95 above median) in either round
					local spread = math.max(idles[i].noise, (r.frameP95 or r.frameMs) - r.frameMs,
						(old.r.frameP95 or old.r.frameMs) - old.r.frameMs)
					local beyond = math.abs(frame - oldFrame) > spread
					if judged and beyond and ratio <= -CHANGE and verdict ~= "regression" then
						verdict = verdict or "improvement"
					elseif judged and beyond and ratio >= CHANGE then
						verdict = "regression"
					end
				end
			end
			local row = {
				scenario = r.scenario, size = r.size, metric = metric, failed = failed, verdict = verdict,
				-- a check alone (no time, no memory: "same as baseline", "stub: every node back"): the page lists these
				-- apart from the measurements
				checkOnly = r.luaMs == 0 and r.frameMs == 0 and (r.kb or 0) == 0 and r.check ~= nil or nil,
				check = r.check,
				-- a task (framework against hand code, black box): the plain framework on a row a hand side shares;
				-- every framework row is also compared with the previous round (framework against itself)
				task = r.impl == "framework" and (best ~= nil or typical ~= nil) or nil,
				previous = old and {
					lua = Lua(old.r.luaMs), frame = (Frame(old.r.frameMs, old.idle)), memory = Memory(old.r.kb),
					kept = Memory(old.r.keptKb),
				} or nil,
				-- each measure's values per side, formatted: the page shows one measure at a time, the sides side by side
				values = {
					lua = { ours = Lua(r.luaMs), engine = Lua(engineLua), backend = Lua(backendLua),
						best = best and Lua(best.r.luaMs) or "", typical = typical and Lua(typical.r.luaMs) or "",
						xBest = Factor(r.luaMs, best and best.r.luaMs, LUA_FLOOR),
						xTypical = Factor(r.luaMs, typical and typical.r.luaMs, LUA_FLOOR), change = changeLua },
					frame = { ours = frameText, best = bestFrameText, typical = typicalFrameText,
						xBest = Factor(frame, bestFrame, 0.001), xTypical = Factor(frame, typicalFrame, 0.001),
						change = changeFrame },
					memory = { ours = Memory(r.kb), engine = engine and Memory(engine.r.kb) or "",
						best = best and Memory(best.r.kb) or "", typical = typical and Memory(typical.r.kb) or "",
						kept = Memory(r.keptKb), engineKept = engine and Memory(engine.r.keptKb) or "",
						bestKept = best and Memory(best.r.keptKb) or "", typicalKept = typical and Memory(typical.r.keptKb) or "" },
				},
				cells = {
					r.scenario, r.size, metric, Lua(r.luaMs), Lua(engineLua), Lua(backendLua), frameText,
					best and Lua(best.r.luaMs) or "", bestFrameText, typical and Lua(typical.r.luaMs) or "",
					typicalFrameText, Factor(r.luaMs, best and best.r.luaMs, LUA_FLOOR), Factor(frame, bestFrame, 0.001),
					Factor(r.luaMs, typical and typical.r.luaMs, LUA_FLOOR), Memory(r.kb or 0),
					engine and Memory(engine.r.kb or 0) or "",
					Memory(r.keptKb),
					engine and Memory(engine.r.keptKb) or "", changeLua, changeFrame, r.check or "",
				},
			}
			if row.checkOnly then
				-- a check measures nothing: no measure values, no cells but its name and its check
				row.values, row.previous, row.task = nil, nil, nil
				for c = 4, #row.cells - 1 do
					row.cells[c] = ""
				end
			end
			entry.rows[#entry.rows + 1] = row
			if verdict then
				local list = verdict == "improvement" and entry.improvements or entry.regressions
				list[#list + 1] = { label = r.scenario .. " " .. r.size .. ": " .. metric, lua = changeLua,
					frame = changeFrame, now = Lua(r.luaMs), was = Lua(old.r.luaMs) }
			end
		elseif failed then
			entry.rows[#entry.rows + 1] = {
				scenario = r.scenario, size = r.size, metric = r.metric .. " (" .. r.impl .. ")", failed = true,
				checkOnly = true, check = r.check,
				cells = { r.scenario, r.size, r.metric .. " (" .. r.impl .. ")", "", "", "", "", "", "", "", "", "", "", "",
					"", "", "", "", r.check },
			}
		end
	end

	local framework = {}
	for _, r in ipairs(results) do
		if r.impl:match("^framework") then
			framework[Key(r)] = true
		end
	end
	for i, r in ipairs(results) do
		if (r.impl == "baseline" or r.impl == "typical") and not framework[Key(r)] then
			entry.hand.rows[#entry.hand.rows + 1] = { cells = { r.scenario, r.size, r.metric .. (r.n == 1 and " ¹" or ""), r.impl, Lua(r.luaMs),
				(Frame(r.frameMs, idles[i])), Memory(r.keptKb) } }
		end
	end
	for _, o in ipairs(round.orders or {}) do
		entry.orders[#entry.orders + 1] = o.scenario .. " " .. o.size .. ": " .. table.concat(o.sides, ", ")
	end
	local names = {}
	for name in pairs(saved.source or {}) do
		if name ~= "idle" then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local s = saved.source[name]
		local typical = s.typical or { lines = 0, chars = 0 }
		entry.source.rows[#entry.source.rows + 1] = { cells = { name, tostring(s.framework.lines),
			tostring(s.baseline.lines), typical.lines > 0 and tostring(typical.lines) or "",
			tostring(s.framework.chars), tostring(s.baseline.chars), typical.chars > 0 and tostring(typical.chars) or "" } }
	end
	return entry
end

-- Markdown --------------------------------------------------------------------------------------------------------

local function Table(out, columns, rows)
	out[#out + 1] = "| " .. table.concat(columns, " | ") .. " |"
	local rule = {}
	for i = 1, #columns do
		rule[i] = i <= 4 and "---" or "---:"
	end
	out[#out + 1] = "| " .. table.concat(rule, " | ") .. " |"
	for _, row in ipairs(rows) do
		out[#out + 1] = "| " .. table.concat(row.cells, " | ") .. " |"
	end
end

--- bench/README.md: the newest round's entry, as Markdown.
local function Markdown(entry)
	local out = {}
	local function add(line)
		out[#out + 1] = line
	end
	add("# Bench")
	add("")
	add("Generated by `scripts/bench_save.lua` from `report.json` (every round, computed from `results/`, one file per")
	add("round: the history); the design site's Bench page shows every round. This is the newest.")
	add("")
	for _, note in ipairs(entry.notes) do
		add("- " .. note)
	end
	add("")
	add("Reading it:")
	add("")
	for _, note in ipairs(entry.reading) do
		add("- " .. note)
	end
	add("")
	for _, line in ipairs(entry.header) do
		add(line)
	end
	add("")
	local function List(title, list)
		add("## " .. title)
		add("")
		if #list == 0 then
			add("None.")
		end
		for _, c in ipairs(list) do
			add(string.format("- %s: Lua %s (%s → %s)%s", c.label, c.lua ~= "" and c.lua or "–", c.was, c.now,
				c.frame ~= "" and (", frame " .. c.frame) or ""))
		end
		add("")
	end
	if entry.comparedWith then
		List("Improvements", entry.improvements)
		List("Regressions", entry.regressions)
	end
	add("## Results")
	add("")
	Table(out, entry.columns, entry.rows)
	add("")
	add("Failed checks: " .. entry.failed .. ".")
	add("")
	add("## By hand only")
	add("")
	add("Hand-written rows with no framework row of the same name (hide and show against unmount and remount).")
	add("")
	Table(out, entry.hand.columns, entry.hand.rows)
	add("")
	add("## Order of the sides")
	add("")
	add("Which side of each block ran first, second, ...: the same order in every round.")
	add("")
	for _, line in ipairs(entry.orders) do
		add("- " .. line)
	end
	add("")
	add("## Source size")
	add("")
	add("Code lines and characters, without comments, blank lines, indentation or bench-only code (checks' hooks, measured variants). Typical exists for signals, coalesce, grid, ticker and reorder only.")
	add("")
	Table(out, entry.source.columns, entry.source.rows)
	add("")
	return table.concat(out, "\n")
end

-- Main -------------------------------------------------------------------------------------------------------------

local RECOUNT, given = false, nil
for _, a in ipairs(arg or {}) do
	if a == "--recount" then
		RECOUNT = true
	else
		given = a
	end
end
-- the newer of the two: the last run sent over the strip, the last one in the SavedVariables (written at a /reload)
local fromSaved = Load(FindSaved(given))
local fromStrip = not given and LoadRecords() or nil
local lines = fromSaved
if fromStrip and (not fromSaved or Split(fromStrip[1])[2] > Split(fromSaved[1])[2]) then
	lines = fromStrip
	print("the newest run, from the companion's records")
end
assert(lines, "no round: run /obench (then /reload, unless the debug addon is on to send it over the strip)")
local round, results = Parse(lines)
if round.mode == "probes" then
	print("a probes run: its lines are in the probes list and the bench's log, nothing to save")
	os.exit(0)
end
if round.mode == "check" then
	-- a check run (`/obench check`): its checks reported, never recorded
	local failed, passed = {}, 0
	for _, r in ipairs(results) do
		if r.check and r.check:match("^FAIL") then
			failed[#failed + 1] = string.format("  %s %s %s (%s): %s", r.scenario, r.size, r.metric, r.impl, r.check)
		elseif r.check == "ok" then
			passed = passed + 1
		elseif r.check and r.check:match("^info ") then
			print(string.format("  %s %s: %s", r.scenario, r.metric, r.check:sub(6)))
		end
	end
	for _, g in ipairs(round.gc or {}) do
		print(string.format("  collector in %d frames: %s %s %s (%s)", g.frames, g.scenario, g.size, g.metric, g.impl))
	end
	local errors = round.errors and round.errors.count or 0
	print(string.format("check run: %d checks passed, %d failed, %d errors (not recorded)", passed, #failed, errors))
	if errors > 0 then
		print("  first errors: " .. round.errors.first)
	end
	if #failed > 0 then
		print(table.concat(failed, "\n"))
	end
	os.exit((#failed > 0 or errors > 0) and 1 or 0)
end
-- a round is recorded only as players would run it: the Core and the bench built with the bench profile (release
-- stripping, the bench's dev file kept); one with the debug addon loaded is marked and compared only with its kind
if round.gc then
	print(#round.gc .. " series had a collection step in their measured frames (frame column holds collector work):")
	for _, g in ipairs(round.gc) do
		print(string.format("  %d frames: %s %s %s (%s)", g.frames, g.scenario, g.size, g.metric, g.impl))
	end
end
local profile = round.build and round.build.core or "?"
local benchProfile = round.build and round.build.bench or "?"
local debugLoaded = false
for _, name in ipairs(round.addons or {}) do
	if name == "OrdaenCore_Debug" then
		debugLoaded = true
	end
end
if round.errors and round.errors.count > 0 then
	print(round.errors.count .. " errors during the round: not recorded (a step that errored left its row missing or"
		.. " half-measured). First: " .. round.errors.first)
	os.exit(1)
end
if profile == "dev" and benchProfile == "dev" and debugLoaded then
	-- the one round that measures what our dev setup costs against players' builds (a dev build with the debug
	-- addon loaded, as we develop): kept to the side, never in the history
	fs.MakeDirs("bench/dev")
	local file = "bench/dev/" .. round.date:gsub(" ", "_"):gsub(":", "") .. ".json"
	Write(file, json.encode({ round = round, builds = { OrdaenCore = Build("OrdaenCore") }, results = results }))
	print("a dev-profile round: saved to the side, " .. file .. " (not in the history)")
	os.exit(0)
end
if profile ~= "bench" or benchProfile ~= "bench" then
	print("not recorded: OrdaenCore built " .. profile .. ", OrdaenBench built " .. benchProfile
		.. ". Rounds count only with both on `ordaen build --profile bench`.")
	os.exit(1)
end
-- a round run with the debug addon loaded (the companion pressed /obench; the addon quiet while it ran) is recorded
-- and marked: its frames hold whatever the quiet addon still does, so it's judged only against rounds marked alike
round.debug = debugLoaded
-- a round with a failed check isn't recorded: its numbers measured something broken
local failures = {}
for _, r in ipairs(results) do
	if r.check and r.check:match("^FAIL") then
		failures[#failures + 1] = string.format("  %s %s %s (%s): %s", r.scenario, r.size, r.metric, r.impl, r.check)
	end
end
if #failures > 0 then
	print(#failures .. " failed checks: the round isn't recorded. Fix them, then run a new round.")
	print(table.concat(failures, "\n"))
	os.exit(1)
end
-- each scenario with a hand-written side: its code's size on every side (units and the scheduler have none to compare)
local function Sources(list)
	local out = {}
	for _, r in ipairs(list) do
		if out[r.scenario] == nil then
			local s = Source(r.scenario)
			out[r.scenario] = s.baseline.lines > 0 and s or false
		end
	end
	for scenario, s in pairs(out) do
		if not s then
			out[scenario] = nil
		end
	end
	return out
end
-- `--recount`: every saved round's source sizes counted again from the current code (after the count's rules change;
-- the scenarios' code is what the rounds ran, apart from the bench markers)
if RECOUNT then
	for _, round_file in ipairs(RoundFiles()) do
		local round_path = RESULTS .. "/" .. round_file
		local saved = json.decode(Read(round_path))
		saved.source = Sources(saved.results)
		Write(round_path, json.encode(saved))
		print("recounted: " .. round_path)
	end
end
local source = Sources(results)
fs.MakeDirs(RESULTS)
local name = round.date:gsub(" ", "_"):gsub(":", "") .. ".json"
local file = RESULTS .. "/" .. name
if Read(file) then
	print("already saved: " .. file)
else
	Write(file, json.encode({
		round = round,
		builds = { OrdaenCore = Build("OrdaenCore"), OrdaenBench = Build("OrdaenBench") },
		source = source,
		results = results,
	}))
	print("saved: " .. file)
end

-- every round's entry, each compared with the newest earlier comparable round
local entries, seen = json.array({}), {}
for _, round_file in ipairs(RoundFiles()) do
	local id = round_file:gsub("%.json$", "")
	local saved = json.decode(Read(RESULTS .. "/" .. round_file))
	-- the newest earlier comparable round of the same plan shape (judged); without one, the newest comparable round of
	-- another shape, its shared rows compared but not judged
	local previous, shape = nil, Shape(saved)
	for i = #seen, 1, -1 do
		if Comparable(saved, seen[i].saved) and Shape(seen[i].saved) == shape then
			previous = seen[i]
			previous.judged = true
			break
		end
	end
	if not previous then
		for i = #seen, 1, -1 do
			if Comparable(saved, seen[i].saved) then
				previous = seen[i]
				previous.judged = false
				break
			end
		end
	end
	entries[#entries + 1] = Model(id, saved, previous)
	seen[#seen + 1] = { id = id, saved = saved }
end
Write("bench/report.json", json.encode({ rounds = entries }))
print("wrote bench/report.json (" .. #entries .. " rounds)")
if #entries > 0 then
	Write("bench/README.md", Markdown(entries[#entries]))
else
	Write("bench/README.md", "# Bench\n\nNo rounds yet: run /obench in game, /reload, then `ordaen lua scripts/bench_save.lua`.\n")
end
print("wrote bench/README.md")
