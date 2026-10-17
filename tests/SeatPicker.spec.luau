local SeatPicker = require("../src/shared/SeatPicker")
local A = require("./assert")
local eq = A.eq

local function seat(id, item, vip, x, z, occupied)
	return { id = id, item = item, vip = vip, x = x, z = z, occupied = occupied or false }
end

local seats = {
	seat(1, "gum", false, 10, 0),
	seat(2, "gum", false, 50, 0),
	seat(3, "gum", true, 5, 0),
	seat(4, "mewing", false, 40, 0),
	seat(5, "mewing", false, 20, 0, true),
	seat(6, "mewing", true, 60, 0),
}

local tests = {}

tests["best owned item wins, nearest free seat"] = function()
	local s = SeatPicker.pick(seats, { gum = true, mewing = true }, false, 0, 0)
	eq(s.id, 4) -- mewing beats gum; seat 5 is taken, VIP 6 not allowed
end

tests["VIP owner prefers VIP seat of best item"] = function()
	local s = SeatPicker.pick(seats, { gum = true, mewing = true }, true, 0, 0)
	eq(s.id, 6)
end

tests["only gum owned: nearest non-VIP gum seat"] = function()
	local s = SeatPicker.pick(seats, { gum = true }, false, 0, 0)
	eq(s.id, 1)
end

tests["falls back to next item when best item seats are full"] = function()
	local full = {
		seat(1, "gum", false, 10, 0),
		seat(2, "mewing", false, 20, 0, true),
		seat(3, "mewing", true, 30, 0),
	}
	local s = SeatPicker.pick(full, { gum = true, mewing = true }, false, 0, 0)
	eq(s.id, 1)
end

tests["nothing free returns nil"] = function()
	eq(SeatPicker.pick({ seat(1, "gum", false, 1, 1, true) }, { gum = true }, false, 0, 0), nil)
end

return tests
