-- Trees, bushes, rocks, hedges and flowers. Every function takes the map rng so the
-- layout is the same on every server.
local Kit = require(script.Parent.Kit)

local part = Kit.part
local pick = Kit.pick

local Flora = {}

local LEAVES = {
	{ Color3.fromRGB(48, 120, 62), Color3.fromRGB(72, 152, 70), Color3.fromRGB(112, 186, 84) },
	{ Color3.fromRGB(40, 110, 76), Color3.fromRGB(62, 142, 90), Color3.fromRGB(98, 176, 102) },
	{ Color3.fromRGB(70, 128, 52), Color3.fromRGB(104, 160, 60), Color3.fromRGB(150, 196, 82) },
}
local BLOSSOM = { Color3.fromRGB(232, 128, 172), Color3.fromRGB(250, 162, 196), Color3.fromRGB(255, 208, 226) }
local PINE = { Color3.fromRGB(34, 92, 66), Color3.fromRGB(44, 108, 74), Color3.fromRGB(58, 126, 82) }
local BARK = Color3.fromRGB(104, 72, 50)
local SOIL = Color3.fromRGB(78, 56, 44)

Flora.FLOWERS = {
	Color3.fromRGB(255, 112, 166),
	Color3.fromRGB(255, 214, 82),
	Color3.fromRGB(176, 128, 255),
	Color3.fromRGB(255, 250, 240),
	Color3.fromRGB(110, 196, 255),
	Color3.fromRGB(255, 150, 90),
}

local function trunk(parent: Instance, base: Vector3, height: number, width: number, color: Color3?)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color or BARK,
		Material = Enum.Material.Wood,
	}).Parent = parent
end

local function canopy(parent: Instance, rng: Random, base: Vector3, height: number, scale: number, shades: { Color3 })
	-- three layered balls, darker below and lighter on top: reads as volume from above
	for i, layer in {
		{ Vector3.new(0, 0, 0), 7.2 },
		{ Vector3.new(rng:NextNumber(-1.4, 1.4), 1.8, rng:NextNumber(-1.4, 1.4)), 5.6 },
		{ Vector3.new(rng:NextNumber(-0.8, 0.8), 3.4, rng:NextNumber(-0.8, 0.8)), 3.8 },
	} do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * layer[2] * scale,
			Position = base + Vector3.new(0, height, 0) + layer[1] * scale,
			Color = shades[i],
			Material = Enum.Material.Grass,
			CanCollide = false,
		}).Parent = parent
	end
end

function Flora.oak(parent: Instance, rng: Random, position: Vector3, scale: number)
	local height = 7 * scale
	trunk(parent, position, height, 1.4 * scale)
	canopy(parent, rng, position, height, scale, pick(rng, LEAVES))
end

function Flora.blossom(parent: Instance, rng: Random, position: Vector3, scale: number)
	local height = 6 * scale
	trunk(parent, position, height, 1.1 * scale, Color3.fromRGB(86, 58, 52))
	canopy(parent, rng, position, height, scale * 0.9, BLOSSOM)
end

-- Tiered pine: stacked discs shrinking upward.
function Flora.pine(parent: Instance, rng: Random, position: Vector3, scale: number)
	trunk(parent, position, 4 * scale, 1.2 * scale)
	local shade = rng:NextInteger(0, 1)
	for i = 0, 3 do
		local radius = (5 - i * 1.1) * scale
		part({
			Name = "Needles",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2 * scale, radius * 2, radius * 2),
			CFrame = CFrame.new(position + Vector3.new(0, (3.6 + i * 2.6) * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = PINE[math.min(#PINE, i + shade + 1)]:Lerp(Color3.new(1, 1, 1), i * 0.03),
			Material = Enum.Material.Grass,
			CanCollide = false,
		}).Parent = parent
	end
	part({
		Name = "Needles",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8 * scale,
		Position = position + Vector3.new(0, 13.4 * scale, 0),
		Color = PINE[3],
		Material = Enum.Material.Grass,
		CanCollide = false,
	}).Parent = parent
end

-- Palm: slightly curved trunk and drooping fronds.
function Flora.palm(parent: Instance, rng: Random, position: Vector3, scale: number)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local seg = 2.6 * scale
	for i = 0, 3 do
		cf = cf * CFrame.Angles(0, 0, math.rad(-5))
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(seg + 0.3, (1.3 - i * 0.12) * scale, (1.3 - i * 0.12) * scale),
			CFrame = cf * CFrame.new(0, seg / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(150, 116, 78):Lerp(Color3.fromRGB(120, 90, 60), i * 0.25),
			Material = Enum.Material.Wood,
		}).Parent = parent
		cf = cf * CFrame.new(0, seg, 0)
	end
	local top = cf.Position
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local frond = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-22), 0, 0)
		part({
			Name = "Frond",
			Size = Vector3.new(1.8 * scale, 0.3, 6.4 * scale),
			CFrame = frond * CFrame.new(0, 0, -3 * scale),
			Color = if i % 2 == 0 then Color3.fromRGB(70, 156, 76) else Color3.fromRGB(96, 178, 84),
			Material = Enum.Material.Grass,
			CanCollide = false,
			CastShadow = true,
		}).Parent = parent
	end
	for _, offset in { Vector3.new(0.6, -0.6, 0), Vector3.new(-0.4, -0.7, 0.5) } do
		part({
			Name = "Coconut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9 * scale,
			Position = top + offset * scale,
			Color = Color3.fromRGB(110, 78, 46),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}).Parent = parent
	end
end

function Flora.bush(parent: Instance, rng: Random, position: Vector3)
	local shades = pick(rng, LEAVES)
	local flowering = rng:NextNumber() < 0.3
	for i = 1, 2 do
		local size = rng:NextNumber(2.4, 3.8) / i
		part({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = position + Vector3.new(rng:NextNumber(-0.8, 0.8), size * 0.35 + (i - 1) * 0.9, rng:NextNumber(-0.8, 0.8)),
			Color = if flowering and i == 2 then pick(rng, BLOSSOM) else shades[i + 1],
			Material = Enum.Material.Grass,
			CanCollide = false,
		}).Parent = parent
	end
end

function Flora.rock(parent: Instance, rng: Random, position: Vector3)
	local s = rng:NextNumber(1.5, 4)
	part({
		Name = "Rock",
		Size = Vector3.new(s, s * 0.6, s * rng:NextNumber(0.7, 1.2)),
		CFrame = CFrame.new(position + Vector3.new(0, s * 0.2, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(132, 128, 138),
		Material = Enum.Material.Slate,
	}).Parent = parent
end

function Flora.flowerPatch(parent: Instance, rng: Random, position: Vector3)
	local color = pick(rng, Flora.FLOWERS)
	for _ = 1, rng:NextInteger(3, 5) do
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			Position = position + Vector3.new(rng:NextNumber(-1.8, 1.8), 0.5, rng:NextNumber(-1.8, 1.8)),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		}).Parent = parent
	end
end

-- Trimmed hedge along `cframe`'s X axis.
function Flora.hedge(parent: Instance, cframe: CFrame, length: number)
	part({
		Name = "Hedge",
		Size = Vector3.new(length, 2.6, 2.2),
		CFrame = cframe * CFrame.new(0, 1.3, 0),
		Color = Color3.fromRGB(52, 122, 64),
		Material = Enum.Material.Grass,
	}).Parent = parent
end

-- Raised flower bed along `cframe`'s X axis: wooden edge, soil, a row of flowers.
function Flora.flowerBed(parent: Instance, rng: Random, cframe: CFrame, length: number)
	part({
		Name = "BedEdge",
		Size = Vector3.new(length, 0.8, 2.6),
		CFrame = cframe * CFrame.new(0, 0.4, 0),
		Color = Color3.fromRGB(196, 150, 110),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	part({
		Name = "Soil",
		Size = Vector3.new(length - 0.5, 0.2, 2.1),
		CFrame = cframe * CFrame.new(0, 0.85, 0),
		Color = SOIL,
		Material = Enum.Material.Ground,
		CanCollide = false,
	}).Parent = parent
	local a, b = pick(rng, Flora.FLOWERS), pick(rng, Flora.FLOWERS)
	local count = math.max(2, math.floor(length / 2))
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * length / count
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.1,
			CFrame = cframe * CFrame.new(x, 1.3, if i % 2 == 0 then 0.4 else -0.4),
			Color = if i % 2 == 0 then a else b,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		}).Parent = parent
	end
end

return Flora
