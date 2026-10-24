-- Shop panel: colorful rarity cards; buy items for Glow, equip owned ones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Shop = {}

local function owned(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("Items") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

local function gradient(parent: Instance, from: Color3, to: Color3, rotation: number)
	Ui.make("UIGradient", {
		Color = ColorSequence.new(from, to),
		Rotation = rotation,
		Parent = parent,
	})
end

local function card(list: Instance, id: string, item: any): TextButton
	local color = Ui.Rarity[item.rarity] or Ui.Colors.Good
	local frame = Ui.make("Frame", {
		LayoutOrder = item.order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = list,
	}, {
		Ui.corner(0.1),
		Ui.make("UIStroke", { Color = color, Thickness = 3 }),
	})
	gradient(frame, color:Lerp(Color3.new(0, 0, 0), 0.35), Color3.fromRGB(30, 26, 45), 90)

	Ui.label({
		Size = UDim2.fromScale(1, 0.12),
		Position = UDim2.fromScale(0, 0.04),
		Text = Strings.get("rarity." .. item.rarity),
		Font = Enum.Font.GothamBold,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4),
		Parent = frame,
	})
	local orb = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.fromScale(0.5, 0.27),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, {
		Ui.make("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Ui.corner(0.5),
		Ui.make("UIGradient", {
			Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5), color:Lerp(Color3.new(0, 0, 0), 0.3)),
			Rotation = 60,
		}),
		Ui.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.5 }),
	})
	-- 3D preview of the item, slowly turning
	local view = Ui.make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = orb,
	})
	local model = Instance.new("Model")
	ItemModels.build(id, model)
	model.Parent = view
	local cframe, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	local distance = size.Magnitude * 1.9
	task.spawn(function()
		local spin = 0
		while view.Parent do
			spin += 0.03
			local eye = cframe.Position + Vector3.new(math.sin(spin), 0.35, math.cos(spin)) * distance
			camera.CFrame = CFrame.lookAt(eye, cframe.Position)
			task.wait(1 / 30)
		end
	end)
	Ui.label({
		Size = UDim2.fromScale(0.92, 0.14),
		Position = UDim2.fromScale(0.04, 0.47),
		Text = Strings.get("item." .. id),
		Parent = frame,
	})
	Ui.label({
		Size = UDim2.fromScale(0.92, 0.1),
		Position = UDim2.fromScale(0.04, 0.62),
		Text = Strings.get("shop.power", { power = item.power }),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(220, 220, 235),
		Parent = frame,
	})
	return Ui.button({
		Size = UDim2.fromScale(0.86, 0.17),
		Position = UDim2.fromScale(0.07, 0.78),
		Parent = frame,
	})
end

function Shop.init(): () -> ()
	local gui = Ui.screen("Shop", 5)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.7),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(0.04),
		Ui.make("UIStroke", { Color = Color3.fromRGB(255, 205, 70), Thickness = 3 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(340, 280) }),
	})
	gradient(panel, Color3.fromRGB(60, 40, 110), Color3.fromRGB(25, 20, 40), 90)
	local scale = Ui.make("UIScale", { Scale = 1, Parent = panel })

	local header = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 0.14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	}, { Ui.corner(0.3) })
	gradient(header, Color3.fromRGB(255, 120, 190), Color3.fromRGB(120, 110, 255), 0)
	Ui.label({
		Size = UDim2.fromScale(0.4, 0.7),
		Position = UDim2.fromScale(0.03, 0.15),
		Text = Strings.get("shop.title"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local balance = Ui.label({
		Size = UDim2.fromScale(0.3, 0.55),
		Position = UDim2.fromScale(0.43, 0.22),
		TextColor3 = Color3.fromRGB(255, 240, 150),
		Parent = header,
	})
	local close = Ui.button({
		Size = UDim2.fromScale(0.08, 0.7),
		Position = UDim2.fromScale(0.9, 0.15),
		Text = "✕",
		BackgroundColor3 = Color3.fromRGB(220, 70, 90),
		Parent = header,
	})
	Ui.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = close })

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromScale(0.03, 0.18),
		Size = UDim2.fromScale(0.94, 0.79),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.make("UIGridLayout", {
			CellSize = UDim2.fromScale(0.23, 0.9),
			CellPadding = UDim2.fromScale(0.02, 0.04),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4) }),
	})

	local ids = {}
	for id in Config.Items do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Items[a].order < Config.Items[b].order
	end)

	local buttons = {}
	for _, id in ids do
		local button = card(list, id, Config.Items[id])
		button.Activated:Connect(function()
			if owned()[id] then
				remotes.Equip:FireServer(id)
			else
				remotes.Buy:FireServer(id)
			end
		end)
		buttons[id] = button
	end

	local function update()
		local have = owned()
		local glow = player:GetAttribute("Glow") or 0
		local equipped = player:GetAttribute("Equipped")
		balance.Text = Strings.get("hud.glow", { n = Strings.num(glow) })
		for id, button in buttons do
			local item = Config.Items[id]
			if equipped == id and have[id] then
				button.Text = Strings.get("shop.equipped")
				button.BackgroundColor3 = Ui.Colors.Muted
			elseif have[id] then
				button.Text = Strings.get("shop.equip")
				button.BackgroundColor3 = Ui.Colors.Good
			else
				button.Text = Strings.get("shop.buy", { price = Strings.num(item.price) })
				button.BackgroundColor3 = if glow >= item.price then Ui.Colors.Accent else Ui.Colors.Muted
			end
		end
	end
	for _, name in { "Items", "Glow", "Equipped" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()

	local function setOpen(open: boolean)
		if open then
			panel.Visible = true
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		else
			panel.Visible = false
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

return Shop
