-- The shared test fakes must not make things up (tests/OrdaenCore/helpers.lua).
local helpers = require("tests.OrdaenCore.helpers")
local forever = require("tests.repo.forever_api")

describe("helpers.stubObject", function()
	local obj = helpers.stubObject("Test")

	it("keeps the state it fakes", function()
		obj:SetText("hi")
		assert.equals("hi", obj:GetText())
		obj:Hide()
		assert.is_false(obj:IsShown())
	end)

	it("reads unset fields as nil, like a real frame", function()
		assert.is_nil(obj.icon)
		assert.is_nil(obj.someFlag)
		assert.is_nil(obj[1])
	end)

	it("only fakes methods a real Forever widget has", function()
		assert.is_function(obj.SetPoint)
		assert.is_function(obj.IsMouseOver)
		if forever.Current() then
			assert.is_nil(obj.MouseIsOver) -- no widget has it; the drawer bug came from assuming otherwise
			assert.is_nil(obj.SetTextColorTypo)
		end
	end)
end)
