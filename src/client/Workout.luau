-- Exercises on the avatar's own face (camera is on the face while the item is held, see FaceCamera).
-- Bone Tapper: a zone lights up on your face; click/tap it and the hammer bonks it.
-- Gua Sha: dots run along your cheek from chin to ear; hold and drag through them.
-- Rules live in shared/MiniGames; every finished rep fires the Rep remote (server checks and pays).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MiniGames = require(ReplicatedStorage.Shared.MiniGames)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local GOLD = Color3.fromRGB(255, 210, 70)
local DIM = Color3.fromRGB(150, 110, 200)
local DONE = Color3.fromRGB(200, 130, 255)
local SURFACE = 0.08 -- studs in front of the head's front face

local Workout = {}

local folder: Folder -- client-only parts, under the camera
local statusLabel: TextLabel
local hammerHead: Part
local hammerHandle: Part
local roller: Part

local mode: string? = nil
local tapper: any = nil
local stroke: any = nil
local strokeSide = "L"
local markers: { Part } = {} -- zone markers (tap) or path dots (stroke)
local statusUntil = 0
local hammerUntil = 0
local hammerZone: Vector3? = nil
local flash: Frame
local stars: { Part } = {}
local hurt: (strength: number) -> ()

local function head(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Head") :: BasePart?
end

local function heldItem(): string?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ItemId")
end

local function setStatus(text: string, color: Color3, seconds: number?)
	statusLabel.Text = text
	statusLabel.TextColor3 = color
	statusUntil = if seconds then os.clock() + seconds else math.huge
end

local function localPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- Panel coordinates (0..1, x right, y down) <-> world point on the face plane.
local function faceToWorld(h: BasePart, x: number, y: number): Vector3
	local s = h.Size
	return h.CFrame:PointToWorldSpace(Vector3.new((x - 0.5) * s.X, (0.5 - y) * s.Y, -s.Z * 0.5 - SURFACE))
end

local function screenToFace(h: BasePart, screen: Vector2): (number?, number?)
	local ray = workspace.CurrentCamera:ScreenPointToRay(screen.X, screen.Y) -- input positions exclude the top bar inset
	local normal = h.CFrame.LookVector
	local planePoint = h.CFrame:PointToWorldSpace(Vector3.new(0, 0, -h.Size.Z * 0.5 - SURFACE))
	local denom = ray.Direction:Dot(normal)
	if math.abs(denom) < 1e-4 then
		return nil, nil
	end
	local t = (planePoint - ray.Origin):Dot(normal) / denom
	if t < 0 then
		return nil, nil
	end
	local hit = h.CFrame:PointToObjectSpace(ray.Origin + ray.Direction * t)
	return hit.X / h.Size.X + 0.5, 0.5 - hit.Y / h.Size.Y
end

local function clearMarkers()
	for _, m in markers do
		m:Destroy()
	end
	table.clear(markers)
end

local function markerSize(h: BasePart, scale: number): Vector3
	local d = math.min(h.Size.X, h.Size.Y) * scale
	return Vector3.new(d, d, d)
end

---------------------------------------------------------------- Bone Tapper

local function startTapper(h: BasePart)
	clearMarkers()
	tapper = MiniGames.Tapper.new(math.floor(os.clock() * 1000) % 100000, os.clock())
	for i in MiniGames.Zones do
		markers[i] = localPart("Zone", markerSize(h, 0.16), DIM, Enum.PartType.Ball)
	end
	setStatus(Strings.get("workout.tap_hint"), GOLD, 2)
end

local function refreshTapper()
	for i, m in markers do
		local lit = tapper.phase == "hit" and tapper.target == i
		m.Color = if lit then GOLD else DIM
		m.Transparency = if lit then 0.05 + 0.15 * math.sin(os.clock() * 12) else 0.65
	end
	if tapper.phase == "rest" then
		setStatus(Strings.get("workout.rest"), Color3.fromRGB(120, 220, 255))
	elseif tapper.phase == "stunned" then
		setStatus(Strings.get("workout.stunned"), Color3.fromRGB(255, 110, 110))
	elseif os.clock() > statusUntil then
		setStatus(Strings.get("workout.combo", { n = tapper.combo }), GOLD)
	end
end

local function bonk(zoneWorld: Vector3)
	hammerZone = zoneWorld
	hammerUntil = os.clock() + 0.3
end

-- X axis of the returned CFrame points along `dir` (cylinders are X-aligned).
local function alongX(position: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(position, position + dir) * CFrame.Angles(0, math.rad(90), 0)
end

-- Toy mallet swings in an arc around a grip below-right of the face, taps the zone, lifts back.
local function animateHammer(h: BasePart)
	local left = hammerUntil - os.clock()
	if not hammerZone or left <= 0 then
		hammerHead.Transparency = 1
		hammerHandle.Transparency = 1
		return
	end
	local t = 1 - left / 0.3 -- 0..1
	local angle = if t < 0.4 then 1.1 * (1 - t / 0.4) else 0.55 * ((t - 0.4) / 0.6)
	local look, right, up = h.CFrame.LookVector, h.CFrame.RightVector, h.CFrame.UpVector
	local grip = hammerZone + look * 0.3 + right * 0.8 - up * 0.65
	local strike = hammerZone + look * 0.14 -- head center when touching the face
	local arm = strike - grip
	local axis = arm:Cross(look).Unit -- positive angle lifts the head away from the face
	local swing = CFrame.fromAxisAngle(axis, angle)
	local headPos = grip + swing:VectorToWorldSpace(arm)
	hammerHead.CFrame = alongX(headPos, swing:VectorToWorldSpace(-look))
	local shaft = headPos - grip
	hammerHandle.Size = Vector3.new(shaft.Magnitude, 0.06, 0.06)
	hammerHandle.CFrame = alongX(grip + shaft / 2, shaft.Unit)
	hammerHead.Transparency = 0
	hammerHandle.Transparency = 0
end

-- Red flash over the screen; lower start transparency = stronger hit.
hurt = function(strength: number)
	flash.BackgroundTransparency = strength
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

-- Cartoon dizzy stars circling the head while stunned.
local function animateStars(h: BasePart)
	local stunned = tapper ~= nil and tapper.phase == "stunned"
	for i, star in stars do
		if stunned then
			local a = os.clock() * 4 + i * (math.pi * 2 / #stars)
			local r = h.Size.X * 0.7
			star.CFrame = h.CFrame * CFrame.new(math.cos(a) * r, h.Size.Y * 0.65, math.sin(a) * r)
			star.Transparency = 0
		else
			star.Transparency = 1
		end
	end
end

local function onTap(h: BasePart, screen: Vector2)
	local x, y = screenToFace(h, screen)
	if not x then
		return
	end
	-- nearest zone within reach of the click
	local best, bestDist = nil, 0.14
	for i, zone in MiniGames.Zones do
		local d = math.sqrt((zone.x - x) ^ 2 + (zone.y - (y :: number)) ^ 2)
		if d < bestDist then
			best, bestDist = i, d
		end
	end
	-- a click on the face away from every zone still lands the hammer: that's a miss
	local onFace = ((x - 0.5) / 0.5) ^ 2 + (((y :: number) - 0.5) / 0.5) ^ 2 <= 1.1
	if not best and not onFace then
		return
	end
	local result = tapper:tap(best or 0, os.clock())
	if result == "stunned" then
		return
	end
	bonk(faceToWorld(h, x, y :: number))
	if result == "hit" then
		remotes.Rep:FireServer()
	elseif result == "miss" then
		remotes.Fail:FireServer("miss")
		hurt(0.45)
		setStatus(Strings.get("workout.ouch"), Color3.fromRGB(255, 110, 110), 1)
	elseif result == "rest_fail" then
		remotes.Fail:FireServer("rest_fail")
		hurt(0.25)
		setStatus(Strings.get("workout.crack"), Color3.fromRGB(255, 80, 80), 1.5)
	end
end

---------------------------------------------------------------- Gua Sha

local function startStroke(h: BasePart)
	clearMarkers()
	stroke = MiniGames.Stroke.new(strokeSide)
	for i in stroke.points do
		markers[i] = localPart("PathDot", markerSize(h, if i == 1 then 0.14 else 0.1), DIM, Enum.PartType.Ball)
	end
end

local function refreshStroke()
	for i, m in markers do
		local reached = i <= stroke.reached
		local nextOne = i == stroke.reached + 1
		m.Color = if reached then DONE elseif nextOne then GOLD else DIM
		m.Transparency = if reached or nextOne then 0.05 else 0.5
	end
	if os.clock() > statusUntil then
		setStatus(Strings.get("workout.stroke_hint"), GOLD)
	end
end

local function onStrokeMove(h: BasePart, screen: Vector2)
	local x, y = screenToFace(h, screen)
	if not x then
		return
	end
	roller.Transparency = 0.1
	roller.CFrame = CFrame.lookAt(faceToWorld(h, x, y :: number), faceToWorld(h, x, y :: number) + h.CFrame.LookVector)
	if stroke:move(x, y) then
		remotes.Rep:FireServer()
		setStatus(Strings.get("workout.stroke_done"), DONE, 0.8)
		strokeSide = if strokeSide == "L" then "R" else "L"
		startStroke(h)
		stroke:press() -- keep holding to flow into the next stroke
	end
end

---------------------------------------------------------------- loop / input

local function setMode(newMode: string?, h: BasePart?)
	if newMode == mode then
		return
	end
	mode = newMode
	clearMarkers()
	tapper, stroke = nil, nil
	roller.Transparency = 1
	statusLabel.Visible = newMode ~= nil
	if not h then
		return
	end
	if newMode == "tap" then
		startTapper(h)
	elseif newMode == "stroke" then
		startStroke(h)
		setStatus(Strings.get("workout.stroke_hint"), GOLD)
	end
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Workout.init()
	folder = Instance.new("Folder")
	folder.Name = "WorkoutParts"
	folder.Parent = workspace.CurrentCamera

	-- small cartoon mallet: round red head, thin wooden shaft
	hammerHead = localPart("HammerHead", Vector3.new(0.3, 0.2, 0.2), Color3.fromRGB(225, 65, 75), Enum.PartType.Cylinder)
	hammerHead.Material = Enum.Material.SmoothPlastic
	hammerHandle = localPart("HammerHandle", Vector3.new(0.8, 0.06, 0.06), Color3.fromRGB(150, 100, 60), Enum.PartType.Cylinder)
	hammerHandle.Material = Enum.Material.Wood
	roller = localPart("GuaSha", Vector3.new(0.35, 0.18, 0.04), DONE)
	roller.Transparency = 1
	hammerHead.Transparency = 1
	hammerHandle.Transparency = 1
	for i = 1, 3 do
		stars[i] = localPart("DizzyStar", Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 230, 90), Enum.PartType.Ball)
		stars[i].Transparency = 1
	end

	local gui = Ui.screen("Workout", 3)
	statusLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.19),
		Size = UDim2.fromScale(0.4, 0.06),
		BackgroundColor3 = Color3.fromRGB(28, 26, 40),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
	})
	Ui.corner(0.3).Parent = statusLabel
	flash = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 40, 40),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = gui,
	})
	gui.Parent = player:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function()
		local h = head()
		local itemId = heldItem()
		setMode(if itemId and h then MiniGames.kindOf(itemId) else nil, h)
		if not h or not mode then
			hammerHead.Transparency = 1
			hammerHandle.Transparency = 1
			for _, star in stars do
				star.Transparency = 1
			end
			return
		end
		if mode == "tap" then
			if tapper:update(os.clock()) == "timeout" then
				setStatus(Strings.get("workout.miss"), Color3.fromRGB(255, 140, 140), 0.6)
			end
			for i, zone in MiniGames.Zones do
				markers[i].CFrame = CFrame.new(faceToWorld(h, zone.x, zone.y))
			end
			refreshTapper()
			animateHammer(h)
			animateStars(h)
		else
			for i, p in stroke.points do
				markers[i].CFrame = CFrame.new(faceToWorld(h, p[1], p[2]))
			end
			refreshStroke()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		local h = head()
		if processed or not h or not mode or not isPress(input) then
			return
		end
		local screen = Vector2.new(input.Position.X, input.Position.Y)
		if mode == "tap" then
			onTap(h, screen)
		else
			stroke:press()
			onStrokeMove(h, screen)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local h = head()
		if mode ~= "stroke" or not h or not stroke or not stroke.pressed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			onStrokeMove(h, Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if mode == "stroke" and stroke and isPress(input) then
			stroke:release()
			roller.Transparency = 1
		end
	end)
end

return Workout
