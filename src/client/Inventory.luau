-- Inventory: timed boosts from the daily bonus (x2, VIP trainers, auto-click). The player
-- switches one on when they want; the server starts the timer (Remotes.Inventory "use").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory") :: RemoteEvent

local EFFECT_COLORS = {
	x2 = Color3.fromRGB(255, 170, 40),
	vip = Color3.fromRGB(255, 215, 80),
	auto = Color3.fromRGB(90, 200, 255),
}

local Inventory = {}

-- "x2_10:2,vip_15:1" -> { x2_10 = 2, vip_15 = 1 }
function Inventory.counts(): { [string]: number }
	local out = {}
	for pair in string.gmatch(player:GetAttribute("Inventory") or "", "[^,]+") do
		local id, n = string.match(pair, "^(.-):(%d+)$")
		if id then
			out[id] = tonumber(n)
		end
	end
	return out
end

-- "x2 rating & Glow · 10 min" style name of a reward item
function Inventory.itemName(id: string): string
	local item = Config.RewardItems[id]
	return Strings.get("reward." .. item.effect) .. " · " .. Strings.get("reward.min", { n = tostring(item.minutes) })
end

function Inventory.color(id: string): Color3
	return EFFECT_COLORS[Config.RewardItems[id].effect]
end

function Inventory.init(): () -> ()
	local gui = Ui.screen("Inventory", 5)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.6),
		BackgroundColor3 = Color3.fromRGB(28, 24, 44),
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(0.05),
		Ui.make("UIStroke", { Color = Color3.fromRGB(120, 230, 255), Thickness = 3 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(320, 300) }),
	})
	local scale = Ui.make("UIScale", { Parent = panel })
	Ui.label({
		Position = UDim2.fromScale(0.05, 0.03),
		Size = UDim2.fromScale(0.9, 0.1),
		Text = Strings.get("inv.title"),
		TextColor3 = Color3.fromRGB(120, 230, 255),
		Parent = panel,
	})
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromScale(0.05, 0.15),
		Size = UDim2.fromScale(0.9, 0.68),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local empty = Ui.label({
		Position = UDim2.fromScale(0.05, 0.35),
		Size = UDim2.fromScale(0.9, 0.2),
		Text = Strings.get("inv.empty"),
		TextWrapped = true,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(210, 205, 225),
		Parent = panel,
	})
	local close = Ui.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(0.4, 0.1),
		Text = Strings.get("common.close"),
		BackgroundColor3 = Ui.Colors.Muted,
		Parent = panel,
	})

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local counts = Inventory.counts()
		local any = false
		for id, count in counts do
			local item = Config.RewardItems[id]
			if item and count > 0 then
				any = true
				local row = Ui.make("Frame", {
					LayoutOrder = item.order,
					Size = UDim2.new(1, -8, 0, 52),
					BackgroundColor3 = Color3.fromRGB(45, 38, 68),
					Parent = list,
				}, { Ui.corner(0.2), Ui.make("UIStroke", { Color = Inventory.color(id), Thickness = 2 }) })
				Ui.label({
					Position = UDim2.fromScale(0.03, 0.1),
					Size = UDim2.fromScale(0.58, 0.8),
					Text = Inventory.itemName(id),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Inventory.color(id),
					Parent = row,
				})
				Ui.label({
					Position = UDim2.fromScale(0.6, 0.1),
					Size = UDim2.fromScale(0.1, 0.8),
					Text = "x" .. tostring(count),
					Parent = row,
				})
				local use = Ui.button({
					Position = UDim2.fromScale(0.72, 0.14),
					Size = UDim2.fromScale(0.26, 0.72),
					Text = Strings.get("inv.use"),
					Parent = row,
				})
				use.Activated:Connect(function()
					remote:FireServer("use", id)
				end)
			end
		end
		empty.Visible = not any
	end

	local function setOpen(open: boolean)
		panel.Visible = open
		if open then
			refresh()
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)
	player:GetAttributeChangedSignal("Inventory"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return function()
		setOpen(not panel.Visible)
	end
end

return Inventory
