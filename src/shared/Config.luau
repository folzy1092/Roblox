-- Game balance numbers. Tune here, nowhere else.
local Config = {}

Config.Tiers = {
	{ id = "Sub3", name = "Sub-3", min = 0 },
	{ id = "Sub5", name = "Sub-5", min = 1000 },
	{ id = "LTN", name = "LTN", min = 4000 },
	{ id = "MTN", name = "MTN", min = 12000 },
	{ id = "HTN", name = "HTN", min = 35000 },
	{ id = "Chadlite", name = "Chadlite", min = 100000 },
	{ id = "Chad", name = "Chad", min = 300000 },
	{ id = "TrueAdam", name = "True Adam", min = 900000 },
}

Config.TopRating = 2500000
Config.MaxRebirths = 7

Config.Items = {
	gum = { power = 1, price = 0, order = 1 },
	mewing = { power = 3, price = 150, order = 2 },
}

Config.Mult = {
	Trainer = 3,
	Vip = 6,
	X2 = 2,
	PassedTier = 3,
	PerRebirth = 0.5,
}

Config.ClickLimitPerSec = 12

-- 0 = gamepass not created yet (treated as not owned)
Config.GamePasses = {
	Vip = 0,
	X2 = 0,
}

return Config
