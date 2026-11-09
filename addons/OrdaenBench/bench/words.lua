-- Strings both sides draw, made once: WORDS[n] is n characters long (the grow scenario), LINES are tooltip lines of
-- varying width, PERCENT[p] is "p%" (the bars' fill widths). Shared so every side lays out exactly the same text.
local WORDS, LINES, PERCENT = {}, {}, {}

local ALPHABET = "abcdefghijklmnopqrstuvwxyz"
for n = 1, 30 do
	local letters = {}
	for i = 1, n do
		local k = (i * 7) % #ALPHABET + 1
		letters[i] = ALPHABET:sub(k, k)
	end
	WORDS[n] = table.concat(letters)
end

local PARTS = {
	"Sword of a Thousand Truths", "+12 Stamina", "Binds when picked up", "Requires Level 60", "Sell Price: 12g 34s",
	"Durability 87 / 100", "Use: Restores 2,500 health over 30 sec.", "Unique", "Item Level 145", "Two-Hand",
	"Equip: Increases your critical strike rating by 28.", "Classes: Warrior, Paladin", "4.6 damage per second",
	"Chance on hit: Sends a shadowy bolt at the enemy.", "Cooldown remaining: 4 min", "Soulbound", "Main Hand",
	"Made by Ordaen", "Reagents: 4 Thorium Bar, 2 Arcanite Bar", "<Right Click to Open>",
}
for i = 1, #PARTS do
	LINES[i] = PARTS[i]
end

for p = 0, 100 do
	PERCENT[p] = p .. "%"
end

return { WORDS = WORDS, LINES = LINES, PERCENT = PERCENT }
