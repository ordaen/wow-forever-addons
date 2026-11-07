-- Ordaen Tooltips: the native GameTooltip stays shown and keeps its content; we read it, draw ours in its place and
-- make it invisible. Anything secret stays native.
local helpers = require("tests.OrdaenCore.helpers")

-- A WoW object stand-in that records calls; methods return these defaults (what the UI renderer measures with).
local DEFAULTS = { GetUnboundedStringWidth = 40, GetStringHeight = 12, GetEffectiveScale = 1, SetFont = true,
	GetFrameLevel = 3 }
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
		local was = self.shown
		self.shown = false
		if was and self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
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

-- A font string of the native tooltip: text, colour, shown.
local function line(text, r, g, b)
	return stub("line", {
		GetText = function()
			return text
		end,
		GetTextColor = function()
			return r or 1, g or 1, b or 1
		end,
		IsShown = function()
			return text ~= nil
		end,
	})
end

describe("Ordaen Tooltips", function()
	local ns, frames, secrets, tooltip, left, right, data, bindings

	local function frameNamed(name)
		for _, f in ipairs(frames) do
			if f.name == name then
				return f
			end
		end
	end

	local function fire(event, arg)
		frames[1].scripts.OnEvent(frames[1], event, arg)
	end

	before_each(function()
		frames, secrets, data, bindings = {}, {}, nil, {}
		left, right = {}, {}
		tooltip = stub("GameTooltip", {
			NumLines = function()
				return #left
			end,
			GetLeftLine = function(_, i)
				return left[i]
			end,
			GetRightLine = function(_, i)
				return right[i]
			end,
			GetPoint = function()
				return "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -20, 20
			end,
			IsForbidden = function()
				return false
			end,
			GetTooltipData = function()
				return data
			end,
		})
		helpers.stubGlobals({
			CreateFrame = function(_, name)
				local f = stub(name or "anon")
				f.shown = true
				table.insert(frames, f)
				return f
			end,
			hooksecurefunc = function(obj, method, fn)
				local original = obj[method]
				obj[method] = function(...)
					local r = original and original(...)
					fn(...)
					return r
				end
			end,
			C_Timer = { After = function() end },
			GameTooltip = tooltip,
			GameTooltipStatusBar = stub("GameTooltipStatusBar"),
			Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2 } },
			C_Item = { GetItemIconByID = function(id)
				return id == 19019 and 135349 or nil
			end },
			C_Spell = { GetSpellTexture = function()
				return 136243
			end },
			ITEM_LEVEL = "Item Level %d",
			SELL_PRICE = "Sell Price:",
			GetMoneyString = function(copper)
				return copper .. "c"
			end,
			issecretvalue = function(v)
				return secrets[v] == true
			end,
			-- Blizzard's spell lines (enUS).
			MANA = "Mana", MANA_COST = "%d Mana", RAGE = "Rage", RAGE_COST = "%d Rage",
			SPELL_RANGE = "%s yd range", MELEE_RANGE = "Melee Range", MELEE = "Melee",
			SPELL_CAST_TIME_SEC = "%.3g sec cast", SPELL_CAST_TIME_INSTANT = "Instant", SPELL_ON_NEXT_SWING = "Next melee",
			SPELL_RECAST_TIME_SEC = "%.3g sec cooldown",
			-- The player's key bindings: command -> key.
			GetBindingKey = function(command)
				return bindings[command]
			end,
			GetBindingText = function(key)
				return (key:gsub("SHIFT%-", "Shift-"))
			end,
		})
		rawget(_G, "C_AddOns").LoadAddOn = function(name)
			assert.equals("OrdaenCore_UI", name)
			helpers.loadAddon("OrdaenCore/OrdaenCore_UI")
			return true
		end
		helpers.loadCore()
		ns = {}
		helpers.loadAddon("OrdaenTooltips", ns)
		fire("ADDON_LOADED", "OrdaenTooltips")
		fire("PLAYER_LOGIN")
	end)

	local function show(lines)
		left, right = {}, {}
		for i, l in ipairs(lines) do
			left[i] = line(l[1], l[3], l[4], l[5])
			right[i] = line(l[2])
		end
		tooltip:Show()
	end

	it("draws the native tooltip's lines in our view and makes the native one invisible", function()
		show({ { "Thunderfury", nil, 1, 0.5, 0 }, { "Binds when picked up" }, { "One-Hand", "Sword" } })
		local view = frameNamed("OrdaenTooltipsGameTooltip")
		assert.is_true(view.shown)
		assert.equals(0, tooltip.alpha)
		local described = ns.Takeover.Describe().GameTooltip
		assert.equals(3, described.rows)
		-- The view sits on the native tooltip's own corner, so it grows the same way.
		assert.same({ "BOTTOMRIGHT", tooltip, "BOTTOMRIGHT" }, view.calls.SetPoint[#view.calls.SetPoint])
	end)

	it("hides ours with the native one", function()
		show({ { "Hogger" } })
		tooltip:Hide()
		assert.is_false(frameNamed("OrdaenTooltipsGameTooltip").shown)
	end)

	it("passes Blizzard's fades to our view and keeps the native one at 0", function()
		show({ { "Hogger" } })
		tooltip:SetAlpha(0.4)
		assert.equals(0, tooltip.alpha)
		assert.equals(0.4, frameNamed("OrdaenTooltipsGameTooltip").alpha)
	end)

	it("leaves a tooltip with secret values native", function()
		local text = "Hogger"
		secrets[text] = true
		show({ { text } })
		assert.is_false(frameNamed("OrdaenTooltipsGameTooltip").shown)
		assert.equals(1, tooltip.alpha)
	end)

	it("draws an item: its icon, its level as the subtitle, the sell price, a divider before addons' lines", function()
		data = { type = 0, id = 19019, lines = { {}, {}, {}, { price = 25000 } } }
		show({
			{ "Thunderfury", nil, 1, 0.5, 0 },
			{ "Item Level 80" },
			{ "One-Hand", "Sword" },
			{ "" },
			{ "Seen in 2 bags (Altoholic)" }, -- another addon's line, after the game's four
		})
		local d = ns.Takeover.Describe().GameTooltip
		assert.equals("Thunderfury", d.title)
		assert.equals("Item Level 80", d.subtitle)
		assert.equals(135349, d.icon)
		assert.equals("25000c", d.price)
		assert.equals(5, d.dividerAt)
	end)

	it("puts a spell's cost, range, cast and cooldown in columns under the title, out of its lines", function()
		data = { type = 1, id = 133, lines = { {}, {}, {}, {} } }
		show({
			{ "Fireball" },
			{ "30 Mana", "35 yd range" },
			{ "3.5 sec cast", "6 sec cooldown" },
			{ "Hurls a fiery ball that causes 50 Fire damage." },
		})
		local d = ns.Takeover.Describe().GameTooltip
		assert.same({ "30 / Mana", "35 yd / Range", "3.5 sec / Cast", "6 sec / Cooldown" }, d.stats)
		assert.equals(1, d.shownRows, "only the description is left as a line")
	end)

	it("shows only the stats a spell has, wordy ones as Blizzard writes them", function()
		data = { type = 1, id = 78, lines = { {}, {}, {}, {} } }
		show({ { "Heroic Strike" }, { "15 Rage", "Melee Range" }, { "Next melee" }, { "A strong attack." } })
		local d = ns.Takeover.Describe().GameTooltip
		assert.same({ "15 / Rage", "Melee / Range", "Next melee / Cast" }, d.stats)
		data = { type = 0, id = 19019, lines = { {}, {} } }
		tooltip:Hide()
		show({ { "Thunderfury" }, { "Item Level 80" } })
		assert.is_false(ns.Takeover.Describe().GameTooltip.stats, "no section on an item")
	end)

	it("shows a unit's level line as its subtitle and no icon", function()
		data = { type = 2, lines = { {}, {}, {} } }
		show({ { "Hogger", nil, 1, 0.1, 0.1 }, { "Level 11 Elite Gnoll" }, { "Riverpaw" } })
		local d = ns.Takeover.Describe().GameTooltip
		assert.equals("Level 11 Elite Gnoll", d.subtitle)
		assert.is_false(d.icon)
		assert.is_false(d.dividerAt) -- every line is the game's: no divider
	end)

	describe("on buttons", function()
		-- A button the tooltip belongs to: a micro button (its binding command) or an action button (a CheckButton
		-- with an action), at height `y`.
		local function button(kind, fields, y)
			local b = stub(fields.name or "Button", fields)
			b.IsObjectType = function(_, t)
				return t == "Button" or (kind == "CheckButton" and t == "CheckButton")
			end
			b.GetCenter = function()
				return 500, y
			end
			return b
		end

		local function hoverOver(owner)
			tooltip.GetOwner = function()
				return owner
			end
		end

		before_each(function()
			rawget(_G, "UIParent").GetHeight = function()
				return 1000
			end
		end)

		it("move a micro button's key out of its title into the hotkey", function()
			hoverOver(button("Button", { name = "CharacterMicroButton", commandName = "TOGGLECHARACTER0" }, 20))
			bindings.TOGGLECHARACTER0 = "C"
			show({ { "Character Info |cffffd200(C)|r" }, { "Your equipment and stats." } })
			local d = ns.Takeover.Describe().GameTooltip
			assert.equals("Character Info", d.title)
			assert.equals("C", d.hotkey)
		end)

		it("show an action button's key binding as the hotkey, a bar addon's click binding too", function()
			hoverOver(button("CheckButton", { name = "BT4Button1", action = 1 }, 20))
			bindings["CLICK BT4Button1:Keybind"] = "SHIFT-1"
			show({ { "Fireball" }, { "Hurls a fiery ball." } })
			assert.equals("Shift-1", ns.Takeover.Describe().GameTooltip.hotkey)
			bindings["CLICK BT4Button1:Keybind"] = nil -- unbound
			show({ { "Fireball" }, { "Hurls a fiery ball." } })
			assert.is_false(ns.Takeover.Describe().GameTooltip.hotkey)
		end)

		it("go beside the button: above it low on the screen, below it high up; off goes back to Blizzard's place", function()
			local low = button("CheckButton", { name = "ActionButton1", commandName = "ACTIONBUTTON1", action = 1 }, 20)
			hoverOver(low)
			show({ { "Fireball" } })
			local view = frameNamed("OrdaenTooltipsGameTooltip")
			local calls = view.calls.SetPoint
			local gap = OrdaenCore.UI.Space("sm")
			assert.same({ "BOTTOM", low, "TOP", 0, gap }, calls[#calls])
			local high = button("Button", { name = "QuestLogMicroButton", commandName = "TOGGLEQUESTLOG" }, 900)
			hoverOver(high)
			tooltip:Hide()
			show({ { "Quest Log" } })
			assert.same({ "TOP", high, "BOTTOM", 0, -gap }, calls[#calls])
			ns.Addon.db.anchorToButtons = false
			tooltip:Hide()
			show({ { "Quest Log" } })
			assert.same({ "BOTTOMRIGHT", tooltip, "BOTTOMRIGHT" }, calls[#calls], "Blizzard's place")
		end)

		it("leave tooltips of things that aren't buttons where Blizzard puts them (units in the world)", function()
			local world = stub("UIParent")
			world.IsObjectType = function(_, t)
				return t == "Frame"
			end
			hoverOver(world)
			show({ { "Hogger" } })
			local calls = frameNamed("OrdaenTooltipsGameTooltip").calls.SetPoint
			assert.same({ "BOTTOMRIGHT", tooltip, "BOTTOMRIGHT" }, calls[#calls])
		end)
	end)
end)
