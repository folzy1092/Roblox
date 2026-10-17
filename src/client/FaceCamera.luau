-- Clicking with a held item: fires Click and smoothly moves the camera onto the face.
-- Camera returns to normal after a short idle, on unequip, or on death.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Strings = require(script.Parent.Strings)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local IDLE_RETURN = 2.5
local BIND_NAME = "LooksmaxFaceCamera"

local FaceCamera = {}

local zoomed = false
local lastClick = 0
local blend = 0

local function head(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Head") :: BasePart?
end

local function stop()
	if not zoomed then
		return
	end
	zoomed = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function start()
	if zoomed then
		return
	end
	zoomed = true
	blend = 0
	local camera = workspace.CurrentCamera
	local from = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local h = head()
		if not h or os.clock() - lastClick > IDLE_RETURN then
			stop()
			return
		end
		blend = math.min(blend + dt * 2, 1)
		local eased = TweenService:GetValue(blend, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local eye = h.CFrame:PointToWorldSpace(Vector3.new(0, 0.3, -3.5))
		local target = CFrame.lookAt(eye, h.Position)
		camera.CFrame = from:Lerp(target, eased)
	end)
end

local function popup(amount: number)
	local h = head()
	if not h or amount <= 0 then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(3, 1)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 1, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = h
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.AutoLocalize = false
	label.Text = "+" .. Strings.num(amount)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 2, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.8, gui.Destroy, gui)
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("ItemId") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		lastClick = os.clock()
		remotes.Click:FireServer()
		start()
	end)
	tool.Unequipped:Connect(stop)
end

local function onCharacter(character: Model)
	stop()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(stop)
	character.ChildAdded:Connect(hookTool)
end

function FaceCamera.init()
	local backpack = player:WaitForChild("Backpack")
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			child.ChildAdded:Connect(hookTool)
			for _, tool in child:GetChildren() do
				hookTool(tool)
			end
		end
	end)
	backpack.ChildAdded:Connect(hookTool)
	for _, tool in backpack:GetChildren() do
		hookTool(tool)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	local lastGlow = player:GetAttribute("Glow") or 0
	player:GetAttributeChangedSignal("Glow"):Connect(function()
		local glow = player:GetAttribute("Glow") or 0
		popup(glow - lastGlow)
		lastGlow = glow
	end)
end

return FaceCamera
