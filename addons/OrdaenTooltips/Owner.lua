-- Ordaen Tooltips, the button a tooltip belongs to: its key binding (shown as the tooltip's hotkey) and whether its
-- tooltip goes beside it. Buttons are the micro menu's and the action bars' (Blizzard's and bar addons').
--   micro and Blizzard action buttons carry their binding command (`commandName`: "TOGGLECHARACTER0",
--   "ACTIONBUTTON1"); LibActionButton's (Bartender) keep theirs in `config.keyBoundTarget` (Bartender maps its
--   bars to Blizzard's: bar 1 is "ACTIONBUTTON1", the others "MULTIACTIONBAR..."; it can be missing), else
--   bind a click ("CLICK BT4Button1:Keybind", "...:LeftButton").
-- Cost: the binding commands of a button are built once (cached per button); a show calls GetBindingKey and reads
-- the key's text from a cache, so it creates no strings.
local _, ns = ...

local Owner = {}
ns.Owner = Owner

local isSecret = issecretvalue

local commands = {} -- button -> { command, command... } (false: none)
local keyText = {} -- key ("SHIFT-1") -> its text for players ("Shift-1"), from Blizzard's own words

local function commandsOf(button)
	local list = commands[button]
	if list == nil then
		list = {}
		local command = rawget(button, "commandName")
		if type(command) == "string" and command ~= "" then
			list[#list + 1] = command
		end
		local config = rawget(button, "config")
		local target = type(config) == "table" and rawget(config, "keyBoundTarget")
		if type(target) == "string" and target ~= "" then
			list[#list + 1] = target
		end
		local name = button:GetName()
		if name then
			list[#list + 1] = "CLICK " .. name .. ":Keybind"
			list[#list + 1] = "CLICK " .. name .. ":LeftButton"
		end
		commands[button] = list
	end
	return list
end

--- The frame that owns `native` (the button hovered), or nil (none, a secret, not a frame).
---@param native GameTooltip
---@return table|nil
function Owner.Of(native)
	local owner = native:GetOwner()
	if owner == nil or isSecret(owner) or type(owner) ~= "table" or not owner.IsObjectType then
		return nil
	end
	return owner
end

--- Whether `owner` is a button whose tooltip goes beside it: a micro menu button or an action button.
---@param owner table
---@return boolean
function Owner.IsButton(owner)
	if not owner:IsObjectType("Button") then
		return false
	end
	-- Micro and Blizzard action buttons name their binding; action buttons (any bar addon's) are CheckButtons
	-- holding an action.
	return rawget(owner, "commandName") ~= nil
		or (owner:IsObjectType("CheckButton") and rawget(owner, "action") ~= nil)
end

--- The key bound to `owner` as players read it ("Shift-1", "C"), or nil.
---@param owner table
---@return string|nil
function Owner.Hotkey(owner)
	for _, command in ipairs(commandsOf(owner)) do
		local key = GetBindingKey(command)
		if type(key) == "string" and key ~= "" then
			local text = keyText[key]
			if not text then
				text = GetBindingText(key) or key
				keyText[key] = text
			end
			return text
		end
	end
	return nil
end

-- Blizzard writes a micro button's binding into its title: "Character Info |cffffd200(C)|r". Its text without that
-- part, and the key in it; nil when the title has none. Only titles that have one are cached (the micro buttons':
-- a handful); a failed match creates no strings.
local stripped = {} -- title -> { text, key }
local TITLE_KEY = "^(.-)%s*|c%x%x%x%x%x%x%x%x%((.-)%)|r$"
---@param title string|nil
---@return string|nil, string|nil
function Owner.SplitTitle(title)
	if type(title) ~= "string" or isSecret(title) then
		return nil, nil
	end
	local entry = stripped[title]
	if not entry then
		if title:byte(-1) ~= 114 then -- "r": no colour reset at the end, no key
			return nil, nil
		end
		local text, key = title:match(TITLE_KEY)
		if not text then
			return nil, nil
		end
		entry = { text, key }
		stripped[title] = entry
	end
	return entry[1], entry[2]
end
