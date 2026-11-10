-- Ordaen Tooltips (design: wow-dev-tools design/tooltips): every tooltip in the one Ordaen skeleton, in place of
-- Blizzard's. Blizzard's tooltips keep their content and owners (every addon that fills them works as before):
-- Ordaen keeps them invisible for the shows drawn here (game.Tooltip, Core) and this module draws its own where
-- Blizzard placed them, from the game's tooltip data and its APIs (read.lua). Each tooltip type has its own switch:
-- off, that type stays Blizzard's, unchanged.
-- Other modules add lines through the module's API (design «API for other addons»):
--   Tooltips:OnTooltip(kind, fn)   fn(tip, model) on each build of a tooltip of that kind ("item", "spell", "aura",
--                                  "unit", "object"); tip:AddLine(text), tip:AddFooter(label, value), tip:AddNote(text),
--                                  tip:AddKey(text). Handlers answer only for what they own, and make no tables.
local Define = import("@ordaen/define")
local L = import("locales")
local Read = import("read")

-- Blizzard's tooltips drawn here: the main one, the linked item's, the comparison ones
local NATIVES = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local COMPARE = { ShoppingTooltip1 = true, ShoppingTooltip2 = true }
-- the lock (design «Tooltips in tooltips»): the main tooltip charges for 1 s in STEPS while the mouse stays on what
-- it describes, then locks; a locked group closes GRACE s after the mouse leaves it (unless it comes back)
local STEPS, STEP = 20, 1 / 20
local GRACE = 0.22

---@enum OrdaenTooltipsPlace
local Place = { Corner = "corner", Anchor = "anchor" } -- where an item's tooltip shows: the game's corner, beside it

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

-- what a button's tooltip is beside: micro menu and action buttons (any bar addon's) name their binding or action
local function IsButton(owner)
	return owner and owner.IsObjectType and owner:IsObjectType("Button") and (rawget(owner, "commandName") ~= nil or
		(owner:IsObjectType("CheckButton") and rawget(owner, "action") ~= nil))
end

local function Views(game, self)
	for i = 1, #NATIVES do
		local name = NATIVES[i]
		local tip = game.Tooltip[name]
		if tip then
			local a = self.viewCalls[name].attributes
			a.anchor = self.anchors[name] or nil
			a.epoch = self.state.epoch
			a.locked = self.state.lock > 0 and self.kept[name] or nil
			a.kept = a.locked
			a.charge = name == "GameTooltip" and self.state.charge or nil
			local call = self.viewCalls[name]
			game.ui:View(game.Layer.Tooltip, call, name)
		end
	end
end

return Define.Module({
	title = "Ordaen Tooltips",
	icon = Define.Asset("Interface/Icons/INV_Misc_Note_01"),

	Setup = function(game, self)
		Define.Persistent({
			anchorToButtons = { type = "boolean", default = true, setting = true },
			itemsOn = { type = "boolean", default = true, setting = true },
			itemsAnchorBags = { type = "choice", choices = Place, default = Place.Corner, setting = true },
			itemsAnchorChar = { type = "choice", choices = Place, default = Place.Anchor, setting = true },
			itemsIlvl = { type = "boolean", default = true, setting = true },
			itemsId = { type = "boolean", default = false, setting = true },
			itemsCount = { type = "boolean", default = true, setting = true },
			itemsStack = { type = "boolean", default = true, setting = true },
			itemsCooldown = { type = "boolean", default = true, setting = true },
			spellsOn = { type = "boolean", default = true, setting = true },
			spellsId = { type = "boolean", default = false, setting = true },
			spellsCooldown = { type = "boolean", default = true, setting = true },
			aurasOn = { type = "boolean", default = true, setting = true },
			aurasId = { type = "boolean", default = false, setting = true },
			aurasCaster = { type = "boolean", default = true, setting = true },
			playersOn = { type = "boolean", default = true, setting = true },
			playersTarget = { type = "boolean", default = true, setting = true },
			playersRelation = { type = "boolean", default = true, setting = true },
			npcsOn = { type = "boolean", default = true, setting = true },
			npcsLoot = { type = "boolean", default = true, setting = true },
			objectsOn = { type = "boolean", default = true, setting = true },
		})
		Define.Ephemeral({
			epoch = { type = "number", default = 0 }, -- a comparison changed another view's rows
			charge = { type = "number", default = 0 }, -- the main tooltip's lock charging: 0 to STEPS
			lock = { type = "number", default = 0 }, -- the locked show of the main tooltip (its tip.shown), 0: none
		})
		local models, ctx, anchors, hooks = {}, { numbers = game.Numbers, L = L }, {}, {}
		self.models, self.anchors = models, anchors

		-- the settings Read follows, read plainly at each build
		local function Settings(owner)
			ctx.owner = owner
			ctx.itemsIlvl, ctx.itemsId = Define.Peek(self.state.itemsIlvl), Define.Peek(self.state.itemsId)
			ctx.itemsCount, ctx.itemsStack = Define.Peek(self.state.itemsCount), Define.Peek(self.state.itemsStack)
			ctx.itemsCooldown, ctx.spellsId = Define.Peek(self.state.itemsCooldown), Define.Peek(self.state.spellsId)
			ctx.spellsCooldown = Define.Peek(self.state.spellsCooldown)
			ctx.aurasId, ctx.aurasCaster = Define.Peek(self.state.aurasId), Define.Peek(self.state.aurasCaster)
			ctx.playersTarget = Define.Peek(self.state.playersTarget)
			ctx.playersRelation, ctx.npcsLoot = Define.Peek(self.state.playersRelation), Define.Peek(self.state.npcsLoot)
			local theme = game.Themes:Active()
			ctx.classNames = not theme or theme.values.classNames:Peek() ~= false
		end

		-- the other modules' lines (the API): written into the model being built
		local building
		local api = {}
		function api:AddLine(text) -- luacheck: ignore 212
			local body = building.body
			body.n = body.n + 1
			body[body.n] = body[body.n] or {}
			local entry = body[body.n]
			entry.left, entry.right, entry.color, entry.rightColor, entry.stat = text, nil, nil, nil, nil
		end
		function api:AddFooter(label, value) -- luacheck: ignore 212
			local foot = building.foot
			foot.n = foot.n + 1
			foot[foot.n] = foot[foot.n] or {}
			local entry = foot[foot.n]
			entry.left, entry.right, entry.valueColor = label, value, nil
		end
		function api:AddNote(text)
			self:AddFooter(text, nil)
		end
		function api:AddKey(text) -- luacheck: ignore 212
			local keys = building.keys
			keys.n = keys.n + 1
			keys[keys.n] = keys[keys.n] or {}
			keys[keys.n].text = text
		end

		-- where the tooltip goes (its settings): beside a button, a bag or character slot, or the game's place
		local function Beside(tip)
			local owner = tip.owner
			local name = owner and owner.GetName and owner:GetName()
			local place
			if Define.Peek(self.state.anchorToButtons) and IsButton(owner) then
				return { to = owner, point = "BOTTOM", relativePoint = "TOP" }
			elseif type(name) == "string" and name:find("^Character.+Slot$") then
				place = Define.Peek(self.state.itemsAnchorChar)
			elseif type(name) == "string" and (name:find("^ContainerFrame%d+Item") or name:find("^Bank")) then
				place = Define.Peek(self.state.itemsAnchorBags)
			end
			if place == Place.Anchor then
				return { to = owner, point = "TOPLEFT", relativePoint = "TOPRIGHT" }
			end
			return nil
		end

		local function Fill(tip)
			Settings(tip.owner)
			local model = models[tip.name]
			if not Read.Fill(model, tip.data, ctx) then
				return false
			end
			building = model
			local list = hooks[model.kind]
			for i = 1, list and #list or 0 do
				list[i](api, model)
			end
			if COMPARE[tip.name] then
				model.header = L.EQUIPPED
			end
			return true
		end

		-- the comparison: one equipped item, its differences on the hovered one; two, on each equipped one
		-- (`showing`: the one being shown now, not marked shown until its show is drawn)
		local function Compare(showing)
			local main = models.GameTooltip
			local one, two = game.Tooltip.ShoppingTooltip1, game.Tooltip.ShoppingTooltip2
			local a = one and (one == showing or one.shown:Peek() > 0) and models.ShoppingTooltip1
			local b = two and (two == showing or two.shown:Peek() > 0) and models.ShoppingTooltip2
			if not main or main.kind ~= "item" or not a then
				return
			end
			if b then
				Read.Compare(a, main, a, L, game.Numbers)
				Read.Compare(b, main, b, L, game.Numbers)
			else
				Read.Compare(main, main, a, L, game.Numbers, true)
			end
			self.state.epoch = Define.Peek(self.state.epoch) + 1
		end

		-- whether this show is drawn here: its type is on and its data reads (else it stays Blizzard's)
		local function Wants(tip)
			local kind = Read.Kind(tip.data)
			local switch = kind and SWITCH[kind]
			if not switch or not switch(self, tip) or not Fill(tip) then
				return false
			end
			anchors[tip.name] = Beside(tip)
			if COMPARE[tip.name] then
				Compare(tip)
			end
			return true
		end

		self.viewCalls = {}
		for i = 1, #NATIVES do
			local tip = game.Tooltip[NATIVES[i]]
			if tip then
				models[tip.name] = Read.NewModel()
				self.viewCalls[tip.name] = { attributes = { tip = tip, model = models[tip.name], refill = Fill } }
				tip:Take(Wants)
			end
		end

		-- the lock: GameTooltip's shows charge; locked, every view shown then stays until it closes
		local main = game.Tooltip.GameTooltip
		local kept, closed = {}, 0 -- the views kept by the lock; the show last closed (it doesn't charge again)
		self.kept = kept
		local function Close()
			closed = Define.Peek(self.state.lock)
			self.state.lock = 0
			self.state.charge = 0
		end
		local function Step()
			local n = Define.Peek(self.state.charge) + 1
			if n < STEPS then
				self.state.charge = n
				return
			end
			for i = 1, #NATIVES do
				local tip = game.Tooltip[NATIVES[i]]
				kept[NATIVES[i]] = tip and tip.shown:Peek() > 0 or nil
			end
			self.state.charge = STEPS
			self.state.lock = main.shown:Peek()
		end
		if main then
			self:Watch(function()
				local shown, lock = main.shown:Get(), self.state.lock
				if shown > 0 and lock ~= 0 and shown ~= lock then
					Close() -- another tooltip starts: the locked one goes
					return
				end
				if shown > 0 and lock == 0 and shown ~= closed then
					self.state.charge = 0
					self:Every(STEP, Step)
				elseif lock == 0 then
					self.state.charge = 0
				end
			end)
		end
		-- the mouse leaving the locked group closes it after the grace, unless it came back
		local leaving, leftAt = false, 0
		local function CloseIfLeft()
			if leaving and GetTime() - leftAt >= GRACE - 0.01 then
				leaving = false
				Close()
			end
		end
		local lockCalls = {
			OnClose = Close,
			OnEnter = function()
				leaving = false
			end,
			OnLeave = function()
				leaving, leftAt = true, GetTime()
				C_Timer.After(GRACE, CloseIfLeft)
			end,
		}
		for _, call in pairs(self.viewCalls) do
			call.attributes.OnClose, call.attributes.OnEnter = lockCalls.OnClose, lockCalls.OnEnter
			call.attributes.OnLeave = lockCalls.OnLeave
		end

		return {
			--- fn(tip, model) on each build of a tooltip of `kind`: tip:AddLine/AddFooter/AddNote/AddKey.
			OnTooltip = function(_, kind, fn)
				local list = hooks[kind]
				if not list then
					list = {}
					hooks[kind] = list
				end
				list[#list + 1] = fn
			end,
		}
	end,

	-- the settings page (design tooltips/settings): Общее, then a tab per tooltip type: its switch, the details under it
	Settings = function(game, self)
		game.ui:SettingsTab({ attributes = { title = L.TAB_GENERAL }, slots = { default = function()
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.anchorToButtons) } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_ITEMS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.itemsOn) } })
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.itemsAnchorBags),
				disabled = not self.state.itemsOn } })
			game.ui:Dropdown({ attributes = { value = Define.Signal(self.state.itemsAnchorChar),
				disabled = not self.state.itemsOn } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsIlvl),
					disabled = not self.state.itemsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsId),
					disabled = not self.state.itemsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsCount),
					disabled = not self.state.itemsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsStack),
					disabled = not self.state.itemsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsCooldown),
					disabled = not self.state.itemsOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_SPELLS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.spellsOn) } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.spellsId),
					disabled = not self.state.spellsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.spellsCooldown),
					disabled = not self.state.spellsOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_AURAS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.aurasOn) } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.aurasId),
					disabled = not self.state.aurasOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.aurasCaster),
					disabled = not self.state.aurasOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_PLAYERS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.playersOn) } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.playersTarget),
					disabled = not self.state.playersOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.playersRelation),
					disabled = not self.state.playersOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_NPCS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.npcsOn) } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.npcsLoot),
					disabled = not self.state.npcsOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_OBJECTS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.objectsOn) } })
		end } })
	end,

	Render = function(game, self)
		Views(game, self)
	end,
})
