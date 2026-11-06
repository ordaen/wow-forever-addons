-- Store: OrdaenCoreDebugDB, the one SavedVariables table of dev mode. WoW writes it to
-- WTF\Account\<account>\SavedVariables\OrdaenCore_Debug.lua on /reload or logout, and Claude
-- reads it there. Players never have it: this addon is disabled by default.
--
--   session          increments on every load (login or /reload)
--   sessions[n]      client and Core versions of session n (kept while an error or save uses it)
--   errors           newest last. kind = "error" | "taint"; source = Ordaen addon folder or "other";
--                    message, stack, locals, count, time/lastTime, session/lastSession, id
--   addons[name]     per Ordaen addon: logging, echo, log (timestamped lines), dump
--   saves            "Save for Claude & reload" clicks: time, session, note, combat (newest last)
--   ui               window/button positions, error filter, seenId (errors up to it were seen)
local _, ns = ...

local Store = {}
ns.Store = Store

Store.ERRORS_MAX = 100
Store.LOG_MAX = 1000
Store.LOG_TRIM_SLACK = 100 -- trim in batches so logging stays cheap
Store.SAVES_MAX = 20
Store.STACK_MAX_CHARS = 6000
Store.LOCALS_MAX_CHARS = 4000

local function fresh()
	return { session = 0, nextId = 0, sessions = {}, errors = {}, addons = {}, saves = {}, ui = {} }
end

-- Until Load() gets the SavedVariables, collect into a temporary table and merge it in later,
-- so nothing raised while addons load is lost.
local db = fresh()
local index = {} -- message -> error entry, for de-duplication
local listeners = {}

local function now()
	return date("%Y-%m-%d %H:%M:%S")
end
Store.Now = now

local function truncate(text, max)
	if type(text) == "string" and #text > max then
		return text:sub(1, max) .. "\n...(truncated)"
	end
	return text
end

local function notify(entry, isNew)
	for _, fn in ipairs(listeners) do
		pcall(fn, entry, isNew)
	end
end

local function metadata(addon, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addon, field)
	end
	return nil
end
Store.Metadata = metadata

--- Client facts for the current session.
function Store.ClientMeta()
	local client, build, buildDate, interface = GetBuildInfo()
	return {
		client = client,
		build = build,
		buildDate = buildDate,
		interface = interface,
		locale = GetLocale and GetLocale() or "?",
		core = OrdaenCore and OrdaenCore.version or "?",
	}
end

--- Take over the SavedVariables table (ADDON_LOADED). Returns the table to assign back to the global.
---@param saved table|nil
---@param meta table client facts for this session
---@return table
function Store.Load(saved, meta)
	if type(saved) ~= "table" then
		saved = {}
	end
	for key, value in pairs(fresh()) do
		if type(saved[key]) ~= type(value) then
			saved[key] = value
		end
	end
	saved.session = saved.session + 1
	saved.sessions[saved.session] = meta

	local early = db
	db = saved
	index = {}
	for _, entry in ipairs(db.errors) do
		index[entry.message] = entry
	end
	for _, entry in ipairs(early.errors) do
		Store.AddError(entry)
	end
	for name, earlyAddon in pairs(early.addons) do
		for _, line in ipairs(earlyAddon.log) do
			Store.AppendLog(name, line)
		end
	end

	-- Forget sessions nothing refers to any more.
	local used = { [db.session] = true }
	for _, entry in ipairs(db.errors) do
		used[entry.session] = true
		used[entry.lastSession or entry.session] = true
	end
	for _, save in ipairs(db.saves) do
		used[save.session] = true
	end
	for session in pairs(db.sessions) do
		if not used[session] then
			db.sessions[session] = nil
		end
	end
	return db
end

---@return table
function Store.Get()
	return db
end

---@return integer
function Store.Session()
	return db.session
end

--- Call fn(entry, isNew) whenever an error is added (isNew) or repeated; fn(nil) when cleared.
function Store.OnChange(fn)
	listeners[#listeners + 1] = fn
end

--- The Ordaen addon an error belongs to: the first Ordaen addon folder in its message, then its
--- stack. Everything else is "other" (other addons, Blizzard).
---@return string
function Store.SourceOf(message, stack)
	local text = tostring(message or "") .. "\n" .. tostring(stack or "")
	return text:match("[Aa]dd[Oo]ns[/\\](Ordaen[%w_]*)[/\\]") or "other"
end

--- If this message was recorded before, count the repeat and return the entry. Cheap enough to
--- call first on every error, before capturing the (expensive) stack.
---@return table|nil
function Store.Repeat(message)
	local entry = index[tostring(message)]
	if entry then
		entry.count = entry.count + 1
		entry.lastTime = now()
		entry.lastSession = db.session
		notify(entry, false)
	end
	return entry
end

--- Record an error. fields: message, stack, locals, kind ("error"), source (derived if missing).
---@return table entry, boolean isNew
function Store.AddError(fields)
	local message = tostring(fields.message)
	local existing = Store.Repeat(message)
	if existing then
		return existing, false
	end
	db.nextId = db.nextId + 1
	local entry = {
		id = db.nextId,
		kind = fields.kind or "error",
		source = fields.source or Store.SourceOf(message, fields.stack),
		message = message,
		stack = truncate(fields.stack, Store.STACK_MAX_CHARS),
		locals = truncate(fields.locals, Store.LOCALS_MAX_CHARS),
		count = 1,
		time = now(),
		session = db.session,
	}
	local errors = db.errors
	errors[#errors + 1] = entry
	index[message] = entry
	while #errors > Store.ERRORS_MAX do
		local dropped = table.remove(errors, 1)
		if index[dropped.message] == dropped then
			index[dropped.message] = nil
		end
	end
	notify(entry, true)
	return entry, true
end

function Store.ClearErrors()
	db.errors = {}
	index = {}
	db.ui.seenId = db.nextId
	notify(nil, false)
end

--- Errors for a filter, newest first. filter: "all" | "ours" | "other" | "taint".
---@return table
function Store.Filter(filter)
	local out = {}
	for i = #db.errors, 1, -1 do
		local e = db.errors[i]
		local ours = e.source ~= "other"
		if filter == "all"
			or (filter == "taint" and e.kind == "taint")
			or (filter == "ours" and e.kind == "error" and ours)
			or (filter == "other" and e.kind == "error" and not ours) then
			out[#out + 1] = e
		end
	end
	return out
end

--- How many recorded errors are newer than the last time the Errors tab was looked at.
---@return integer
function Store.NewCount()
	local seen = db.ui.seenId or 0
	local n = 0
	for _, e in ipairs(db.errors) do
		if e.id > seen then
			n = n + 1
		end
	end
	return n
end

function Store.MarkSeen()
	db.ui.seenId = db.nextId
end

--- Plain-text description of one error, for the detail view and bug reports.
---@return string
function Store.FormatError(e)
	local m = db.sessions[e.session] or {}
	local lines = {
		string.format("%s in %s: x%d, first %s%s", e.kind == "taint" and "Blocked action" or "Error", e.source,
			e.count, e.time, e.lastTime and (", last " .. e.lastTime) or ""),
		string.format("Client %s (build %s, %s), interface %s, locale %s. Ordaen Core %s.", tostring(m.client),
			tostring(m.build), tostring(m.buildDate), tostring(m.interface), tostring(m.locale), tostring(m.core)),
	}
	if e.source ~= "other" then
		lines[#lines + 1] = string.format("%s %s", e.source, tostring(metadata(e.source, "Version") or "?"))
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = e.message
	if e.stack then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- stack:"
		lines[#lines + 1] = e.stack
	end
	if e.locals then
		lines[#lines + 1] = "-- locals:"
		lines[#lines + 1] = e.locals
	end
	return table.concat(lines, "\n")
end

--- Per-addon dev data, created on first use.
---@return table
function Store.Addon(name)
	local addon = db.addons[name]
	if not addon then
		addon = { logging = true, echo = false, log = {} }
		db.addons[name] = addon
	end
	return addon
end

--- Keep only the newest `max` entries of an array, in order.
function Store.TrimLog(log, max)
	local n = #log
	if n <= max then
		return
	end
	local drop = n - max
	for i = 1, max do
		log[i] = log[i + drop]
	end
	for i = max + 1, n do
		log[i] = nil
	end
end

function Store.AppendLog(name, line)
	local log = Store.Addon(name).log
	log[#log + 1] = line
	if #log > Store.LOG_MAX + Store.LOG_TRIM_SLACK then
		Store.TrimLog(log, Store.LOG_MAX)
	end
end

--- Remember a "Save for Claude & reload" click. fields: note, combat.
function Store.AddSave(fields)
	local saves = db.saves
	saves[#saves + 1] = {
		time = now(),
		session = db.session,
		note = fields.note,
		combat = fields.combat,
	}
	while #saves > Store.SAVES_MAX do
		table.remove(saves, 1)
	end
end
