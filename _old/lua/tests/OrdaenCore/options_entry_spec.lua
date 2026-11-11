-- Ordaen in Blizzard's options (addons/OrdaenCore/Commands.lua) on the fake client, as built: at login it registers
-- one entry under Параметры → Модификации; choosing it opens Ordaen's settings window and closes Blizzard's panel.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("Ordaen's entry in Blizzard's options", function()
	it("is registered at login and opens the settings window, closing Blizzard's", function()
		local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenLibrary", "OrdaenSettings" } })
		local canvas, name, registered, hidden
		wow.env.Settings = {
			RegisterCanvasLayoutCategory = function(frame, title)
				canvas, name = frame, title
				return { title = title }
			end,
			RegisterAddOnCategory = function(category)
				registered = category
			end,
		}
		wow.env.SettingsPanel = wow.env.CreateFrame("Frame", nil, wow.env.UIParent)
		wow.env.HideUIPanel = function(frame)
			hidden = frame
		end
		wow:Login()
		local ns = wow.addons.OrdaenCore.ns
		assert.are.equal("Ordaen", name)
		assert.are.equal(name, registered.title)
		assert.is_nil(ns.App.Module("OrdaenSettings"))
		canvas:SetParent(wow.env.SettingsPanel) -- Blizzard's panel holds the category's canvas, shown when it's chosen
		canvas:Hide()
		canvas:Show()
		wow:Tick()
		local settings = ns.App.Module("OrdaenSettings")
		assert.is_truthy(settings and settings.root)
		assert.are.equal(wow.env.SettingsPanel, hidden)
		assert.are.same({}, wow.errors)
	end)

	it("doesn't open the window when Blizzard's panel opens on it, the category picked last", function()
		local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenLibrary", "OrdaenSettings" } })
		local canvas
		wow.env.Settings = {
			RegisterCanvasLayoutCategory = function(frame)
				canvas = frame
				return {}
			end,
			RegisterAddOnCategory = function() end,
		}
		local panel = wow.env.CreateFrame("Frame", nil, wow.env.UIParent)
		wow.env.SettingsPanel = panel
		wow.env.HideUIPanel = function() end
		wow:Login()
		panel:Hide()
		canvas:SetParent(panel)
		panel:Show() -- the panel opens (Esc → Параметры) with Ordaen's canvas shown in it
		assert.is_nil(wow.addons.OrdaenCore.ns.App.Module("OrdaenSettings"))
		assert.are.same({}, wow.errors)
	end)
end)
