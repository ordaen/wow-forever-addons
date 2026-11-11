-- Made by lunatype from OrdaenTooltips/term.test.luna: change the source, not this file.
local R = LunaType
local __expect = R.expect
local __OrdaenTooltips_term_term = R.addon("OrdaenTooltips")["term"].term
local M = {}
R.addon("OrdaenTooltips")["term.test"] = M

R.test("a term's tooltip has its name and its text", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:6", function()
	local model = __OrdaenTooltips_term_term("cd", nil)
	__expect(model.kind == "term", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:8: model.kind == Kind::Term")
	__expect(model.name == "Cooldown", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:9: model.name == \"Cooldown\"")
	__expect(#model.body == 1, "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:10: model.body.length == 1")
	local __t1 = model.body[1]
	local __t2
	if __t1 ~= nil then __t2 = __t1.left end
	__expect(__t2 == "How long to wait before using it again.", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:11: model.body[1]?.left == \"How long to wait before using it again.\"")
end)

R.test("the amount a part speaks of stands in the name and in the text", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:14", function()
	__expect(__OrdaenTooltips_term_term("arm", "120").name == "Armour 120", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:15: term(Term::Arm, \"120\").name == \"Armour 120\"")
	local __t3 = __OrdaenTooltips_term_term("bag", "16").body[1]
	local __t4
	if __t3 ~= nil then __t4 = __t3.left end
	__expect(__t4 == "A bag with 16 slots: how many items it holds.", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:16: term(Term::Bag, \"16\").body[1]?.left == \"A bag with 16 slots: how many items it holds.\"")
end)

R.test("a term named without an amount leaves its place empty", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:19", function()
	__expect(__OrdaenTooltips_term_term("arm", nil).name == "Armour ", "../wow-forever-addons/addons/OrdaenTooltips/term.test.luna:20: term(Term::Arm, nil).name == \"Armour \"")
end)

M.__test1 = __test1
M.__test2 = __test2
M.__test3 = __test3
