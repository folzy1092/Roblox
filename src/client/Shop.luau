-- Shop panel: buy items for Glow, equip owned ones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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

function Shop.init(): () -> ()
	local gui = Ui.screen("Shop", 5)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.45, 0.6),
		BackgroundColor3 = Ui.Colors.Panel,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(0.05), Ui.make("UISizeConstraint", { MinSize = Vector2.new(320, 260) }) })
	Ui.label({
		Size = UDim2.fromScale(0.6, 0.12),
		Position = UDim2.fromScale(0.05, 0.03),
		Text = Strings.get("shop.title"),
		TextColor3 = Ui.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local close = Ui.button({
		Size = UDim2.fromScale(0.25, 0.1),
		Position = UDim2.fromScale(0.7, 0.04),
		Text = Strings.get("common.close"),
		BackgroundColor3 = Ui.Colors.Muted,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromScale(0.05, 0.18),
		Size = UDim2.fromScale(0.9, 0.78),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local ids = {}
	for id in Config.Items do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Items[a].order < Config.Items[b].order
	end)

	local rows = {}
	for _, id in ids do
		local item = Config.Items[id]
		local row = Ui.make("Frame", {
			LayoutOrder = item.order,
			Size = UDim2.new(1, -10, 0, 64),
			BackgroundColor3 = Color3.fromRGB(45, 42, 62),
			Parent = list,
		}, { Ui.corner(0.15) })
		Ui.label({
			Size = UDim2.fromScale(0.5, 0.5),
			Position = UDim2.fromScale(0.04, 0.05),
			Text = Strings.get("item." .. id),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.label({
			Size = UDim2.fromScale(0.5, 0.35),
			Position = UDim2.fromScale(0.04, 0.58),
			Text = Strings.get("shop.power", { power = item.power }),
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(200, 200, 220),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local button = Ui.button({
			Size = UDim2.fromScale(0.4, 0.7),
			Position = UDim2.fromScale(0.57, 0.15),
			Parent = row,
		})
		button.Activated:Connect(function()
			if owned()[id] then
				remotes.Equip:FireServer(id)
			else
				remotes.Buy:FireServer(id)
			end
		end)
		rows[id] = button
	end

	local function update()
		local have = owned()
		local glow = player:GetAttribute("Glow") or 0
		local equipped = player:GetAttribute("Equipped")
		for id, button in rows do
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

	gui.Parent = player:WaitForChild("PlayerGui")
	return function()
		panel.Visible = not panel.Visible
	end
end

return Shop
