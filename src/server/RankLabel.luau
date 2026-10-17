-- Custom name tag: player name on top, PSL rank + progress bar under it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local RankLabel = {}

local function build(player: Player, head: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RankLabel"
	gui.Size = UDim2.fromScale(6, 1.8)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 100
	gui.Adornee = head

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.Size = UDim2.fromScale(1, 0.45)
	name.BackgroundTransparency = 1
	name.Text = player.DisplayName
	name.AutoLocalize = false
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Parent = gui

	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.Position = UDim2.fromScale(0, 0.45)
	rank.Size = UDim2.fromScale(1, 0.32)
	rank.BackgroundTransparency = 1
	rank.AutoLocalize = false
	rank.TextScaled = true
	rank.Font = Enum.Font.FredokaOne
	rank.TextColor3 = Color3.fromRGB(255, 220, 90)
	rank.TextStrokeTransparency = 0.4
	rank.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.2, 0.82)
	bar.Size = UDim2.fromScale(0.6, 0.12)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	bar.BorderSizePixel = 0
	bar.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local function update()
		local tier, frac = Progression.tierProgress(player:GetAttribute("Rating") or 0)
		rank.Text = Config.Tiers[tier].name
		fill.Size = UDim2.fromScale(frac, 1)
	end
	update()
	gui.Parent = head
	return update
end

function RankLabel.attach(player: Player)
	local current: (() -> ())? = nil
	player:GetAttributeChangedSignal("Rating"):Connect(function()
		if current then
			current()
		end
	end)
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local head = character:WaitForChild("Head") :: BasePart
		current = build(player, head)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return RankLabel
