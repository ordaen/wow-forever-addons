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

describe("helpers.loadCore's debug kit", function()
	local Core

	before_each(function()
		helpers.stubGlobals()
		Core = helpers.loadCore()
	end)

	it("is one strict kit for every addon", function()
		assert.equals(Core.NewDebug("A"), Core.NewDebug("B"))
	end)

	it("works like the stand-in when called with ':'", function()
		local Debug = Core.NewDebug("A")
		local fn = function() end
		assert.equals(fn, Debug:Wrap(fn))
		assert.is_false(Debug:TraceEnabled())
		Debug:Logf("%d", 1)
	end)

	it("fails a '.' call and an unknown method", function()
		local Debug = Core.NewDebug("A")
		assert.has_error(function()
			Debug.Logf("%d", 1)
		end, "debug kit method Logf called with '.' (use ':')")
		assert.has_error(function()
			Debug:Nope()
		end, "the debug kit has no method Nope")
	end)
end)
