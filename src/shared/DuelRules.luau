-- Duel rules shared by server and client. Pure logic, unit-tested with Lune.
-- A duel is a speed race of face workouts on your own avatar's face (camera on the face):
-- both players get the same schedule (same seed).
--   tap    : Bone Tapper, bonk the glowing bone before it fades
--   stroke : Gua Sha, drag through the dots along the jaw / cheekbone
--   chew   : jaw rhythm, tap the jaw muscle when the shrinking ring closes on it
-- Score = points (with combo bonus) x accuracy.
local DuelRules = {}

DuelRules.DURATIONS = { 90, 180 }
DuelRules.SEGMENT = 15 -- seconds per exercise
DuelRules.COUNTDOWN = 3
DuelRules.INVITE_SECONDS = 15
DuelRules.MAX_EVENTS_PER_SEC = 8
DuelRules.KINDS = { "tap", "stroke", "chew" }

-- chew rhythm: a ring closes on the jaw in `beat` seconds; tap within WINDOW of the beat (as a
-- share of the beat). The beat speeds up during the segment.
DuelRules.CHEW = { firstBeat = 0.95, minBeat = 0.55, speedUp = 0.96, window = 0.2, late = 1.25 }

local function lcg(seed: number): () -> number
	local state = (seed * 7919 + 17) % 2147483647
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

export type Segment = { kind: string, start: number, finish: number }

-- Exercise list for a duel: every kind appears, order shuffled by seed, never twice in a row.
function DuelRules.schedule(seed: number, duration: number): { Segment }
	local rand = lcg(seed)
	local out = {}
	local t = 0
	local last = nil
	local bag = {}
	while t < duration do
		if #bag == 0 then
			bag = table.clone(DuelRules.KINDS)
		end
		local i = 1 + math.floor(rand() * #bag)
		if bag[i] == last and #bag > 1 then
			i = (i % #bag) + 1
		end
		local kind = table.remove(bag, i)
		local finish = math.min(duration, t + DuelRules.SEGMENT)
		table.insert(out, { kind = kind, start = t, finish = finish })
		last = kind
		t = finish
	end
	return out
end

function DuelRules.kindAt(schedule: { Segment }, t: number): string?
	for _, seg in schedule do
		if t >= seg.start and t < seg.finish then
			return seg.kind
		end
	end
	return nil
end

export type Score = { hits: number, misses: number, combo: number, points: number }

function DuelRules.newScore(): Score
	return { hits = 0, misses = 0, combo = 0, points = 0 }
end

-- Returns false for unknown events.
function DuelRules.apply(score: Score, event: any): boolean
	if event == "hit" then
		score.hits += 1
		score.combo += 1
		score.points += 10 * (1 + math.min(score.combo, 20) * 0.05)
		return true
	elseif event == "miss" then
		score.misses += 1
		score.combo = 0
		return true
	end
	return false
end

function DuelRules.accuracy(score: Score): number
	local total = score.hits + score.misses
	return if total == 0 then 0 else score.hits / total
end

function DuelRules.final(score: Score): number
	return math.floor(score.points * DuelRules.accuracy(score))
end

-- Chew tap at `phase` (time since the beat started / beat length; 1 = ring closed).
function DuelRules.chewJudge(phase: number): string
	return if math.abs(phase - 1) <= DuelRules.CHEW.window then "hit" else "miss"
end

-- Next beat length after one beat.
function DuelRules.nextBeat(beat: number): number
	return math.max(DuelRules.CHEW.minBeat, beat * DuelRules.CHEW.speedUp)
end

-- Sliding one-second window of event times. Mutates `window`.
function DuelRules.allowEvent(window: { number }, now: number): boolean
	while #window > 0 and now - window[1] >= 1 do
		table.remove(window, 1)
	end
	if #window >= DuelRules.MAX_EVENTS_PER_SEC then
		return false
	end
	table.insert(window, now)
	return true
end

return DuelRules
