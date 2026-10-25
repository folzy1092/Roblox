-- Duels panel: pick 1:30 or 3:00, challenge any player in the server, or walk to the arena.
-- The match itself runs in DuelGame.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DuelGame = require(script.Parent.DuelGame)
local DuelRules = require(game:GetService("ReplicatedStorage").Shared.DuelRules)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local RED = Color3.fromRGB(230, 70, 80)

local Duels = {}

function Duels.init(): () -> ()
	DuelGame.init()
	local gui = Ui.screen("Duels", 5)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.44, 0.66),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(0.05),
		Ui.make("UIStroke", { Color = Color3.fromRGB(255, 90, 90), Thickness = 3 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(330, 320) }),
		Ui.make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(120, 30, 50), Color3.fromRGB(30, 20, 40)),
			Rotation = 90,
		}),
	})
	local scale = Ui.make("UIScale", { Parent = panel })

	Ui.label({
		Size = UDim2.fromScale(0.62, 0.1),
		Position = UDim2.fromScale(0.05, 0.03),
		Text = Strings.get("duels.title"),
		TextColor3 = Color3.fromRGB(255, 200, 200),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local winsLabel = Ui.label({
		Size = UDim2.fromScale(0.28, 0.07),
		Position = UDim2.fromScale(0.67, 0.045),
		TextColor3 = Color3.fromRGB(255, 210, 70),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.13),
		Text = Strings.get("duels.how"),
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(235, 225, 235),
		Parent = panel,
	})

	-- duration picker
	local duration = DuelRules.DURATIONS[1]
	local durButtons = {}
	for i, d in DuelRules.DURATIONS do
		local b = Ui.button({
			Size = UDim2.fromScale(0.42, 0.08),
			Position = UDim2.fromScale(0.05 + (i - 1) * 0.48, 0.25),
			Text = string.format("%d:%02d", d // 60, d % 60),
			Parent = panel,
		})
		durButtons[d] = b
		b.Activated:Connect(function()
			duration = d
			for dd, bb in durButtons do
				bb.BackgroundColor3 = if dd == duration then RED else Ui.Colors.Muted
			end
		end)
	end
	for dd, bb in durButtons do
		bb.BackgroundColor3 = if dd == duration then RED else Ui.Colors.Muted
	end

	-- players list
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromScale(0.05, 0.36),
		Size = UDim2.fromScale(0.9, 0.45),
		BackgroundColor3 = Color3.fromRGB(20, 14, 26),
		BackgroundTransparency = 0.3,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.corner(0.05),
		Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.Name }),
		Ui.make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
	})
	local empty = Ui.label({
		Size = UDim2.new(1, 0, 0, 40),
		Text = Strings.get("duels.nobody"),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 190, 210),
		Parent = list,
	})

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player then
				count += 1
				local row = Ui.make("Frame", {
					Name = other.DisplayName,
					Size = UDim2.new(1, 0, 0, 46),
					BackgroundColor3 = Color3.fromRGB(55, 30, 50),
					Parent = list,
				}, { Ui.corner(0.2) })
				Ui.label({
					Size = UDim2.fromScale(0.6, 0.8),
					Position = UDim2.fromScale(0.03, 0.1),
					Text = `{other.DisplayName}  ·  {other:GetAttribute("DuelWins") or 0}W`,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				local fight = Ui.button({
					Size = UDim2.fromScale(0.33, 0.76),
					Position = UDim2.fromScale(0.65, 0.12),
					Text = Strings.get("duels.challenge"),
					BackgroundColor3 = RED,
					Parent = row,
				})
				fight.Activated:Connect(function()
					DuelGame.invite(other.UserId, duration)
				end)
			end
		end
		empty.Visible = count == 0
		winsLabel.Text = Strings.get("duels.wins", { n = player:GetAttribute("DuelWins") or 0 })
	end

	local go = Ui.button({
		Size = UDim2.fromScale(0.55, 0.09),
		Position = UDim2.fromScale(0.05, 0.86),
		Text = Strings.get("duels.go"),
		BackgroundColor3 = Color3.fromRGB(150, 60, 200),
		Parent = panel,
	})
	local close = Ui.button({
		Size = UDim2.fromScale(0.33, 0.09),
		Position = UDim2.fromScale(0.62, 0.86),
		Text = Strings.get("common.close"),
		BackgroundColor3 = Ui.Colors.Muted,
		Parent = panel,
	})

	local function setOpen(open: boolean)
		panel.Visible = open
		if open then
			refresh()
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end

	go.Activated:Connect(function()
		setOpen(false)
		local target = workspace:GetAttribute("ArenaSpawn")
		local character = player.Character
		if typeof(target) == "Vector3" and character then
			character:PivotTo(CFrame.new(target))
		end
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if panel.Visible then
				refresh()
			end
		end)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return function()
		setOpen(not panel.Visible)
	end
end

return Duels
