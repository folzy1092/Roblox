-- Generates the lobby: grass terrain, plaza, mirrors, trainer seats, nature and decor.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local rng = Random.new(20261017) -- fixed seed: same map every server

local PLAZA_SIZE = Vector3.new(64, 4, 64)
local TRAINER_AREA_X = 40
local ARENA_CENTER = Vector3.new(0, 0, 84)
local ARENA_RADIUS = 26
local WORLD_RADIUS = 125 -- invisible wall; cliffs start right behind it
local POND = Vector3.new(-82, 0, 58)

-- Every trainer seat on the map: item, VIP?, position (x, z).
local TRAINER_SPOTS = {
	{ "gum", false, -40, -14 }, { "gum", false, -40, -2 }, { "gum", true, -40, 10 },
	{ "mewing", false, 40, -14 }, { "mewing", false, 40, -2 }, { "mewing", true, 40, 10 },
	{ "jawball", false, -26, 46 }, { "jawball", true, -38, 46 },
	{ "guasha", false, 26, 46 }, { "guasha", true, 38, 46 },
	{ "bonetapper", false, -32, -46 }, { "bonetapper", true, 32, -46 },
}
local TRAINER_TITLES = {
	gum = "Gum Trainer",
	mewing = "Mewing Trainer",
	jawball = "Jaw Ball Trainer",
	guasha = "Gua Sha Trainer",
	bonetapper = "Bone Tapper Trainer",
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function sign(parent: Instance, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(8, 1.5)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = parent
end

-- Framed mirror. `cframe` front (-Z) faces the viewer. The client draws a live
-- reflection on parts named MirrorSurface (see client/MirrorView).
local function mirror(parent: Instance, cframe: CFrame, size: Vector2, glow: Color3)
	part({
		Name = "MirrorFrame",
		Size = Vector3.new(size.X + 0.8, size.Y + 0.8, 0.4),
		CFrame = cframe * CFrame.new(0, 0, 0.2),
		Color = Color3.fromRGB(45, 40, 55),
		Material = Enum.Material.SmoothPlastic,
	}).Parent = parent

	local surface = part({
		Name = "MirrorSurface",
		Size = Vector3.new(size.X, size.Y, 0.2),
		CFrame = cframe,
		Color = Color3.fromRGB(140, 160, 185),
		Material = Enum.Material.SmoothPlastic, -- SurfaceGui reflection is not drawn on Glass
		Reflectance = 0.2,
		CanQuery = false,
	})
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Brightness = 0.6
	light.Range = 7
	light.Angle = 70
	light.Color = glow
	light.Parent = surface
	CollectionService:AddTag(surface, "Mirror") -- client finds mirrors by tag (works with streaming)
	surface.Parent = parent

	-- thin soft light strips on the frame edges
	local w, h, t = size.X / 2 + 0.25, size.Y / 2 + 0.25, 0.14
	for _, strip in {
		{ Vector3.new(size.X + 0.5, t, t), Vector3.new(0, h, -0.12) },
		{ Vector3.new(size.X + 0.5, t, t), Vector3.new(0, -h, -0.12) },
		{ Vector3.new(t, size.Y + 0.5, t), Vector3.new(w, 0, -0.12) },
		{ Vector3.new(t, size.Y + 0.5, t), Vector3.new(-w, 0, -0.12) },
	} do
		part({
			Name = "MirrorTrim",
			Size = strip[1],
			CFrame = cframe * CFrame.new(strip[2]),
			Color = glow,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			CanQuery = false,
		}).Parent = parent
	end
end

-- One trainer = platform + single Seat facing a mirror. Seat holds one player at a time.
local function trainer(folder: Folder, itemId: string, title: string, vip: boolean, position: Vector3)
	local model = Instance.new("Model")
	model.Name = `{itemId}{if vip then "_VIP" else ""}`
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Vip", vip)

	local color = if vip then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(90, 200, 120)
	model:SetAttribute("Color", color)
	local base = part({
		Name = "Base",
		Size = Vector3.new(8, 0.6, 8),
		Position = position,
		Color = Color3.fromRGB(60, 56, 70),
		Material = Enum.Material.SmoothPlastic,
	})
	base.Parent = model

	-- thin edge under the base: lights up while someone trains
	part({
		Name = "Trim",
		Size = Vector3.new(8.4, 0.3, 8.4),
		Position = position - Vector3.new(0, 0.2, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}).Parent = model

	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = CFrame.new(position + Vector3.new(0, 0.8, 1.5))
	seat.Color = color
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat:SetAttribute("TrainerSeat", true)
	seat.Parent = model

	part({
		Name = "Backrest",
		Size = Vector3.new(3, 3, 0.5),
		Position = position + Vector3.new(0, 2.5, 3.1),
		Color = color,
		Material = Enum.Material.Fabric,
	}).Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Sit"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat

	local mirrorPos = position + Vector3.new(0, 3.6, -3.4)
	mirror(model, CFrame.lookAt(mirrorPos, mirrorPos + Vector3.zAxis), Vector2.new(4.4, 5.6), color)

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "ActiveSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(color)
	sparkles.Rate = 5
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.Size = NumberSequence.new(0.2)
	sparkles.LightEmission = 0.3
	sparkles.Enabled = false
	sparkles.Parent = base

	sign(base, if vip then `VIP {title}` else title, color)

	local status = Instance.new("BillboardGui")
	status.Name = "Status"
	status.Size = UDim2.fromScale(4, 0.8)
	status.StudsOffset = Vector3.new(0, 8.6, 0)
	status.MaxDistance = 60
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Label"
	statusLabel.Size = UDim2.fromScale(1, 1)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Free"
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.FredokaOne
	statusLabel.TextColor3 = Color3.fromRGB(160, 255, 170)
	statusLabel.TextStrokeTransparency = 0.3
	statusLabel.Parent = status
	status.Parent = base

	model.PrimaryPart = base
	model.Parent = folder
end

local function inBuiltArea(x: number, z: number): boolean
	local plaza = math.abs(x) < PLAZA_SIZE.X / 2 + 6 and math.abs(z) < PLAZA_SIZE.Z / 2 + 6
	local titleWalk = math.abs(x) < 20 and z < -30 and z > -58
	local arena = (Vector3.new(x, 0, z) - ARENA_CENTER).Magnitude < ARENA_RADIUS + 10 or (math.abs(x) < 8 and z > 30 and z < 62)
	local pond = (Vector3.new(x, 0, z) - POND).Magnitude < 20
	if plaza or titleWalk or arena or pond then
		return true
	end
	for _, spot in TRAINER_SPOTS do
		if math.abs(x - spot[3]) < 11 and math.abs(z - spot[4]) < 11 then
			return true
		end
	end
	return false
end

local function scatterPoint(minRadius: number, maxRadius: number): Vector3?
	for _ = 1, 20 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minRadius, maxRadius)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if not inBuiltArea(x, z) then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

local LEAF_COLORS = {
	Color3.fromRGB(70, 150, 80),
	Color3.fromRGB(95, 175, 85),
	Color3.fromRGB(60, 130, 90),
	Color3.fromRGB(120, 190, 95),
}

local function tree(parent: Instance, position: Vector3, scale: number)
	local height = 8 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.4 * scale, 1.4 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(105, 70, 45),
		Material = Enum.Material.Wood,
	}).Parent = parent
	local leaf = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	for i = 1, 4 do
		local offset = if i == 1
			then Vector3.new(0, height + 1, 0)
			else Vector3.new(rng:NextNumber(-2, 2), height - 0.5 + rng:NextNumber(-1, 1), rng:NextNumber(-2, 2))
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (if i == 1 then 6.5 else 4.5) * scale,
			Position = position + offset * Vector3.new(scale, 1, scale),
			Color = leaf:Lerp(Color3.new(1, 1, 0.8), i * 0.04),
			Material = Enum.Material.Grass,
			CanCollide = false,
		}).Parent = parent
	end
end

local function bush(parent: Instance, position: Vector3)
	local leaf = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	for _ = 1, rng:NextInteger(2, 3) do
		local size = rng:NextNumber(2, 3.5)
		part({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = position + Vector3.new(rng:NextNumber(-1.2, 1.2), size * 0.35, rng:NextNumber(-1.2, 1.2)),
			Color = leaf,
			Material = Enum.Material.Grass,
			CanCollide = false,
		}).Parent = parent
	end
end

local function rock(parent: Instance, position: Vector3)
	local s = rng:NextNumber(1.5, 4)
	part({
		Name = "Rock",
		Size = Vector3.new(s, s * 0.6, s * rng:NextNumber(0.7, 1.2)),
		CFrame = CFrame.new(position + Vector3.new(0, s * 0.2, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(120, 118, 125),
		Material = Enum.Material.Slate,
	}).Parent = parent
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 110, 160),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(120, 200, 255),
}

local function flowerPatch(parent: Instance, position: Vector3)
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for _ = 1, rng:NextInteger(4, 7) do
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			Position = position + Vector3.new(rng:NextNumber(-2, 2), 0.5, rng:NextNumber(-2, 2)),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		}).Parent = parent
	end
end

local function lamp(parent: Instance, position: Vector3)
	part({
		Name = "Pole",
		Size = Vector3.new(0.5, 9, 0.5),
		Position = position + Vector3.new(0, 4.5, 0),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
	}).Parent = parent
	local bulb = part({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		Position = position + Vector3.new(0, 9.3, 0),
		Color = Color3.fromRGB(255, 225, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Parent = bulb
	bulb.Parent = parent
end

local function bench(parent: Instance, cframe: CFrame)
	part({
		Name = "BenchSeat",
		Size = Vector3.new(6, 0.4, 2),
		CFrame = cframe * CFrame.new(0, 1.4, 0),
		Color = Color3.fromRGB(150, 100, 60),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	for _, x in { -2.5, 2.5 } do
		part({
			Name = "BenchLeg",
			Size = Vector3.new(0.4, 1.2, 1.8),
			CFrame = cframe * CFrame.new(x, 0.6, 0),
			Color = Color3.fromRGB(40, 40, 50),
			Material = Enum.Material.Metal,
		}).Parent = parent
	end
end

local function titleSign(parent: Instance)
	local board = part({
		Name = "TitleBoard",
		Size = Vector3.new(34, 8, 1),
		Position = Vector3.new(0, 14, -48),
		Color = Color3.fromRGB(25, 20, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.AutoLocalize = false
	label.Text = "LOOKSMAX SIMULATOR"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 205, 70)
	label.Parent = gui
	gui.Parent = board
	board.Parent = parent
	for _, x in { -15, 15 } do
		part({
			Name = "TitlePillar",
			Size = Vector3.new(1.5, 18, 1.5),
			Position = Vector3.new(x, 9, -48),
			Color = Color3.fromRGB(70, 60, 90),
			Material = Enum.Material.SmoothPlastic,
		}).Parent = parent
	end
end

-- Duel arena: round stage with two facing duel pads, neon ring, stands and a big sign.
local function duelArena()
	local folder = Instance.new("Model")
	folder.Name = "DuelArena"
	local c = ARENA_CENTER
	local red = Color3.fromRGB(235, 70, 80)

	part({
		Name = "Stage",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, ARENA_RADIUS * 2, ARENA_RADIUS * 2),
		CFrame = CFrame.new(c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 35, 60),
		Material = Enum.Material.SmoothPlastic,
	}).Parent = folder
	part({
		Name = "StageRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, ARENA_RADIUS * 2 + 1.5, ARENA_RADIUS * 2 + 1.5),
		CFrame = CFrame.new(c + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = red,
		Material = Enum.Material.Neon,
	}).Parent = folder
	part({
		Name = "ArenaSpawn",
		Size = Vector3.new(6, 0.2, 6),
		Position = c + Vector3.new(0, 1.3, -(ARENA_RADIUS - 6)),
		Transparency = 1,
		CanCollide = false,
	}).Parent = folder

	-- two duel pads facing each other, each with its own mirror
	for _, side in { -1, 1 } do
		local padPos = c + Vector3.new(side * 9, 1.4, 0)
		part({
			Name = "DuelPad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 7, 7),
			CFrame = CFrame.new(padPos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if side < 0 then Color3.fromRGB(80, 160, 255) else red,
			Material = Enum.Material.Neon,
		}).Parent = folder
		local mirrorPos = padPos + Vector3.new(side * 5, 3.4, 0)
		mirror(folder, CFrame.lookAt(mirrorPos, mirrorPos - Vector3.new(side, 0, 0)), Vector2.new(4.4, 5.6),
			if side < 0 then Color3.fromRGB(80, 160, 255) else red)
	end
	local vs = part({
		Name = "VsSign",
		Size = Vector3.new(1, 1, 1),
		Position = c + Vector3.new(0, 9, 0),
		Transparency = 1,
		CanCollide = false,
	})
	sign(vs, "VS", Color3.fromRGB(255, 220, 220))
	vs.Parent = folder

	-- neon posts around the ring
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * (ARENA_RADIUS + 1.5), 0, math.sin(a) * (ARENA_RADIUS + 1.5))
		part({
			Name = "Post",
			Size = Vector3.new(0.8, 6, 0.8),
			Position = pos + Vector3.new(0, 3, 0),
			Color = Color3.fromRGB(40, 35, 50),
			Material = Enum.Material.Metal,
		}).Parent = folder
		part({
			Name = "PostLight",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.2,
			Position = pos + Vector3.new(0, 6.4, 0),
			Color = if i % 2 == 0 then red else Color3.fromRGB(80, 160, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}).Parent = folder
	end

	-- stands on the far side
	for row = 0, 2 do
		part({
			Name = "Stand",
			Size = Vector3.new(30, 1.2, 3),
			Position = c + Vector3.new(0, 0.6 + row * 1.2, ARENA_RADIUS + 5 + row * 3),
			Color = Color3.fromRGB(70, 60, 90):Lerp(Color3.new(1, 1, 1), row * 0.06),
			Material = Enum.Material.SmoothPlastic,
		}).Parent = folder
	end

	local board = part({
		Name = "ArenaBoard",
		Size = Vector3.new(26, 6, 1),
		Position = c + Vector3.new(0, 14, ARENA_RADIUS + 14),
		Color = Color3.fromRGB(30, 20, 35),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Duel Arena"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = red
	label.Parent = gui
	gui.Parent = board
	board.Parent = folder

	folder.Parent = workspace
end

local function cliffs(t: Terrain)
	local cliffRng = Random.new(77)
	-- inner ring of rocky hills right behind the wall, outer ring of bigger peaks
	for _, ring in { { WORLD_RADIUS + 22, 18, 30, 4 }, { WORLD_RADIUS + 55, 30, 48, 6 } } do
		local radius, minR, maxR, step = ring[1], ring[2], ring[3], ring[4]
		for deg = 0, 359, step do
			local a = math.rad(deg + cliffRng:NextNumber(-2, 2))
			local r = radius + cliffRng:NextNumber(-6, 6)
			local size = cliffRng:NextNumber(minR, maxR)
			local center = Vector3.new(math.cos(a) * r, cliffRng:NextNumber(-size * 0.35, size * 0.15), math.sin(a) * r)
			t:FillBall(center, size, if cliffRng:NextNumber() < 0.7 then Enum.Material.Rock else Enum.Material.Slate)
			-- grassy caps on some peaks
			if cliffRng:NextNumber() < 0.5 then
				t:FillBall(center + Vector3.new(0, size * 0.75, 0), size * 0.35, Enum.Material.LeafyGrass)
			end
		end
	end
end

local function pond(t: Terrain)
	t:FillCylinder(CFrame.new(POND + Vector3.new(0, -1, 0)), 4, 17, Enum.Material.Sand)
	t:FillCylinder(CFrame.new(POND + Vector3.new(0, 0, 0)), 6, 13, Enum.Material.Air)
	t:FillCylinder(CFrame.new(POND + Vector3.new(0, -3.5, 0)), 3, 13, Enum.Material.Water)
end

local function terrain()
	local t = workspace.Terrain
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(400, 12, 400), Enum.Material.Grass)
	-- plaza, paths to trainer areas, title sign and arena
	t:FillBlock(CFrame.new(0, -2, 0), PLAZA_SIZE, Enum.Material.Pavement)
	t:FillBlock(CFrame.new(0, -2, -2), Vector3.new(TRAINER_AREA_X * 2 + 28, 4, 8), Enum.Material.Pavement)
	t:FillBlock(CFrame.new(0, -2, -44), Vector3.new(8, 4, 24), Enum.Material.Pavement)
	t:FillBlock(CFrame.new(0, -2, 46), Vector3.new(8, 4, 32), Enum.Material.Pavement)
	for _, spot in TRAINER_SPOTS do
		t:FillBlock(CFrame.new(spot[3], -2, spot[4]), Vector3.new(14, 4, 14), Enum.Material.Cobblestone)
	end
	pond(t)
	cliffs(t)
	pcall(function()
		(t :: any).Decoration = true -- animated grass blades
	end)
	t.WaterWaveSize = 0.1
	t.WaterColor = Color3.fromRGB(60, 140, 160)
end

-- Invisible ring wall so players can't walk out to the cliffs or the map edge.
local function walls()
	local folder = Instance.new("Folder")
	folder.Name = "Walls"
	local count = 36
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		local pos = Vector3.new(math.cos(a) * WORLD_RADIUS, 100, math.sin(a) * WORLD_RADIUS)
		part({
			Name = "Wall",
			Size = Vector3.new(2 * math.pi * WORLD_RADIUS / count + 2, 220, 2),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, 100, 0)),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		}).Parent = folder
	end
	folder.Parent = workspace
end

local function lighting()
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 150)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Color = Color3.fromRGB(255, 215, 200)
	atmosphere.Decay = Color3.fromRGB(130, 110, 170)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 20
	bloom.Threshold = 2
	bloom.Parent = Lighting
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.Parent = Lighting
end

local function nature()
	local folder = Instance.new("Folder")
	folder.Name = "Nature"
	-- dense forest belt along the wall hides where the world ends
	for _ = 1, 70 do
		local p = scatterPoint(WORLD_RADIUS - 22, WORLD_RADIUS + 6)
		if p then
			tree(folder, p, rng:NextNumber(1.3, 2))
		end
	end
	for _ = 1, 55 do
		local p = scatterPoint(60, WORLD_RADIUS - 4)
		if p then
			tree(folder, p, rng:NextNumber(0.9, 1.6))
		end
	end
	for _ = 1, 70 do
		local p = scatterPoint(36, WORLD_RADIUS - 4)
		if p then
			bush(folder, p)
		end
	end
	for _ = 1, 25 do
		local p = scatterPoint(40, WORLD_RADIUS - 2)
		if p then
			rock(folder, p)
		end
	end
	for _ = 1, 60 do
		local p = scatterPoint(36, WORLD_RADIUS - 6)
		if p then
			flowerPatch(folder, p)
		end
	end
	folder.Parent = workspace
end

local function decor()
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	for _, pos in {
		Vector3.new(-14, 0, -7), Vector3.new(14, 0, -7), Vector3.new(-30, 0, -7), Vector3.new(30, 0, -7),
		Vector3.new(-6, 0, -36), Vector3.new(6, 0, -36), Vector3.new(-28, 0, 28), Vector3.new(28, 0, 28),
	} do
		lamp(folder, pos)
	end
	bench(folder, CFrame.new(-22, 0, 8))
	bench(folder, CFrame.new(22, 0, 8))
	bench(folder, CFrame.new(0, 0, 28) * CFrame.Angles(0, math.rad(180), 0))
	titleSign(folder)
	folder.Parent = workspace
end

-- Terrain surface can render a bit above its nominal y=0. Measure where it really is
-- and shift everything we built by that amount, so nothing sinks into the ground.
local function snapToGround()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local heights = {}
	for _, x in { 0, -TRAINER_AREA_X, TRAINER_AREA_X } do
		local hit = workspace:Raycast(Vector3.new(x, 60, -2), Vector3.new(0, -120, 0), params)
		if hit then
			table.insert(heights, hit.Position.Y)
		end
	end
	if #heights == 0 then
		return
	end
	local ground = math.max(table.unpack(heights))
	if math.abs(ground) < 0.05 then
		return
	end
	local offset = Vector3.new(0, ground, 0)
	local roots = { workspace:FindFirstChildOfClass("SpawnLocation") }
	for _, name in { "Lobby", "Trainers", "DuelArena", "Decor", "Nature" } do
		table.insert(roots, workspace:FindFirstChild(name))
	end
	for _, root in roots do
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in list do
			if d:IsA("BasePart") then
				d.CFrame += offset
			end
		end
	end
end

function MapBuilder.build()
	if workspace:FindFirstChild("Trainers") then
		return
	end

	-- Studio "Baseplate" template plate would hide the grass
	local templatePlate = workspace:FindFirstChild("Baseplate")
	if templatePlate then
		templatePlate:Destroy()
	end
	terrain()

	if not workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = workspace
	end

	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = Vector3.new(math.cos(angle) * 24, 5.5, math.sin(angle) * 24)
		mirror(lobby, CFrame.lookAt(pos, Vector3.new(0, 5.5, 0)), Vector2.new(7, 10), Color3.fromRGB(255, 235, 210))
	end
	lobby.Parent = workspace

	local trainers = Instance.new("Folder")
	trainers.Name = "Trainers"
	for _, spot in TRAINER_SPOTS do
		trainer(trainers, spot[1], TRAINER_TITLES[spot[1]], spot[2], Vector3.new(spot[3], 0.3, spot[4]))
	end
	trainers.Parent = workspace

	duelArena()
	walls()
	decor()
	nature()
	snapToGround()
	-- clients may not have the arena streamed in, so publish the teleport point
	workspace:SetAttribute("ArenaSpawn", workspace.DuelArena.ArenaSpawn.Position + Vector3.new(0, 4, 0))
	lighting()
end

return MapBuilder
