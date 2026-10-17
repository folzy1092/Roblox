local P = require("../src/shared/Progression")
local A = require("./assert")
local eq, truthy = A.eq, A.truthy

local noBoost = { trainerMult = 1, hasX2 = false }

local tests = {}

tests["tierIndex boundaries"] = function()
	eq(P.tierIndex(0), 1)
	eq(P.tierIndex(999), 1)
	eq(P.tierIndex(1000), 2)
	eq(P.tierIndex(900000), 8)
	eq(P.tierIndex(5000000), 8)
end

tests["capRating per rebirth"] = function()
	eq(P.capRating(0), 1000)
	eq(P.capRating(6), 900000)
	eq(P.capRating(7), 2500000)
end

tests["tierProgress fraction"] = function()
	local tier, frac = P.tierProgress(500)
	eq(tier, 1)
	eq(frac, 0.5)
	local t8, f8 = P.tierProgress(2500000)
	eq(t8, 8)
	eq(f8, 1)
end

tests["clickGain multipliers"] = function()
	local d = P.defaultData()
	eq(P.clickGain(d, noBoost), 1)
	d.rebirths = 2 -- rating 0 is tier 1 <= 2 -> passed-tier speedup
	eq(P.clickGain(d, noBoost), 1 * 2 * 3)
	eq(P.clickGain(d, { trainerMult = 3, hasX2 = true }), 1 * 2 * 3 * 3 * 2)
	d.rating = 4000 -- tier 3, not passed before with 2 rebirths
	eq(P.clickGain(d, noBoost), 1 * 2)
end

tests["applyClick clamps rating, full glow"] = function()
	local c = P.defaultData()
	c.rating = 999
	local r, g = P.applyClick(c, { trainerMult = 3, hasX2 = false })
	eq(c.rating, 1000)
	eq(r, 1)
	eq(g, 3)
	eq(c.glow, 3)
	local r2, g2 = P.applyClick(c, noBoost)
	eq(r2, 0)
	eq(g2, 1)
	eq(c.rating, 1000)
end

tests["rebirth resets and raises cap"] = function()
	local c = P.defaultData()
	eq(P.canRebirth(c), false)
	c.rating = 1000
	c.glow = 500
	c.items.mewing = true
	c.equipped = "mewing"
	truthy(P.canRebirth(c))
	P.applyRebirth(c)
	eq(c.rebirths, 1)
	eq(c.rating, 0)
	eq(c.glow, 0)
	eq(c.equipped, "gum")
	eq(c.items.mewing, nil)
	truthy(c.items.gum)
	eq(P.capRating(c.rebirths), 4000)
	local m = P.defaultData()
	m.rebirths = 7
	m.rating = 2500000
	eq(P.canRebirth(m), false)
end

tests["shop buy rules"] = function()
	local s = P.defaultData()
	eq(select(2, P.canBuy(s, "mewing")), "glow")
	s.glow = 150
	truthy(P.canBuy(s, "mewing"))
	P.applyBuy(s, "mewing")
	eq(s.glow, 0)
	truthy(s.items.mewing)
	eq(s.equipped, "mewing")
	eq(select(2, P.canBuy(s, "mewing")), "owned")
	eq(select(2, P.canBuy(s, "nope")), "unknown")
	eq(select(2, P.canBuy(s, 42)), "unknown")
end

tests["item ladder: each next item costs more and hits harder"] = function()
	local C = require("../src/shared/Config")
	local ids = {}
	for id in C.Items do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return C.Items[a].order < C.Items[b].order
	end)
	eq(#ids, 5)
	eq(ids[1], "gum")
	eq(ids[5], "bonetapper")
	for i = 2, #ids do
		local prev, cur = C.Items[ids[i - 1]], C.Items[ids[i]]
		truthy(cur.price > prev.price, `price grows at {ids[i]}`)
		truthy(cur.power > prev.power, `power grows at {ids[i]}`)
		truthy(cur.rarity ~= nil and cur.icon ~= nil, `{ids[i]} has rarity and icon`)
	end
	local d = P.defaultData()
	d.glow = 1200
	truthy(P.canBuy(d, "jawball"))
end

return tests
