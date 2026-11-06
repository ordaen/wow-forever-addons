-- Ordaen Panel's segments (Segments.lua): what each reads from the game, with the shared fakes (stubs are checked
-- against the Forever API dump).
local helpers = require("tests.OrdaenCore.helpers")

describe("Ordaen Panel segments", function()
	local ns, changed, now, timers

	before_each(function()
		now, timers, changed = 100, {}, {}
		helpers.stubGlobals({
			GetTime = function()
				return now
			end,
			C_Timer = {
				After = function(delay, fn)
					timers[#timers + 1] = { at = now + delay, fn = fn }
				end,
			},
			C_FriendList = {
				GetNumOnlineFriends = function()
					return 3
				end,
			},
			BNGetNumFriends = function()
				return 10, 4
			end,
			IsInGuild = function()
				return true
			end,
			GetNumGuildMembers = function()
				return 120, 12, 14
			end,
			C_GuildInfo = { GuildRoster = function() end },
			GetMoney = function()
				return 1234567
			end,
			C_CurrencyInfo = {
				GetBackpackCurrencyInfo = function(i)
					local list = {
						{ name = "Honor", quantity = 450, iconFileID = 1 },
						{ name = "Marks", quantity = 12, iconFileID = 2 },
					}
					return list[i]
				end,
			},
			BACKPACK_CONTAINER = 0,
			NUM_BAG_SLOTS = 4,
			NUM_REAGENTBAG_SLOTS = 1,
			C_Container = {
				GetContainerNumFreeSlots = function(bag)
					return ({ [0] = 5, 2, 0, 3, 1, 7 })[bag] or 0
				end,
			},
			UnitLevel = function()
				return 42
			end,
			GetMaxPlayerLevel = function()
				return 60
			end,
			UnitXP = function()
				return 3000
			end,
			UnitXPMax = function()
				return 10000
			end,
			GetXPExhaustion = function()
				return 2000
			end,
			IsXPUserDisabled = function()
				return false
			end,
			C_Reputation = { GetWatchedFactionData = function() end },
			C_QuestLog = {
				GetNumQuestLogEntries = function()
					return 2
				end,
				GetInfo = function(i)
					return ({ { isHeader = true }, { questID = 7 } })[i]
				end,
				ReadyForTurnIn = function()
					return true
				end,
			},
			GetQuestLogRewardXP = function()
				return 500
			end,
		})
		ns = {}
		for _, file in ipairs({ "Data.lua", "Segments.lua" }) do
			assert(loadfile("addons/OrdaenPanel/" .. file))("OrdaenPanel", ns)
		end
		function ns.Changed(name)
			changed[#changed + 1] = name
		end
	end)

	it("counts friends (WoW and Battle.net) and guild members online", function()
		ns.Segments.social.update()
		local m = ns.Segments.social.model
		assert.same({ 3, 4, 12, 120, true }, { m.friends, m.bnet, m.guild, m.guildTotal, m.inGuild })
	end)

	it("reads gold and the backpack currencies into reused tables", function()
		local seg = ns.Segments.currencies
		seg.update()
		local m = seg.model
		assert.same({ 123, 45, 67, 2 }, { m.gold, m.silver, m.copper, m.count })
		local first = m.list[1]
		seg.update()
		assert.equals(first, m.list[1], "no new table per update")
		assert.equals("Marks", m.list[2].name)
	end)

	it("counts free slots in the bags and the reagent bag", function()
		ns.Segments.bags.update()
		assert.same({ 11, 7 }, { ns.Segments.bags.model.free, ns.Segments.bags.model.reagentFree })
	end)

	it("shows experience with quest XP, and counts the quest log once per burst", function()
		local seg = ns.Segments.experience
		seg.start()
		seg.update("PLAYER_XP_UPDATE")
		assert.same({ 3000, 3500, 5500 }, { seg.model.value, seg.model.quest, seg.model.overlay })
		assert.is_false(seg.update("QUEST_LOG_UPDATE"))
		assert.is_false(seg.update("QUEST_LOG_UPDATE"))
		assert.equals(1, #timers, "one count for the burst")
		timers[1].fn()
		assert.same({ "experience" }, changed)
	end)

	it("orders Blizzard's micro buttons as laid out, without hidden ones", function()
		local function button(name, left, top, shown)
			return {
				GetName = function()
					return name
				end,
				IsVisible = function()
					return shown ~= false
				end,
				GetLeft = function()
					return left
				end,
				GetTop = function()
					return top
				end,
			}
		end
		local out = { "stale", "stale", "stale", "stale", "stale" }
		ns.Micro.Order({
			button("GuildMicroButton", 60, 10),
			button("CharacterMicroButton", 0, 10),
			button("StoreMicroButton", 90, 10, false),
			button("SomeTexture", 5, 10),
			button("EJMicroButton", 30, 10),
			button("HelpMicroButton", 120, 10),
		}, { HelpMicroButton = true }, out)
		local names = {}
		for i, b in ipairs(out) do
			names[i] = b:GetName()
		end
		assert.same({ "CharacterMicroButton", "EJMicroButton", "GuildMicroButton" }, names)
	end)
end)
