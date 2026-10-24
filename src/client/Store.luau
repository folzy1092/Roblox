-- VIP / store panel: gamepasses for Robux.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Store = {}

-- Prompt a developer product. In Studio, products without an id are granted through the
-- Studio-only DEV remote so they can be tested before they exist on the website.
function Store.buyProduct(key: string)
	local id = Config.DevProducts[key]
	if id and id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif RunService:IsStudio() then
		remotes.Dev:FireServer("product", key)
	end
end

local GOLD = Color3.fromRGB(255, 195, 50)

function Store.init(): () -> ()
	local gui = Ui.screen("Store", 5)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(0.05),
		Ui.make("UIStroke", { Color = GOLD, Thickness = 3 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(330, 260) }),
		Ui.make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(90, 60, 20), Color3.fromRGB(30, 22, 40)),
			Rotation = 90,
		}),
	})
	local scale = Ui.make("UIScale", { Parent = panel })

	Ui.label({
		Size = UDim2.fromScale(0.7, 0.12),
		Position = UDim2.fromScale(0.05, 0.04),
		Text = Strings.get("store.title"),
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local close = Ui.button({
		Size = UDim2.fromScale(0.1, 0.1),
		Position = UDim2.fromScale(0.86, 0.04),
		Text = "X",
		BackgroundColor3 = Color3.fromRGB(220, 70, 90),
		Parent = panel,
	})
	Ui.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = close })

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromScale(0.05, 0.2),
		Size = UDim2.fromScale(0.9, 0.76),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local rows = {}
	for _, item in Config.StoreItems do
		local key = item.pass or item.product
		local row = Ui.make("Frame", {
			LayoutOrder = item.order,
			Size = UDim2.new(1, -10, 0, 76),
			BackgroundColor3 = if item.product then Color3.fromRGB(38, 46, 66) else Color3.fromRGB(45, 38, 60),
			Parent = list,
		}, { Ui.corner(0.12), Ui.make("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.5 }) })
		local prefix = if item.pass then "pass." else "product."
		Ui.label({
			Size = UDim2.fromScale(0.6, 0.38),
			Position = UDim2.fromScale(0.04, 0.1),
			Text = Strings.get(prefix .. key),
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.label({
			Size = UDim2.fromScale(0.6, 0.36),
			Position = UDim2.fromScale(0.04, 0.54),
			Text = Strings.get(prefix .. key .. ".desc"),
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(225, 220, 235),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local button = Ui.button({
			Size = UDim2.fromScale(0.3, 0.5),
			Position = UDim2.fromScale(0.67, 0.25),
			BackgroundColor3 = Ui.Colors.Good,
			Parent = row,
		})
		button.Activated:Connect(function()
			if item.product then
				Store.buyProduct(item.product)
				return
			end
			local id = Config.GamePasses[item.pass]
			if id ~= 0 and player:GetAttribute("Pass_" .. item.pass) ~= true then
				MarketplaceService:PromptGamePassPurchase(player, id)
			end
		end)
		rows[key] = { button = button, price = item.price, pass = item.pass, product = item.product }
	end

	local function update()
		for _, row in rows do
			local id = if row.pass then Config.GamePasses[row.pass] else Config.DevProducts[row.product]
			if row.pass and player:GetAttribute("Pass_" .. row.pass) == true then
				row.button.Text = Strings.get("store.owned")
				row.button.BackgroundColor3 = Ui.Colors.Muted
			elseif id == 0 and not (row.product and RunService:IsStudio()) then
				row.button.Text = Strings.get("store.soon")
				row.button.BackgroundColor3 = Ui.Colors.Muted
			else
				row.button.Text = Strings.get("store.buy", { price = row.price })
				row.button.BackgroundColor3 = Ui.Colors.Good
			end
		end
	end
	for _, row in rows do
		if row.pass then
			player:GetAttributeChangedSignal("Pass_" .. row.pass):Connect(update)
		end
	end
	update()

	local function setOpen(open: boolean)
		panel.Visible = open
		if open then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return function()
		setOpen(not panel.Visible)
	end
end

return Store
