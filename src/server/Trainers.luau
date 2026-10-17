-- Trainer seats: sit via prompt, one player per seat, VIP seats need the VIP pass.
-- An occupied seat lights up and its holder gets the trainer multiplier.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local Trainers = {}

type OwnsPass = (player: Player, passName: string) -> boolean

local function setActive(model: Model, active: boolean, vipBlocked: boolean?)
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
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
end

local function setup(model: Model, ownsPass: OwnsPass)
	local seat = model:FindFirstChild("Seat") :: Seat
	local vip = model:GetAttribute("Vip") == true

	seat.SitPrompt.Triggered:Connect(function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and not seat.Occupant and humanoid.Health > 0 then
			seat:Sit(humanoid)
		end
	end)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
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
		setActive(model, humanoid ~= nil)
	end)

	setActive(model, false)
end

function Trainers.init(ownsPass: OwnsPass)
	local folder = workspace:WaitForChild("Trainers")
	for _, model in folder:GetChildren() do
		setup(model, ownsPass)
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
