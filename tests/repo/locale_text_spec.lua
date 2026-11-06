-- Player-facing text against the writing rules (.claude/skills/text-en, text-ru): the wording that the rules
-- forbid fails here, so it can't come back. Add a pattern when a rule gets a mechanical form.
local function localeFiles(code)
	local files = {}
	local p = io.popen("find addons -path '*/locales/" .. code .. ".json' | sort")
	for path in p:lines() do
		files[#files + 1] = path
	end
	p:close()
	return files
end

-- Each line of a locale file with the key and the text.
local function entries(path)
	local out = {}
	local n = 0
	for line in io.lines(path) do
		n = n + 1
		local key, text = line:match('^%s*"([%w_]+)"%s*:%s*"(.*)",?%s*$')
		if key then
			out[#out + 1] = { line = n, key = key, text = text }
		end
	end
	return out
end

local RULES = {
	enUS = {
		{ "^Click:", 'name the button: "Left-click:"' },
		{ "%f[%a]LMB%f[%A]", 'write "Left-click"' },
		{ "%f[%a]RMB%f[%A]", 'write "Right-click"' },
		{ "[Pp]lease", "no fluff: drop \"please\"" },
		{ "!", "no exclamation marks" },
		{ "[Tt]his option", 'no fluff: say what it does, not "this option"' },
	},
	ruRU = {
		{ "[Щщ]елч", 'mouse buttons are "ЛКМ"/"ПКМ"' },
		{ "[Кк]лик", 'mouse buttons are "ЛКМ"/"ПКМ"' },
		{ "кнопк[ао]й мыши", 'mouse buttons are "ЛКМ"/"ПКМ"' },
		{ "[Пп]ожалуйста", 'no fluff: drop "пожалуйста"' },
		{ "!", "no exclamation marks" },
		{ "позволяет", 'no fluff: say what it does ("позволяет …")' },
		{ "[Зз]десь вы можете", "no fluff" },
	},
}

describe("player-facing text", function()
	for code, rules in pairs(RULES) do
		it("follows the " .. code .. " writing rules", function()
			local problems = {}
			for _, path in ipairs(localeFiles(code)) do
				for _, entry in ipairs(entries(path)) do
					for _, rule in ipairs(rules) do
						if entry.text:find(rule[1]) then
							problems[#problems + 1] =
								string.format("%s:%d %s: %s", path, entry.line, entry.key, rule[2])
						end
					end
				end
			end
			assert.are.same({}, problems)
		end)
	end
end)
