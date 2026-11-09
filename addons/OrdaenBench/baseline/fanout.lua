-- fanout, by hand: a change calls 5000 listener functions, registered in an array.
local WATCHES = 5000

local Fanout = {}

local value, sink = 0, 0
local listeners = {}

function Fanout.Make()
	for i = 1, WATCHES do
		listeners[i] = function()
			sink = value
		end
	end
end

function Fanout.Bump()
	value = value + 1
	local list = listeners
	for i = 1, WATCHES do
		list[i]()
	end
end

return Fanout
