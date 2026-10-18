-- Exercise mini-games for the stronger items. Pure logic (no Roblox APIs), unit-tested with Lune.
-- Gua Sha = "stroke": drag along a lit path on the face from chin to ear.
-- Bone Tapper = "tap": hit the lit face zone; rest after every set, tapping during rest stuns you.
local MiniGames = {}

local KINDS = {
	guasha = "stroke",
	bonetapper = "tap",
}

-- One finished rep is worth this many clicks of the item.
MiniGames.RepFactor = {
	stroke = 5,
	tap = 2,
}

-- Mistakes cost this many base clicks of rating and Glow ("you hurt yourself").
MiniGames.PenaltyFactor = {
	miss = 2, -- hit the face outside the lit zone
	rest_fail = 6, -- hit during the rest: something cracked
}

-- Server-side floor between accepted reps (anti-spam).
MiniGames.MinRepInterval = {
	stroke = 0.45,
	tap = 0.2,
}

function MiniGames.kindOf(itemId: string): string?
	return KINDS[itemId]
end

-- Face zones for the tapper, in panel coordinates (0..1, x right, y down).
MiniGames.Zones = {
	{ name = "browL", x = 0.36, y = 0.3 },
	{ name = "browR", x = 0.64, y = 0.3 },
	{ name = "cheekL", x = 0.28, y = 0.55 },
	{ name = "cheekR", x = 0.72, y = 0.55 },
	{ name = "jawL", x = 0.34, y = 0.76 },
	{ name = "jawR", x = 0.66, y = 0.76 },
	{ name = "chin", x = 0.5, y = 0.86 },
}

-- Small deterministic RNG so tests are stable without Roblox's Random.
local function lcg(seed: number): () -> number
	local state = (seed * 7919 + 13) % 2147483647
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

---------------------------------------------------------------- Tapper

local Tapper = {}
Tapper.__index = Tapper
Tapper.HIT_WINDOW = 1.4 -- seconds to hit a lit zone
Tapper.SET_SIZE = 5 -- hits per set before a rest
Tapper.REST = 2.0 -- rest length; don't tap!
Tapper.STUN = 3.0 -- penalty for tapping during rest

function Tapper.new(seed: number, now: number)
	local self = setmetatable({
		rand = lcg(seed),
		phase = "hit",
		target = nil :: number?,
		deadline = 0,
		hitsInSet = 0,
		combo = 0,
		phaseEnds = 0,
	}, Tapper)
	self:_light(now)
	return self
end

function Tapper:_light(now: number)
	local previous = self.target
	local nextZone = previous
	while nextZone == previous do
		nextZone = 1 + math.floor(self.rand() * #MiniGames.Zones)
	end
	self.target = nextZone
	self.deadline = now + Tapper.HIT_WINDOW
end

-- Advance timers. Returns "timeout" when a lit zone expired, else nil.
function Tapper:update(now: number): string?
	if self.phase == "rest" or self.phase == "stunned" then
		if now >= self.phaseEnds then
			self.phase = "hit"
			self.hitsInSet = 0
			self:_light(now)
		end
		return nil
	end
	if now > self.deadline then
		self.combo = 0
		self:_light(now)
		return "timeout"
	end
	return nil
end

-- Returns "hit" | "miss" | "rest_fail" | "stunned".
function Tapper:tap(zone: number, now: number): string
	self:update(now)
	if self.phase == "stunned" then
		return "stunned"
	end
	if self.phase == "rest" then
		self.phase = "stunned"
		self.phaseEnds = now + Tapper.STUN
		self.combo = 0
		self.target = nil
		return "rest_fail"
	end
	if zone ~= self.target then
		self.combo = 0
		return "miss"
	end
	self.combo += 1
	self.hitsInSet += 1
	if self.hitsInSet >= Tapper.SET_SIZE then
		self.phase = "rest"
		self.phaseEnds = now + Tapper.REST
		self.target = nil
	else
		self:_light(now)
	end
	return "hit"
end

MiniGames.Tapper = Tapper

---------------------------------------------------------------- Stroke

local Stroke = {}
Stroke.__index = Stroke
Stroke.RADIUS = 0.08 -- how close the pointer must pass each point (panel units)

-- Chin to ear along the left cheek; the right side is mirrored.
local LEFT_PATH = {
	{ 0.44, 0.84 },
	{ 0.36, 0.76 },
	{ 0.29, 0.66 },
	{ 0.25, 0.55 },
	{ 0.22, 0.45 },
	{ 0.2, 0.36 },
}

function Stroke.new(side: string)
	local points = {}
	for _, p in LEFT_PATH do
		table.insert(points, if side == "R" then { 1 - p[1], p[2] } else { p[1], p[2] })
	end
	return setmetatable({ side = side, points = points, reached = 0, pressed = false }, Stroke)
end

function Stroke:press()
	self.pressed = true
	self.reached = 0
end

function Stroke:release()
	self.pressed = false
	self.reached = 0
end

-- Feed pointer position (panel units). Returns true when the stroke is completed.
function Stroke:move(x: number, y: number): boolean
	if not self.pressed then
		return false
	end
	local nextPoint = self.points[self.reached + 1]
	if nextPoint and math.sqrt((x - nextPoint[1]) ^ 2 + (y - nextPoint[2]) ^ 2) <= Stroke.RADIUS then
		self.reached += 1
		if self.reached >= #self.points then
			self.reached = 0
			return true
		end
	end
	return false
end

MiniGames.Stroke = Stroke

return MiniGames
