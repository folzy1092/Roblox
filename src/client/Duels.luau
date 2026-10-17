-- Duels panel: explains duels and teleports to the arena. Matches come in the next stage.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Duels = {}

function Duels.init(): () -> ()
	local gui = Ui.screen("Duels", 5)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(0.06),
		Ui.make("UIStroke", { Color = Color3.fromRGB(255, 90, 90), Thickness = 3 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(320, 240) }),
		Ui.make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(120, 30, 50), Color3.fromRGB(30, 20, 40)),
			Rotation = 90,
		}),
	})
	local scale = Ui.make("UIScale", { Parent = panel })

	Ui.label({
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.05),
		Text = "⚔️ " .. Strings.get("duels.title"),
		TextColor3 = Color3.fromRGB(255, 200, 200),
		Parent = panel,
	})
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.36),
		Position = UDim2.fromScale(0.05, 0.24),
		Text = Strings.get("duels.info"),
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Parent = panel,
	})
	local go = Ui.button({
		Size = UDim2.fromScale(0.55, 0.16),
		Position = UDim2.fromScale(0.06, 0.74),
		Text = Strings.get("duels.go"),
		BackgroundColor3 = Color3.fromRGB(230, 70, 80),
		Parent = panel,
	})
	local close = Ui.button({
		Size = UDim2.fromScale(0.3, 0.16),
		Position = UDim2.fromScale(0.65, 0.74),
		Text = Strings.get("common.close"),
		BackgroundColor3 = Ui.Colors.Muted,
		Parent = panel,
	})

	local function setOpen(open: boolean)
		panel.Visible = open
		if open then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end

	go.Activated:Connect(function()
		setOpen(false)
		local arena = workspace:FindFirstChild("DuelArena")
		local spawnPart = arena and arena:FindFirstChild("ArenaSpawn")
		local character = player.Character
		if spawnPart and character then
			character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
		end
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return function()
		setOpen(not panel.Visible)
	end
end

return Duels
