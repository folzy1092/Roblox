-- Man-made decor: lamps, benches, planters, gym sculptures and the plaza fountain.
local Kit = require(script.Parent.Kit)
local Flora = require(script.Parent.Flora)

local part = Kit.part
local disc = Kit.disc

local Props = {}

local IRON = Color3.fromRGB(42, 40, 52)
local MARBLE = Color3.fromRGB(240, 234, 226)
local WARM = Color3.fromRGB(255, 214, 160)

-- Lantern street lamp with a glowing core inside a glass box.
function Props.lamp(parent: Instance, position: Vector3, accent: Color3?)
	part({
		Name = "LampBase",
		Size = Vector3.new(1.4, 0.8, 1.4),
		Position = position + Vector3.new(0, 0.4, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
	}).Parent = parent
	part({
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 0.45, 0.45),
		CFrame = CFrame.new(position + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = IRON,
		Material = Enum.Material.Metal,
	}).Parent = parent
	part({
		Name = "LampRing",
		Size = Vector3.new(1.3, 0.25, 1.3),
		Position = position + Vector3.new(0, 8.6, 0),
		Color = accent or Color3.fromRGB(255, 190, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}).Parent = parent
	part({
		Name = "Lantern",
		Size = Vector3.new(1.5, 1.9, 1.5),
		Position = position + Vector3.new(0, 9.7, 0),
		Color = Color3.fromRGB(255, 236, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CanCollide = false,
	}).Parent = parent
	local core = part({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		Position = position + Vector3.new(0, 9.7, 0),
		Color = WARM,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	Kit.light(core, Color3.fromRGB(255, 205, 140), 18, 1.4)
	core.Parent = parent
	part({
		Name = "LampCap",
		Size = Vector3.new(2, 0.35, 2),
		Position = position + Vector3.new(0, 10.8, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
	}).Parent = parent
end

-- Park bench; `cframe` -Z is where people look when they sit.
function Props.bench(parent: Instance, cframe: CFrame)
	part({
		Name = "BenchSeat",
		Size = Vector3.new(6, 0.4, 2),
		CFrame = cframe * CFrame.new(0, 1.4, 0),
		Color = Color3.fromRGB(176, 118, 72),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	part({
		Name = "BenchBack",
		Size = Vector3.new(6, 1.4, 0.3),
		CFrame = cframe * CFrame.new(0, 2.5, 0.9) * CFrame.Angles(math.rad(10), 0, 0),
		Color = Color3.fromRGB(176, 118, 72),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	for _, x in { -2.5, 2.5 } do
		part({
			Name = "BenchLeg",
			Size = Vector3.new(0.4, 1.2, 1.8),
			CFrame = cframe * CFrame.new(x, 0.6, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
		}).Parent = parent
	end
end

-- Round marble planter with a bush and a few flowers.
function Props.planter(parent: Instance, rng: Random, position: Vector3, radius: number, rim: Color3?)
	disc({ Name = "Planter", Color = MARBLE, Material = Enum.Material.Marble }, position + Vector3.new(0, 1.4, 0), radius, 1.4)
		.Parent = parent
	disc({
		Name = "PlanterRim",
		Color = rim or Color3.fromRGB(230, 170, 120),
		Material = Enum.Material.SmoothPlastic,
	}, position + Vector3.new(0, 1.6, 0), radius + 0.15, 0.25).Parent = parent
	disc({ Name = "Soil", Color = Color3.fromRGB(78, 56, 44), Material = Enum.Material.Ground, CanCollide = false },
		position + Vector3.new(0, 1.65, 0), radius - 0.3, 0.1).Parent = parent
	part({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 1.3,
		Position = position + Vector3.new(0, 1.6 + radius * 0.5, 0),
		Color = Color3.fromRGB(62, 142, 76),
		Material = Enum.Material.Grass,
		CanCollide = false,
	}).Parent = parent
	local color = Kit.pick(rng, Flora.FLOWERS)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(0, 0.6)
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Position = position + Vector3.new(math.cos(a) * (radius - 0.5), 1.9, math.sin(a) * (radius - 0.5)),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		}).Parent = parent
	end
end

-- Giant dumbbell sculpture lying on a plinth (gym landmark).
function Props.dumbbell(parent: Instance, cframe: CFrame, color: Color3)
	part({
		Name = "Plinth",
		Size = Vector3.new(9, 1, 4),
		CFrame = cframe * CFrame.new(0, 0.5, 0),
		Color = MARBLE,
		Material = Enum.Material.Marble,
	}).Parent = parent
	part({
		Name = "Bar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 0.8, 0.8),
		CFrame = cframe * CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(205, 210, 220),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
	}).Parent = parent
	for _, x in { -3.2, 3.2 } do
		part({
			Name = "Plate",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 4, 4),
			CFrame = cframe * CFrame.new(x, 3, 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		}).Parent = parent
	end
end

-- Tiered marble fountain with a glowing golden crystal on top and water spray.
function Props.fountain(parent: Instance, center: Vector3)
	local water = Color3.fromRGB(120, 210, 240)
	disc({ Name = "FountainRim", Color = Color3.fromRGB(255, 120, 180), Material = Enum.Material.Neon },
		center + Vector3.new(0, 0.55, 0), 10.3, 0.5).Parent = parent
	disc({ Name = "FountainBasin", Color = MARBLE, Material = Enum.Material.Marble }, center + Vector3.new(0, 1.8, 0), 10, 1.5)
		.Parent = parent
	disc({
		Name = "FountainWater",
		Color = water,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Reflectance = 0.15,
	}, center + Vector3.new(0, 1.9, 0), 9.2, 0.3).Parent = parent
	disc({ Name = "FountainColumn", Color = MARBLE, Material = Enum.Material.Marble }, center + Vector3.new(0, 5.4, 0), 2, 3.6)
		.Parent = parent
	disc({ Name = "FountainBowl", Color = MARBLE, Material = Enum.Material.Marble }, center + Vector3.new(0, 6.2, 0), 5, 0.9)
		.Parent = parent
	disc({
		Name = "FountainWater",
		Color = water,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	}, center + Vector3.new(0, 6.3, 0), 4.4, 0.3).Parent = parent
	disc({ Name = "FountainColumn", Color = Color3.fromRGB(255, 200, 70), Material = Enum.Material.Metal },
		center + Vector3.new(0, 9.4, 0), 0.9, 3.2).Parent = parent

	-- the "glow" crystal: tilted golden cube, lit from inside
	local crystal = part({
		Name = "GlowCrystal",
		Size = Vector3.one * 3.4,
		CFrame = CFrame.new(center + Vector3.new(0, 12.2, 0)) * CFrame.Angles(math.rad(45), math.rad(35), math.rad(35)),
		Color = Color3.fromRGB(255, 205, 80),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Kit.light(crystal, Color3.fromRGB(255, 200, 120), 26, 1.6)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.4)
	sparkle.LightEmission = 0.6
	sparkle.Parent = crystal
	crystal.Parent = parent

	-- water jets from the top bowl falling into the basin
	local jet = part({
		Name = "FountainJet",
		Size = Vector3.new(6, 0.2, 6),
		Position = center + Vector3.new(0, 6.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	spray.Transparency = NumberSequence.new(0.4, 1)
	spray.Size = NumberSequence.new(0.6, 1.4)
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.Speed = NumberRange.new(7, 9)
	spray.SpreadAngle = Vector2.new(28, 28)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.LightEmission = 0.3
	spray.Parent = jet
	jet.Parent = parent
end

return Props
