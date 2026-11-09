-- A drawing backend that draws nothing, for the framework-engine rows: the same framework steps with this backend
-- swapped in measure the engine alone, so the framework row minus the engine row is the backend's share. Its nodes
-- come from a pool filled before the first swap (untimed), so it makes no garbage.
local Stub = {}

local pool, pooled = {}, 0

--- Fill the pool (untimed, before the first swap).
function Stub.Fill(count)
	for _ = pooled + 1, count do
		pooled = pooled + 1
		pool[pooled] = {}
	end
end

function Stub:Layer(name) -- luacheck: ignore 212
	return {}
end

function Stub:Create(kind) -- luacheck: ignore 212
	local node = pool[pooled]
	if node then
		pool[pooled] = nil
		pooled = pooled - 1
		return node
	end
	return {}
end

function Stub:Take(frame) -- luacheck: ignore 212
	return {}
end

function Stub:Set(node, attributes) end -- luacheck: ignore 212

function Stub:SetChildren(node, children, count) end -- luacheck: ignore 212

function Stub:Release(node) -- luacheck: ignore 212
	pooled = pooled + 1
	pool[pooled] = node
end

function Stub:Flush() end -- luacheck: ignore 212

return Stub
