-- Pure progression math. No Roblox APIs: unit-tested with Lune.
local Config = if script then require(script.Parent.Config) else require("./Config")

export type Data = {
	version: number,
	rating: number,
	glow: number,
	rebirths: number,
	items: { [string]: boolean },
	equipped: string,
}

export type ClickContext = {
	trainerMult: number,
	hasX2: boolean,
	factor: number?, -- mini-game rep worth (1 = plain click)
}

local Progression = {}

function Progression.defaultData(): Data
	return {
		version = 1,
		rating = 0,
		glow = 0,
		rebirths = 0,
		items = { gum = true },
		equipped = "gum",
	}
end

function Progression.tierIndex(rating: number): number
	local index = 1
	for i, tier in Config.Tiers do
		if rating >= tier.min then
			index = i
		end
	end
	return index
end

function Progression.capRating(rebirths: number): number
	local next = Config.Tiers[rebirths + 2]
	return if next then next.min else Config.TopRating
end

-- Returns tier index and fraction 0..1 towards the next tier (or TopRating).
function Progression.tierProgress(rating: number): (number, number)
	local index = Progression.tierIndex(rating)
	local low = Config.Tiers[index].min
	local nextTier = Config.Tiers[index + 1]
	local high = if nextTier then nextTier.min else Config.TopRating
	return index, math.clamp((rating - low) / (high - low), 0, 1)
end

function Progression.clickGain(data: Data, ctx: ClickContext): number
	local item = Config.Items[data.equipped]
	if not item then
		return 0
	end
	local gain = item.power * (1 + Config.Mult.PerRebirth * data.rebirths) * ctx.trainerMult * (ctx.factor or 1)
	if Progression.tierIndex(data.rating) <= data.rebirths then
		gain *= Config.Mult.PassedTier
	end
	if ctx.hasX2 then
		gain *= Config.Mult.X2
	end
	return gain
end

-- Mutates data. Returns rating added (after cap clamp) and glow added.
function Progression.applyClick(data: Data, ctx: ClickContext): (number, number)
	local gain = Progression.clickGain(data, ctx)
	local before = data.rating
	data.rating = math.min(before + gain, Progression.capRating(data.rebirths))
	data.glow += gain
	return data.rating - before, gain
end

-- Self-inflicted mistake (e.g. Bone Tapper hit in the wrong place): lose `factor` base clicks
-- of rating and Glow. Base = no trainer/x2 boosts. Never below zero. Returns amount lost.
function Progression.applyPenalty(data: Data, factor: number): number
	local loss = Progression.clickGain(data, { trainerMult = 1, hasX2 = false, factor = factor })
	data.rating = math.max(0, data.rating - loss)
	data.glow = math.max(0, data.glow - loss)
	return loss
end

function Progression.canRebirth(data: Data): boolean
	return data.rebirths < Config.MaxRebirths and data.rating >= Progression.capRating(data.rebirths)
end

function Progression.applyRebirth(data: Data)
	local fresh = Progression.defaultData()
	data.rebirths += 1
	data.rating = fresh.rating
	data.glow = fresh.glow
	data.items = fresh.items
	data.equipped = fresh.equipped
end

function Progression.canBuy(data: Data, itemId: any): (boolean, string?)
	local item = if typeof(itemId) == "string" then Config.Items[itemId] else nil
	if not item then
		return false, "unknown"
	end
	if data.items[itemId] then
		return false, "owned"
	end
	if data.glow < item.price then
		return false, "glow"
	end
	return true, nil
end

function Progression.applyBuy(data: Data, itemId: string)
	data.glow -= Config.Items[itemId].price
	data.items[itemId] = true
	data.equipped = itemId
end

return Progression
