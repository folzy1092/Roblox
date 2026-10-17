-- Picks the trainer seat the guide arrow should point to. Pure logic, unit-tested with Lune.
local Config = if script then require(script.Parent.Config) else require("./Config")

export type SeatInfo = {
	id: any,
	item: string,
	vip: boolean,
	x: number,
	z: number,
	occupied: boolean,
}

local SeatPicker = {}

-- Owned items from strongest to weakest.
local function ownedByStrength(owned: { [string]: boolean }): { string }
	local list = {}
	for id in owned do
		if Config.Items[id] then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return Config.Items[a].order > Config.Items[b].order
	end)
	return list
end

-- Nearest free seat for the best owned item; VIP seats first if the player has VIP.
-- Falls back to weaker items when every seat of the best one is taken.
function SeatPicker.pick(seats: { SeatInfo }, owned: { [string]: boolean }, hasVip: boolean, x: number, z: number): SeatInfo?
	for _, item in ownedByStrength(owned) do
		local best, bestScore = nil, math.huge
		for _, s in seats do
			if s.item == item and not s.occupied and (hasVip or not s.vip) then
				local dist = math.sqrt((s.x - x) ^ 2 + (s.z - z) ^ 2)
				-- VIP owners: any VIP seat beats any normal seat
				local score = dist + (if hasVip and not s.vip then 1e6 else 0)
				if score < bestScore then
					best, bestScore = s, score
				end
			end
		end
		if best then
			return best
		end
	end
	return nil
end

return SeatPicker
