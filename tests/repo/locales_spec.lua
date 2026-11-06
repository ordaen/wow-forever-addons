-- Checks every addon's translations, with no per-addon wiring: for each addons/<Addon>/Locale.lua
-- (English base, sets ns.L and ns.ApplyTranslation) and each Locale_<code>.lua next to it.
-- Test-only: nothing here costs players anything at runtime.
--   * every English key is translated, and no translation key is unknown (catches typos)
--   * format placeholders (%s, %d, ...) match, so string.format can't break in one language
--   * on clients in other languages the file returns before building its table

local function listDir(dir, pattern)
	local out = {}
	local pipe = assert(io.popen('ls -1 "' .. dir .. '" 2>/dev/null'))
	for name in pipe:lines() do
		if name:match(pattern) then
			out[#out + 1] = name
		end
	end
	pipe:close()
	table.sort(out)
	return out
end

local function exists(path)
	local f = io.open(path)
	if f then
		f:close()
	end
	return f ~= nil
end

-- English keys of an addon: load Locale.lua as on an English client and read its raw table.
local function englishStrings(addon)
	local ns = {}
	local saved = rawget(_G, "GetLocale")
	rawset(_G, "GetLocale", function()
		return "enUS"
	end)
	assert(loadfile("addons/" .. addon .. "/Locale.lua"))(addon, ns)
	rawset(_G, "GetLocale", saved)
	local strings = {}
	for key, text in pairs(ns.L) do
		strings[key] = text
	end
	return strings
end

-- Load a translation file into a fake namespace; returns the table it applies (nil if none).
local function translation(addon, file, locale)
	local applied
	local ns = {
		LOCALE = locale,
		ApplyTranslation = function(strings)
			applied = strings
		end,
	}
	assert(loadfile("addons/" .. addon .. "/" .. file))(addon, ns)
	return applied
end

local function placeholders(text)
	local out = {}
	for spec in tostring(text):gmatch("%%[%-%+ #0]*%d*%.?%d*[%a%%]") do
		if spec ~= "%%" then
			out[#out + 1] = spec
		end
	end
	return table.concat(out, " ")
end

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

for _, addon in ipairs(listDir("addons", "^Ordaen")) do
	if exists("addons/" .. addon .. "/Locale.lua") then
		for _, file in ipairs(listDir("addons/" .. addon, "^Locale_%a%a%a%a%.lua$")) do
			local locale = file:match("^Locale_(%a%a%a%a)%.lua$")

			describe(addon .. " " .. locale .. " translation", function()
				local english, translated

				before_each(function()
					english = englishStrings(addon)
					translated = translation(addon, file, locale)
				end)

				it("translates every English string", function()
					assert.is_table(translated, file .. " applied nothing for " .. locale)
					local missing = {}
					for _, key in ipairs(sortedKeys(english)) do
						if type(translated[key]) ~= "string" or translated[key] == "" then
							missing[#missing + 1] = key
						end
					end
					assert.are.same({}, missing, locale .. " is missing these keys")
				end)

				it("has no keys that English doesn't have (typos)", function()
					local unknown = {}
					for _, key in ipairs(sortedKeys(translated)) do
						if english[key] == nil then
							unknown[#unknown + 1] = key
						end
					end
					assert.are.same({}, unknown, locale .. " has unknown keys")
				end)

				it("keeps the same format placeholders as English", function()
					local mismatched = {}
					for _, key in ipairs(sortedKeys(translated)) do
						if english[key] ~= nil and placeholders(english[key]) ~= placeholders(translated[key]) then
							mismatched[#mismatched + 1] = key
						end
					end
					assert.are.same({}, mismatched, locale .. " changes the placeholders of these keys")
				end)

				it("does nothing on clients in other languages", function()
					local other = locale == "enUS" and "deDE" or "enUS"
					assert.is_nil(translation(addon, file, other))
				end)
			end)
		end
	end
end
