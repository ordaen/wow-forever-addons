-- Ordaen Tooltips (design: wow-dev-tools design/tooltips): every tooltip in the one Ordaen skeleton, in place of
-- Blizzard's. Blizzard's tooltips keep their content and owners (every addon that fills them works as before):
-- Ordaen keeps them invisible for the shows drawn here (game.Tooltip, Core) and this module draws its own view where
-- Blizzard placed them, from the game's tooltip data (read.lua). Each tooltip type has its own switch: off, that
-- type stays Blizzard's, unchanged.
local Define = import("@ordaen/define")
local L = import("locales")
local Read = import("read")

-- Blizzard's tooltips drawn here: the main one, the linked item's, the comparison ones
local NATIVES = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
-- a tooltip kind (read.lua) -> whether its switch is on
local SWITCH = {
	item = function(self)
		return Define.Peek(self.state.itemsOn)
	end,
	spell = function(self)
		return Define.Peek(self.state.spellsOn)
	end,
	aura = function(self)
		return Define.Peek(self.state.aurasOn)
	end,
	-- a player's or an NPC's: each has its own switch
	unit = function(self, tip)
		local first = tip.data.lines[1]
		local unit = first and first.unitToken
		if type(unit) == "string" and UnitIsPlayer(unit) then
			return Define.Peek(self.state.playersOn)
		end
		return Define.Peek(self.state.npcsOn)
	end,
	object = function(self)
		return Define.Peek(self.state.objectsOn)
	end,
}

local function Views(game, self)
	for i = 1, #NATIVES do
		local name = NATIVES[i]
		local tip = game.Tooltip[name]
		if tip then
			game.ui:View(game.Layer.Tooltip, { attributes = { tip = tip, model = self.models[name] } }, name)
		end
	end
end

return Define.Module({
	title = "Ordaen Tooltips",
	icon = Define.Asset("Interface/Icons/INV_Misc_Note_01"),

	Setup = function(game, self)
		Define.Persistent({
			itemsOn = { type = "boolean", default = true, setting = true },
			spellsOn = { type = "boolean", default = true, setting = true },
			aurasOn = { type = "boolean", default = true, setting = true },
			playersOn = { type = "boolean", default = true, setting = true },
			npcsOn = { type = "boolean", default = true, setting = true },
			objectsOn = { type = "boolean", default = true, setting = true },
			itemsId = { type = "boolean", default = false, setting = true },
			itemsIlvl = { type = "boolean", default = true, setting = true },
			spellsId = { type = "boolean", default = false, setting = true },
			aurasId = { type = "boolean", default = false, setting = true },
		})
		local models, settings = {}, { numbers = game.Numbers, L = L }
		self.models = models
		-- whether this show is drawn here: its type is on and its data reads (else it stays Blizzard's)
		local function Wants(tip)
			local kind = Read.Kind(tip.data)
			local switch = kind and SWITCH[kind]
			if not switch or not switch(self, tip) then
				return false
			end
			settings.itemsId = Define.Peek(self.state.itemsId)
			settings.itemsIlvl = Define.Peek(self.state.itemsIlvl)
			settings.spellsId = Define.Peek(self.state.spellsId)
			settings.aurasId = Define.Peek(self.state.aurasId)
			return Read.Fill(models[tip.name], tip.data, settings)
		end
		for i = 1, #NATIVES do
			local tip = game.Tooltip[NATIVES[i]]
			if tip then
				models[tip.name] = Read.NewModel()
				tip:Take(Wants)
			end
		end
	end,

	-- the settings page (design tooltips/settings): a tab per tooltip type with its switch, the type's details under it
	Settings = function(game, self)
		game.ui:SettingsTab({ attributes = { title = L.TAB_ITEMS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.itemsOn) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsIlvl),
				disabled = not self.state.itemsOn } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsId),
				disabled = not self.state.itemsOn } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_SPELLS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.spellsOn) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.spellsId),
				disabled = not self.state.spellsOn } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_AURAS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.aurasOn) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.aurasId),
				disabled = not self.state.aurasOn } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_PLAYERS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.playersOn) } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_NPCS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.npcsOn) } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_OBJECTS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.objectsOn) } })
		end } })
	end,

	Render = function(game, self)
		Views(game, self)
	end,
})
