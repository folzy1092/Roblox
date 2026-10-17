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

local function trainer(folder: Folder, itemId: string, title: string, vip: boolean, position: Vector3)
	local model = Instance.new("Model")
	model.Name = `{itemId}{if vip then "_VIP" else ""}`
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Vip", vip)

	local color = if vip then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(90, 200, 120)
	local base = part({
		Name = "Base",
		Size = Vector3.new(10, 0.6, 10),
		Position = position,
		Color = color,
		Material = Enum.Material.Neon,
	})
	base.Parent = model

	local zone = part({
		Name = "Zone",
		Size = Vector3.new(8, 1, 8),
		Position = position + Vector3.new(0, 0.8, 0),
		Transparency = 0.7,
		CanCollide = false,
		CanQuery = false,
		Color = color,
		Material = Enum.Material.ForceField,
	})
	zone.Parent = model

	local chair = part({
		Name = "Mirror",
		Size = Vector3.new(6, 7, 0.4),
		Position = position + Vector3.new(0, 4, -5),
		Color = Color3.fromRGB(200, 230, 255),
		Material = Enum.Material.Glass,
		Reflectance = 0.6,
	})
	chair.Parent = model

	sign(base, if vip then `VIP {title}` else title, color)
	model.PrimaryPart = base
	model.Parent = folder
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
end

return MapBuilder
