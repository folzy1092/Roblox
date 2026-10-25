local DuelRules = require("../src/shared/DuelRules")
local A = require("./assert")
local eq, truthy = A.eq, A.truthy

local tests = {}

tests["schedule covers the whole duel with all exercise kinds"] = function()
	local s = DuelRules.schedule(42, 90)
	eq(s[1].start, 0)
	eq(s[#s].finish, 90)
	for i = 2, #s do
		eq(s[i].start, s[i - 1].finish)
	end
	local kinds = {}
	for _, seg in s do
		kinds[seg.kind] = true
	end
	truthy(kinds.tap and kinds.rhythm and kinds.hold, "all three kinds appear")
end

tests["schedule is the same for both players (same seed)"] = function()
	local a, b = DuelRules.schedule(7, 180), DuelRules.schedule(7, 180)
	eq(#a, #b)
	for i = 1, #a do
		eq(a[i].kind, b[i].kind)
	end
end

tests["kindAt finds the active exercise"] = function()
	local s = DuelRules.schedule(3, 90)
	eq(DuelRules.kindAt(s, 0), s[1].kind)
	eq(DuelRules.kindAt(s, s[2].start + 0.1), s[2].kind)
	eq(DuelRules.kindAt(s, 999), nil)
end

tests["hits build combo and points, a miss resets combo"] = function()
	local sc = DuelRules.newScore()
	DuelRules.apply(sc, "hit")
	DuelRules.apply(sc, "hit")
	eq(sc.hits, 2)
	eq(sc.combo, 2)
	truthy(sc.points > 20, "combo bonus")
	DuelRules.apply(sc, "miss")
	eq(sc.combo, 0)
	eq(sc.misses, 1)
end

tests["final score is points times accuracy"] = function()
	local sc = DuelRules.newScore()
	for _ = 1, 3 do
		DuelRules.apply(sc, "hit")
	end
	DuelRules.apply(sc, "miss")
	eq(DuelRules.accuracy(sc), 0.75)
	eq(DuelRules.final(sc), math.floor(sc.points * 0.75))
	eq(DuelRules.final(DuelRules.newScore()), 0)
end

tests["rate limit drops spam"] = function()
	local window = {}
	local accepted = 0
	for i = 1, 30 do
		if DuelRules.allowEvent(window, i * 0.01) then
			accepted += 1
		end
	end
	eq(accepted, DuelRules.MAX_EVENTS_PER_SEC)
	truthy(DuelRules.allowEvent(window, 2), "allowed again after a second")
end

tests["unknown events are ignored"] = function()
	local sc = DuelRules.newScore()
	eq(DuelRules.apply(sc, "lol"), false)
	eq(sc.hits + sc.misses, 0)
end

return tests
