local Looks = require("../src/shared/Looks")
local A = require("./assert")
local eq, truthy = A.eq, A.truthy

local function near(a: number, b: number, msg: string)
	truthy(math.abs(a - b) < 1e-6, `{msg}: expected {b}, got {a}`)
end

local tests = {}

tests["fresh player is round with no jaw"] = function()
	local s = Looks.shape(0)
	eq(s.fat, 1)
	eq(s.jaw, 0)
end

tests["visible change already inside Sub-3"] = function()
	local s = Looks.shape(1000) -- top of Sub-3
	near(s.fat, 0.6, "fat at Sub-3 top")
	truthy(s.jaw > 0, "jaw starts growing in Sub-3")
end

tests["True Adam is fully sculpted"] = function()
	local s = Looks.shape(2500000)
	eq(s.fat, 0)
	eq(s.jaw, 1)
end

tests["fat never grows and jaw never shrinks with rating"] = function()
	local prev = Looks.shape(0)
	for _, rating in { 100, 500, 999, 1000, 3000, 4000, 12000, 35000, 100000, 300000, 900000, 2500000 } do
		local s = Looks.shape(rating)
		truthy(s.fat <= prev.fat, `fat grew at {rating}`)
		truthy(s.jaw >= prev.jaw, `jaw shrank at {rating}`)
		prev = s
	end
end

return tests
