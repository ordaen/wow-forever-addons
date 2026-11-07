-- Ordaen Panel's micro menu tooltips (MicroTips.lua): what a hover fills, in OrdaenCore.UI's shared sections
-- (UI.Stats, UI.Rows), with the shared fakes.
local helpers = require("tests.OrdaenCore.helpers")

describe("Ordaen Panel micro menu tooltips", function()
	local shown, hidden, durability, held, MicroTips

	-- A micro button: its name, Blizzard's title (with the key), and the scripts the tooltips hook.
	local function button(name)
		local b = { scripts = {}, tooltipText = "Character Info |cffffd200(C)|r", enabled = true }
		function b:GetName()
			return name
		end
		function b:IsEnabled()
			return self.enabled
		end
		function b:HookScript(script, fn)
			self.scripts[script] = fn
		end
		return b
	end

	-- The texts of a block's shown children, depth first (values through their format, like the renderer).
	local function texts(block, out)
		out = out or {}
		if block.hidden then
			return out
		end
		if block.text then
			out[#out + 1] = block.text
		elseif block.format then
			out[#out + 1] = string.format(block.format, unpack(block.args))
		end
		for _, child in ipairs(block) do
			texts(child, out)
		end
		return out
	end

	before_each(function()
		shown, hidden, held = nil, 0, true
		durability = { [5] = { 30, 100 }, [8] = { 90, 100 } }
		helpers.stubGlobals({
			GetAverageItemLevel = function()
				return 60.4, 58.4
			end,
			INVSLOT_FIRST_EQUIPPED = 1,
			INVSLOT_LAST_EQUIPPED = 19,
			GetInventoryItemDurability = function(slot)
				local d = durability[slot]
				if d then
					return d[1], d[2]
				end
			end,
			GetInventoryItemLink = function(_, slot)
				return "[Chest " .. slot .. "]"
			end,
			UnitStat = function(_, index)
				return 0, 100 + index
			end,
			SPELL_STAT1_NAME = "Strength", SPELL_STAT2_NAME = "Agility", SPELL_STAT3_NAME = "Stamina",
			SPELL_STAT4_NAME = "Intellect", SPELL_STAT5_NAME = "Spirit",
			STAT_AVERAGE_ITEM_LEVEL = "Item Level", DURABILITY = "Durability",
			GameTooltip = { Hide = function() end },
		})
		helpers.loadCore()
		local UI = OrdaenCore.UI
		-- the tooltip, recorded: its block and who it is shown for
		UI.Tooltip = function(block)
			local tip = { block = block }
			function tip:Show(owner)
				shown = { owner = owner, block = self.block, hotkey = self.hotkey }
			end
			function tip:Hide()
				hidden = hidden + 1
			end
			return tip
		end
		UI.Binding = function()
			return nil
		end
		local ns = {
			L = setmetatable({ MT_MOST_WORN = "%s is at %d%%" }, { __index = function(_, k)
				return k
			end }),
			View = { Holds = function()
				return held
			end },
			Addon = { Debug = { Warnf = function(_, fmt, ...)
				error(fmt:format(...))
			end, IsEnabled = function()
				return false
			end } },
		}
		assert(loadfile("addons/OrdaenPanel/MicroTips.lua"))("OrdaenPanel", ns)
		MicroTips = ns.MicroTips
	end)

	it("shows the character's item level, durability, attributes and most worn item in sections", function()
		local b = button("CharacterMicroButton")
		MicroTips.Attach(b)
		b.scripts.OnEnter(b)
		assert.equals(b, shown.owner)
		assert.same({ "Character Info", "58.4", "Item Level", "30%", "Durability", "Strength", "101", "Agility", "102",
			"Stamina", "103", "Intellect", "104", "Spirit", "105", "[Chest 5] is at 30%" }, texts(shown.block))
		-- every part after the title is a section (the theme's section gap above it), the tooltip itself has no gap
		assert.equals(0, shown.block.gap)
		for i = 2, #shown.block do
			assert.equals("section", shown.block[i].style)
		end
		b.scripts.OnLeave(b)
		assert.equals(1, hidden)
	end)

	it("empties the sections between hovers", function()
		local b = button("CharacterMicroButton")
		MicroTips.Attach(b)
		b.scripts.OnEnter(b)
		durability = {}
		b.scripts.OnEnter(b)
		assert.same({ "Character Info", "58.4", "Item Level", "Strength", "101", "Agility", "102", "Stamina", "103",
			"Intellect", "104", "Spirit", "105" }, texts(shown.block))
	end)

	it("leaves Blizzard's tooltip on a greyed-out button, a button given back, and one we have nothing for", function()
		local b = button("CharacterMicroButton")
		MicroTips.Attach(b)
		b.enabled = false
		b.scripts.OnEnter(b)
		assert.is_nil(shown)
		b.enabled, held = true, false
		b.scripts.OnEnter(b)
		assert.is_nil(shown)
		local spellbook = button("SpellbookMicroButton")
		MicroTips.Attach(spellbook)
		assert.is_nil(spellbook.scripts.OnEnter)
	end)
end)
