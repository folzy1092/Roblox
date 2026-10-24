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

-- rarity drives shop card colors
Config.Items = {
	gum = { power = 1, price = 0, order = 1, rarity = "Common" },
	mewing = { power = 3, price = 150, order = 2, rarity = "Common" },
	jawball = { power = 8, price = 1200, order = 3, rarity = "Rare" },
	guasha = { power = 20, price = 6000, order = 4, rarity = "Epic" },
	bonetapper = { power = 50, price = 25000, order = 5, rarity = "Legendary" },
}

Config.Mult = {
	Trainer = 3,
	Vip = 6,
	X2 = 2,
	Boost = 2, -- x2 boost developer product
	PassedTier = 3,
	PerRebirth = 0.5,
}

Config.ClickLimitPerSec = 12

-- Experimental procedural head mesh (client/HeadMesh). Off: quality not good enough yet,
-- tier heads will come from ready-made models.
Config.UseMeshHeads = false
-- Own head pack from tools/blender/make_heads.py, imported into ReplicatedStorage.TierHeads
-- (Head1..Head8). Worn over the avatar head by server/HeadWear.
Config.UseTierHeadModels = true
-- Plain numbers (no Roblox types here, Config is also loaded by Lune tests).
Config.TierHeadFit = {
	scale = { 1.35, 1.35, 1.35 }, -- model height = avatar head height * y (x/z keep model proportions)
	offsetY = 0.12, -- studs: raise so the face sits where the avatar head was (hair line on top)
	rotateY = 0, -- degrees, if the imported model faces the wrong way
}
-- Face shape of each tier model (fat, jaw) — must match TIERS in make_heads.py.
Config.TierShapes = {
	{ fat = 1.0, jaw = 0.0 },
	{ fat = 0.75, jaw = 0.12 },
	{ fat = 0.5, jaw = 0.26 },
	{ fat = 0.3, jaw = 0.4 },
	{ fat = 0.15, jaw = 0.55 },
	{ fat = 0.05, jaw = 0.7 },
	{ fat = 0.0, jaw = 0.85 },
	{ fat = 0.0, jaw = 1.0 },
}

-- Catalog heads per tier: off — user didn't like them; own Blender heads are coming.
Config.UseCatalogHeads = false
-- Ready-made catalog Dynamic Head asset ids per tier (index = Config.Tiers index).
-- Swapped on the avatar by server/HeadSwap. Replace any id to change a tier's head.
Config.TierHeads = {
	136967365144969, -- Sub-3: [Recolorable] Fat Baby Head
	113829053542009, -- Sub-5: Recolorable Derpy Chubby Stare Face
	111537048429429, -- LTN: Tired Guy Neutral Face (Recolorable)
	88262921856011, -- MTN: Friendly Guy Face (Recolorable)
	92149876723195, -- HTN: Jawline Anime Male Head
	127751361486358, -- Chadlite: Handsome Mog Man v2
	127729810850806, -- Chad: True Sigma Mewing Mogger Face
	14544640290, -- True Adam: GigaChad
}

-- Old part-based cheeks/jaw sculpt (server/Face). Off: looked like blocks.
Config.UsePartSculpt = false

-- trainer seat: max sitting time, then a pause before the same player can sit again
Config.SeatMaxSeconds = 90
Config.SeatCooldownSeconds = 10
Config.SeatLeaveCooldown = 5 -- after standing up on your own

-- In Studio playtests act as if every gamepass is owned (to test VIP seats, x2).
Config.StudioOwnsAllPasses = true
-- In Studio playtests unlock every item (progress is then not saved).
Config.StudioGrantAllItems = true

-- 0 = gamepass not created yet (treated as not owned)
Config.GamePasses = {
	Vip = 0,
	X2 = 0,
	AutoClick = 0,
}

-- Developer products (bought many times). 0 = not created yet.
Config.DevProducts = {
	Boost15 = 0, -- x2 rating & Glow for 15 minutes
	Recover = 0, -- instantly recover from a Bone Tapper stun
}
Config.BoostSeconds = 15 * 60
Config.AutoClickPerSec = 6

-- What the VIP/store panel shows. Real price is set on the Roblox site; this is the label.
Config.StoreItems = {
	{ pass = "Vip", price = 249, order = 1 },
	{ pass = "X2", price = 199, order = 2 },
	{ pass = "AutoClick", price = 149, order = 3 },
	{ product = "Boost15", price = 29, order = 4 },
	{ product = "Recover", price = 15, order = 5 },
}

return Config
