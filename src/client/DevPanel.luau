-- Temporary test panel, Studio only: jump to any tier to preview the face, add Glow, reset.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local DevPanel = {}

function DevPanel.init()
	if not RunService:IsStudio() then
		return
	end
	local gui = Ui.screen("DevPanel", 20)

	local list = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 60),
		Size = UDim2.fromOffset(150, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(0.06),
		Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Ui.make("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	})

	local function button(order: number, text: string, color: Color3, onClick: () -> ())
		local b = Ui.button({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 28),
			Text = text,
			BackgroundColor3 = color,
			Parent = list,
		})
		b.Activated:Connect(onClick)
	end

	for i, tier in Config.Tiers do
		button(i, tier.name, Color3.fromRGB(70, 90, 160), function()
			remotes.Dev:FireServer("tier", i)
		end)
	end
	button(20, "MAX", Color3.fromRGB(200, 150, 40), function()
		remotes.Dev:FireServer("max")
	end)
	button(21, "+50K Glow", Color3.fromRGB(80, 160, 90), function()
		remotes.Dev:FireServer("glow")
	end)
	button(22, "Reset", Color3.fromRGB(170, 60, 70), function()
		remotes.Dev:FireServer("reset")
	end)

	local toggle = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 20),
		Size = UDim2.fromOffset(70, 32),
		Text = "DEV",
		BackgroundColor3 = Color3.fromRGB(230, 70, 160),
		Parent = gui,
	})
	toggle.Activated:Connect(function()
		list.Visible = not list.Visible
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return DevPanel
