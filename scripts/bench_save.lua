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

--- A scenario's code: components/<name>*.lua on the framework, baseline/<name>.lua by hand.
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
	local baseline = {}
	if Read(BENCH .. "/baseline/" .. scenario .. ".lua") then
		baseline[1] = BENCH .. "/baseline/" .. scenario .. ".lua"
	end
	return { framework = Sum(framework), baseline = Sum(baseline) }
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
	local round = { date = head[2], client = head[3], fps = tonumber(head[4]), luaHeapKb = tonumber(head[5]) }
	local results = json.array({})
	for i = 2, #lines do
		local f = Split(lines[i])
		results[#results + 1] = {
			scenario = f[1], size = f[2], impl = f[3], metric = f[4],
			ms = tonumber(f[5]), maxMs = tonumber(f[6]), kb = tonumber(f[7]), n = tonumber(f[8]),
			check = f[9] ~= "" and f[9] or nil,
		}
	end
	return round, results
end

-- The README ------------------------------------------------------------------------------------------------------

local function Key(r)
	return r.scenario .. "|" .. r.size .. "|" .. r.metric:gsub(" %(make%)$", "")
end

local function Rounds()
	local list = {}
	for _, name in ipairs(fs.List(RESULTS)) do
		if name:match("%.json$") then
			list[#list + 1] = name
		end
	end
	return list
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
	local before = {}
	if previous then
		for _, r in ipairs(previous.results) do
			if r.impl == "framework" then
				before[Key(r)] = r
			end
		end
	end
	local byHand = {}
	for _, r in ipairs(round.results) do
		if r.impl == "baseline" then
			byHand[Key(r)] = r
		end
	end
	local out = {}
	local function add(line)
		out[#out + 1] = line
	end
	add("# Bench")
	add("")
	add("Generated by `scripts/bench_save.lua` from the newest round in `results/` (one file per round: the history).")
	add("Framework against the same scenario written by hand (`addons/OrdaenBench`); ms per call or per frame, as the")
	add("metric says; KB is Lua heap growth per call (a garbage collection step inside a call reads low).")
	add("")
	add(string.format("Newest round: %s, client %s, %s fps; Core %s.", round.round.date, round.round.client,
		tostring(round.round.fps), round.builds.OrdaenCore and round.builds.OrdaenCore.commit or "?"))
	if previous then
		add(string.format("Compared with: %s (Core %s).", previous.round.date,
			previous.builds.OrdaenCore and previous.builds.OrdaenCore.commit or "?"))
	end
	add("")
	add("| Scenario | Size | Metric | Framework ms | By hand ms | × | Framework KB | Change | Check |")
	add("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |")
	local failed = 0
	for _, r in ipairs(round.results) do
		if r.impl == "framework" then
			local hand = byHand[Key(r)]
			local factor = hand and hand.ms > 0 and string.format("%.1f", r.ms / hand.ms) or ""
			local old = before[Key(r)]
			local change = old and old.ms > 0 and string.format("%+.0f%%", (r.ms - old.ms) / old.ms * 100) or ""
			if r.check and r.check:match("^FAIL") then
				failed = failed + 1
			end
			add(string.format("| %s | %s | %s | %.3f | %s | %s | %.1f | %s | %s |", r.scenario, r.size, r.metric, r.ms,
				hand and string.format("%.3f", hand.ms) or "", factor, r.kb, change, r.check or ""))
		end
	end
	add("")
	add("Failed checks: " .. failed .. ".")
	add("")
	add("## Source size")
	add("")
	add("Code lines and characters, without comments, blank lines or indentation.")
	add("")
	add("| Scenario | Framework lines | By hand lines | Framework chars | By hand chars |")
	add("| --- | ---: | ---: | ---: | ---: |")
	local names = {}
	for name in pairs(round.source) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local s = round.source[name]
		add(string.format("| %s | %d | %d | %d | %d |", name, s.framework.lines, s.baseline.lines, s.framework.chars,
			s.baseline.chars))
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
