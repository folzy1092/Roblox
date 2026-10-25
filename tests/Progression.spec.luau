local P = require("../src/shared/Progression")
local A = require("./assert")
local eq, truthy = A.eq, A.truthy

local noBoost = { trainerMult = 1, hasX2 = false }

local tests = {}

local DAY = 86400

tests["daily: first claim is day 1, then nothing until tomorrow"] = function()
	local d = P.defaultData()
	local day, ready = P.dailyStatus(d, 10 * DAY + 5)
	eq(day, 1)
	eq(ready, true)
	local got, items = P.claimDaily(d, 10 * DAY + 5)
	eq(got, 1)
	eq(items[1], "x2_10")
	eq(d.inventory.x2_10, 1)
	eq((P.claimDaily(d, 10 * DAY + 80000)), nil)
	eq(d.inventory.x2_10, 1)
	local _, again = P.dailyStatus(d, 10 * DAY + 80000)
	eq(again, false)
end

tests["daily: one claim per day, streak to day 7 mega pack, then day 1 again"] = function()
	local d = P.defaultData()
	for i = 1, 7 do
		eq((P.claimDaily(d, (20 + i) * DAY)), i)
		eq((P.claimDaily(d, (20 + i) * DAY + 100)), nil) -- spamming the button gives nothing
	end
	eq(d.inventory.vip_30, 2) -- day 6 + mega pack
	eq(d.inventory.auto_30, 2)
	eq((P.claimDaily(d, 28 * DAY)), 1)
end

tests["daily: missing a day restarts the streak"] = function()
	local d = P.defaultData()
	P.claimDaily(d, 30 * DAY)
	P.claimDaily(d, 31 * DAY)
	eq(d.dailyDay, 2)
	eq((P.claimDaily(d, 33 * DAY)), 1)
end

tests["inventory: using a boost starts its timer, only if owned"] = function()
	local d = P.defaultData()
	eq(P.useItem(d, "vip_15"), false)
	eq(P.useItem(d, "nope"), false)
	d.inventory.vip_15 = 2
	eq(P.useItem(d, "vip_15"), true)
	eq(d.vipLeft, 900)
	eq(d.inventory.vip_15, 1)
	eq(P.useItem(d, "vip_15"), true)
	eq(d.vipLeft, 1800) -- stacks
	eq(d.inventory.vip_15, nil)
	d.inventory.x2_10 = 1
	P.useItem(d, "x2_10")
	eq(d.boostLeft, 600)
end

tests["inventory: timers tick down and report when they end"] = function()
	local d = P.defaultData()
	d.autoLeft = 2
	eq(P.tickEffects(d, 1), false)
	eq(P.tickEffects(d, 1), true)
	eq(d.autoLeft, 0)
	eq(P.tickEffects(d, 1), false)
end

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
		truthy(cur.rarity ~= nil, `{ids[i]} has rarity`)
	end
	local d = P.defaultData()
	d.glow = 1200
	truthy(P.canBuy(d, "jawball"))
end

tests["rep factor scales a click"] = function()
	local d = P.defaultData()
	eq(P.clickGain(d, { trainerMult = 3, hasX2 = false, factor = 5 }), 15)
end

tests["penalty takes rating and glow, never below zero"] = function()
	local d = P.defaultData()
	d.equipped = "bonetapper"
	d.items.bonetapper = true
	d.rating = 500
	d.glow = 120
	local lost = P.applyPenalty(d, 2) -- base gain 50 * 2 = 100
	eq(lost, 100)
	eq(d.rating, 400)
	eq(d.glow, 20)
	P.applyPenalty(d, 6)
	eq(d.rating, 100)
	eq(d.glow, 0)
end

tests["boost doubles a click and stacks with x2"] = function()
	local d = P.defaultData()
	eq(d.boostLeft, 0)
	eq(P.clickGain(d, { trainerMult = 1, hasX2 = false, hasBoost = true }), 2)
	eq(P.clickGain(d, { trainerMult = 1, hasX2 = true, hasBoost = true }), 4)
end

tests["boost time adds up and is capped"] = function()
	local d = P.defaultData()
	P.addBoost(d, 900)
	P.addBoost(d, 900)
	eq(d.boostLeft, 1800)
	P.addBoost(d, 10 ^ 9)
	eq(d.boostLeft, P.MAX_BOOST)
end

tests["receipts are granted once and the list stays short"] = function()
	local d = P.defaultData()
	truthy(P.markReceipt(d, "a"))
	eq(P.markReceipt(d, "a"), false)
	for i = 1, 80 do
		P.markReceipt(d, "r" .. i)
	end
	truthy(#d.receipts <= 50, "receipt list capped")
	eq(P.markReceipt(d, "r80"), false)
end

return tests
