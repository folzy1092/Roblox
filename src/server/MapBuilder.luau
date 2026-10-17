-- Generates the lobby: floor, spawn, mirrors and trainer pairs.
local MapBuilder = {}

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
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = false
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
		Color = color:Lerp(Color3.new(0, 0, 0), 0.45),
		Material = Enum.Material.SmoothPlastic,
	})
	base.Parent = model

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

	local back = part({
		Name = "Backrest",
		Size = Vector3.new(3, 3, 0.5),
		Position = position + Vector3.new(0, 2.5, 3.1),
		Color = color,
		Material = Enum.Material.Fabric,
	})
	back.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Sit"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat

	local mirror = part({
		Name = "Mirror",
		Size = Vector3.new(5, 6, 0.4),
		Position = position + Vector3.new(0, 3.6, -3.4),
		Color = Color3.fromRGB(200, 230, 255),
		Material = Enum.Material.Glass,
		Reflectance = 0.6,
	})
	mirror.Parent = model
	part({
		Name = "MirrorFrame",
		Size = Vector3.new(5.8, 6.8, 0.3),
		Position = position + Vector3.new(0, 3.6, -3.65),
		Color = color,
		Material = Enum.Material.Neon,
	}).Parent = model

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "ActiveSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(color)
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.Size = NumberSequence.new(0.3)
	sparkles.Enabled = false
	sparkles.Parent = base

	sign(base, if vip then `VIP {title}` else title, color)

	local status = Instance.new("BillboardGui")
	status.Name = "Status"
	status.Size = UDim2.fromScale(5, 1)
	status.StudsOffset = Vector3.new(0, 3.6, 0)
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

local function tree(parent: Instance, position: Vector3, scale: number)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8 * scale, 1.4 * scale, 1.4 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(105, 70, 45),
		Material = Enum.Material.Wood,
	}).Parent = parent
	for i, offset in { Vector3.new(0, 9, 0), Vector3.new(1.8, 7.5, 0.6), Vector3.new(-1.6, 7.8, -0.8) } do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (if i == 1 then 6 else 4.5) * scale,
			Position = position + offset * scale,
			Color = Color3.fromRGB(70, 160, 90):Lerp(Color3.fromRGB(120, 200, 110), i / 4),
			Material = Enum.Material.Grass,
			CanCollide = false,
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
		Size = Vector3.one * 1.4,
		Position = position + Vector3.new(0, 9.4, 0),
		Color = Color3.fromRGB(255, 220, 160),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.5
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

local function flowerBed(parent: Instance, position: Vector3)
	part({
		Name = "Bed",
		Size = Vector3.new(6, 0.8, 3),
		Position = position + Vector3.new(0, 0.4, 0),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Ground,
	}).Parent = parent
	local colors = { Color3.fromRGB(255, 110, 160), Color3.fromRGB(255, 220, 80), Color3.fromRGB(170, 120, 255) }
	for i = 1, 6 do
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.8,
			Position = position + Vector3.new(-2.5 + i * 0.85, 1.1, (i % 2) * 0.8 - 0.4),
			Color = colors[(i % 3) + 1],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}).Parent = parent
	end
end

local function titleSign(parent: Instance)
	local board = part({
		Name = "TitleBoard",
		Size = Vector3.new(34, 8, 1),
		Position = Vector3.new(0, 14, -45),
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
			Position = Vector3.new(x, 9, -45),
			Color = Color3.fromRGB(255, 205, 70),
			Material = Enum.Material.Neon,
		}).Parent = parent
	end
end

local function lighting()
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 120, 150)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Color = Color3.fromRGB(255, 200, 190)
		atmosphere.Decay = Color3.fromRGB(120, 90, 160)
		atmosphere.Glare = 0.4
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 30
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.15
		cc.Contrast = 0.08
		cc.Parent = Lighting
	end
end

-- Paths, trees, lamps, benches, flowers, title sign and sunset lighting.
local function decorate()
	local decor = Instance.new("Folder")
	decor.Name = "Decor"

	for _, x in { -1, 1 } do
		part({
			Name = "Path",
			Size = Vector3.new(30, 0.2, 6),
			Position = Vector3.new(x * 22, 0.1, -2),
			Color = Color3.fromRGB(230, 220, 200),
			Material = Enum.Material.Pavement,
		}).Parent = decor
	end
	part({
		Name = "Path",
		Size = Vector3.new(6, 0.2, 36),
		Position = Vector3.new(0, 0.1, -26),
		Color = Color3.fromRGB(230, 220, 200),
		Material = Enum.Material.Pavement,
	}).Parent = decor

	for _, pos in {
		Vector3.new(-60, 0, -30), Vector3.new(60, 0, -30), Vector3.new(-60, 0, 30), Vector3.new(60, 0, 30),
		Vector3.new(-25, 0, 45), Vector3.new(25, 0, 45), Vector3.new(-30, 0, -55), Vector3.new(30, 0, -55),
		Vector3.new(-80, 0, 0), Vector3.new(80, 0, 0),
	} do
		tree(decor, pos, 1 + (math.abs(pos.X + pos.Z) % 3) * 0.15)
	end
	for _, pos in {
		Vector3.new(-12, 0, -6), Vector3.new(12, 0, -6), Vector3.new(-30, 0, -6), Vector3.new(30, 0, -6),
		Vector3.new(-5, 0, -30), Vector3.new(5, 0, -30),
	} do
		lamp(decor, pos)
	end
	bench(decor, CFrame.new(-22, 0, 6))
	bench(decor, CFrame.new(22, 0, 6))
	bench(decor, CFrame.new(0, 0, 30) * CFrame.Angles(0, math.rad(180), 0))
	for _, pos in { Vector3.new(-10, 0, 30), Vector3.new(10, 0, 30), Vector3.new(-10, 0, -38), Vector3.new(10, 0, -38) } do
		flowerBed(decor, pos)
	end
	titleSign(decor)
	decor.Parent = workspace
	lighting()
end

function MapBuilder.build()
	if workspace:FindFirstChild("Trainers") then
		return
	end

	if not workspace:FindFirstChild("Baseplate") then
		part({
			Name = "Baseplate",
			Size = Vector3.new(300, 2, 300),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(70, 70, 85),
			Material = Enum.Material.Slate,
		}).Parent = workspace
	end

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
		local pos = Vector3.new(math.cos(angle) * 24, 5, math.sin(angle) * 24)
		part({
			Name = "BigMirror",
			Size = Vector3.new(10, 10, 0.5),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, 5, 0)),
			Color = Color3.fromRGB(200, 230, 255),
			Material = Enum.Material.Glass,
			Reflectance = 0.7,
		}).Parent = lobby
	end
	lobby.Parent = workspace

	local trainers = Instance.new("Folder")
	trainers.Name = "Trainers"
	trainer(trainers, "gum", "Gum Trainer", false, Vector3.new(-40, 0.3, -10))
	trainer(trainers, "gum", "Gum Trainer", true, Vector3.new(-40, 0.3, 6))
	trainer(trainers, "mewing", "Mewing Trainer", false, Vector3.new(40, 0.3, -10))
	trainer(trainers, "mewing", "Mewing Trainer", true, Vector3.new(40, 0.3, 6))
	trainers.Parent = workspace

	decorate()
end

return MapBuilder
