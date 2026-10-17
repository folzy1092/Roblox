-- Bottom HUD: tier, rating bar, Glow, Shop and Rebirth buttons, save warning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Hud = {}

local function attr(name: string, default: any): any
	local value = player:GetAttribute(name)
	return if value == nil then default else value
end

function Hud.rebirthReady(): boolean
	local rebirths = attr("Rebirths", 0)
	return rebirths < Config.MaxRebirths and attr("Rating", 0) >= Progression.capRating(rebirths)
end

-- Shows a yes/no dialog for rebirth. Exposed so the start menu can reuse it.
function Hud.confirmRebirth(gui: ScreenGui)
	local nextTier = Config.Tiers[attr("Rebirths", 0) + 2]
	local overlay = Ui.make("Frame", {
		Name = "Confirm",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 20,
		Parent = gui,
	})
	local box = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.3),
		BackgroundColor3 = Ui.Colors.Panel,
		ZIndex = 21,
		Parent = overlay,
	}, { Ui.corner(0.08), Ui.make("UIAspectRatioConstraint", { AspectRatio = 2 }) })
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.5),
		Position = UDim2.fromScale(0.05, 0.08),
		Text = Strings.get("rebirth.confirm", { tier = if nextTier then nextTier.name else "" }),
		ZIndex = 22,
		Parent = box,
	})
	local yes = Ui.button({
		Size = UDim2.fromScale(0.4, 0.25),
		Position = UDim2.fromScale(0.06, 0.66),
		Text = Strings.get("common.yes"),
		ZIndex = 22,
		Parent = box,
	})
	local no = Ui.button({
		Size = UDim2.fromScale(0.4, 0.25),
		Position = UDim2.fromScale(0.54, 0.66),
		Text = Strings.get("common.no"),
		BackgroundColor3 = Ui.Colors.Muted,
		ZIndex = 22,
		Parent = box,
	})
	yes.Activated:Connect(function()
		remotes.Rebirth:FireServer()
		overlay:Destroy()
	end)
	no.Activated:Connect(function()
		overlay:Destroy()
	end)
end

function Hud.init(onShop: () -> ()): ScreenGui
	local gui = Ui.screen("Hud", 1)

	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(0.42, 0.12),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { Ui.corner(0.2), Ui.make("UISizeConstraint", { MinSize = Vector2.new(300, 70) }) })

	local tierLabel = Ui.label({
		Size = UDim2.fromScale(0.3, 0.45),
		Position = UDim2.fromScale(0.03, 0.06),
		TextColor3 = Ui.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local glowLabel = Ui.label({
		Size = UDim2.fromScale(0.4, 0.4),
		Position = UDim2.fromScale(0.57, 0.08),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	local bar = Ui.make("Frame", {
		Size = UDim2.fromScale(0.94, 0.3),
		Position = UDim2.fromScale(0.03, 0.6),
		BackgroundColor3 = Color3.fromRGB(15, 14, 22),
		Parent = panel,
	}, { Ui.corner(0.5) })
	local fill = Ui.make("Frame", {
		BackgroundColor3 = Ui.Colors.Accent,
		Parent = bar,
	}, { Ui.corner(0.5) })
	local ratingLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
		Parent = bar,
	})

	local shopButton = Ui.button({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.015, 0.5),
		Size = UDim2.fromScale(0.11, 0.07),
		Text = Strings.get("hud.shop"),
		BackgroundColor3 = Color3.fromRGB(120, 110, 255),
		Parent = gui,
	}, nil)
	Ui.make("UISizeConstraint", { MinSize = Vector2.new(90, 40), Parent = shopButton })
	shopButton.Activated:Connect(onShop)

	local rebirthButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.985, 0.5),
		Size = UDim2.fromScale(0.16, 0.08),
		Text = Strings.get("hud.rebirth_ready"),
		BackgroundColor3 = Ui.Colors.Accent,
		TextColor3 = Color3.fromRGB(40, 30, 0),
		Visible = false,
		Parent = gui,
	})
	Ui.make("UISizeConstraint", { MinSize = Vector2.new(120, 44), Parent = rebirthButton })
	rebirthButton.Activated:Connect(function()
		Hud.confirmRebirth(gui)
	end)

	local banner = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.5, 0.04),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(170, 50, 50),
		Text = Strings.get("data.not_saved"),
		Visible = false,
		Parent = gui,
	})

	local function update()
		local rating = attr("Rating", 0)
		local rebirths = attr("Rebirths", 0)
		local cap = Progression.capRating(rebirths)
		local tier = Progression.tierIndex(rating)
		tierLabel.Text = Config.Tiers[tier].name
		glowLabel.Text = Strings.get("hud.glow", { n = Strings.num(attr("Glow", 0)) })
		ratingLabel.Text = Strings.get("hud.rating", { n = Strings.num(rating), cap = Strings.num(cap) })
		fill.Size = UDim2.fromScale(math.clamp(rating / cap, 0, 1), 1)
		rebirthButton.Visible = Hud.rebirthReady()
		banner.Visible = player:GetAttribute("DataLoaded") == false
	end
	for _, name in { "Rating", "Glow", "Rebirths", "DataLoaded" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

return Hud
