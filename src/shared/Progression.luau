-- Pure progression math. No Roblox APIs: unit-tested with Lune.
local Config = if script then require(script.Parent.Config) else require("./Config")

export type Data = {
	version: number,
	rating: number,
	glow: number,
	rebirths: number,
	items: { [string]: boolean },
	equipped: string,
	boostLeft: number, -- seconds of x2 boost left (ticks only while online)
	receipts: { string }, -- recent developer-product purchase ids (grant once)
	duelWins: number,
	dailyDay: number, -- streak day claimed last (1..7), 0 = never
	dailyLast: number, -- UTC day number of the last claim
	inventory: { [string]: number }, -- reward boosts not used yet (Config.RewardItems ids)
	vipLeft: number, -- seconds of VIP trainers from a reward boost
	autoLeft: number, -- seconds of auto-click from a reward boost
}

export type ClickContext = {
	trainerMult: number,
	hasX2: boolean,
	factor: number?, -- mini-game rep worth (1 = plain click)
	hasBoost: boolean?, -- active x2 boost product
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
		boostLeft = 0,
		receipts = {},
		duelWins = 0,
		dailyDay = 0,
		dailyLast = 0,
		inventory = {},
		vipLeft = 0,
		autoLeft = 0,
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
	if ctx.hasBoost then
		gain *= Config.Mult.Boost
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

Progression.MAX_BOOST = 24 * 3600
local MAX_RECEIPTS = 50

function Progression.addBoost(data: Data, seconds: number)
	data.boostLeft = math.min(Progression.MAX_BOOST, data.boostLeft + seconds)
end

-- Remembers a purchase id. Returns false if it was already granted.
function Progression.markReceipt(data: Data, purchaseId: string): boolean
	if table.find(data.receipts, purchaseId) then
		return false
	end
	table.insert(data.receipts, purchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
	return true
end

---------------------------------------------------------------- daily bonus

local function dayNumber(now: number): number
	return math.floor(now / 86400)
end

-- Which streak day comes next and whether it can be claimed now (`now` = unix seconds).
function Progression.dailyStatus(data: Data, now: number): (number, boolean)
	local today = dayNumber(now)
	if data.dailyLast == today then
		return data.dailyDay, false -- already claimed today
	elseif data.dailyLast == today - 1 then
		return data.dailyDay % #Config.DailyRewards + 1, true -- streak goes on (after day 7: day 1)
	end
	return 1, true -- first time or missed a day
end

-- Mutates data. Puts the day's rewards in the inventory. Returns the day and the reward ids,
-- or nil if today's bonus is already taken.
function Progression.claimDaily(data: Data, now: number): (number?, { string })
	local day, ready = Progression.dailyStatus(data, now)
	if not ready then
		return nil, {}
	end
	local rewards = Config.DailyRewards[day]
	for _, id in rewards do
		data.inventory[id] = (data.inventory[id] or 0) + 1
	end
	data.dailyDay = day
	data.dailyLast = dayNumber(now)
	return day, rewards
end

---------------------------------------------------------------- inventory boosts

local EFFECT_FIELD = { x2 = "boostLeft", vip = "vipLeft", auto = "autoLeft" }

-- Switches on one inventory boost: its minutes add to that effect's timer. False if not owned.
function Progression.useItem(data: Data, id: any): boolean
	local item = if typeof(id) == "string" then Config.RewardItems[id] else nil
	if not item or (data.inventory[id] or 0) <= 0 then
		return false
	end
	data.inventory[id] -= 1
	if data.inventory[id] <= 0 then
		data.inventory[id] = nil
	end
	local field = EFFECT_FIELD[item.effect]
	data[field] = math.min(Progression.MAX_BOOST, data[field] + item.minutes * 60)
	return true
end

-- Ticks the timed effects down. Returns true when the client should be told (an effect ended
-- or a 10-second mark passed).
function Progression.tickEffects(data: Data, seconds: number): boolean
	local changed = false
	for _, field in EFFECT_FIELD do
		local left = data[field]
		if left > 0 then
			data[field] = math.max(0, left - seconds)
			if data[field] == 0 or data[field] % 10 == 0 then
				changed = true
			end
		end
	end
	return changed
end

return Progression
