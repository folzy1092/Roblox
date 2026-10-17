-- Guide tracer: while you hold an item (and aren't seated), running arrows on the ground
-- lead to the nearest free seat for your best item, and a light beacon marks that seat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SeatPicker = require(ReplicatedStorage.Shared.SeatPicker)

local player = Players.LocalPlayer

local ARROW_COUNT = 12
local SPACING = 3.2
local SPEED = 6 -- studs per second the arrows run
local RETARGET_SECONDS = 0.4
local COLOR = Color3.fromRGB(255, 215, 80)

local Guide = {}

local folder: Folder
local arrows: { { Part } } = {}
local beacon: Part
local target: Vector3? = nil
local lastPick = 0

local function arm(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = COLOR
	p.Size = Vector3.new(0.35, 0.12, 1.5)
	p.Transparency = 1
	p.Parent = folder
	return p
end

local function build()
	folder = Instance.new("Folder")
	folder.Name = "GuideArrows"
	folder.Parent = workspace.CurrentCamera -- local only
	for i = 1, ARROW_COUNT do
		arrows[i] = { arm(), arm() }
	end
	beacon = Instance.new("Part")
	beacon.Name = "GuideBeacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = COLOR
	beacon.Size = Vector3.new(40, 1.2, 1.2)
	beacon.Transparency = 1
	beacon.Parent = folder
end

local function heldItem(): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("ItemId") ~= nil
end

local function seated(): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

local function seatList(): { SeatPicker.SeatInfo }
	local list = {}
	local info = ReplicatedStorage:FindFirstChild("SeatInfo")
	if not info then
		return list
	end
	for _, c in info:GetChildren() do
		local pos = c:GetAttribute("Position")
		if typeof(pos) == "Vector3" then
			table.insert(list, {
				id = pos,
				item = c:GetAttribute("Item"),
				vip = c:GetAttribute("Vip") == true,
				x = pos.X,
				z = pos.Z,
				occupied = c:GetAttribute("Occupied") == true,
			})
		end
	end
	return list
end

local function owned(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("Items") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

local function hide()
	for _, pair in arrows do
		pair[1].Transparency = 1
		pair[2].Transparency = 1
	end
	beacon.Transparency = 1
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not heldItem() or seated() then
		target = nil
		hide()
		return
	end

	local now = os.clock()
	if now - lastPick > RETARGET_SECONDS then
		lastPick = now
		local pick = SeatPicker.pick(seatList(), owned(), player:GetAttribute("Pass_Vip") == true, root.Position.X, root.Position.Z)
		target = if pick then pick.id else nil
	end
	if not target then
		hide()
		return
	end

	local feet = root.Position - Vector3.new(0, 2.7, 0)
	local flat = Vector3.new(target.X - feet.X, 0, target.Z - feet.Z)
	local dist = flat.Magnitude
	local dir = if dist > 0.01 then flat.Unit else Vector3.zAxis
	local phase = (now * SPEED) % SPACING

	for i, pair in arrows do
		local along = 2.5 + (i - 1) * SPACING + phase
		local visible = along < dist - 2
		if visible then
			local t = along / dist
			local pos = feet + dir * along + Vector3.new(0, (target.Y - 0.5 - feet.Y) * t + 0.15, 0)
			local base = CFrame.lookAt(pos, pos + dir)
			pair[1].CFrame = base * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, 0.7)
			pair[2].CFrame = base * CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(0, 0, 0.7)
			-- fade in near the player, fade out near the end
			local fade = math.clamp(math.min(along - 2.5, dist - 2 - along) / 3, 0, 1)
			pair[1].Transparency = 1 - 0.85 * fade
			pair[2].Transparency = 1 - 0.85 * fade
		else
			pair[1].Transparency = 1
			pair[2].Transparency = 1
		end
	end

	beacon.CFrame = CFrame.new(target + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Transparency = 0.55 + 0.15 * math.sin(now * 4)
end

function Guide.init()
	build()
	RunService.RenderStepped:Connect(step)
end

return Guide
