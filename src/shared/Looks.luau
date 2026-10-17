-- Face shape from rating: round cheeks melt away early, jaw builds up over all tiers.
-- Pure math, unit-tested with Lune.
local Config = if script then require(script.Parent.Config) else require("./Config")
local Progression = if script then require(script.Parent.Progression) else require("./Progression")

export type Shape = {
	fat: number, -- 1 = round baby face, 0 = lean
	jaw: number, -- 0 = no jawline, 1 = True Adam jaw
}

local FAT_SPEED = 3.2 -- fat gone by mid MTN, so first tiers show clear change
local JAW_START = 0.05
local JAW_SPEED = 1.4

local Looks = {}

-- Overall progress 0..1 across all tiers (tier steps + fraction inside tier).
function Looks.progress(rating: number): number
	local tier, frac = Progression.tierProgress(rating)
	return math.clamp((tier - 1 + frac) / #Config.Tiers, 0, 1)
end

function Looks.shape(rating: number): Shape
	local t = Looks.progress(rating)
	return {
		fat = math.clamp(1 - t * FAT_SPEED, 0, 1),
		jaw = math.clamp((t - JAW_START) * JAW_SPEED, 0, 1),
	}
end

return Looks
