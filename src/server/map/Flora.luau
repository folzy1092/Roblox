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

-- Ellipsoid leaf blob: a Part with a sphere SpecialMesh fills its (non-uniform) box.
local function blob(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local p = part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

local function canopy(parent: Instance, rng: Random, base: Vector3, height: number, scale: number, shades: { Color3 })
	-- a cluster of soft clumps: big core, side clumps around it, a lighter crown on top
	local top = base + Vector3.new(0, height, 0)
	blob(parent, "Leaves", Vector3.new(7, 5.4, 7) * scale, CFrame.new(top), shades[1])
	local count = rng:NextInteger(4, 5)
	local spin = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = spin + i / count * math.pi * 2
		local r = rng:NextNumber(2.2, 3) * scale
		local s = rng:NextNumber(3.6, 4.8) * scale
		blob(parent, "Leaves", Vector3.new(s, s * 0.8, s),
			CFrame.new(top + Vector3.new(math.cos(a) * r, rng:NextNumber(-0.6, 1.2) * scale, math.sin(a) * r)),
			shades[(i % 2) + 1])
	end
	blob(parent, "Leaves", Vector3.new(4.6, 3.6, 4.6) * scale,
		CFrame.new(top + Vector3.new(rng:NextNumber(-0.6, 0.6), 2.4 * scale, rng:NextNumber(-0.6, 0.6))), shades[3])
end

function Flora.oak(parent: Instance, rng: Random, position: Vector3, scale: number)
	local height = 7 * scale
	trunk(parent, position, height + 1, 0.9 * scale)
	canopy(parent, rng, position, height, scale, pick(rng, LEAVES))
end

function Flora.blossom(parent: Instance, rng: Random, position: Vector3, scale: number)
	local height = 6 * scale
	trunk(parent, position, height + 1, 0.75 * scale, Color3.fromRGB(86, 58, 52))
	canopy(parent, rng, position, height, scale * 0.9, BLOSSOM)
end

-- Fir: soft overlapping skirts that get narrower toward a pointed tip (no flat discs).
function Flora.pine(parent: Instance, rng: Random, position: Vector3, scale: number)
	trunk(parent, position, 3.5 * scale, 0.8 * scale)
	local shade = rng:NextInteger(0, 1)
	local layers = 6
	for i = 0, layers - 1 do
		local t = i / (layers - 1)
		local width = (6.4 - 5 * t) * scale
		local tall = (3.2 - 1.2 * t) * scale
		local y = (3 + i * 1.9) * scale
		blob(parent, "Needles", Vector3.new(width, tall, width),
			CFrame.new(position + Vector3.new(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			PINE[math.min(#PINE, math.floor(t * 2) + shade + 1)])
	end
	blob(parent, "Needles", Vector3.new(1.2, 2.6, 1.2) * scale,
		CFrame.new(position + Vector3.new(0, (3 + layers * 1.9) * scale, 0)), PINE[3])
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
	for i = 1, 3 do
		local size = rng:NextNumber(2.2, 3.4) * (1 - (i - 1) * 0.2)
		blob(parent, "Bush", Vector3.new(size, size * 0.75, size),
			CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), size * 0.3 + (i - 1) * 0.4, rng:NextNumber(-1, 1))),
			if flowering and i == 3 then pick(rng, BLOSSOM) else shades[math.min(3, i)])
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
