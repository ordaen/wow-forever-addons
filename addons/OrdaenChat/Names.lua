-- Character names in chat in their class colour: Blizzard's own per-chat-type switch (SetChatColorNameByClass, the
-- "class colour" checkboxes in its chat settings), turned on for every type that shows names, or off. The game saves
-- it as part of its chat settings. Nothing runs after that.
local _, ns = ...

local Names = {}
ns.Names = Names

local CHANNELS = 20 -- numbered channels (CHANNEL1 ...)

--- Class colours for names in every chat type on (`on`) or off.
---@param on boolean
function Names.ClassColors(on)
	local done = {}
	for _, events in pairs(ChatTypeGroup) do
		for _, event in ipairs(events) do
			local chatType = type(event) == "string" and event:match("^CHAT_MSG_(.+)")
			if chatType and not done[chatType] then
				done[chatType] = true
				SetChatColorNameByClass(chatType, on)
			end
		end
	end
	for i = 1, CHANNELS do
		SetChatColorNameByClass("CHANNEL" .. i, on)
	end
	ns.Debug:Logf("names: class colours %s", on and "on" or "off")
end
