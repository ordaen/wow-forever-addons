-- Ordaen Chat: the default tabs (once per character, through Blizzard's chat window API), new channels sorted into
-- the Channels tab, whispers in their own tabs, and the input group (Blizzard's chat menu button next to the input).
local helpers = require("tests.OrdaenCore.helpers")

-- A WoW object stand-in that records calls; methods return these defaults (what the UI renderer measures with).
local DEFAULTS = { GetUnboundedStringWidth = 40, GetStringHeight = 12, GetEffectiveScale = 1, SetFont = true,
	GetFrameLevel = 3, GetWidth = 300, GetHeight = 24, GetNumPoints = 0 }
local function stub(name, extra)
	local obj = { name = name, calls = {}, scripts = {}, shown = false }
	setmetatable(obj, { __index = function(self, method)
		if not helpers.isStubMethod(method) then
			return nil
		end
		local fn = function(_, ...)
			self.calls[method] = self.calls[method] or {}
			table.insert(self.calls[method], { ... })
			return DEFAULTS[method]
		end
		rawset(self, method, fn)
		return fn
	end })
	function obj:Show()
		local was = self.shown
		self.shown = true
		if not was and self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function obj:Hide()
		self.shown = false
	end
	function obj:IsShown()
		return self.shown
	end
	function obj:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function obj:HookScript(script, fn)
		local before = self.scripts[script]
		self.scripts[script] = before and function(...)
			before(...)
			fn(...)
		end or fn
	end
	function obj:GetName()
		return self.name
	end
	function obj:SetAlpha(a)
		self.alpha = a
	end
	function obj:GetAlpha()
		return self.alpha or 1
	end
	function obj:IsObjectType(kind)
		return kind == self.kind
	end
	function obj:GetRegions() end
	function obj:GetChildren() end
	function obj:SetParent(p)
		self.parent = p
	end
	function obj:GetParent()
		return self.parent
	end
	function obj:SetPoint(...)
		self.point = { ... }
	end
	function obj:CreateFontString()
		return stub(name .. ".font")
	end
	function obj:CreateTexture()
		return stub(name .. ".texture")
	end
	for k, v in pairs(extra or {}) do
		rawset(obj, k, v)
	end
	return obj
end

-- A chat window like ChatFrameMixin's: message groups and channels, saved by the game (here: in the table).
local function chatWindow(i, title, shown)
	local w = stub("ChatFrame" .. i)
	w.title, w.open = title, shown
	w.messageTypeList, w.channelList = {}, {}
	function w:RemoveAllMessageGroups()
		self.messageTypeList = {}
	end
	function w:AddMessageGroup(group)
		table.insert(self.messageTypeList, group)
	end
	function w:ContainsChannel(channel)
		for _, c in ipairs(self.channelList) do
			if c == channel then
				return true
			end
		end
		return false
	end
	function w:AddChannel(channel)
		table.insert(self.channelList, channel)
	end
	function w:RemoveChannel(channel)
		for k, c in ipairs(self.channelList) do
			if c == channel then
				table.remove(self.channelList, k)
				return
			end
		end
	end
	w.editBox = stub("ChatFrame" .. i .. "EditBox", { GetFont = function()
		return "Fonts\\FRIZQT__.TTF", 14, ""
	end })
	w.isDocked = true
	function w:GetFont()
		return "Fonts\\FRIZQT__.TTF", 14, ""
	end
	return w
end

describe("Ordaen Chat", function()
	local ns, frames, windows, cvars, menuButton, channelButton, art, loaded, stack, windowArt, selectedWindow

	local function fire(event, ...)
		frames[1].scripts.OnEvent(frames[1], event, ...)
	end

	local function login()
		fire("ADDON_LOADED", "OrdaenChat")
		fire("PLAYER_LOGIN")
	end

	local function windowTitled(title)
		for _, w in ipairs(windows) do
			if w.open and w.title == title then
				return w
			end
		end
	end

	before_each(function()
		frames, windows, cvars, art, loaded, windowArt = {}, {}, {}, {}, {}, {}
		stack = "" -- who calls a claimed method: nobody's addon (Blizzard's own code) unless a test says so
		rawset(_G, "OrdaenChatDB", nil) -- SavedVariables: each test starts as a new character
		rawset(_G, "OrdaenChatCharDB", nil)
		local globals = {
			CreateFrame = function(_, name)
				local f = stub(name or "anon")
				f.shown = true
				table.insert(frames, f)
				return f
			end,
			hooksecurefunc = function(obj, method, fn)
				if type(obj) == "string" then
					obj, method, fn = _G, obj, method
				end
				local original = obj[method]
				rawset(obj, method, function(...)
					local r = original and original(...)
					fn(...)
					return r
				end)
			end,
			C_Timer = { After = function() end },
			debugstack = function()
				return stack
			end,
			NUM_CHAT_WINDOWS = 10,
			GENERAL = "General",
			GUILD = "Guild",
			CHANNELS = "Channels",
			GetChatWindowInfo = function(i)
				local w = windows[i]
				return w.title, 14, 0, 0, 0, 1, w.open, false, w.open
			end,
			FCF_OpenNewWindow = function(title)
				for _, w in ipairs(windows) do
					if not w.open then
						w.title, w.open = title, true
						return w
					end
				end
			end,
			FCF_SelectDockFrame = function() end,
			FCF_OpenTemporaryWindow = function() end,
			-- Blizzard's tab colours (the selection changed) and alert flashes (a message in a hidden tab).
			FCFTab_UpdateColors = function() end,
			FCF_StartAlertFlash = function() end,
			FCF_StopAlertFlash = function() end,
			GeneralDockManager = stub("GeneralDockManager"),
			FCFDock_GetSelectedWindow = function()
				return selectedWindow
			end,
			GetChannelName = function()
				return 0
			end,
			C_CVar = {
				SetCVar = function(name, value)
					cvars[name] = value
					return true
				end,
				GetCVar = function(name)
					return cvars[name]
				end,
			},
		}
		for i = 1, 10 do
			local title = (i == 1 and "General") or (i == 2 and "Combat Log") or ""
			windows[i] = chatWindow(i, title, i <= 2)
			globals["ChatFrame" .. i] = windows[i]
			for _, part in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
				local texture = stub("ChatFrame" .. i .. "EditBox" .. part, { kind = "Texture" })
				art[#art + 1] = texture
				globals["ChatFrame" .. i .. "EditBox" .. part] = texture
			end
			-- The window's background (reaches past it) and its tab with the tab's name.
			local background = stub("ChatFrame" .. i .. "Background", { kind = "Texture" })
			globals["ChatFrame" .. i .. "Background"] = background
			windowArt[i] = background
			local label = stub("ChatFrame" .. i .. "TabText", { kind = "FontString", GetFont = function()
				return "Fonts\\FRIZQT__.TTF", 12, ""
			end })
			local tab = stub("ChatFrame" .. i .. "Tab", { GetFontString = function()
				return label
			end })
			tab.label = label
			globals["ChatFrame" .. i .. "Tab"] = tab
			windows[i].tab = tab
		end
		-- Blizzard's default: every channel shows in General.
		windows[1].channelList = { "General", "Trade", "LocalDefense" }
		windows[1].messageTypeList = { "SAY", "GUILD", "CHANNEL" }
		menuButton = stub("ChatFrameMenuButton", { GetWidth = function()
			return 26
		end })
		menuButton.parent = windows[1]
		menuButton.shown = true -- Blizzard shows it
		globals.ChatFrameMenuButton = menuButton
		channelButton = stub("ChatFrameChannelButton", { GetWidth = function()
			return 26
		end })
		channelButton.parent = windows[1]
		channelButton.shown = true
		globals.ChatFrameChannelButton = channelButton
		helpers.stubGlobals(globals)
		rawget(_G, "C_AddOns").IsAddOnLoaded = function(name)
			return loaded[name] == true
		end
		rawget(_G, "C_AddOns").LoadAddOn = function(name)
			assert.equals("OrdaenCore_UI", name)
			helpers.loadAddon("OrdaenCore/OrdaenCore_UI")
			return true
		end
		helpers.loadCore()
		ns = {}
		helpers.loadAddon("OrdaenChat", ns)
	end)

	after_each(function()
		assert.same({}, helpers.forwarded) -- no error was caught and reported on the way
	end)

	describe("tabs", function()
		it("set up General, Guild and Channels at the first login, and leave Combat Log alone", function()
			login()
			local general, guild, channels = windows[1], windowTitled("Guild"), windowTitled("Channels")
			assert.truthy(guild)
			assert.truthy(channels)
			assert.same({}, windows[2].messageTypeList) -- Combat Log untouched
			assert.same({ "GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "GUILD_DISCORD" }, guild.messageTypeList)
			assert.same({ "CHANNEL" }, channels.messageTypeList)
			assert.same({ "General", "LocalDefense", "Trade" }, channels.channelList)
			assert.same({}, general.channelList)
			for _, group in ipairs(general.messageTypeList) do
				assert.is_not.equals("GUILD", group)
				assert.is_not.equals("CHANNEL", group)
			end
			assert.equals(1, _G.OrdaenChatCharDB.tabLayout)
		end)

		it("open whispers in their own tabs", function()
			login()
			assert.equals("popout", cvars.whisperMode)
			assert.equals("popout", cvars.bnWhisperMode)
		end)

		it("are set up once: the player's own changes stay at the next login", function()
			rawset(_G, "OrdaenChatCharDB", { tabLayout = 1 })
			login()
			assert.is_nil(windowTitled("Guild"))
			assert.same({ "General", "Trade", "LocalDefense" }, windows[1].channelList)
			assert.is_nil(cvars.whisperMode)
		end)

		it("reuse a tab that already has the name", function()
			windows[3].title, windows[3].open = "Guild", true
			login()
			assert.equals(windows[3], windowTitled("Guild"))
			assert.equals("Channels", windows[4].title)
		end)

		it("say so when no chat window is free", function()
			for i = 3, 10 do
				windows[i].title, windows[i].open = "Tab" .. i, true
			end
			login()
			assert.is_nil(windowTitled("Channels"))
			assert.same({ "General", "Trade", "LocalDefense" }, windows[1].channelList) -- nothing moved
		end)

		it("give a channel its own tab with /ochat tab", function()
			login()
			SlashCmdList.ORDAENCHAT("tab trade")
			local trade = windowTitled("Trade")
			assert.truthy(trade)
			assert.same({ "Trade" }, trade.channelList)
			assert.same({ "CHANNEL" }, trade.messageTypeList)
			assert.is_false(windowTitled("Channels"):ContainsChannel("Trade"))
		end)
	end)

	describe("new channels", function()
		it("go to the Channels tab", function()
			login()
			windows[1]:AddChannel("LookingForGroup") -- Blizzard adds a joined channel to General
			fire("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", "", "", "", "", 0, 4, "LookingForGroup")
			assert.is_true(windowTitled("Channels"):ContainsChannel("LookingForGroup"))
			assert.is_false(windows[1]:ContainsChannel("LookingForGroup"))
		end)

		it("stay in a tab the player put them in", function()
			login()
			SlashCmdList.ORDAENCHAT("tab Trade")
			fire("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "", "", "", 0, 2, "Trade")
			assert.is_false(windowTitled("Channels"):ContainsChannel("Trade"))
		end)

		it("stay where they are with the setting off", function()
			rawset(_G, "OrdaenChatDB", { sortChannels = false })
			login()
			windows[1]:AddChannel("LookingForGroup")
			fire("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", "", "", "", "", 0, 4, "LookingForGroup")
			assert.is_true(windows[1]:ContainsChannel("LookingForGroup"))
		end)
	end)

	describe("input group", function()
		it("puts the chat menu button on the left of the input and hides the input's art", function()
			login()
			assert.equals(windows[1].editBox, menuButton.parent)
			assert.same({ "RIGHT", windows[1].editBox, "LEFT", -2, 0 }, menuButton.point)
			for _, texture in ipairs(art) do
				assert.equals(0, texture.alpha)
			end
		end)

		it("puts the channels button next to the chat menu, in the same group", function()
			login()
			assert.equals(windows[1].editBox, channelButton.parent)
			assert.same({ "RIGHT", menuButton, "LEFT", -2, 0 }, channelButton.point)
		end)

		it("follows the input that is shown", function()
			login()
			windows[3].editBox:Show()
			assert.equals(windows[3].editBox, menuButton.parent)
		end)

		it("puts the button back when Blizzard's layout moves it", function()
			login()
			menuButton:SetPoint("BOTTOM", windows[1], "TOP", 0, 0)
			assert.same({ "RIGHT", windows[1].editBox, "LEFT", -2, 0 }, menuButton.point)
		end)

		it("gives everything back when turned off", function()
			login()
			ns.Addon.db.inputGroup = false
			ns.Addon:_SettingChanged("inputGroup", false)
			assert.equals(windows[1], menuButton.parent)
			assert.equals(1, art[1].alpha)
		end)
	end)

	describe("conflicts", function()
		local function conflictWith(other)
			for _, c in ipairs(ns.Addon:Conflicts()) do
				if c.other == other then
					return c
				end
			end
		end

		it("with Prat: asked at login, input group and look stay off, tabs still set up", function()
			loaded["Prat-3.0"] = true
			login()
			local c = conflictWith("Prat-3.0")
			assert.truthy(c)
			assert.is_false(c.handled) -- the player is asked (Core's dialog)
			assert.equals(windows[1], menuButton.parent) -- we never took the button
			assert.is_nil(art[1].alpha)
			assert.is_nil(windowArt[1].alpha, "the chat's background stays Blizzard's (or the other addon's)")
			assert.is_false(ns.Look.Describe().on)
			assert.truthy(windowTitled("Channels"))
			assert.is_true(ns.Input.Describe().yielded)
		end)

		it("with an addon that moves the chat menu button later: it is named and keeps the button", function()
			login()
			stack = [[[string "@Interface/AddOns/Chattynator/Core.lua"]:120: in function 'Layout']]
			menuButton:SetPoint("TOPLEFT", windows[1], "TOPRIGHT", 0, 0)
			assert.truthy(conflictWith("Chattynator"))
			assert.same({ "TOPLEFT", windows[1], "TOPRIGHT", 0, 0 }, menuButton.point) -- not moved back
			assert.equals(1, art[1].alpha) -- our look is gone, the input's own art is back
		end)
	end)

	describe("look", function()
		it("dresses the windows and tabs in the theme, keeping Blizzard's sizes, with the theme's fonts", function()
			selectedWindow = windows[1]
			login()
			assert.equals(0, windowArt[1].alpha)
			assert.equals(0, windowArt[3].alpha) -- every window, also the ones opened for tabs
			assert.is_nil(windows[1].calls.SetSize, "Edit Mode keeps the window's size")
			local look = ns.Look.Describe()
			assert.equals("selected", look.tabs.ChatFrame1Tab)
			assert.equals("normal", look.tabs.ChatFrame2Tab)
			assert.truthy(windows[1].tab.label.calls.SetFont, "the tab's name in the theme's font")
			assert.truthy(windows[1].calls.SetFont, "the chat lines in the theme's font")
		end)

		it("follows Blizzard's tab selection and new-message flashes", function()
			selectedWindow = windows[1]
			login()
			FCF_StartAlertFlash(windows[2])
			assert.equals("flash", ns.Look.Describe().tabs.ChatFrame2Tab)
			selectedWindow = windows[2]
			FCFTab_UpdateColors(windows[2].tab, true)
			assert.equals("selected", ns.Look.Describe().tabs.ChatFrame2Tab)
			assert.equals("normal", ns.Look.Describe().tabs.ChatFrame1Tab)
		end)

		it("gives Blizzard's look back when turned off", function()
			login()
			ns.Addon.db.chatLook = false
			ns.Addon:_SettingChanged("chatLook", false)
			assert.equals(1, windowArt[1].alpha)
		end)
	end)
end)
