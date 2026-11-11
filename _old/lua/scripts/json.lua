-- Minimal JSON for the repo's Lua tools (Lua 5.1, no dependencies). Encoding is deterministic: object
-- keys are sorted and every array element / object member gets its own line, so generated files diff
-- well in git. Tables with keys 1..n are arrays; empty tables encode as {} unless marked with
-- json.array(t). Decoding supports what we write: objects, arrays, strings (with \" \\ \/ \n \t \r \b \f
-- and \uXXXX escapes), numbers, true, false, null (null decodes to nil, i.e. the key is absent).
local json = {}

local ARRAY = setmetatable({}, { __mode = "k" })

--- Mark a table as a JSON array (so an empty one encodes as [] instead of {}).
function json.array(t)
	ARRAY[t] = true
	return t
end

local function isArray(t)
	if ARRAY[t] then
		return true
	end
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
		n = n + 1
	end
	return n > 0 and n == #t
end

local ESCAPES = {
	['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r",
	["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f",
}

local function encodeString(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", c:byte())
	end) .. '"'
end

local function encode(value, indent, out)
	local kind = type(value)
	if kind == "table" then
		local inner = indent .. "\t"
		if isArray(value) then
			if #value == 0 then
				out[#out + 1] = "[]"
				return
			end
			out[#out + 1] = "[\n"
			for i, item in ipairs(value) do
				out[#out + 1] = inner
				encode(item, inner, out)
				out[#out + 1] = i < #value and ",\n" or "\n"
			end
			out[#out + 1] = indent .. "]"
		else
			local keys = {}
			for k in pairs(value) do
				keys[#keys + 1] = tostring(k)
			end
			table.sort(keys)
			if #keys == 0 then
				out[#out + 1] = "{}"
				return
			end
			out[#out + 1] = "{\n"
			for i, k in ipairs(keys) do
				local item = value[k]
				if item == nil then
					item = value[tonumber(k)]
				end
				out[#out + 1] = inner .. encodeString(k) .. ": "
				encode(item, inner, out)
				out[#out + 1] = i < #keys and ",\n" or "\n"
			end
			out[#out + 1] = indent .. "}"
		end
	elseif kind == "string" then
		out[#out + 1] = encodeString(value)
	elseif kind == "number" then
		out[#out + 1] = value == math.floor(value) and string.format("%d", value) or string.format("%.14g", value)
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif value == nil then
		out[#out + 1] = "null"
	else
		error("cannot encode a " .. kind)
	end
end

---@return string
function json.encode(value)
	local out = {}
	encode(value, "", out)
	out[#out + 1] = "\n"
	return table.concat(out)
end

local function decodeError(s, pos, what)
	local line = select(2, s:sub(1, pos):gsub("\n", "")) + 1
	error(string.format("JSON: %s at line %d", what, line), 0)
end

local decodeValue

local function skip(s, pos)
	return s:find("[^ \t\r\n]", pos) or #s + 1
end

local function decodeString(s, pos)
	local out, i = {}, pos + 1
	while true do
		local c = s:sub(i, i)
		if c == "" then
			decodeError(s, pos, "unterminated string")
		elseif c == '"' then
			return table.concat(out), i + 1
		elseif c == "\\" then
			local e = s:sub(i + 1, i + 1)
			local simple = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" }
			if simple[e] then
				out[#out + 1] = simple[e]
				i = i + 2
			elseif e == "u" then
				local code = tonumber(s:sub(i + 2, i + 5), 16)
				if not code then
					decodeError(s, i, "bad \\u escape")
				end
				if code < 0x80 then
					out[#out + 1] = string.char(code)
				elseif code < 0x800 then
					out[#out + 1] = string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
				else
					out[#out + 1] = string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40,
						0x80 + code % 0x40)
				end
				i = i + 6
			else
				decodeError(s, i, "bad escape")
			end
		else
			local j = s:find('["\\]', i) or #s + 1
			out[#out + 1] = s:sub(i, j - 1)
			i = j
		end
	end
end

function decodeValue(s, pos)
	pos = skip(s, pos)
	local c = s:sub(pos, pos)
	if c == "{" then
		local obj = {}
		pos = skip(s, pos + 1)
		if s:sub(pos, pos) == "}" then
			return obj, pos + 1
		end
		while true do
			if s:sub(pos, pos) ~= '"' then
				decodeError(s, pos, "expected a key")
			end
			local key
			key, pos = decodeString(s, pos)
			pos = skip(s, pos)
			if s:sub(pos, pos) ~= ":" then
				decodeError(s, pos, "expected ':'")
			end
			obj[key], pos = decodeValue(s, pos + 1)
			pos = skip(s, pos)
			local sep = s:sub(pos, pos)
			if sep == "}" then
				return obj, pos + 1
			elseif sep ~= "," then
				decodeError(s, pos, "expected ',' or '}'")
			end
			pos = skip(s, pos + 1)
		end
	elseif c == "[" then
		local arr = json.array({})
		pos = skip(s, pos + 1)
		if s:sub(pos, pos) == "]" then
			return arr, pos + 1
		end
		while true do
			arr[#arr + 1], pos = decodeValue(s, pos)
			pos = skip(s, pos)
			local sep = s:sub(pos, pos)
			if sep == "]" then
				return arr, pos + 1
			elseif sep ~= "," then
				decodeError(s, pos, "expected ',' or ']'")
			end
			pos = pos + 1
		end
	elseif c == '"' then
		return decodeString(s, pos)
	elseif s:find("^true", pos) then
		return true, pos + 4
	elseif s:find("^false", pos) then
		return false, pos + 5
	elseif s:find("^null", pos) then
		return nil, pos + 4
	else
		local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		if not num or num == "" then
			decodeError(s, pos, "unexpected character")
		end
		return tonumber(num), pos + #num
	end
end

---@return any
function json.decode(s)
	local value, pos = decodeValue(s, 1)
	if skip(s, pos) <= #s then
		decodeError(s, pos, "trailing characters")
	end
	return value
end

return json
