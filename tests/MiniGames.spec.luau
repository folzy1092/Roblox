local MiniGames = require("../src/shared/MiniGames")
local A = require("./assert")
local eq, truthy = A.eq, A.truthy

local tests = {}

tests["only gua sha and bone tapper are mini-games"] = function()
	eq(MiniGames.kindOf("guasha"), "stroke")
	eq(MiniGames.kindOf("bonetapper"), "tap")
	eq(MiniGames.kindOf("gum"), nil)
end

tests["tapper: hitting the lit zone counts, wrong zone misses"] = function()
	local t = MiniGames.Tapper.new(1, 0)
	local lit = t.target
	eq(t:tap(lit, 0.5), "hit")
	local other = if t.target == 1 then 2 else 1
	eq(t:tap(other, 0.6), "miss")
end

tests["tapper: rest after a set, tapping during rest stuns"] = function()
	local t = MiniGames.Tapper.new(2, 0)
	local now = 0
	for _ = 1, MiniGames.Tapper.SET_SIZE do
		now += 0.3
		eq(t:tap(t.target, now), "hit")
	end
	eq(t.phase, "rest")
	eq(t:tap(1, now + 0.1), "rest_fail")
	eq(t.phase, "stunned")
	eq(t:tap(t.target or 1, now + 0.5), "stunned")
	t:update(now + 0.1 + MiniGames.Tapper.STUN + 0.01)
	eq(t.phase, "hit")
end

tests["tapper: waiting out the rest goes back to hitting"] = function()
	local t = MiniGames.Tapper.new(3, 0)
	local now = 0
	for _ = 1, MiniGames.Tapper.SET_SIZE do
		now += 0.3
		t:tap(t.target, now)
	end
	t:update(now + MiniGames.Tapper.REST + 0.01)
	eq(t.phase, "hit")
	truthy(t.target ~= nil, "new zone lit")
end

tests["tapper: lit zone times out as a miss"] = function()
	local t = MiniGames.Tapper.new(4, 0)
	local first = t.target
	eq(t:update(MiniGames.Tapper.HIT_WINDOW + 0.01), "timeout")
	truthy(t.target ~= nil, "next zone lit")
	eq(t.combo, 0)
	local _ = first
end

tests["stroke: passing all points in order completes"] = function()
	local s = MiniGames.Stroke.new("L")
	s:press()
	local done = false
	for _, p in s.points do
		done = s:move(p[1], p[2])
	end
	truthy(done, "stroke complete")
end

tests["stroke: skipping a point or releasing early does not complete"] = function()
	local s = MiniGames.Stroke.new("R")
	s:press()
	local pts = s.points
	eq(s:move(pts[1][1], pts[1][2]), false)
	eq(s:move(pts[#pts][1], pts[#pts][2]), false) -- jumped to the end
	s:release()
	eq(s.reached, 0)
end

tests["stroke: moving without pressing does nothing"] = function()
	local s = MiniGames.Stroke.new("L")
	for _, p in s.points do
		eq(s:move(p[1], p[2]), false)
	end
end

tests["penalty factors: rest fail hurts more than a miss"] = function()
	truthy(MiniGames.PenaltyFactor.rest_fail > MiniGames.PenaltyFactor.miss, "rest fail worse")
	eq(MiniGames.PenaltyFactor.bogus, nil)
end

return tests
