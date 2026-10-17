-- Live "reflection": the nearest MirrorSurface shows a copy of your character
-- in a ViewportFrame, so you watch your own face change while training.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local RANGE = 16
local RESYNC_SECONDS = 1

local MirrorView = {}

local mirrors: { BasePart } = {}
local gui: SurfaceGui? = nil
local viewport: ViewportFrame? = nil
local camera: Camera? = nil
local clone: Model? = nil
local pairs_: { { BasePart } } = {}
local sourceCount = -1
local lastSync = 0

-- Mirrors stream in and out with the map, so track them by tag instead of scanning once.
local function trackMirrors()
	for _, m in CollectionService:GetTagged("Mirror") do
		table.insert(mirrors, m)
	end
	CollectionService:GetInstanceAddedSignal("Mirror"):Connect(function(m)
		table.insert(mirrors, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Mirror"):Connect(function(m)
		local i = table.find(mirrors, m)
		if i then
			table.remove(mirrors, i)
		end
	end)
end

local function nearestMirror(root: BasePart): BasePart?
	local best, bestDist = nil, RANGE
	for _, m in mirrors do
		if not m.Parent then
			continue
		end
		-- only when standing in front of the mirror face
		local rel = m.CFrame:PointToObjectSpace(root.Position)
		local dist = (m.Position - root.Position).Magnitude
		if rel.Z < 0 and dist < bestDist then
			best, bestDist = m, dist
		end
	end
	return best
end

local function clearClone()
	if clone then
		clone:Destroy()
	end
	clone = nil
	table.clear(pairs_)
	sourceCount = -1
end

-- Copy the character into the viewport and pair parts by descendant order.
local function rebuildClone(character: Model)
	clearClone()
	local world = viewport and viewport:FindFirstChildOfClass("WorldModel")
	if not world then
		return
	end
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = false
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- pair parts by their path inside the character (descendant order is not stable)
	local function pathOf(inst: Instance, root: Instance): string
		local names = {}
		local node = inst
		while node and node ~= root do
			table.insert(names, 1, node.Name)
			node = node.Parent
		end
		return table.concat(names, "/")
	end
	local byPath: { [string]: { BasePart } } = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			local key = pathOf(d, copy)
			byPath[key] = byPath[key] or {}
			table.insert(byPath[key], d)
		end
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local list = byPath[pathOf(d, character)]
			local twin = list and table.remove(list, 1)
			if twin then
				table.insert(pairs_, { d, twin })
			end
		end
	end
	copy.Parent = world
	clone = copy
	sourceCount = #character:GetDescendants()
end

local function hide()
	if gui then
		gui.Enabled = false
	end
	clearClone()
end

local function ensureGui(): SurfaceGui
	if gui then
		return gui
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "MirrorView"
	g.Face = Enum.NormalId.Front
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.ResetOnSpawn = false
	g.Enabled = false
	local v = Instance.new("ViewportFrame")
	v.Size = UDim2.fromScale(1, 1)
	v.BackgroundColor3 = Color3.fromRGB(150, 170, 195)
	v.Ambient = Color3.fromRGB(170, 170, 180)
	v.LightColor = Color3.fromRGB(255, 240, 225)
	v.LightDirection = Vector3.new(0, -0.6, 1)
	v.Parent = g
	Instance.new("WorldModel").Parent = v
	local c = Instance.new("Camera")
	c.FieldOfView = 40
	c.Parent = v
	v.CurrentCamera = c
	Instance.new("UIGradient", v).Transparency = NumberSequence.new(0, 0.05)
	g.Parent = player:WaitForChild("PlayerGui")
	gui, viewport, camera = g, v, c
	return g
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not root or not head then
		hide()
		return
	end
	local m = nearestMirror(root)
	if not m then
		hide()
		return
	end
	local g = ensureGui()
	g.Adornee = m
	g.Enabled = true

	local now = os.clock()
	if not clone or (now - lastSync > RESYNC_SECONDS and #character:GetDescendants() ~= sourceCount) then
		lastSync = now
		rebuildClone(character)
	end
	for _, pair in pairs_ do
		local s, d = pair[1], pair[2]
		if s.Parent then
			d.CFrame = s.CFrame
			if d.Size ~= s.Size then
				d.Size = s.Size
			end
			d.Transparency = s.Transparency
		end
	end

	-- camera sits on the mirror plane, looking at your face
	local eye = m.Position + m.CFrame.LookVector * 0.1
	eye = Vector3.new(eye.X, head.Position.Y + 0.3, eye.Z)
	if camera then
		camera.CFrame = CFrame.lookAt(eye, head.Position)
	end
end

function MirrorView.init()
	trackMirrors()
	RunService.RenderStepped:Connect(step)
	player.CharacterAdded:Connect(clearClone)
end

return MirrorView
