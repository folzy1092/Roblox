-- Generates the lobby: grass terrain, plaza, mirrors, trainer seats, nature and decor.
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local rng = Random.new(20261017) -- fixed seed: same map every server

local PLAZA_SIZE = Vector3.new(64, 4, 64)
local TRAINER_AREA_X = 40
local ARENA_CENTER = Vector3.new(0, 0, 84)
local ARENA_RADIUS = 26

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
	gui.StudsOffset = Vector3.new(0, 7.5, 0)
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
		Material = Enum.Material.Glass,
		Reflectance = 0.35,
		CanQuery = false,
	})
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Brightness = 0.6
	light.Range = 7
	light.Angle = 70
	light.Color = glow
	light.Parent = surface
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
	status.StudsOffset = Vector3.new(0, 6.4, 0)
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
	local trainers = math.abs(math.abs(x) - TRAINER_AREA_X) < 14 and math.abs(z + 2) < 20
	local titleWalk = math.abs(x) < 20 and z < -30 and z > -58
	local arena = (Vector3.new(x, 0, z) - ARENA_CENTER).Magnitude < ARENA_RADIUS + 10 or (math.abs(x) < 8 and z > 30 and z < 62)
	return plaza or trainers or titleWalk or arena
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
	sign(vs, "⚔️ VS ⚔️", Color3.fromRGB(255, 220, 220))
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

local function terrain()
	local t = workspace.Terrain
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(520, 12, 520), Enum.Material.Grass)
	-- plaza, paths to trainer areas and to the title sign
	t:FillBlock(CFrame.new(0, -2, 0), PLAZA_SIZE, Enum.Material.Pavement)
	t:FillBlock(CFrame.new(0, -2, -2), Vector3.new(TRAINER_AREA_X * 2 + 28, 4, 8), Enum.Material.Pavement)
	t:FillBlock(CFrame.new(0, -2, -44), Vector3.new(8, 4, 24), Enum.Material.Pavement)
	t:FillBlock(CFrame.new(0, -2, 46), Vector3.new(8, 4, 32), Enum.Material.Pavement)
	for _, side in { -1, 1 } do
		t:FillBlock(CFrame.new(side * TRAINER_AREA_X, -2, -2), Vector3.new(20, 4, 36), Enum.Material.Cobblestone)
	end
	pcall(function()
		(t :: any).Decoration = true -- animated grass blades
	end)
	t.WaterWaveSize = 0.1
end

local function lighting()
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 150)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
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
	for _ = 1, 55 do
		local p = scatterPoint(60, 230)
		if p then
			tree(folder, p, rng:NextNumber(0.9, 1.6))
		end
	end
	for _ = 1, 70 do
		local p = scatterPoint(36, 200)
		if p then
			bush(folder, p)
		end
	end
	for _ = 1, 25 do
		local p = scatterPoint(40, 220)
		if p then
			rock(folder, p)
		end
	end
	for _ = 1, 60 do
		local p = scatterPoint(36, 160)
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
	trainer(trainers, "gum", "Gum Trainer", false, Vector3.new(-TRAINER_AREA_X, 0.3, -10))
	trainer(trainers, "gum", "Gum Trainer", true, Vector3.new(-TRAINER_AREA_X, 0.3, 6))
	trainer(trainers, "mewing", "Mewing Trainer", false, Vector3.new(TRAINER_AREA_X, 0.3, -10))
	trainer(trainers, "mewing", "Mewing Trainer", true, Vector3.new(TRAINER_AREA_X, 0.3, 6))
	trainers.Parent = workspace

	duelArena()
	decor()
	nature()
	lighting()
end

return MapBuilder
