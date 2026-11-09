-- The scheduler experiment: two ways to start the engine's flush, each as 1000 independent minimal schedulers (so a
-- per-scheduler cost of a few µs shows above the frame's noise; a row's ms is µs per scheduler).
--   attach (the engine's way): a write sets the OnUpdate if nothing is pending (`SetScript` on), the flush removes it
--     (`SetScript` off): two C calls per busy frame, nothing on an idle frame, a pending check per write.
--   always: the OnUpdate is set once and stays; each frame it returns at once when nothing is pending: one Lua call per
--     frame, busy or idle; a write only marks pending.
-- The flush itself does the same nothing on both (it clears pending and counts), so only the mechanism differs. A
-- write's cost is in the Lua column; the OnUpdate's (its run, attach's SetScript off) in the frame column.
local COUNT = 1000

local Schedulers = {}

local frames, pending, flushes = {}, {}, { attach = 0, always = 0 }
local writes = {}

local function Make(variant)
	local list, marks, flushOf = {}, {}, {}
	for i = 1, COUNT do
		local frame = CreateFrame("Frame")
		marks[i] = false
		if variant == "attach" then
			frame:SetScript("OnUpdate", nil)
			flushOf[i] = function(self)
				marks[i] = false
				flushes.attach = flushes.attach + 1
				self:SetScript("OnUpdate", nil)
			end
		else
			frame:SetScript("OnUpdate", function()
				if not marks[i] then
					return
				end
				marks[i] = false
				flushes.always = flushes.always + 1
			end)
		end
		list[i] = frame
	end
	frames[variant], pending[variant] = list, marks
	if variant == "attach" then
		writes.attach = function(i)
			if not marks[i] then
				marks[i] = true
				list[i]:SetScript("OnUpdate", flushOf[i])
			end
		end
	else
		writes.always = function(i)
			marks[i] = true
		end
	end
end

--- Make both variants' schedulers (once: frames are never freed). `always` is made stopped: Stop/Start keep its
--- OnUpdates off while other rows run.
function Schedulers.Make()
	if frames.attach then
		return
	end
	Make("attach")
	Make("always")
	Schedulers.Stop("always")
end

--- One write to each of the variant's schedulers, `times` times over (a write-heavy frame repeats them).
function Schedulers.Write(variant, times)
	local write = writes[variant]
	for _ = 1, times or 1 do
		for i = 1, COUNT do
			write(i)
		end
	end
end

--- Detach the always-on OnUpdates (between its rows) and set them again (for its rows).
function Schedulers.Stop(variant)
	if variant == "always" then
		for _, frame in ipairs(frames.always) do
			frame:Hide()
		end
	end
end

function Schedulers.Start(variant)
	if variant == "always" then
		for _, frame in ipairs(frames.always) do
			frame:Show()
		end
	end
end

--- How many flushes the variant ran (the bench's check: one per scheduler per written frame).
function Schedulers.Flushes(variant)
	return flushes[variant]
end

--- Whether anything is still pending (after a row, nothing should be).
function Schedulers.Pending(variant)
	local marks = pending[variant]
	for i = 1, COUNT do
		if marks[i] then
			return true
		end
	end
	return false
end

return Schedulers
