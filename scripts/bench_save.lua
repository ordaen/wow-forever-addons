-- Save the last OrdaenBench round (/obench in game, then /reload) to bench/results/<date>_<time>.json, then rewrite
-- bench/report.json (every round, computed: tables, changes, improvements and regressions) and bench/README.md (the
-- newest round). Run from the repo root: ordaen lua scripts/bench_save.lua [SavedVariables dir]
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
	"Frame", "× best Lua", "× best frame", "× typical Lua", "Net KB", "Kept KB", "Change Lua", "Change frame", "Check",
}
local HAND_COLUMNS = { "Scenario", "Size", "Metric", "Side", "Lua", "Frame", "Kept KB" }
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
	"**Net KB:** Lua heap growth per call (negative: a call that frees). The collector is stopped through every"
		.. " series, so no time holds collector work; what collecting a scenario's garbage costs is a bench of its"
		.. " own. **Kept KB** (make"
		.. " rows): what stays after a full collection. The Lua heap only: WoW frames' own memory is invisible to every"
		.. " side.",
	"**¹** a single sample (a first opening, a hand make): its frame time is one frame's, not a median.",
	"**Built as players run it:** every round is on the bench profile (release stripping, the bench's dev hooks kept)"
		.. " with the debug addon disabled; bench_save refuses any other.",
	"**Engine / backend, read with care:** the stub run touches less memory, so the engine runs with warmer caches"
		.. " there and the backend's share reads slightly high. Hand-written drawing leaves its text layout to WoW's"
		.. " drawing, so compare the backend with best's frame column, not its Lua column.",
	"**Change:** against the newest earlier comparable round (clean builds); an improvement or a"
		.. " regression is a change of " .. CHANGE * 100 .. "% or more (frame changes also beyond the idle spread). Same"
		.. " graphics quality and spot in the world (zone and subzone) only; stand in the same place facing the"
		.. " same way, since the world drawn is in every frame time.",
}
local READING = {
	"**One /obench:** a cold block first (the large grid opened on every side while the session is fresh), then the"
		.. " whole plan untracked (one-time costs: fonts, first textures, Blizzard code), then the whole plan measured.",
	"**make (pool warm):** the framework opened again after closing, its frames back from the pools; hand code makes"
		.. " new frames every time. **make (cold)** compares the first opening on every side.",
	"**grid close and open+close:** the framework unmounts and mounts again (the MVP has no hidden attribute); hand"
		.. " code hides and shows (\"By hand only\"). Not the same operation: no factor.",
	"**framework-naive:** grid and ticker written as code reads without the build's lifting and hoisting: new tables"
		.. " and a new slot function every call. Its rows include lost skipping (a new slot function re-renders the"
		.. " child), not only allocation.",
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

--- Rounds compare only when both ran clean builds at the same graphics quality and spot (every round runs at the
--- same resolution and render scale, so those aren't recorded).
local function Comparable(a, b)
	local ba, bb = a.round.build or {}, b.round.build or {}
	return Clean(a) and Clean(b) and ba.graphics ~= nil and ba.graphics == bb.graphics
		and ba.zone == bb.zone and ba.subzone == bb.subzone
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
		return "<" .. LUA_FLOOR
	end
	return string.format("%.3f", ms)
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
	return string.format("%.3f", above), above
end

local function Factor(a, b, floor)
	if not (a and b) or b < floor then
		return ""
	end
	return string.format("%.1f", a / b)
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
	}
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
		head(string.format("Built: Core %s, Bench %s (profiles). Where: %s%s. Graphics: %s.", build.core or "?",
			build.bench or "?", build.zone or "?", (build.subzone or "") ~= "" and (", " .. build.subzone) or "",
			build.graphics or build.graphicsQuality or "?"))
	end
	if round.addons then
		head(string.format("Loaded addons (%d): %s.", #round.addons, table.concat(round.addons, ", ")))
	end
	if previous then
		entry.comparedWith = previous.id
		head(string.format("Compared with: round %s, %s (Core %s).", tostring(previous.saved.round.number),
			previous.saved.round.date, Commit(previous.saved.builds.OrdaenCore)))
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
			local bestFrameText, bestFrame = "", nil
			if best then
				bestFrameText, bestFrame = Frame(best.r.frameMs, best.idle)
			end
			local typicalFrameText = typical and Frame(typical.r.frameMs, typical.idle) or ""
			local engineLua = engine and engine.r.luaMs
			local backendLua = engineLua and math.max(r.luaMs - engineLua, 0)
			local changeLua, changeFrame, verdict = "", "", nil
			if old then
				if old.r.luaMs and old.r.luaMs >= LUA_FLOOR and r.luaMs >= LUA_FLOOR then
					changeLua = Percent(r.luaMs, old.r.luaMs)
					local ratio = (r.luaMs - old.r.luaMs) / old.r.luaMs
					if ratio <= -CHANGE then
						verdict = "improvement"
					elseif ratio >= CHANGE then
						verdict = "regression"
					end
				end
				local _, oldFrame = Frame(old.r.frameMs, old.idle)
				if frame and oldFrame then
					changeFrame = Percent(frame, oldFrame)
					local ratio = (frame - oldFrame) / oldFrame
					local beyond = math.abs(frame - oldFrame) > idles[i].noise
					if beyond and ratio <= -CHANGE and verdict ~= "regression" then
						verdict = verdict or "improvement"
					elseif beyond and ratio >= CHANGE then
						verdict = "regression"
					end
				end
			end
			local row = {
				scenario = r.scenario, size = r.size, metric = metric, failed = failed, verdict = verdict,
				cells = {
					r.scenario, r.size, metric, Lua(r.luaMs), Lua(engineLua), Lua(backendLua), frameText,
					best and Lua(best.r.luaMs) or "", bestFrameText, typical and Lua(typical.r.luaMs) or "",
					typicalFrameText, Factor(r.luaMs, best and best.r.luaMs, LUA_FLOOR), Factor(frame, bestFrame, 0.001),
					Factor(r.luaMs, typical and typical.r.luaMs, LUA_FLOOR), string.format("%.1f", r.kb or 0),
					r.keptKb and string.format("%.0f", r.keptKb) or "", changeLua, changeFrame, r.check or "",
				},
			}
			entry.rows[#entry.rows + 1] = row
			if verdict then
				local list = verdict == "improvement" and entry.improvements or entry.regressions
				list[#list + 1] = { label = r.scenario .. " " .. r.size .. ": " .. metric, lua = changeLua,
					frame = changeFrame, now = Lua(r.luaMs), was = Lua(old.r.luaMs) }
			end
		elseif failed then
			entry.rows[#entry.rows + 1] = {
				scenario = r.scenario, size = r.size, metric = r.metric .. " (" .. r.impl .. ")", failed = true,
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
				(Frame(r.frameMs, idles[i])), r.keptKb and string.format("%.0f", r.keptKb) or "" } }
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
	add("Code lines and characters, without comments, blank lines or indentation.")
	add("")
	Table(out, entry.source.columns, entry.source.rows)
	add("")
	return table.concat(out, "\n")
end

-- Main -------------------------------------------------------------------------------------------------------------

local path = FindSaved(arg and arg[1])
assert(path, "no OrdaenBench.lua under " .. DEFAULT_WTF)
local round, results = Parse(Load(path))
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
-- stripping, the bench's dev file kept), and the debug addon not loaded
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
if profile ~= "bench" or benchProfile ~= "bench" or debugLoaded then
	print("not recorded: OrdaenCore built " .. profile .. ", OrdaenBench built " .. benchProfile
		.. (debugLoaded and ", and OrdaenCore_Debug was loaded" or "")
		.. ". Rounds count only with both on `ordaen build --profile bench` and the debug addon disabled.")
	os.exit(1)
end
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
local source = {}
for _, r in ipairs(results) do
	if not source[r.scenario] then
		source[r.scenario] = Source(r.scenario)
	end
end
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
	local previous
	for i = #seen, 1, -1 do
		if Comparable(saved, seen[i].saved) then
			previous = seen[i]
			break
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
