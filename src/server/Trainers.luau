-- Trainer seats: sit via prompt, one player per seat, VIP seats need the VIP pass.
-- An occupied seat lights up and its holder gets the trainer multiplier.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local Trainers = {}

-- Seat list mirrored into ReplicatedStorage so clients see far seats even when the map
-- around them is not streamed in (used by the guide arrow).
local seatInfoFolder = Instance.new("Folder")
seatInfoFolder.Name = "SeatInfo"
seatInfoFolder.Parent = ReplicatedStorage
local seatInfo: { [Model]: Configuration } = {}

-- seat -> who sits and since when; player -> may not sit again until
local sessions: { [Seat]: { player: Player, since: number, model: Model } } = {}
local cooldownUntil: { [Player]: number } = {}

type OwnsPass = (player: Player, passName: string) -> boolean

local function setActive(model: Model, active: boolean, vipBlocked: boolean?)
	local info = seatInfo[model]
	if info then
		info:SetAttribute("Occupied", active)
	end
	local base = model:FindFirstChild("Base") :: BasePart
	local trim = model:FindFirstChild("Trim") :: BasePart
	local color = model:GetAttribute("Color") :: Color3
	trim.Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic
	trim.Color = if active then color else color:Lerp(Color3.new(0, 0, 0), 0.4)
	local sparkles = base:FindFirstChild("ActiveSparkles") :: ParticleEmitter
	sparkles.Enabled = active
	local label = base.Status.Label :: TextLabel
	if vipBlocked then
		label.Text = "VIP only"
		label.TextColor3 = Color3.fromRGB(255, 200, 40)
	elseif active then
		label.Text = "Busy"
		label.TextColor3 = Color3.fromRGB(255, 130, 130)
	else
		label.Text = "Free"
		label.TextColor3 = Color3.fromRGB(160, 255, 170)
	end
	local prompt = model.Seat:FindFirstChild("SitPrompt") :: ProximityPrompt
	prompt.Enabled = not active
end

local function kick(seat: Seat)
	local humanoid = seat.Occupant
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if humanoid then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

local THROW_DISTANCE = 15

-- After a timeout, land the player ~15 studs from the seat, on the side facing the spawn.
local function throwAway(player: Player, seat: Seat)
	task.delay(0.15, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
		local toward = (if spawn then spawn.Position else Vector3.zero) - seat.Position
		toward = Vector3.new(toward.X, 0, toward.Z)
		local dir = if toward.Magnitude > 0.1 then toward.Unit else Vector3.zAxis
		local landing = seat.Position + dir * THROW_DISTANCE + Vector3.new(0, 3, 0)
		character:PivotTo(CFrame.lookAt(landing, landing + dir))
	end)
end

local function timerLabel(model: Model): TextLabel
	local status = (model:FindFirstChild("Base") :: BasePart):FindFirstChild("Status") :: BillboardGui
	local timer = status:FindFirstChild("Timer") :: TextLabel?
	if timer then
		return timer
	end
	status.Size = UDim2.fromScale(4, 1.5)
	local label = status:FindFirstChild("Label") :: TextLabel
	label.Size = UDim2.fromScale(1, 0.55)
	local t = label:Clone()
	t.Name = "Timer"
	t.AutoLocalize = false
	t.Position = UDim2.fromScale(0, 0.55)
	t.Size = UDim2.fromScale(1, 0.45)
	t.Text = ""
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = status
	return t
end

local function setup(model: Model, ownsPass: OwnsPass)
	local seat = model:FindFirstChild("Seat") :: Seat
	local vip = model:GetAttribute("Vip") == true

	local info = Instance.new("Configuration")
	info.Name = "Seat" .. (#seatInfoFolder:GetChildren() + 1)
	info:SetAttribute("Item", model:GetAttribute("ItemId"))
	info:SetAttribute("Vip", vip)
	info:SetAttribute("Position", seat.Position)
	info:SetAttribute("Occupied", false)
	info.Parent = seatInfoFolder
	seatInfo[model] = info

	seat.SitPrompt.Triggered:Connect(function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and not seat.Occupant and humanoid.Health > 0 then
			seat:Sit(humanoid)
		end
	end)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
		local previous = sessions[seat]
		if previous then
			previous.player:SetAttribute("SeatEndsAt", nil)
		end
		sessions[seat] = nil
		timerLabel(model).Text = ""
		if player and (cooldownUntil[player] or 0) > os.clock() then
			-- just got kicked for sitting too long: free the seat for others
			kick(seat)
			setActive(model, false)
			return
		end
		if player and vip and not ownsPass(player, "Vip") then
			kick(seat)
			setActive(model, false, true)
			if Config.GamePasses.Vip ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.Vip)
			end
			task.delay(2, function()
				if not seat.Occupant then
					setActive(model, false)
				end
			end)
			return
		end
		if player then
			sessions[seat] = { player = player, since = os.clock(), model = model }
			player:SetAttribute("SeatEndsAt", workspace:GetServerTimeNow() + Config.SeatMaxSeconds)
		end
		setActive(model, humanoid ~= nil)
	end)

	setActive(model, false)
end

function Trainers.init(ownsPass: OwnsPass)
	local folder = workspace:WaitForChild("Trainers")
	for _, model in folder:GetChildren() do
		setup(model, ownsPass)
	end

	-- seat time limit: countdown on the sign, kick when it runs out
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for seat, info in sessions do
				local left = Config.SeatMaxSeconds - (now - info.since)
				if left <= 0 then
					cooldownUntil[info.player] = now + Config.SeatCooldownSeconds
					sessions[seat] = nil
					info.player:SetAttribute("SeatEndsAt", nil)
					kick(seat)
					throwAway(info.player, seat)
				else
					timerLabel(info.model).Text = string.format("%d:%02d", left // 60, left % 60)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldownUntil[player] = nil
	end)
end

-- Stand the player up if they sit on a trainer (used on rebirth).
function Trainers.standUp(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("Seat") and seat:GetAttribute("TrainerSeat") then
		kick(seat)
	end
end

-- Multiplier for the seat the player sits on, if it matches their held item.
function Trainers.mult(player: Player, data: Progression.Data, ownsPass: OwnsPass): number
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat or not seat:GetAttribute("TrainerSeat") then
		return 1
	end
	local model = seat.Parent
	if not model or model:GetAttribute("ItemId") ~= data.equipped then
		return 1
	end
	if model:GetAttribute("Vip") then
		return if ownsPass(player, "Vip") then Config.Mult.Vip else 1
	end
	return Config.Mult.Trainer
end

return Trainers
