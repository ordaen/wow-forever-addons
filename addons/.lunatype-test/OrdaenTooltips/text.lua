-- Made by lunatype from OrdaenTooltips/text.luna: change the source, not this file.
local R = LunaType
local __string_contains = R.string.contains
local __math_floor = R.math.floor
local __string_toNumber = R.string.toNumber
local __string_format = R.string.format
local __math_round = R.math.round
local M = {}
R.addon("OrdaenTooltips")["text"] = M
local form, pluralForm, grammar, clean, number, last, labelled, duration

function form(n)
	local ones = n % 10
	local tens = n % 100
	if ones == 1 and tens ~= 11 then
		return 1
	end
	if ones >= 2 and ones <= 4 and (tens < 12 or tens > 14) then
		return 2
	end
	return 3
end

function pluralForm(n, forms)
	local one, few, many = (forms):match("^([^:]*):([^:]*):?(.*)$")
	if one == nil or few == nil then
		return forms
	end
	local __s1 = form(n)
	if __s1 == 1 then
		return one
	elseif __s1 == 2 then
		return few
	else
		do
			if many == nil or many == "" then
				return few
			end
			return many
		end
	end
end

function grammar(text)
	if not __string_contains(text, "|3") and not __string_contains(text, "|4") then
		return text
	end
	local counted = ((text):gsub("(%d+)([^|%d]*)|4([^;]*);", function(n, between, forms)
		return n .. between .. pluralForm(__math_floor(__string_toNumber(n) or 0), forms)
	end))
	return ((counted):gsub("|3%-%d+%((.-)%)", "%1"))
end

function clean(text)
	if text == nil or text == "" then
		return nil
	end
	return grammar(text)
end

function number(text)
	local digits = ((((text):gsub("[%s\194\160]", ""))):gsub(",", "."))
	return __string_toNumber(digits)
end

function last(text)
	local found = (text):match("([%d%.,]+)%s*$")
	if found == nil then
		return nil
	end
	return number(found)
end

function labelled(line)
	local label, value = (line):match("^([^:|]+):%s+(.+)$")
	if label == nil then
		return line, nil
	end
	return label, value
end

function duration(seconds, hours, minutes, short)
	if seconds >= 3600 then
		return __string_format(hours, __math_round(seconds / 3600))
	end
	if seconds >= 60 then
		return __string_format(minutes, __math_round(seconds / 60))
	end
	return __string_format(short, __math_round(seconds))
end

M.form = form
M.pluralForm = pluralForm
M.grammar = grammar
M.clean = clean
M.number = number
M.last = last
M.labelled = labelled
M.duration = duration
