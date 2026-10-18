-- Generates the lobby: a round plaza with a fountain, themed trainer halls around it
-- (mirror walls, arches, pergola roofs), the duel arena, paths, nature and lighting.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.map.Kit)
local Flora = require(script.Parent.map.Flora)
local Props = require(script.Parent.map.Props)

local part = Kit.part
local disc = Kit.disc

local MapBuilder = {}

local rng = Random.new(20261017) -- fixed seed: same map every server

-- Sized for 32 players: 23 trainer seats in 5 halls, 2 duel stations, room to walk around.
local PLAZA_RADIUS = 36
local ARENA_CENTER = Vector3.new(0, 0, 125)
local ARENA_RADIUS = 36
local WORLD_RADIUS = 190 -- invisible wall; mountain backdrop starts right behind it
local POND = Vector3.new(-95, 0, 85)
local TITLE_Z = -118
local SPAWN = Vector3.new(0, 0.6, -21)
local FLOOR_TOP = 0.8 -- hall floors are raised platforms

local GOLD = Color3.fromRGB(255, 200, 40)
local CREAM = Color3.fromRGB(240, 230, 218)

-- Trainer halls. Each hall faces the plaza; seats sit along its mirror walls.
-- size = (width, depth); layout picks the seat template below.
local ZONES = {
	{ id = "gum", title = "Gum Gym", color = Color3.fromRGB(255, 105, 175), center = Vector2.new(-80, 0),
		size = Vector2.new(36, 34), layout = "six", landmark = "dumbbell" },
	{ id = "mewing", title = "Mewing Studio", color = Color3.fromRGB(70, 185, 255), center = Vector2.new(80, 0),
		size = Vector2.new(36, 34), layout = "six", landmark = "dumbbell" },
	{ id = "jawball", title = "Jaw Ball Court", color = Color3.fromRGB(255, 145, 50), center = Vector2.new(-46, -80),
		size = Vector2.new(30, 26), layout = "four", landmark = "ball" },
	{ id = "guasha", title = "Gua Sha Spa", color = Color3.fromRGB(50, 205, 150), center = Vector2.new(46, -80),
		size = Vector2.new(30, 26), layout = "four", landmark = "palms" },
	{ id = "bonetapper", title = "Bone Tapper Lab", color = Color3.fromRGB(160, 100, 255), center = Vector2.new(66, 66),
		size = Vector2.new(32, 22), layout = "three", landmark = "obelisk" },
}

local TRAINER_TITLES = {
	gum = "Gum Trainer",
	mewing = "Mewing Trainer",
	jawball = "Jaw Ball Trainer",
	guasha = "Gua Sha Trainer",
	bonetapper = "Bone Tapper Trainer",
}

local BACK, LEFT, RIGHT = Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)

-- Seat templates in hall space: x across, z toward the entrance (+z = plaza side).
-- Each seat faces a mirror on the wall in `facing` direction. Counts: six = 4 + 2 VIP,
-- four = 3 + 1 VIP, three = 2 + 1 VIP (same as before the redesign).
local function stations(zone): { { any } }
	local w, d = zone.size.X / 2, zone.size.Y / 2
	local backZ, sideX = -d + 4.4, w - 4.4
	if zone.layout == "six" then
		return {
			{ -sideX, -1, LEFT, false }, { -sideX, 9, LEFT, false },
			{ sideX, -1, RIGHT, false }, { sideX, 9, RIGHT, false },
			{ -6, backZ, BACK, true }, { 6, backZ, BACK, true },
		}
	elseif zone.layout == "four" then
		return {
			{ -sideX, 1, LEFT, false }, { sideX, 1, RIGHT, false },
			{ -5, backZ, BACK, false }, { 5, backZ, BACK, true },
		}
	end
	return { { -10, backZ, BACK, false }, { 10, backZ, BACK, false }, { 0, backZ, BACK, true } }
end

-- Hall frame: origin at the hall center, -Z points away from the plaza.
local function zoneFrame(zone): CFrame
	local c = Vector3.new(zone.center.X, 0, zone.center.Y)
	return CFrame.lookAt(c, c + c.Unit)
end

-- Walkways: from the plaza edge to each hall entrance, the title sign and the arena.
local PATHS = {}
for _, zone in ZONES do
	local frame = zoneFrame(zone)
	local dir = zone.center.Unit
	local entrance = (frame * CFrame.new(0, 0, zone.size.Y / 2 + 1)).Position
	table.insert(PATHS, { dir * (PLAZA_RADIUS - 1), Vector2.new(entrance.X, entrance.Z), 10 })
end
table.insert(PATHS, { Vector2.new(0, -PLAZA_RADIUS + 1), Vector2.new(0, TITLE_Z + 3), 10 })
table.insert(PATHS, { Vector2.new(0, PLAZA_RADIUS - 1), Vector2.new(0, ARENA_CENTER.Z - ARENA_RADIUS), 10 })

local PATH_ANGLES = {}
for _, path in PATHS do
	table.insert(PATH_ANGLES, math.atan2(path[1].Y, path[1].X))
end

-- true when angle `a` (radians) on the plaza ring is at least `gap` away from every path
local function clearOfPaths(a: number, gap: number): boolean
	for _, pa in PATH_ANGLES do
		local diff = math.abs((a - pa + math.pi) % (2 * math.pi) - math.pi)
		if diff < gap then
			return false
		end
	end
	return true
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
-- `cframe` is the platform center; its look direction points at the mirror.
local function trainer(folder: Folder, itemId: string, title: string, vip: boolean, cframe: CFrame, zoneColor: Color3)
	local model = Instance.new("Model")
	model.Name = `{itemId}{if vip then "_VIP" else ""}`
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Vip", vip)

	local color = if vip then GOLD else zoneColor
	model:SetAttribute("Color", color)
	local base = part({
		Name = "Base",
		Size = Vector3.new(8, 0.6, 8),
		CFrame = cframe,
		Color = zoneColor:Lerp(Color3.fromRGB(30, 26, 40), 0.75),
		Material = Enum.Material.SmoothPlastic,
	})
	base.Parent = model

	-- thin edge under the base: lights up while someone trains
	part({
		Name = "Trim",
		Size = Vector3.new(8.4, 0.3, 8.4),
		CFrame = cframe * CFrame.new(0, -0.2, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}).Parent = model

	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = cframe * CFrame.new(0, 0.8, 1.5)
	seat.Color = color
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat:SetAttribute("TrainerSeat", true)
	seat.Parent = model

	part({
		Name = "Backrest",
		Size = Vector3.new(3, 3, 0.5),
		CFrame = cframe * CFrame.new(0, 2.5, 3.1),
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

	mirror(model, cframe * CFrame.new(0, 3.6, -3.4) * CFrame.Angles(0, math.pi, 0), Vector2.new(4.4, 5.6), color)

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

	-- the hall arch names the trainer; only VIP seats get their own sign
	if vip then
		Kit.sign(base, "VIP", GOLD, 10, 4)
	end

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

-- Landmark sculpture outside a hall entrance.
local function landmark(parent: Instance, kind: string, cframe: CFrame, color: Color3)
	if kind == "dumbbell" then
		Props.dumbbell(parent, cframe * CFrame.Angles(0, math.rad(90), 0), color)
	elseif kind == "palms" then
		Flora.palm(parent, rng, cframe.Position, 1.1)
		Flora.palm(parent, rng, (cframe * CFrame.new(0, 0, -5)).Position, 0.9)
	elseif kind == "ball" then
		part({ Name = "Plinth", Size = Vector3.new(4, 2, 4), CFrame = cframe * CFrame.new(0, 1, 0), Color = CREAM,
			Material = Enum.Material.Marble }).Parent = parent
		part({ Name = "JawBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 4.4, CFrame = cframe * CFrame.new(0, 4.2, 0),
			Color = color, Material = Enum.Material.SmoothPlastic }).Parent = parent
	else -- obelisk
		part({ Name = "Plinth", Size = Vector3.new(4, 1.4, 4), CFrame = cframe * CFrame.new(0, 0.7, 0), Color = CREAM,
			Material = Enum.Material.Marble }).Parent = parent
		part({ Name = "Obelisk", Size = Vector3.new(2, 9, 2), CFrame = cframe * CFrame.new(0, 5.9, 0), Color = color,
			Material = Enum.Material.SmoothPlastic }).Parent = parent
		local tip = part({ Name = "ObeliskTip", Size = Vector3.one * 1.6, CanCollide = false, Color = GOLD,
			Material = Enum.Material.Neon,
			CFrame = cframe * CFrame.new(0, 11.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)) })
		Kit.light(tip, GOLD, 14, 1.2)
		tip.Parent = parent
	end
end

-- A trainer hall: raised floor with colored border, mirror walls on three sides,
-- pergola roof, entrance arch with the hall name, planters and a landmark outside.
local function hall(zonesFolder: Folder, trainers: Folder, zone)
	local model = Instance.new("Model")
	model.Name = `{zone.id}Hall`
	local frame = zoneFrame(zone)
	local W, D = zone.size.X, zone.size.Y
	local color = zone.color
	local floorColor = color:Lerp(Color3.new(1, 1, 1), 0.82)
	local wallColor = color:Lerp(Color3.new(1, 1, 1), 0.55)
	local darkColor = color:Lerp(Color3.fromRGB(30, 26, 40), 0.55)
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	local function block(name: string, size: Vector3, cf: CFrame, c: Color3, material: Enum.Material?, extra: { [string]: any }?)
		local props = { Name = name, Size = size, CFrame = cf, Color = c, Material = material or Enum.Material.SmoothPlastic }
		for k, v in extra or {} do
			props[k] = v
		end
		local p = part(props)
		p.Parent = model
		return p
	end

	block("Border", Vector3.new(W + 3.4, 0.5, D + 3.4), at(0, 0.25, 0), color)
	block("Floor", Vector3.new(W + 1, FLOOR_TOP, D + 1), at(0, FLOOR_TOP / 2, 0), floorColor, Enum.Material.Marble)
	block("EntranceGlow", Vector3.new(W + 3.4, 0.12, 0.5), at(0, 0.56, D / 2 + 1.45), color, Enum.Material.Neon,
		{ CanCollide = false })
	-- floor emblem in the open middle of the hall
	local emblem = at(0, 0, D / 2 - 8)
	disc({ Name = "Emblem", Color = color, Material = Enum.Material.SmoothPlastic },
		emblem.Position + Vector3.new(0, FLOOR_TOP + 0.04, 0), 5, 0.1).Parent = model
	disc({ Name = "Emblem", Color = floorColor, Material = Enum.Material.SmoothPlastic },
		emblem.Position + Vector3.new(0, FLOOR_TOP + 0.06, 0), 3.9, 0.1).Parent = model
	block("Emblem", Vector3.new(2.6, 0.1, 2.6), emblem * CFrame.new(0, FLOOR_TOP + 0.07, 0) * CFrame.Angles(0, math.rad(45), 0),
		color, Enum.Material.Neon, { CanCollide = false })

	-- walls behind the mirrors, with a glowing top edge
	local wallH = 9
	local wallY = FLOOR_TOP + wallH / 2
	block("Wall", Vector3.new(W + 0.8, wallH, 1), at(0, wallY, -D / 2 + 0.1), wallColor)
	block("WallGlow", Vector3.new(W + 0.8, 0.3, 1.1), at(0, FLOOR_TOP + wallH + 0.15, -D / 2 + 0.1), color, Enum.Material.Neon,
		{ CanCollide = false })
	for _, side in { -1, 1 } do
		local x = side * (W / 2 - 0.1)
		block("Wall", Vector3.new(1, wallH, D + 0.4), at(x, wallY, -0.2), wallColor)
		block("WallGlow", Vector3.new(1.1, 0.3, D + 0.4), at(x, FLOOR_TOP + wallH + 0.15, -0.2), color, Enum.Material.Neon,
			{ CanCollide = false })
		-- arch pillar with a glowing cap
		block("Pillar", Vector3.new(2.2, 12.4, 2.2), at(side * (W / 2 + 0.1), 6.2, D / 2 + 0.3), darkColor)
		local cap = block("PillarCap", Vector3.one * 1.6, at(side * (W / 2 + 0.1), 13.2, D / 2 + 0.3), GOLD, Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball, CanCollide = false })
		Kit.light(cap, color, 16, 1.2)
		-- planter at each front corner
		Props.planter(model, rng, (frame * CFrame.new(side * (W / 2 + 3.6), 0, D / 2 + 3.6)).Position, 1.8, color)
	end

	-- pergola roof: slats let light (and the camera) through
	local beams = math.floor(D / 4)
	for i = 1, beams do
		block("RoofBeam", Vector3.new(W + 0.6, 0.5, 0.8), at(0, FLOOR_TOP + wallH + 0.55, -D / 2 + i * D / (beams + 1)), CREAM,
			Enum.Material.WoodPlanks)
	end

	-- entrance arch with the hall name on both sides
	local header = block("ArchSign", Vector3.new(W + 3, 2.8, 1.2), at(0, 11.4, D / 2 + 0.3), darkColor)
	Kit.faceText(header, Enum.NormalId.Back, string.upper(zone.title), Color3.new(1, 1, 1), color:Lerp(Color3.new(0, 0, 0), 0.5))
	Kit.faceText(header, Enum.NormalId.Front, string.upper(zone.title), Color3.new(1, 1, 1), color:Lerp(Color3.new(0, 0, 0), 0.5))
	block("ArchGlow", Vector3.new(W + 3.2, 0.3, 1.3), at(0, 9.85, D / 2 + 0.3), color, Enum.Material.Neon, { CanCollide = false })

	landmark(model, zone.landmark, at(W / 2 + 7, 0, D / 2 - 6), color)

	for _, s in stations(zone) do
		local localPos = Vector3.new(s[1], FLOOR_TOP + 0.3, s[2])
		local cf = frame * CFrame.lookAt(localPos, localPos + s[3])
		trainer(trainers, zone.id, TRAINER_TITLES[zone.id], s[4], cf, color)
	end

	model.Parent = zonesFolder
end

-- Round plaza: tiled star pattern, fountain with the glow crystal, four big mirrors,
-- planters, benches and lamps between the walkways.
local function plaza()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local o = Vector3.zero
	disc({ Name = "PlazaGlow", Color = Color3.fromRGB(255, 120, 180), Material = Enum.Material.Neon }, o + Vector3.new(0, 0.3, 0),
		PLAZA_RADIUS + 0.7, 0.3).Parent = folder
	disc({ Name = "PlazaFloor", Color = CREAM, Material = Enum.Material.Marble }, o + Vector3.new(0, 0.4, 0), PLAZA_RADIUS, 0.4)
		.Parent = folder
	disc({ Name = "PlazaBand", Color = Color3.fromRGB(190, 160, 235), Material = Enum.Material.SmoothPlastic },
		o + Vector3.new(0, 0.45, 0), PLAZA_RADIUS - 5, 0.1).Parent = folder
	disc({ Name = "PlazaInner", Color = CREAM, Material = Enum.Material.Marble }, o + Vector3.new(0, 0.5, 0), PLAZA_RADIUS - 6.5,
		0.1).Parent = folder
	-- compass-star rays: long pink / short gold
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local long = i % 2 == 0
		local length = if long then 17 else 9
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = dir * (11 + length / 2) + Vector3.new(0, 0.53, 0)
		part({
			Name = "PlazaRay",
			Size = Vector3.new(if long then 2.6 else 1.6, 0.06, length),
			CFrame = CFrame.lookAt(pos, pos + dir),
			Color = if long then Color3.fromRGB(255, 140, 190) else Color3.fromRGB(255, 205, 110),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}).Parent = folder
	end

	Props.fountain(folder, o + Vector3.new(0, 0.5, 0))

	-- four big mirrors around the fountain, on marble pedestals
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = Vector3.new(math.cos(angle) * 24, 6.4, math.sin(angle) * 24)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 6.4, 0))
		part({
			Name = "MirrorPedestal",
			Size = Vector3.new(9, 0.9, 2.4),
			CFrame = cf * CFrame.new(0, -5.45, 0.3),
			Color = Color3.fromRGB(70, 60, 90),
			Material = Enum.Material.Marble,
		}).Parent = folder
		mirror(folder, cf, Vector2.new(7, 10), Color3.fromRGB(255, 235, 210))
	end

	-- ring furniture: lamps, planters and benches, skipping the walkways
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2 + math.pi / 16
		if clearOfPaths(a, math.rad(11)) then
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			if i % 2 == 0 then
				Props.planter(folder, rng, dir * (PLAZA_RADIUS - 3), 2.2)
			else
				Props.bench(folder, CFrame.lookAt(dir * (PLAZA_RADIUS - 3) + Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, 0)))
			end
		end
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		if clearOfPaths(a, math.rad(8)) then
			Props.lamp(folder, Vector3.new(math.cos(a), 0, math.sin(a)) * (PLAZA_RADIUS + 1.6))
		end
	end
	folder.Parent = workspace
end

local function distToSegment(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function inBuiltArea(x: number, z: number): boolean
	local p = Vector2.new(x, z)
	if p.Magnitude < PLAZA_RADIUS + 10 then
		return true
	end
	if math.abs(x) < 24 and z < TITLE_Z + 10 and z > TITLE_Z - 12 then
		return true
	end
	if (Vector3.new(x, 0, z) - ARENA_CENTER).Magnitude < ARENA_RADIUS + 12 or (p - Vector2.new(POND.X, POND.Z)).Magnitude < 22 then
		return true
	end
	for _, zone in ZONES do
		if (p - zone.center).Magnitude < zone.size.Magnitude / 2 + 12 then
			return true
		end
	end
	for _, path in PATHS do
		if distToSegment(p, path[1], path[2]) < path[3] / 2 + 6 then
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

local function titleSign(parent: Instance)
	local board = part({
		Name = "TitleBoard",
		Size = Vector3.new(40, 9, 1),
		Position = Vector3.new(0, 15, TITLE_Z),
		Color = Color3.fromRGB(34, 24, 54),
		Material = Enum.Material.SmoothPlastic,
	})
	Kit.faceText(board, Enum.NormalId.Back, "LOOKSMAX SIMULATOR", Color3.fromRGB(255, 210, 80), Color3.fromRGB(120, 40, 90))
	board.Parent = parent
	part({
		Name = "TitleGlow",
		Size = Vector3.new(41.6, 10.6, 0.6),
		Position = Vector3.new(0, 15, TITLE_Z - 0.4),
		Color = Color3.fromRGB(255, 120, 180),
		Material = Enum.Material.Neon,
	}).Parent = parent
	for _, x in { -20.5, 20.5 } do
		part({
			Name = "TitlePillar",
			Size = Vector3.new(2, 20, 2),
			Position = Vector3.new(x, 10, TITLE_Z),
			Color = Color3.fromRGB(70, 60, 100),
			Material = Enum.Material.Marble,
		}).Parent = parent
		local cap = part({
			Name = "TitleCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			Position = Vector3.new(x, 21, TITLE_Z),
			Color = GOLD,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		Kit.light(cap, Color3.fromRGB(255, 200, 120), 18, 1.2)
		cap.Parent = parent
		Props.planter(parent, rng, Vector3.new(x + (if x < 0 then -4 else 4), 0, TITLE_Z + 2), 2)
	end
end

-- Duel arena: round stage with two facing duel pads, neon ring, stands and a big sign.
local function duelArena()
	local folder = Instance.new("Model")
	folder.Name = "DuelArena"
	local c = ARENA_CENTER
	local red = Color3.fromRGB(235, 70, 80)
	local blue = Color3.fromRGB(80, 160, 255)

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
	disc({ Name = "StageCircle", Color = Color3.fromRGB(70, 55, 95), Material = Enum.Material.SmoothPlastic, CanCollide = false },
		c + Vector3.new(0, 1.24, 0), ARENA_RADIUS - 8, 0.06).Parent = folder
	part({
		Name = "ArenaSpawn",
		Size = Vector3.new(6, 0.2, 6),
		Position = c + Vector3.new(0, 1.3, -(ARENA_RADIUS - 6)),
		Transparency = 1,
		CanCollide = false,
	}).Parent = folder

	-- two duel stations, far apart; each = two pads facing each other with their own mirrors
	for _, stationZ in { -14, 14 } do
		for _, side in { -1, 1 } do
			local padPos = c + Vector3.new(side * 12, 1.4, stationZ)
			part({
				Name = "DuelPad",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 7, 7),
				CFrame = CFrame.new(padPos) * CFrame.Angles(0, 0, math.rad(90)),
				Color = if side < 0 then blue else red,
				Material = Enum.Material.Neon,
			}).Parent = folder
			local mirrorPos = padPos + Vector3.new(side * 5, 3.4, 0)
			mirror(folder, CFrame.lookAt(mirrorPos, mirrorPos - Vector3.new(side, 0, 0)), Vector2.new(4.4, 5.6),
				if side < 0 then blue else red)
		end
	end
	local vs = part({
		Name = "VsSign",
		Size = Vector3.new(1, 1, 1),
		Position = c + Vector3.new(0, 9, 0),
		Transparency = 1,
		CanCollide = false,
	})
	Kit.sign(vs, "VS", Color3.fromRGB(255, 220, 220))
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
			Color = if i % 2 == 0 then red else blue,
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
	Kit.faceText(board, Enum.NormalId.Front, "Duel Arena", red)
	board.Parent = folder

	folder.Parent = workspace
end

-- Mountain backdrop behind the invisible wall: four rings, each bigger and taller,
-- so from anywhere inside (even zoomed out) the world looks walled in by mountains.
-- Purely visual: the Walls ring stops players long before they reach the slopes.
local MOUNTAIN_RINGS = {
	-- distance past the wall, min/max size, angle step, center height (fraction of size), snow?
	{ 30, 28, 42, 4, 0.15, 0.45, false },
	{ 75, 50, 75, 5, 0.2, 0.5, false },
	{ 140, 85, 120, 6, 0.3, 0.6, true },
	{ 240, 120, 160, 8, 0.4, 0.8, true },
}

local function mountains(t: Terrain)
	local mRng = Random.new(77)
	for ringIndex, ring in MOUNTAIN_RINGS do
		local radius, minS, maxS, step, minY, maxY, snowy = WORLD_RADIUS + ring[1], ring[2], ring[3], ring[4], ring[5], ring[6], ring[7]
		for deg = 0, 359, step do
			local a = math.rad(deg + mRng:NextNumber(-2, 2))
			local r = radius + mRng:NextNumber(-8, 8)
			local size = mRng:NextNumber(minS, maxS)
			local center = Vector3.new(math.cos(a) * r, mRng:NextNumber(size * minY, size * maxY), math.sin(a) * r)
			t:FillBall(center, size, if mRng:NextNumber() < 0.7 then Enum.Material.Rock else Enum.Material.Slate)
			if ringIndex == 2 then
				-- steep crag in front: tall tilted slab breaks the round silhouettes
				local h = mRng:NextNumber(60, 100)
				local foot = Vector3.new(math.cos(a) * (r - 18), h / 2 - 10, math.sin(a) * (r - 18))
				t:FillBlock(CFrame.lookAt(foot, Vector3.new(0, foot.Y, 0)) * CFrame.Angles(math.rad(mRng:NextNumber(-12, -4)), 0, math.rad(mRng:NextNumber(-8, 8))),
					Vector3.new(mRng:NextNumber(22, 34), h, 18), Enum.Material.Rock)
			end
			local top = center + Vector3.new(0, size * 0.8, 0)
			if snowy and top.Y > 140 then
				t:FillBall(top, size * 0.32, Enum.Material.Snow)
			elseif not snowy and mRng:NextNumber() < 0.5 then
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
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1400, 12, 1400), Enum.Material.Grass)
	t:FillCylinder(CFrame.new(0, -2, 0), 4, PLAZA_RADIUS + 2, Enum.Material.Pavement)
	for _, path in PATHS do
		local a, b = Vector3.new(path[1].X, -2, path[1].Y), Vector3.new(path[2].X, -2, path[2].Y)
		t:FillBlock(CFrame.lookAt((a + b) / 2, b), Vector3.new(path[3], 4, (b - a).Magnitude + 4), Enum.Material.Pavement)
	end
	-- paved apron under the title sign
	t:FillBlock(CFrame.new(0, -2, TITLE_Z), Vector3.new(50, 4, 14), Enum.Material.Pavement)
	pond(t)
	mountains(t)
	pcall(function()
		(t :: any).Decoration = true -- animated grass blades
	end)
	t:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 168, 74))
	t:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(84, 150, 70))
	t:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(226, 210, 186))
	t:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(232, 210, 160))
	t:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 118, 134))
	t:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(104, 98, 116))
	t:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(246, 248, 255))
	t.WaterWaveSize = 0.1
	t.WaterColor = Color3.fromRGB(60, 160, 180)
end

-- Invisible ring wall: the only real boundary. Mountains behind it are just scenery.
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
	Lighting.ClockTime = 15.4
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 60, 85)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.SunAngularSize = 16
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(205, 220, 255)
	atmosphere.Decay = Color3.fromRGB(150, 120, 190)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 0.7
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 22
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.18
	cc.Contrast = 0.1
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 248, 242)
	cc.Parent = Lighting
end

local function nature()
	local folder = Instance.new("Folder")
	folder.Name = "Nature"
	-- dense forest belt along the wall hides where the world ends
	for _ = 1, 95 do
		local p = scatterPoint(WORLD_RADIUS - 24, WORLD_RADIUS + 6)
		if p then
			if rng:NextNumber() < 0.6 then
				Flora.pine(folder, rng, p, rng:NextNumber(1.2, 1.8))
			else
				Flora.oak(folder, rng, p, rng:NextNumber(1.3, 1.9))
			end
		end
	end
	-- parkland between the halls: mixed oaks, pink blossoms and some pines
	for _ = 1, 100 do
		local p = scatterPoint(50, WORLD_RADIUS - 26)
		if p then
			local roll = rng:NextNumber()
			if roll < 0.45 then
				Flora.oak(folder, rng, p, rng:NextNumber(0.9, 1.4))
			elseif roll < 0.75 then
				Flora.blossom(folder, rng, p, rng:NextNumber(0.9, 1.3))
			else
				Flora.pine(folder, rng, p, rng:NextNumber(0.8, 1.2))
			end
		end
	end
	-- blossom ring framing the plaza
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2 + math.pi / 16
		if clearOfPaths(a, math.rad(14)) then
			Flora.blossom(folder, rng, Vector3.new(math.cos(a), 0, math.sin(a)) * (PLAZA_RADIUS + 9), 1.1)
		end
	end
	-- palms around the pond
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		Flora.palm(folder, rng, POND + Vector3.new(math.cos(a), 0, math.sin(a)) * 20, rng:NextNumber(0.9, 1.2))
	end
	for _ = 1, 80 do
		local p = scatterPoint(40, WORLD_RADIUS - 4)
		if p then
			Flora.bush(folder, rng, p)
		end
	end
	for _ = 1, 35 do
		local p = scatterPoint(44, WORLD_RADIUS - 2)
		if p then
			Flora.rock(folder, rng, p)
		end
	end
	for _ = 1, 45 do
		local p = scatterPoint(40, WORLD_RADIUS - 6)
		if p then
			Flora.flowerPatch(folder, rng, p)
		end
	end
	folder.Parent = workspace
end

-- Walkway dressing: lamp pairs every 16 studs, hedges (main walks) or flower beds
-- (hall walks) between them.
local function decor()
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	for index, path in PATHS do
		local a, b, width = path[1], path[2], path[3]
		local length = (b - a).Magnitude
		local u = (b - a).Unit
		local n = Vector2.new(-u.Y, u.X)
		local accent = if index <= #ZONES then ZONES[index].color else nil
		local t = 6
		while t < length - 3 do
			for _, side in { -1, 1 } do
				local lampAt = a + u * t + n * side * (width / 2 + 1.2)
				Props.lamp(folder, Vector3.new(lampAt.X, 0, lampAt.Y), accent)
				local segEnd = math.min(t + 14, length - 2)
				if segEnd - t > 6 then
					local mid = a + u * ((t + segEnd) / 2) + n * side * (width / 2 + 2.6)
					local pos = Vector3.new(mid.X, 0, mid.Y)
					local cf = CFrame.lookAt(pos, pos + Vector3.new(n.X, 0, n.Y))
					if index <= #ZONES then
						Flora.flowerBed(folder, rng, cf, segEnd - t - 3)
					else
						Flora.hedge(folder, cf, segEnd - t - 3)
					end
				end
			end
			t += 16
		end
	end

	-- pond corner: benches looking at the water
	for _, a in { 0.4, 1.3 } do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = POND - dir * 24
		Props.bench(folder, CFrame.lookAt(pos, POND))
	end
	titleSign(folder)
	folder.Parent = workspace
end

-- Terrain surface can render a bit above its nominal y=0. Measure where it really is
-- and shift everything we built by that amount, so nothing sinks into the ground.
local function snapToGround()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	-- terrain collision appears a moment after FillBlock, so retry until the ray hits
	local heights = {}
	for _ = 1, 40 do
		table.clear(heights)
		for _, x in { 0, -40, 40 } do
			local hit = workspace:Raycast(Vector3.new(x, 60, -2), Vector3.new(0, -120, 0), params)
			if hit then
				table.insert(heights, hit.Position.Y)
			end
		end
		if #heights == 3 and math.max(table.unpack(heights)) > 0.05 then
			break
		end
		task.wait(0.1)
	end
	-- measured in Studio: terrain filled to y=0 renders its surface at y≈2
	local ground = if #heights > 0 then math.max(2, math.max(table.unpack(heights))) else 2
	local offset = Vector3.new(0, ground, 0)
	local roots = { workspace:FindFirstChildOfClass("SpawnLocation") }
	for _, name in { "Lobby", "Trainers", "Zones", "DuelArena", "Decor", "Nature" } do
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

	-- spawn on the plaza in front of the fountain (the center is the fountain now);
	-- invisible so the tile pattern shows through
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = workspace
	end
	spawn.CFrame = CFrame.lookAt(SPAWN, Vector3.new(0, SPAWN.Y, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end

	plaza()

	local trainers = Instance.new("Folder")
	trainers.Name = "Trainers"
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	for _, zone in ZONES do
		hall(zones, trainers, zone)
	end
	zones.Parent = workspace
	trainers.Parent = workspace

	duelArena()
	walls()
	decor()
	nature()
	snapToGround()
	-- clients may not have the arena streamed in, so publish the teleport point
	workspace:SetAttribute("ArenaSpawn", workspace.DuelArena.ArenaSpawn.CFrame.Position + Vector3.new(0, 4, 0))
	lighting()
end

return MapBuilder
