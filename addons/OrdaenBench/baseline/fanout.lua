-- fanout, by hand: a change calls 5000 listener functions, registered in an array.
local WATCHES = 5000

local Fanout = {}

local value, sum = 0, 0 -- sum: what every run read, the bench's checksum
local listeners = {}

function Fanout.Make()
	value, sum, listeners = 0, 0, {}
	for i = 1, WATCHES do
		listeners[i] = function()
			sum = sum + value
		end
	end
end

-- bench: begin
function Fanout.Checksum()
	return sum
end
-- bench: end

--- Drop what the last make built (untimed, before the next make: its kept KB is then its own).
-- bench: begin
function Fanout.Release()
	listeners = {}
end
-- bench: end

function Fanout.Bump()
	value = value + 1
	local list = listeners
	for i = 1, WATCHES do
		list[i]()
	end
end

return Fanout
