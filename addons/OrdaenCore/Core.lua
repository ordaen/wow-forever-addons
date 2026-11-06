-- Ordaen Core: code shared by all Ordaen addons. Every Ordaen addon declares
-- `## Dependencies: OrdaenCore` and gets the API from the global OrdaenCore.
--
-- Compatibility rule: users update the Core and the addons independently, so the public API
-- only grows. Never change or remove something that has been released; add a new name instead.
-- An addon that needs a newer Core declares `## X-Ordaen-MinCore: <version>` in its TOC and
-- calls OrdaenCore.IsCompatible(addonName) before using anything else.
local addonName, ns = ...

local Core = {}
ns.Core = Core
OrdaenCore = Core

local function metadata(addon, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addon, field)
	end
	return nil
end

Core.version = metadata(addonName, "Version") or "0.0.0"

-- The packager replaces this token with the release tag. If it is still there, this is a
-- git checkout (development), where versions in the TOC don't mean anything yet.
local PACKAGED_VERSION = "@project-version@"
Core.isDevBuild = PACKAGED_VERSION:sub(1, 1) == "@"

--- Compare two dotted versions ("1.2.3"); missing parts count as 0.
---@return integer -1 if a < b, 0 if equal, 1 if a > b
function Core.CompareVersions(a, b)
	local function parts(v)
		local out = {}
		for n in tostring(v):gmatch("%d+") do
			out[#out + 1] = tonumber(n)
		end
		return out
	end
	local pa, pb = parts(a), parts(b)
	for i = 1, math.max(#pa, #pb) do
		local x, y = pa[i] or 0, pb[i] or 0
		if x ~= y then
			return x < y and -1 or 1
		end
	end
	return 0
end

local warned = {}

--- Whether this Core is new enough for `addon` (its `## X-Ordaen-MinCore` TOC field).
--- Prints one chat warning per addon when it isn't. Development checkouts always pass.
---@param addon string
---@return boolean
function Core.IsCompatible(addon)
	local required = metadata(addon, "X-Ordaen-MinCore")
	if not required or Core.isDevBuild or Core.CompareVersions(Core.version, required) >= 0 then
		return true
	end
	if not warned[addon] then
		warned[addon] = true
		local title = metadata(addon, "Title") or addon
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"|cffff5555%s needs Ordaen Core %s or newer (you have %s). Please update Ordaen Core.|r",
			title, required, Core.version))
	end
	return false
end
