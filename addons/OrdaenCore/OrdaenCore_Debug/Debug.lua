-- Ordaen Core - Debug (OrdaenCore_Debug): the optional development mode for Ordaen addons.
--
-- Disabled by default (## DefaultState: Disabled), so players never record anything: without it,
-- OrdaenCore.NewDebug returns a no-op stand-in and errors take WoW's normal path. Enabling it in the
-- AddOns list replaces OrdaenCore.NewDebug with the real kit below. Ordaen addons list this addon in
-- ## OptionalDeps, so it loads before them.
--
-- One instance per addon. Everything is stored in that addon's SavedVariables under db.debug,
-- which WoW writes to WTF\Account\<account>\SavedVariables\<Addon>.lua on /reload or logout:
--   enabled, echo   log switches (/<cmd> debug, /<cmd> debug echo); the log is on by default
--   log             timestamped lines, newest last, capped at LOG_MAX
--   errors          de-duplicated errors with stack, locals and client info, capped at ERRORS_MAX
--   dump            last /<cmd> dump: client info + the addon's own state snapshot
local Core = OrdaenCore
Core.debugMode = true

local instances = {}

--- The debug kit for one addon. Calling it again for the same addon returns the same instance.
---@param addonName string
---@return table Debug
function Core.NewDebug(addonName)
	if instances[addonName] then
		return instances[addonName]
	end
	local Debug = {}
	instances[addonName] = Debug

	Debug.LOG_MAX = 1000
	Debug.LOG_TRIM_SLACK = 100 -- trim in batches so logging stays O(1) amortized
	Debug.ERRORS_MAX = 50
	Debug.SNAPSHOT_DEPTH = 5
	Debug.SNAPSHOT_MAX_KEYS = 200
	Debug.LOCALS_MAX_CHARS = 4000
	Debug.ISSUE_URL = "https://github.com/ordaen/forever-addons/issues/new?template=bug_report.yml"

	-- Until Init() hands us the SavedVariables table, keep data here and merge it in later,
	-- so errors raised while the addon's files load are not lost.
	local state = { log = {}, errors = {}, enabled = false, echo = false }
	local options = {}
	local notified = {} -- error messages already announced in chat this session

	local function pack(...)
		return { n = select("#", ...), ... }
	end

	local function joinArgs(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		return table.concat(parts, " ")
	end

	local function metadata(field)
		if C_AddOns and C_AddOns.GetAddOnMetadata then
			return C_AddOns.GetAddOnMetadata(addonName, field)
		end
		return nil
	end

	local function title()
		return options.title or metadata("Title") or addonName
	end

	local function chat(...)
		if options.print then
			options.print(...)
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. title() .. "|r: " .. joinArgs(...))
		end
	end

	local function now()
		return date("%Y-%m-%d %H:%M:%S")
	end

	local function timestamp()
		local t = GetTime and GetTime() or 0
		return string.format("%s.%03d", date("%H:%M:%S"), math.floor((t % 1) * 1000))
	end

	--- Client and addon facts attached to dumps and error reports.
	---@return table
	function Debug.Meta()
		local client, build, buildDate, interface = GetBuildInfo()
		return {
			addon = addonName,
			addonVersion = options.version or metadata("Version") or "?",
			core = Core.version,
			client = client,
			build = build,
			buildDate = buildDate,
			interface = interface,
			locale = GetLocale and GetLocale() or "?",
		}
	end

	--- Hand the kit the addon's SavedVariables table. Call from ADDON_LOADED.
	---@param db table SavedVariables table; debug data is kept in db.debug
	---@param opts table|nil { slash = "/mc", version = "1.0.0", title = "...", print = fn, dump = fn():table }
	function Debug.Init(db, opts)
		options = opts or {}
		local saved = db.debug or {}
		db.debug = saved
		saved.log = saved.log or {}
		saved.errors = saved.errors or {}
		saved.enabled = saved.enabled ~= false -- dev mode: log unless switched off
		saved.echo = saved.echo == true

		local early = state
		state = saved
		if early ~= saved then
			for _, entry in ipairs(early.errors) do
				Debug.RecordError(entry.message, entry.stack, entry.locals)
			end
		end

		if state.enabled then
			local m = Debug.Meta()
			Debug.Log("---- session start:", m.addon, m.addonVersion, "client", m.client, m.build, m.interface)
			chat("debug logging is |cffffff00on|r (" .. (options.slash or "") .. " debug off to stop).")
		end
	end

	---@return boolean
	function Debug.IsEnabled()
		return state.enabled
	end

	--- Keep only the newest `max` entries of an array, in order.
	---@param log table
	---@param max integer
	function Debug.TrimLog(log, max)
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

	--- Append a line to the debug log (only while debug is on). Arguments are joined like print().
	function Debug.Log(...)
		if not state.enabled then
			return
		end
		local line = timestamp() .. " " .. joinArgs(...)
		local log = state.log
		log[#log + 1] = line
		if #log > Debug.LOG_MAX + Debug.LOG_TRIM_SLACK then
			Debug.TrimLog(log, Debug.LOG_MAX)
		end
		if state.echo then
			chat("|cff999999" .. line .. "|r")
		end
	end

	--- Like Log, with string.format.
	function Debug.Logf(fmt, ...)
		if state.enabled then
			Debug.Log(string.format(fmt, ...))
		end
	end

	local function round(x)
		return math.floor(x * 100 + 0.5) / 100
	end

	-- Frames, textures and font strings are tables with a GetObjectType method. SavedVariables
	-- cannot store them, so describe the parts that matter for layout bugs instead.
	local function isWidget(v)
		return type(v) == "table" and type(v.GetObjectType) == "function"
	end

	local function call(obj, method, ...)
		local fn = obj[method]
		if type(fn) ~= "function" then
			return nil
		end
		local ok, a, b = pcall(fn, obj, ...)
		if ok then
			return a, b
		end
		return nil
	end

	local function widgetName(w)
		if not isWidget(w) then
			return nil
		end
		return call(w, "GetName") or ("<" .. tostring(call(w, "GetObjectType")) .. ">")
	end

	local function describeWidget(w)
		local out = {
			widget = call(w, "GetObjectType"),
			name = call(w, "GetName"),
			parent = widgetName(call(w, "GetParent")),
			shown = call(w, "IsShown"),
			visible = call(w, "IsVisible"),
			strata = call(w, "GetFrameStrata"),
			level = call(w, "GetFrameLevel"),
			alpha = call(w, "GetAlpha"),
			scale = call(w, "GetScale"),
		}
		local width, height = call(w, "GetSize")
		if width then
			out.size = round(width) .. "x" .. round(height)
		end
		local numPoints = call(w, "GetNumPoints") or 0
		if numPoints > 0 then
			out.points = {}
			for i = 1, numPoints do
				local ok, point, relativeTo, relativePoint, x, y = pcall(w.GetPoint, w, i)
				if ok and point then
					out.points[i] = string.format(
						"%s %s %s %s %s",
						point,
						widgetName(relativeTo) or "nil",
						tostring(relativePoint),
						tostring(x and round(x)),
						tostring(y and round(y))
					)
				end
			end
		end
		return out
	end

	--- Convert any value into something SavedVariables can store: widgets become descriptions,
	--- functions become "<function>", cycles and deep tables are cut off.
	---@param value any
	---@param depth integer|nil
	---@return any
	function Debug.Snapshot(value, depth)
		local seen = {}
		local function snap(v, d)
			local t = type(v)
			if t == "string" or t == "number" or t == "boolean" or t == "nil" then
				return v
			end
			if t ~= "table" then
				return "<" .. t .. ">"
			end
			if isWidget(v) then
				return describeWidget(v)
			end
			if seen[v] then
				return "<cycle>"
			end
			if d <= 0 then
				return "<table>"
			end
			seen[v] = true
			local out, count = {}, 0
			for k, val in pairs(v) do
				count = count + 1
				if count > Debug.SNAPSHOT_MAX_KEYS then
					out["<truncated>"] = true
					break
				end
				local kt = type(k)
				local key = (kt == "string" or kt == "number" or kt == "boolean") and k or tostring(k)
				out[key] = snap(val, d - 1)
			end
			seen[v] = nil -- only cut real cycles, not tables shared by two branches
			return out
		end
		return snap(value, depth or Debug.SNAPSHOT_DEPTH)
	end

	--- Save client info and the addon's state (opts.dump) to db.debug.dump.
	---@return table
	function Debug.Dump()
		local data = { time = now(), meta = Debug.Meta() }
		if options.dump then
			local ok, result = pcall(options.dump)
			data.state = ok and Debug.Snapshot(result) or ("dump failed: " .. tostring(result))
		end
		state.dump = data
		Debug.Log("dump saved")
		return data
	end

	--- Store an error, merging repeats of the same message.
	---@return table entry, boolean isNew
	function Debug.RecordError(message, stack, locals)
		message = tostring(message)
		local errors = state.errors
		for _, entry in ipairs(errors) do
			if entry.message == message then
				entry.count = entry.count + 1
				entry.lastTime = now()
				return entry, false
			end
		end
		if type(locals) == "string" and #locals > Debug.LOCALS_MAX_CHARS then
			locals = locals:sub(1, Debug.LOCALS_MAX_CHARS) .. "\n...(truncated)"
		end
		local entry = {
			message = message,
			stack = stack,
			locals = locals,
			count = 1,
			time = now(),
			meta = Debug.Meta(),
		}
		errors[#errors + 1] = entry
		while #errors > Debug.ERRORS_MAX do
			table.remove(errors, 1)
		end
		return entry, true
	end

	local function record(err, stack, locals)
		local _, isNew = Debug.RecordError(err, stack, locals)
		Debug.Log("ERROR", err)
		if isNew and not notified[tostring(err)] then
			notified[tostring(err)] = true
			chat("|cffff5555hit an error.|r Type " .. (options.slash or "") .. " errors to copy a report.")
		end
	end

	local function errorHandler(err)
		-- Capture first, called directly so the levels hold: level 1 is this handler,
		-- level 2 is where the error was raised.
		local stack = debugstack and debugstack(2) or nil
		local locals = debuglocals and debuglocals(2) or nil
		-- A bug in our own recording must never swallow the original error.
		pcall(record, err, stack, locals)
		-- Pass it on (BugSack/BugGrabber or Blizzard's error frame) while the original stack is live.
		local handler = geterrorhandler and geterrorhandler()
		if handler then
			handler(err)
		end
		return err
	end

	--- Call fn(...) and record any error instead of letting it escape. Returns fn's results, or
	--- nothing if it failed.
	function Debug.Call(fn, ...)
		local args = pack(...)
		local results = pack(xpcall(function()
			return fn(unpack(args, 1, args.n))
		end, errorHandler))
		if not results[1] then
			return
		end
		return unpack(results, 2, results.n)
	end

	--- Wrap a function (event handler, OnClick, slash handler...) with Debug.Call.
	function Debug.Wrap(fn)
		return function(...)
			return Debug.Call(fn, ...)
		end
	end

	--- Plain-text report of the recorded errors, newest first, for pasting into a bug report.
	---@param maxErrors integer|nil
	---@return string
	function Debug.FormatReport(maxErrors)
		local m = Debug.Meta()
		local lines = {
			string.format("Addon: %s %s (Ordaen Core %s)", m.addon, m.addonVersion, tostring(m.core)),
			string.format("Client: %s (build %s, %s), interface %s, locale %s",
				tostring(m.client), tostring(m.build), tostring(m.buildDate), tostring(m.interface), tostring(m.locale)),
			"Report time: " .. now(),
		}
		local errors = state.errors
		if #errors == 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "No errors recorded."
		end
		local shown = 0
		for i = #errors, 1, -1 do
			if maxErrors and shown >= maxErrors then
				lines[#lines + 1] = ""
				lines[#lines + 1] = string.format("(%d older errors not shown)", i)
				break
			end
			shown = shown + 1
			local e = errors[i]
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format("==== Error %d: x%d, first %s%s", shown, e.count, e.time,
				e.lastTime and (", last " .. e.lastTime) or "")
			if e.meta and e.meta.addonVersion ~= m.addonVersion then
				lines[#lines + 1] = "(raised by version " .. tostring(e.meta.addonVersion) .. ")"
			end
			lines[#lines + 1] = e.message
			if e.stack then
				lines[#lines + 1] = "-- stack:"
				lines[#lines + 1] = e.stack
			end
			if e.locals then
				lines[#lines + 1] = "-- locals:"
				lines[#lines + 1] = e.locals
			end
		end
		return table.concat(lines, "\n")
	end

	local reportFrame

	local function setReadOnly(editBox, getText)
		editBox:SetScript("OnTextChanged", function(self, userInput)
			if userInput then
				self:SetText(getText())
				self:HighlightText()
			end
		end)
		editBox:SetScript("OnEditFocusGained", function(self)
			self:HighlightText()
		end)
	end

	local function buildReportFrame()
		local backdrop = BackdropTemplateMixin and "BackdropTemplate" or nil
		local f = CreateFrame("Frame", addonName .. "DebugReport", UIParent, backdrop)
		f:SetSize(680, 440)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:SetClampedToScreen(true)
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		if f.SetBackdrop then
			f:SetBackdrop({
				bgFile = "Interface/Tooltips/UI-Tooltip-Background",
				edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
				edgeSize = 16,
				insets = { left = 4, right = 4, top = 4, bottom = 4 },
			})
			f:SetBackdropColor(0, 0, 0, 0.92)
		end
		table.insert(UISpecialFrames, f:GetName()) -- Escape closes it

		local heading = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		heading:SetPoint("TOPLEFT", 14, -12)
		heading:SetText(title() .. " error report")

		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -2, -2)

		local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
		hint:SetText("Press Ctrl+C to copy the report, then paste it into a bug report at:")

		local url = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
		url:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -4)
		url:SetPoint("RIGHT", f, "RIGHT", -16, 0)
		url:SetHeight(20)
		url:SetAutoFocus(false)
		url:SetText(Debug.ISSUE_URL)
		url:SetCursorPosition(0)
		setReadOnly(url, function()
			return Debug.ISSUE_URL
		end)
		url:SetScript("OnEscapePressed", function()
			f:Hide()
		end)

		local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", url, "BOTTOMLEFT", -6, -10)
		scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 12)

		local text = CreateFrame("EditBox", nil, scroll)
		text:SetMultiLine(true)
		text:SetAutoFocus(false)
		text:SetFontObject(ChatFontNormal)
		text:SetWidth(620)
		text:SetScript("OnEscapePressed", function()
			f:Hide()
		end)
		setReadOnly(text, function()
			return f.reportText or ""
		end)
		scroll:SetScrollChild(text)

		f.text = text
		f:Hide()
		return f
	end

	--- Open a window with the error report selected, ready for Ctrl+C.
	function Debug.ShowReport()
		reportFrame = reportFrame or buildReportFrame()
		reportFrame.reportText = Debug.FormatReport(10)
		reportFrame:Show()
		reportFrame.text:SetText(reportFrame.reportText)
		reportFrame.text:SetCursorPosition(0)
		reportFrame.text:SetFocus()
		reportFrame.text:HighlightText()
	end

	--- Help lines for the addon's own /<cmd> help output.
	function Debug.HelpLines()
		local s = options.slash or ""
		return {
			s .. " debug [on||off||echo||clear] - debug log, saved on /reload",
			s .. " dump - save the addon's current state, saved on /reload",
			s .. " errors [clear] - show a copyable error report",
		}
	end

	--- Handle the debug subcommands of the addon's slash command.
	---@param msg string the slash command's argument text
	---@return boolean handled false if msg is not a debug command
	function Debug.HandleSlash(msg)
		local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
		cmd, rest = cmd:lower(), rest:lower()

		if cmd == "debug" then
			if rest == "" then
				state.enabled = not state.enabled
			elseif rest == "on" then
				state.enabled = true
			elseif rest == "off" then
				state.enabled = false
			elseif rest == "echo" then
				state.echo = not state.echo
				chat("debug echo to chat is " .. (state.echo and "on" or "off") .. ".")
				return true
			elseif rest == "clear" then
				state.log = {}
				state.dump = nil
				chat("debug log cleared.")
				return true
			elseif rest == "error" then
				-- Exercise the whole error pipeline: record, chat notice, BugSack, report window.
				Debug.Call(error, "test error from " .. (options.slash or "") .. " debug error")
				return true
			else
				return false
			end
			if state.enabled then
				Debug.Log("---- debug enabled")
			end
			chat("debug logging is " .. (state.enabled and "|cffffff00on|r" or "off") .. ". /reload writes it to disk.")
			return true
		elseif cmd == "dump" then
			Debug.Dump()
			chat("state saved. /reload to write it to disk.")
			return true
		elseif cmd == "errors" then
			if rest == "clear" then
				state.errors = {}
				notified = {}
				chat("errors cleared.")
			else
				Debug.ShowReport()
			end
			return true
		end
		return false
	end

	return Debug
end
