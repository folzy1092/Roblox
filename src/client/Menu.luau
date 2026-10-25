-- Start menu: three cards (Start / Duels / Rebirth).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Menu = {}

local function card(parent: Instance, order: number, color: Color3, title: string, hint: string, enabled: boolean)
	local button = Ui.make("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromScale(0.28, 0.8),
		BackgroundColor3 = if enabled then color else Ui.Colors.Muted,
		AutoButtonColor = enabled,
		Text = "",
		Parent = parent,
	}, { Ui.corner(0.08), Ui.make("UIAspectRatioConstraint", { AspectRatio = 0.75 }) })
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.3),
		Position = UDim2.fromScale(0.05, 0.3),
		Text = title,
		Parent = button,
	})
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.62),
		Text = hint,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(235, 235, 245),
		Parent = button,
	})
	return button
end

function Menu.show(hudGui: ScreenGui, openDuels: (() -> ())?)
	local gui = Ui.screen("StartMenu", 10)
	local root = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 10, 20),
		BackgroundTransparency = 0.15,
		Active = true,
		Parent = gui,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.7, 0.1),
		Text = Strings.get("menu.title"),
		TextColor3 = Ui.Colors.Accent,
		Parent = root,
	})
	local row = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.9, 0.62),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local rebirths = player:GetAttribute("Rebirths") or 0
	local from = Config.Tiers[math.min(rebirths + 1, #Config.Tiers)].name
	local nextTier = Config.Tiers[rebirths + 2]
	local to = if nextTier then nextTier.name else from

	local start = card(row, 1, Ui.Colors.Good, Strings.get("menu.start"), Strings.get("menu.start_hint"), true)
	local duels = card(row, 2, Color3.fromRGB(220, 60, 90), Strings.get("menu.duels"), Strings.get("menu.duels_hint"), true)
	duels.Activated:Connect(function()
		gui:Destroy()
		if openDuels then
			openDuels()
		end
	end)
	local rebirth = card(
		row,
		3,
		Color3.fromRGB(200, 140, 30),
		Strings.get("menu.rebirth"),
		Strings.get("menu.rebirth_info", { from = from, to = to }),
		true
	)

	start.Activated:Connect(function()
		gui:Destroy()
	end)
	rebirth.Activated:Connect(function()
		gui:Destroy()
		if Hud.rebirthReady() then
			Hud.confirmRebirth(hudGui)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Menu
