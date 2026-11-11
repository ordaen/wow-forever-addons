-- What dev.d.luna declares: the dev addon's own API (`OrdaenCoreDebug`), or nothing without it.
local R = LunaType
local api = rawget(_G, "OrdaenCoreDebug")

local M = { available = api ~= nil }

function M.get(name)
	return api ~= nil and api:Get(name) == true
end

function M.set(name, on)
	if api and api:Get(name) ~= on then
		api:Set(name, on)
	end
end

function M.label(name)
	return api and (api:Describe(name)) or name
end

function M.tip(name)
	local _, tip = api and api:Describe(name)
	return tip or ""
end

function M.channels()
	return api and api:RecorderChannels() or {}
end

function M.addons()
	return api and api:Addons() or {}
end

function M.queued()
	return api and (api:Status()) or 0
end

function M.errors()
	local _, errors = api and api:Status()
	return errors or 0
end

function M.sendState()
	if api then
		api:SendState()
	end
end

function M.dumpApi()
	if api then
		api:DumpApi()
	end
end

function M.hasDump()
	return api ~= nil and api:HasDump() == true
end

function M.clearDump()
	if api then
		api:ClearDump()
	end
end

function M.artPreview()
	if api then
		api:ToggleArtPreview()
	end
end

R.addon("OrdaenDev")["dev"] = M
