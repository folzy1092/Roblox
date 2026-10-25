-- Start menu: big PLAY button + daily login bonus (7-day streak, claimed on the server).
-- Duels and rebirth live on the in-game buttons; a newcomer just wants to start playing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Daily") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 200, 60)
local CLAIMED = Color3.fromRGB(70, 190, 120)
local FUTURE = Color3.fromRGB(45, 40, 65)

local Menu = {}

-- short tile text for one reward item: "x2 10m", "VIP 15m", "Auto 30m"
local function short(id: string): string
	local item = Config.RewardItems[id]
	return Strings.get("reward.short." .. item.effect) .. " " .. item.minutes .. "m"
end

function Menu.show()
	local old = player.PlayerGui:FindFirstChild("StartMenu")
	if old then
		old:Destroy()
	end
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
		Position = UDim2.fromScale(0.5, 0.07),
		Size = UDim2.fromScale(0.7, 0.1),
		Text = Strings.get("menu.title"),
		TextColor3 = Ui.Colors.Accent,
		Parent = root,
	})

	-- daily bonus panel
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.78, 0.42),
		BackgroundColor3 = Color3.fromRGB(28, 24, 44),
		Parent = root,
	}, {
		Ui.corner(0.08),
		Ui.make("UIStroke", { Color = GOLD, Thickness = 3, Transparency = 0.3 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(330, 190) }),
	})
	Ui.label({
		Position = UDim2.fromScale(0.04, 0.05),
		Size = UDim2.fromScale(0.92, 0.16),
		Text = Strings.get("daily.title"),
		TextColor3 = GOLD,
		Parent = panel,
	})
	Ui.label({
		Position = UDim2.fromScale(0.04, 0.21),
		Size = UDim2.fromScale(0.92, 0.09),
		Text = Strings.get("daily.hint"),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(215, 210, 230),
		Parent = panel,
	})
	local row = Ui.make("Frame", {
		Position = UDim2.fromScale(0.03, 0.34),
		Size = UDim2.fromScale(0.94, 0.38),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.012, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tiles = {}
	for day = 1, #Config.DailyRewards do
		local items = Config.DailyRewards[day]
		local last = day == #Config.DailyRewards
		local tile = Ui.make("Frame", {
			LayoutOrder = day,
			Size = UDim2.fromScale(0.13, 1),
			BackgroundColor3 = FUTURE,
			Parent = row,
		}, { Ui.corner(0.15), Ui.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 1 }) })
		Ui.label({
			Size = UDim2.fromScale(0.9, 0.28),
			Position = UDim2.fromScale(0.05, 0.06),
			Text = Strings.get("daily.day", { n = tostring(day) }),
			Font = Enum.Font.GothamBold,
			Parent = tile,
		})
		Ui.label({
			Size = UDim2.fromScale(0.9, 0.36),
			Position = UDim2.fromScale(0.05, 0.36),
			Text = if last then Strings.get("daily.mega") else short(items[1]),
			TextColor3 = if last then GOLD else Inventory.color(items[1]),
			Parent = tile,
		})
		Ui.label({
			Name = "Extra",
			Size = UDim2.fromScale(0.9, 0.22),
			Position = UDim2.fromScale(0.05, 0.74),
			Text = if last then "x2+VIP+Auto" else "",
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(200, 195, 215),
			Parent = tile,
		})
		tiles[day] = tile
	end

	local claim = Ui.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromScale(0.42, 0.16),
		Text = Strings.get("daily.claim"),
		BackgroundColor3 = GOLD,
		Parent = panel,
	})
	local pulse: Tween? = nil

	local function refresh()
		local nextDay = player:GetAttribute("DailyNext") or 1
		local ready = player:GetAttribute("DailyReady") == true
		for day, tile in tiles do
			local claimed = day < nextDay or (day == nextDay and not ready)
			local today = day == nextDay and ready
			tile.BackgroundColor3 = if claimed then CLAIMED elseif today then Color3.fromRGB(120, 70, 200) else FUTURE
			tile:FindFirstChildOfClass("UIStroke").Transparency = if today then 0 else 1
			if claimed then
				tile:FindFirstChild("Extra").Text = "✓"
			end
		end
		claim.Text = if ready then Strings.get("daily.claim") else Strings.get("daily.claimed")
		claim.BackgroundColor3 = if ready then GOLD else Ui.Colors.Muted
		claim.AutoButtonColor = ready
		if pulse then
			pulse:Cancel()
			pulse = nil
		end
		local scale = claim:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", { Parent = claim })
		scale.Scale = 1
		if ready then
			pulse = TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 })
			pulse:Play()
		end
	end
	refresh()
	local conns = {
		player:GetAttributeChangedSignal("DailyReady"):Connect(refresh),
		player:GetAttributeChangedSignal("DailyNext"):Connect(refresh),
		remote.OnClientEvent:Connect(function(day: number)
			claim.Text = Strings.get("daily.added")
			local tile = tiles[day]
			if tile then
				tile.Size = UDim2.fromScale(0.16, 1.15)
				TweenService:Create(tile, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.13, 1) }):Play()
			end
		end),
	}
	claim.Activated:Connect(function()
		if player:GetAttribute("DailyReady") == true then
			remote:FireServer()
		end
	end)

	local play = Ui.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.fromScale(0.34, 0.12),
		Text = Strings.get("menu.play"),
		BackgroundColor3 = Ui.Colors.Good,
		Parent = root,
	})
	Ui.make("UISizeConstraint", { MinSize = Vector2.new(200, 56), Parent = play })
	play.Activated:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
		gui:Destroy()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Menu
