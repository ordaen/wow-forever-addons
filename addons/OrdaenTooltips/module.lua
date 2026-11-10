-- Ordaen Tooltips (design: wow-dev-tools design/tooltips): every tooltip in the one Ordaen skeleton, in place of
-- Blizzard's. Blizzard's tooltips keep their content and owners (every addon that fills them works as before):
-- Ordaen keeps them invisible for the shows drawn here (game.Tooltip, Core) and this module draws its own where
-- Blizzard placed them, from the game's tooltip data and its APIs (read.lua). Each tooltip type has its own switch:
-- off, that type stays Blizzard's, unchanged.
-- Other modules extend tooltips through the module's API (design tooltips «API for other addons»): an event per kind
-- (Item, Spell, Aura, Player, Npc, Object, Text) fired on each build of such a tooltip, listened to with the filter
-- helper For, from a watch (it subscribes again when Tooltips comes back):
--   local Tooltips = game:UseModule("Tooltips")
--   self:Watch(function()
--     self:On(Tooltips.Item, Tooltips.For(filter, function(tip, model, owner) tip:AddRow(...) end))
--   end)
-- `filter`: nil (every one), a number (the item's, spell's or aura's id), a string (the owner frame's name), a frame
-- (that owner), a function(owner, model) returning true. `tip` adds to it: AddLine(text, color?) a body sentence,
-- AddRow(label, value, term?, valueColor?) a row, AddCell(text, glyph?, term?) a cell of the band, AddSection(title?)
-- the «More» section (this handler's lines and rows after it go there), AddFooter(label, value?) / AddNote(text) the
-- footer, AddKey(text) a hotkey line. DefineTerm(key, name, text): a glossary entry a `term` can name (a locked
-- tooltip opens it on that part). Handlers answer only for what they own, and make no tables per show.
local Define = import("@ordaen/define")
local L = import("locales")
local floor = math.floor
local Read = import("read")
Read.racials = import("racials")
Read.talents = import("talents")
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
-- the API's events by Read's kind (a unit: a player or an NPC)
local EVENTS = { item = "Item", spell = "Spell", aura = "Aura", player = "Player", npc = "Npc", object = "Object",
	text = "Text" }
local Anchored -- below: a tooltip's anchor beside its owner

-- a tooltip's type on the settings page (its tab): Read's kind, a unit split into a player or an NPC
local function TypeOf(kind, tip)
	if kind == "unit" then
		local first = tip.data and tip.data.lines and tip.data.lines[1]
		local unit = first and first.unitToken
		return type(unit) == "string" and UnitIsPlayer(unit) and "players" or "npcs"
	end
	return kind == "item" and "items" or kind == "spell" and "spells" or kind == "aura" and "auras"
		or kind == "object" and "objects" or kind == "text" and "texts" or nil
end
-- each type's «Включено» (off: that type stays Blizzard's) and «Подсказки в подсказках» (off: it never locks)
local ON = {
	items = function(self)
		return Define.Peek(self.state.itemsOn)
	end,
	spells = function(self)
		return Define.Peek(self.state.spellsOn)
	end,
	auras = function(self)
		return Define.Peek(self.state.aurasOn)
	end,
	players = function(self)
		return Define.Peek(self.state.playersOn)
	end,
	npcs = function(self)
		return Define.Peek(self.state.npcsOn)
	end,
	objects = function(self)
		return Define.Peek(self.state.objectsOn)
	end,
	texts = function(self)
		return Define.Peek(self.state.textsOn)
	end,
}
local LOCK = {
	items = function(self)
		return Define.Peek(self.state.itemsLock)
	end,
	spells = function(self)
		return Define.Peek(self.state.spellsLock)
	end,
	auras = function(self)
		return Define.Peek(self.state.aurasLock)
	end,
	players = function(self)
		return Define.Peek(self.state.playersLock)
	end,
	npcs = function(self)
		return Define.Peek(self.state.npcsLock)
	end,
	objects = function(self)
		return Define.Peek(self.state.objectsLock)
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
			itemsLock = { type = "boolean", default = true, setting = true },
			itemsAnchorBags = { type = "choice", choices = Place, default = Place.Anchor, setting = true },
			itemsAnchorChar = { type = "choice", choices = Place, default = Place.Anchor, setting = true },
			itemsIlvl = { type = "boolean", default = true, setting = true },
			itemsId = { type = "boolean", default = false, setting = true },
			itemsCount = { type = "boolean", default = true, setting = true },
			itemsStack = { type = "boolean", default = true, setting = true },
			itemsCooldown = { type = "boolean", default = true, setting = true },
			spellsOn = { type = "boolean", default = true, setting = true },
			spellsLock = { type = "boolean", default = true, setting = true },
			spellsId = { type = "boolean", default = false, setting = true },
			spellsNext = { type = "boolean", default = true, setting = true },
			spellsCooldown = { type = "boolean", default = true, setting = true },
			aurasOn = { type = "boolean", default = true, setting = true },
			aurasLock = { type = "boolean", default = true, setting = true },
			aurasId = { type = "boolean", default = false, setting = true },
			aurasCaster = { type = "boolean", default = true, setting = true },
			aurasTotal = { type = "boolean", default = true, setting = true },
			playersOn = { type = "boolean", default = true, setting = true },
			playersLock = { type = "boolean", default = true, setting = true },
			playersInspect = { type = "boolean", default = true, setting = true },
			playersTarget = { type = "boolean", default = true, setting = true },
			playersRelation = { type = "boolean", default = true, setting = true },
			npcsOn = { type = "boolean", default = true, setting = true },
			npcsLock = { type = "boolean", default = true, setting = true },
			npcsParty = { type = "boolean", default = true, setting = true },
			npcsLoot = { type = "boolean", default = true, setting = true },
			npcsRep = { type = "boolean", default = true, setting = true },
			objectsOn = { type = "boolean", default = true, setting = true },
			objectsLock = { type = "boolean", default = true, setting = true },
			textsOn = { type = "boolean", default = true, setting = true },
			textsExtra = { type = "boolean", default = true, setting = true },
		})
		Define.Ephemeral({
			epoch = { type = "number", default = 0 }, -- a comparison changed another view's rows
			charge = { type = "number", default = 0 }, -- the main tooltip's lock charging: 0 to STEPS
			lock = { type = "number", default = 0 }, -- 1: the main tooltip's group is locked
			nest = { type = "number", default = 0 }, -- a tooltip opened from a link opened or closed
		})
		local models, ctx, anchors = {}, { numbers = game.Numbers, L = L }, {}
		self.models, self.anchors = models, anchors

		-- the settings Read follows, read plainly at each build
		local function Settings(owner)
			ctx.owner = owner
			ctx.itemsIlvl, ctx.itemsId = Define.Peek(self.state.itemsIlvl), Define.Peek(self.state.itemsId)
			ctx.itemsCount, ctx.itemsStack = Define.Peek(self.state.itemsCount), Define.Peek(self.state.itemsStack)
			ctx.itemsCooldown, ctx.spellsId = Define.Peek(self.state.itemsCooldown), Define.Peek(self.state.spellsId)
			ctx.spellsCooldown = Define.Peek(self.state.spellsCooldown)
			ctx.spellsNext = Define.Peek(self.state.spellsNext)
			ctx.aurasId, ctx.aurasCaster = Define.Peek(self.state.aurasId), Define.Peek(self.state.aurasCaster)
			ctx.aurasTotal = Define.Peek(self.state.aurasTotal)
			ctx.playersTarget = Define.Peek(self.state.playersTarget)
			ctx.playersInspect = Define.Peek(self.state.playersInspect)
			ctx.playersRelation, ctx.npcsLoot = Define.Peek(self.state.playersRelation), Define.Peek(self.state.npcsLoot)
			ctx.npcsParty, ctx.npcsRep = Define.Peek(self.state.npcsParty), Define.Peek(self.state.npcsRep)
			local theme = game.Themes:Active()
			ctx.classNames = not theme or theme.values.classNames:Peek() ~= false
		end

		-- the other modules' additions (the API): written into the model being built; lines and rows go to the body,
		-- after AddSection to «More»
		local building, target
		local api = {}
		local function Line(list, left, right, color, rightColor, term)
			list.n = list.n + 1
			local entry = list[list.n] or {}
			list[list.n] = entry
			entry.left, entry.right, entry.color, entry.rightColor, entry.term = left, right, color, rightColor, term
			entry.desc, entry.link, entry.valueLink, entry.indent, entry.stat = nil, nil, nil, nil, nil
			return entry
		end
		function api:AddLine(text, color) -- luacheck: ignore 212
			Line(target, text, nil, color, nil, nil).desc = color == nil or nil
		end
		function api:AddRow(label, value, term, valueColor) -- luacheck: ignore 212
			Line(target, label, value, nil, valueColor, term)
		end
		function api:AddSection(title) -- luacheck: ignore 212
			target = building.more
			if title then
				Line(target, title, nil, Read.Rgb(0.5, 0.5, 0.5), nil, nil)
			end
		end
		function api:AddCell(text, glyph, term) -- luacheck: ignore 212
			local cols = building.cols
			cols.n = cols.n + 1
			local cell = cols[cols.n] or {}
			cols[cols.n] = cell
			cell.text, cell.color, cell.glyph, cell.tint = text, nil, glyph, nil
			cell.term, cell.amount, cell.link = term or glyph, nil, nil
		end
		function api:AddFooter(label, value) -- luacheck: ignore 212
			local foot = building.foot
			foot.n = foot.n + 1
			local entry = foot[foot.n] or {}
			foot[foot.n] = entry
			entry.left, entry.right, entry.valueColor, entry.term, entry.amount = label, value, nil, nil, nil
			entry.link, entry.valueLink = nil, nil
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
		-- whether a filter lets this tooltip through (For checked its type)
		local function Passes(filter, owner, model)
			local t = type(filter)
			if filter == nil then
				return true
			elseif t == "number" then
				return model.id == filter
			elseif t == "string" then
				return owner ~= nil and owner.GetName ~= nil and owner:GetName() == filter
			elseif t == "function" then
				return filter(owner, model) == true
			end
			return owner == filter
		end
		--- A handler for the kinds' events: `fn(tip, model, owner)` on the tooltips `filter` lets through (the header).
		local function For(filter, fn)
			local t = type(filter)
			if type(fn) ~= "function" then
				error("Tooltips.For: the handler must be a function", 2)
			elseif filter ~= nil and t ~= "number" and t ~= "string" and t ~= "function" and t ~= "table" then
				error("Tooltips.For: a filter is an id, an owner's name, an owner frame or a function", 2)
			end
			return function(tip, model, owner) -- made once, when it subscribes
				if Passes(filter, owner, model) then
					target = model.body -- each handler starts in the body
					fn(tip, model, owner)
				end
			end
		end
		local events = {}
		for kind, name in pairs(EVENTS) do
			events[kind] = Define.Event()
			events[name] = events[kind]
		end
		local function Extend(model, owner)
			local kind = model.kind
			if kind == "unit" then
				kind = model.portrait and UnitIsPlayer(model.portrait) and "player" or "npc"
			end
			local event = events[kind]
			if event then
				building = model
				event:Fire(api, model, owner)
			end
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

		-- what a show is read from: its data, or without data (or of a kind not read here) the text it shows
		local function Data(tip)
			local data = tip.data
			if Read.Kind(data) then
				return data
			end
			return tip:Lines()
		end

		-- the model of `tip` from its show (a refill: a timer, an inspect come back), extended by the API's handlers
		local function Fill(tip, data)
			data = data or Data(tip)
			if not data then
				return false
			end
			Settings(tip.owner)
			local model = models[tip.name]
			if not Read.Fill(model, data, ctx) then
				return false
			end
			Extend(model, tip.owner)
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
			local data = Data(tip)
			local kind = Read.Kind(data)
			local switch = ON[TypeOf(kind, tip)]
			if not switch or not switch(self, tip) or not Fill(tip, data) then
				return false
			end
			anchors[tip.name] = Beside(tip)
			if COMPARE[tip.name] then
				Compare(tip)
			end
			return true
		end

		-- the micro menu's and bags' buttons tell more (design tooltips/text «Buttons»), through the API
		import("buttons")(self, events, For, function()
			return Define.Peek(self.state.textsExtra)
		end, L)

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
		-- the inspected player's points per talent tree (design «Разрушение 0/0/10»: the tree with most points, then all
		-- three in their order): their learned ranks from the trait API's inspect config, each spell's tree from
		-- talents.lua (Forever's API has one tree per class, the client data the classic three); nil without data
		local INSPECT_CONFIG = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1
		local points, tabOfOrder = { 0, 0, 0 }, {}
		local function InspectedTrees()
			if not C_Traits.HasValidInspectData() then
				return nil
			end
			local config = C_Traits.GetConfigInfo(INSPECT_CONFIG)
			local treeID = config and config.treeIDs and config.treeIDs[1]
			local nodes = treeID and C_Traits.GetTreeNodes(treeID)
			if not nodes then
				return nil
			end
			points[1], points[2], points[3] = 0, 0, 0
			local trees = Read.talents
			for i = 1, #nodes do
				local node = C_Traits.GetNodeInfo(INSPECT_CONFIG, nodes[i])
				local rank = node and node.currentRank or 0
				local entryID = rank > 0 and node.activeEntry and node.activeEntry.entryID
				local entry = entryID and C_Traits.GetEntryInfo(INSPECT_CONFIG, entryID)
				local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
				local tab = definition and definition.spellID and trees.tab[definition.spellID]
				local info = tab and trees.name[tab]
				if info then
					points[info.order] = points[info.order] + rank
					tabOfOrder[info.order] = info
				end
			end
			local top = 1
			for i = 2, 3 do
				if points[i] > points[top] then
					top = i
				end
			end
			local name = tabOfOrder[top] and (tabOfOrder[top][GetLocale()] or tabOfOrder[top].enUS)
			if not name or points[top] == 0 then
				return nil
			end
			return name .. " " .. points[1] .. "/" .. points[2] .. "/" .. points[3]
		end
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
			entry.spec = InspectedTrees()
			if not entry.spec then -- no talent data in the inspect: the spec's name alone
				local specID = GetInspectSpecialization(unit)
				if specID and specID > 0 then
					local _, name = GetSpecializationInfoByID(specID)
					entry.spec = name
				end
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
				-- its type's «Подсказки в подсказках» off: it never charges
				local lockable = LOCK[TypeOf(Read.Kind(data), main)]
				if lock == 0 and not closed and lockable and lockable(self) then
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
			local stat, statAmount = link:match("^ordaen:stat:([%w_]+):(%-?%d+)$")
			if stat then -- an item stat: what it gives this character
				if not Read.Stat(model, stat, tonumber(statAmount), L) then
					return
				end
			elseif raceID then -- a race's racial abilities
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
			public = {
				signals = { Item = events.Item, Spell = events.Spell, Aura = events.Aura, Player = events.Player,
					Npc = events.Npc, Object = events.Object, Text = events.Text },
				functions = {
					For = For,
					--- A glossary entry a row's or cell's `term` can name (see the header).
					DefineTerm = function(key, name, text)
						if type(key) ~= "string" or key:find(":", 1, true) or type(name) ~= "string"
							or type(text) ~= "string" then
							error("Tooltips.DefineTerm: a key without «:», a name and a text", 2)
						end
						Read.terms[key] = { name = name, text = text }
					end,
				},
			},
		}
	end,

	-- the settings page (design tooltips/settings): Общее, then a tab per tooltip type: its switch, the details under it
	Settings = function(game, self)
		game.ui:SettingsTab({ attributes = { title = L.TAB_GENERAL }, slots = { default = function()
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.anchorToButtons) } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_ITEMS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.itemsOn) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.itemsLock),
				disabled = not self.state.itemsOn } })
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
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.spellsLock),
				disabled = not self.state.spellsOn } })
			game.ui:Section({ attributes = { title = L.SECTION_MORE }, slots = { default = function()
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.spellsId),
					disabled = not self.state.spellsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.spellsNext),
					disabled = not self.state.spellsOn } })
				game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.spellsCooldown),
					disabled = not self.state.spellsOn } })
			end } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_AURAS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.aurasOn) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.aurasLock),
				disabled = not self.state.aurasOn } })
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
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.playersLock),
				disabled = not self.state.playersOn } })
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
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.npcsLock),
				disabled = not self.state.npcsOn } })
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
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.objectsLock),
				disabled = not self.state.objectsOn } })
		end } })
		game.ui:SettingsTab({ attributes = { title = L.TAB_TEXTS }, slots = { default = function()
			game.ui:Switch({ attributes = { value = Define.Signal(self.state.textsOn) } })
			game.ui:Checkbox({ attributes = { value = Define.Signal(self.state.textsExtra),
				disabled = not self.state.textsOn } })
		end } })
	end,

	Render = function(game, self)
		Views(game, self)
	end,
})
