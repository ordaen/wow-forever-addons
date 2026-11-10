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
local floor = math.floor
local Read = import("read")
Read.racials = import("racials")
local HELP_CURSOR = import("cursor")

-- Blizzard's tooltips drawn here: the main one, the linked item's, the comparison ones
local NATIVES = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local COMPARE = { ShoppingTooltip1 = true, ShoppingTooltip2 = true }
-- the lock (design «Tooltips in tooltips»): after DELAY s on what it describes (a passing mouse sees no bar) the main
-- tooltip charges for CHARGE s, then locks; the bar's fill is the charge in STEPS (per cent), read from the clock at
-- each frame while it charges; a locked group closes GRACE s after the mouse leaves it (unless it comes back)
local DELAY, CHARGE, STEPS, STEP = 0.18, 1, 100, 0
local GRACE = 0.22
local REFRESH = 0.1 -- a hide shorter than this is Blizzard refreshing the tooltip, not the mouse leaving

-- what a link opens: our spell links (a description's spell names), the game's item and spell links
local function DataOf(link)
	local id = link:match("^ordaen:spell:(%d+)")
	if id then
		return C_TooltipInfo.GetSpellByID(tonumber(id))
	end
	if link:find("^item:") or link:find("^spell:") then
		return C_TooltipInfo.GetHyperlink(link)
	end
	local unit = link:match("^unit:(.+)$")
	if unit then
		return UnitExists(unit) and C_TooltipInfo.GetUnit(unit) or nil
	end
	return nil
end

---@enum OrdaenTooltipsPlace
local Place = { Corner = "corner", Anchor = "anchor" } -- where an item's tooltip shows: the game's corner, beside it
local Anchored -- below: a tooltip's anchor beside its owner

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

-- what a tooltip can sit beside: the frame it belongs to (a button of any bar, a slot, a micro menu button), not the
-- screen or the world (a unit in the world, a tooltip with no owner) and not a unit frame (those keep the game's
-- place); it must be on screen
local function Placeable(owner)
	if not owner or owner == UIParent or owner == WorldFrame or not owner.IsVisible or not owner:IsVisible() then
		return false
	end
	local unit = rawget(owner, "unit")
	if unit == nil and owner.GetAttribute then
		unit = owner:GetAttribute("unit")
	end
	return unit == nil and owner:GetCenter() ~= nil
end

-- beside its owner (design tooltips «Placement»): above it in the screen's lower half, below it in the upper half;
-- lined up on its right edge in the screen's right third, else on its left edge. A new table each show.
Anchored = function(owner)
	local x, y = owner:GetCenter()
	local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return { to = owner, below = y * scale > UIParent:GetHeight() / 2, right = x * scale > UIParent:GetWidth() * 2 / 3 }
end

local function Views(game, self)
	for i = 1, #NATIVES do
		local name = NATIVES[i]
		local tip = game.Tooltip[name]
		if tip and not COMPARE[name] then -- the comparison tooltips are the main one's (its group draws them)
			local a = self.viewCalls[name].attributes
			a.places = self.anchors -- read by the view at each show (its place is decided when it shows)
			a.epoch = self.state.epoch
			a.locked = self.state.lock > 0 and self.kept[name] or nil
			a.kept = a.locked
			a.charge = name == "GameTooltip" and self.chargeSignal or nil
			if name == "GameTooltip" then
				a.nest = self.state.nest
			end
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
			itemsAnchorBags = { type = "choice", choices = Place, default = Place.Anchor, setting = true },
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
			aurasTotal = { type = "boolean", default = true, setting = true },
			playersOn = { type = "boolean", default = true, setting = true },
			playersInspect = { type = "boolean", default = true, setting = true },
			playersTarget = { type = "boolean", default = true, setting = true },
			playersRelation = { type = "boolean", default = true, setting = true },
			npcsOn = { type = "boolean", default = true, setting = true },
			npcsParty = { type = "boolean", default = true, setting = true },
			npcsLoot = { type = "boolean", default = true, setting = true },
			npcsRep = { type = "boolean", default = true, setting = true },
			objectsOn = { type = "boolean", default = true, setting = true },
		})
		Define.Ephemeral({
			epoch = { type = "number", default = 0 }, -- a comparison changed another view's rows
			charge = { type = "number", default = 0 }, -- the main tooltip's lock charging: 0 to STEPS
			lock = { type = "number", default = 0 }, -- 1: the main tooltip's group is locked
			nest = { type = "number", default = 0 }, -- a tooltip opened from a link opened or closed
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
			ctx.aurasTotal = Define.Peek(self.state.aurasTotal)
			ctx.playersTarget = Define.Peek(self.state.playersTarget)
			ctx.playersInspect = Define.Peek(self.state.playersInspect)
			ctx.playersRelation, ctx.npcsLoot = Define.Peek(self.state.playersRelation), Define.Peek(self.state.npcsLoot)
			ctx.npcsParty, ctx.npcsRep = Define.Peek(self.state.npcsParty), Define.Peek(self.state.npcsRep)
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
			if type(name) == "string" and name:find("^Character.+Slot$") then
				place = Define.Peek(self.state.itemsAnchorChar)
			elseif type(name) == "string" and (name:find("^ContainerFrame%d+Item") or name:find("^Bank")) then
				place = Define.Peek(self.state.itemsAnchorBags)
			elseif Define.Peek(self.state.anchorToButtons) then
				place = Place.Anchor
			end
			if place == Place.Anchor and Placeable(owner) then
				return Anchored(owner)
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

		-- the spellbook's names: a description's spell names link to their tooltips
		self:On("SPELLS_CHANGED", Read.Spellbook)
		Read.Spellbook()
		Read.Schools(L)
		self:On("UPDATE_FACTION", Read.Factions)
		Read.Factions()

		-- inspecting players (design players «Spec and gear by inspect»): on demand when a player's tooltip shows, one
		-- at a time, throttled, never while the Inspect window is open; cached by GUID for INSPECT_TTL s, in memory
		local INSPECT_TTL, INSPECT_EVERY = 300, 1.5
		local GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 } -- no shirt (4), no tabard (19)
		local inspected, pending, asked = {}, nil, -INSPECT_EVERY
		function ctx.inspect(unit)
			local guid = UnitGUID(unit)
			local entry = guid and inspected[guid]
			if entry and GetTime() - entry.at < INSPECT_TTL then
				return entry
			end
			if not CanInspect(unit) then
				return nil, "no"
			elseif not CheckInteractDistance(unit, 1) then
				return nil, "far"
			end
			local window = rawget(_G, "InspectFrame")
			if not pending and GetTime() - asked >= INSPECT_EVERY and not (window and window:IsShown()) then
				pending, asked = guid, GetTime()
				NotifyInspect(unit)
			end
			return nil, "pending"
		end
		self:On("INSPECT_READY", function(guid)
			if guid ~= pending then
				return
			end
			pending = nil
			local unit = UnitTokenFromGUID(guid)
			if not unit then
				return
			end
			local entry = { at = GetTime() }
			local specID = GetInspectSpecialization(unit)
			if specID and specID > 0 then
				local _, name = GetSpecializationInfoByID(specID)
				entry.spec = name
			end
			local total, count = 0, 0
			for i = 1, #GEAR_SLOTS do
				local link = GetInventoryItemLink(unit, GEAR_SLOTS[i])
				local level = link and C_Item.GetDetailedItemLevelInfo(link)
				if level then
					total, count = total + level, count + 1
				end
			end
			entry.gear = count > 0 and floor(total / count + 0.5) or nil
			inspected[guid] = entry
			ClearInspectPlayer()
			-- the player's tooltip shows the result
			local main = game.Tooltip.GameTooltip
			if main and main.shown:Peek() > 0 and Fill(main) then
				self.state.epoch = Define.Peek(self.state.epoch) + 1
			end
		end)

		self.chargeSignal = Define.Signal(self.state.charge) -- the bar reads it: a step moves only the bar
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
		-- the views kept by the lock; what the main tooltip shows (its data's type and link, id or GUID: Blizzard shows
		-- the same thing again several times a second, an action button's or a bag item's, and that's one target that
		-- keeps charging); whether the target was closed (it doesn't charge again until something else shows)
		local kept, targetType, targetId, closed = {}, nil, nil, false
		self.kept = kept
		-- the tooltips opened from links: their models by depth (`n` open), whether the mouse is on each, when the
		-- link that opened the next was left
		-- (`nested.at[d]`: the frame of the text that opened it, which it opens at)
		local nested = { n = 0, at = {} }
		local function Truncate(depth)
			if nested.n > depth then
				nested.n = depth
				self.state.nest = Define.Peek(self.state.nest) + 1
			end
		end
		local function Close()
			closed = true
			self.state.lock = 0
			self.state.charge = 0
			Truncate(0)
			ResetCursor() -- a term's help cursor: its text goes without an OnLeave
		end
		-- Blizzard hides and shows a button's tooltip again as it refreshes it: only a hide that lasts ends the charge
		local hiddenAt = 0
		local function EndIfHidden()
			if main.shown:Peek() == 0 and Define.Peek(self.state.lock) == 0 and GetTime() - hiddenAt >= REFRESH - 0.01 then
				self.state.charge = 0
				targetType, targetId, closed = nil, nil, false
			end
		end
		local started = 0 -- when the target began to show
		local function Step()
			local n = math.floor((GetTime() - started - DELAY) / CHARGE * STEPS)
			if n < STEPS then
				if n > 0 and n ~= Define.Peek(self.state.charge) then
					self.state.charge = n
				end
				return
			end
			for i = 1, #NATIVES do
				local tip = game.Tooltip[NATIVES[i]]
				kept[NATIVES[i]] = tip and tip.shown:Peek() > 0 or nil
			end
			self.state.charge = STEPS
			self.state.lock = 1
		end
		if main then
			self:Watch(function()
				local shown, lock = main.shown:Get(), self.state.lock
				if shown == 0 then
					if lock == 0 then -- hidden: the charge ends unless it's back within REFRESH (a refresh)
						hiddenAt = GetTime()
						C_Timer.After(REFRESH, EndIfHidden)
					end
					return
				end
				local data = main.data
				local id = data and (data.hyperlink or data.guid or data.id)
				if data and (data.type ~= targetType or id ~= targetId) then
					if lock ~= 0 then
						Close() -- another tooltip starts: the locked one goes
					end
					targetType, targetId, closed = data.type, id, false
					self.state.charge = 0
					started = GetTime()
				end
				if lock == 0 and not closed then
					self:Every(STEP, Step) -- every frame; the same target shown again keeps its charge
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
		-- a term or link hovered in the locked group opens its tooltip at the text; it takes no mouse and goes as the
		-- mouse leaves the text (design: a tooltip's tooltips never hold the mouse)
		local links = {}
		local function Open(link)
			local model = nested[1] or Read.NewModel()
			nested[1] = model
			-- a term's glossary entry (ordaen:term:key:amount), else what the game's data says of the link
			local key, amount = link:match("^ordaen:term:([^:]+):(.*)$")
			local building = link:match("^ordaen:camp:(.+)$")
			local raceID, classID, raceName = link:match("^ordaen:race:(%d+):(%d+):(.*)$")
			if raceID then -- a race's racial abilities
				if not Read.Race(model, tonumber(raceID), tonumber(classID), raceName) then
					return
				end
			elseif building then -- a camp building's full sentence
				if not Read.Text(model, building, Read.camp[building]) then
					return
				end
			elseif key then
				if not Read.Term(model, key, amount ~= "" and amount or nil, L) then
					return
				end
			else
				local data = DataOf(link)
				Settings(nil)
				if not data or not Read.Fill(model, data, ctx) then
					return
				end
			end
			nested.n = 1
			self.state.nest = Define.Peek(self.state.nest) + 1
		end
		links[0] = function(link, entered)
			-- a link's text shows the question-mark cursor, as a term does (TermText)
			if entered then
				SetCursor(HELP_CURSOR)
			else
				ResetCursor()
			end
			if entered then
				-- the text's own frame, under the mouse now: the tooltip opens at it
				local foci = GetMouseFoci()
				nested.at[1] = foci and foci[1] or nil
				Open(link)
			else
				Truncate(0)
			end
		end
		local mainCall = self.viewCalls.GameTooltip
		if mainCall then
			mainCall.attributes.nested = nested
			-- the comparison tooltips: drawn in the main one's group, on its right (each its tip and model)
			local compares = {}
			for name in pairs(COMPARE) do
				local tip = game.Tooltip[name]
				if tip then
					compares[#compares + 1] = { tip = tip, model = models[name], name = name,
						call = { attributes = { side = false } } }
				end
			end
			table.sort(compares, function(x, y)
				return x.name < y.name
			end)
			mainCall.attributes.compares, mainCall.attributes.keptBy = compares, kept
		end
		for _, call in pairs(self.viewCalls) do
			call.attributes.links = links
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
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.aurasTotal),
					disabled = not self.state.aurasOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_PLAYERS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.playersOn) } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.playersInspect),
					disabled = not self.state.playersOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.playersTarget),
					disabled = not self.state.playersOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.playersRelation),
					disabled = not self.state.playersOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_NPCS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.npcsOn) } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.npcsParty),
					disabled = not self.state.npcsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.npcsLoot),
					disabled = not self.state.npcsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.npcsRep),
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
