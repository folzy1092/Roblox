-- Exercise panel for mini-game items (Gua Sha stroke, Bone Tapper taps).
-- Shows a drawn face on the right side of the screen; finished reps fire the Rep remote.
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
local DIM = Color3.fromRGB(110, 80, 150) -- readable on any skin tone

local Workout = {}

local gui: ScreenGui
local panel: Frame
local face: Frame
local title: TextLabel
local status: TextLabel
local layer: Frame -- zones / path dots live here (face-relative)
local hammer: Frame
local roller: Frame

local mode: string? = nil
local tapper: any = nil
local stroke: any = nil
local strokeSide = "L"
local zoneButtons: { TextButton } = {}
local pathDots: { Frame } = {}
local statusUntil = 0

local function heldItem(): string?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ItemId")
end

local function setStatus(text: string, color: Color3, seconds: number?)
	status.Text = text
	status.TextColor3 = color
	statusUntil = if seconds then os.clock() + seconds else math.huge
end

local function clearLayer()
	for _, child in layer:GetChildren() do
		child:Destroy()
	end
	table.clear(zoneButtons)
	table.clear(pathDots)
end

local function dot(x: number, y: number, size: number, color: Color3): Frame
	return Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(size, size),
		BackgroundColor3 = color,
		Parent = layer,
	}, { Ui.corner(0.5), Ui.make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
end

local function shakeFace()
	face.Position = UDim2.fromScale(0.5, 0.56)
	TweenService:Create(face, TweenInfo.new(0.15, Enum.EasingStyle.Elastic), { Position = UDim2.fromScale(0.5, 0.55) }):Play()
end

---------------------------------------------------------------- Bone Tapper

local function swingHammer(x: number, y: number)
	hammer.Visible = true
	hammer.Position = UDim2.fromScale(x + 0.06, y + 0.02)
	hammer.Rotation = -55
	local down = TweenService:Create(hammer, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = 15 })
	down:Play()
	down.Completed:Once(function()
		shakeFace()
		TweenService:Create(hammer, TweenInfo.new(0.2), { Rotation = -40 }):Play()
	end)
end

local function refreshZones()
	for i, button in zoneButtons do
		local lit = tapper and tapper.phase == "hit" and tapper.target == i
		button.BackgroundColor3 = if lit then GOLD else DIM
		button.BackgroundTransparency = if lit then 0 else 0.75
		local outline = button:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Transparency = if lit then 0 else 0.6
		end
	end
	if tapper.phase == "rest" then
		setStatus(Strings.get("workout.rest"), Color3.fromRGB(120, 220, 255))
	elseif tapper.phase == "stunned" then
		setStatus(Strings.get("workout.stunned"), Color3.fromRGB(255, 110, 110))
	elseif os.clock() > statusUntil then
		setStatus(Strings.get("workout.combo", { n = tapper.combo }), GOLD)
	end
end

local function startTapper()
	clearLayer()
	tapper = MiniGames.Tapper.new(math.floor(os.clock() * 1000) % 100000, os.clock())
	for i, zone in MiniGames.Zones do
		local button = Ui.make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(zone.x, zone.y),
			Size = UDim2.fromScale(0.17, 0.17),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = DIM,
			Parent = layer,
		}, {
			Ui.corner(0.5),
			Ui.make("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Ui.make("UIStroke", { Color = GOLD, Thickness = 2 }),
		})
		button.Activated:Connect(function()
			local result = tapper:tap(i, os.clock())
			if result == "hit" then
				swingHammer(zone.x, zone.y)
				remotes.Rep:FireServer()
			elseif result == "miss" then
				setStatus(Strings.get("workout.miss"), Color3.fromRGB(255, 140, 140), 0.6)
			elseif result == "rest_fail" then
				swingHammer(zone.x, zone.y)
			end
			refreshZones()
		end)
		zoneButtons[i] = button
	end
	setStatus(Strings.get("workout.tap_hint"), GOLD, 2)
	refreshZones()
end

---------------------------------------------------------------- Gua Sha

local function refreshPath()
	for i, d in pathDots do
		local reached = stroke and i <= stroke.reached
		d.BackgroundColor3 = if reached then Color3.fromRGB(190, 120, 255) else DIM
		d.BackgroundTransparency = if reached then 0 else 0.35
	end
end

local function startStroke()
	clearLayer()
	stroke = MiniGames.Stroke.new(strokeSide)
	for i, p in stroke.points do
		pathDots[i] = dot(p[1], p[2], if i == 1 then 0.1 else 0.07, DIM)
	end
	-- start marker: big ring on the chin end
	local start = stroke.points[1]
	Ui.make("UIStroke", { Color = GOLD, Thickness = 3, Parent = pathDots[1] })
	local _ = start
	refreshPath()
end

local function facePoint(screen: Vector3): (number, number)
	local rel = (Vector2.new(screen.X, screen.Y) - face.AbsolutePosition) / face.AbsoluteSize
	return rel.X, rel.Y
end

local function onStrokeMove(x: number, y: number)
	roller.Position = UDim2.fromScale(x, y)
	if stroke:move(x, y) then
		remotes.Rep:FireServer()
		shakeFace()
		setStatus(Strings.get("workout.stroke_done"), Color3.fromRGB(210, 160, 255), 0.8)
		strokeSide = if strokeSide == "L" then "R" else "L"
		startStroke()
		stroke:press() -- keep holding to go straight into the next stroke
	end
	refreshPath()
end

---------------------------------------------------------------- panel

local function build()
	gui = Ui.screen("Workout", 3)
	gui.IgnoreGuiInset = false -- input positions and GUI share the same space
	panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.985, 0.47),
		Size = UDim2.fromScale(0.3, 0.62),
		BackgroundColor3 = Color3.fromRGB(28, 26, 40),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(0.06),
		Ui.make("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.3 }),
		Ui.make("UIAspectRatioConstraint", { AspectRatio = 0.78 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(220, 280) }),
	})
	title = Ui.label({
		Size = UDim2.fromScale(0.9, 0.08),
		Position = UDim2.fromScale(0.05, 0.02),
		TextColor3 = GOLD,
		Parent = panel,
	})
	status = Ui.label({
		Size = UDim2.fromScale(0.9, 0.07),
		Position = UDim2.fromScale(0.05, 0.11),
		Font = Enum.Font.GothamBold,
		Parent = panel,
	})

	face = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.78, 0.72),
		BackgroundColor3 = Color3.fromRGB(245, 205, 170),
		Active = true,
		Parent = panel,
	}, { Ui.corner(0.5), Ui.make("UIStroke", { Color = Color3.fromRGB(80, 60, 50), Thickness = 2 }) })
	-- simple drawn features
	for _, x in { 0.36, 0.64 } do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.4),
			Size = UDim2.fromScale(0.09, 0.05),
			BackgroundColor3 = Color3.fromRGB(40, 35, 45),
			Parent = face,
		}, { Ui.corner(0.5) })
	end
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.67),
		Size = UDim2.fromScale(0.2, 0.025),
		BackgroundColor3 = Color3.fromRGB(150, 70, 70),
		Parent = face,
	}, { Ui.corner(0.5) })

	layer = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = face })

	-- hammer: pivot at the bottom of the handle
	hammer = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromScale(0.06, 0.3),
		BackgroundColor3 = Color3.fromRGB(120, 80, 50),
		Visible = false,
		ZIndex = 5,
		Parent = face,
	}, { Ui.corner(0.3) })
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(4.2, 0.28),
		BackgroundColor3 = Color3.fromRGB(190, 195, 210),
		ZIndex = 6,
		Parent = hammer,
	}, { Ui.corner(0.2), Ui.make("UIStroke", { Color = Color3.fromRGB(70, 70, 80), Thickness = 2 }) })

	-- gua sha roller follows the pointer while dragging
	roller = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.16, 0.08),
		BackgroundColor3 = Color3.fromRGB(190, 120, 255),
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 5,
		Parent = face,
	}, { Ui.corner(0.5), Ui.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }) })

	face.InputBegan:Connect(function(input)
		if mode ~= "stroke" then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stroke:press()
			roller.Visible = true
			onStrokeMove(facePoint(input.Position))
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if mode == "stroke" and stroke and stroke.pressed and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			onStrokeMove(facePoint(input.Position))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if mode == "stroke" and stroke and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			stroke:release()
			roller.Visible = false
			refreshPath()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setMode(newMode: string?, itemId: string?)
	if newMode == mode then
		return
	end
	mode = newMode
	hammer.Visible = false
	roller.Visible = false
	panel.Visible = newMode ~= nil
	if newMode == "tap" then
		title.Text = Strings.get("item." .. itemId)
		startTapper()
	elseif newMode == "stroke" then
		title.Text = Strings.get("item." .. itemId)
		setStatus(Strings.get("workout.stroke_hint"), GOLD)
		startStroke()
	else
		clearLayer()
		tapper, stroke = nil, nil
	end
end

function Workout.init()
	build()
	RunService.Heartbeat:Connect(function()
		local itemId = heldItem()
		setMode(if itemId then MiniGames.kindOf(itemId) else nil, itemId)
		if mode == "tap" and tapper then
			if tapper:update(os.clock()) == "timeout" then
				setStatus(Strings.get("workout.miss"), Color3.fromRGB(255, 140, 140), 0.6)
			end
			refreshZones()
		end
		-- face color follows the character's skin
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if head and mode then
			face.BackgroundColor3 = head.Color
		end
	end)
end

return Workout
