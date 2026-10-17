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
		Active = true,
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

function Hud.init(actions: { [string]: () -> () }): ScreenGui
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

	-- left side bar: Shop / Duels / Menu
	local side = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.012, 0.5),
		Size = UDim2.fromScale(0.12, 0.4),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.make("UIListLayout", { Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(110, 200) }),
	})
	for order, entry in {
		{ "hud.shop", Color3.fromRGB(255, 120, 190), Color3.fromRGB(140, 90, 255), "shop" },
		{ "hud.duels", Color3.fromRGB(255, 90, 80), Color3.fromRGB(170, 30, 70), "duels" },
		{ "hud.vip", Color3.fromRGB(255, 220, 90), Color3.fromRGB(230, 140, 20), "store" },
		{ "hud.menu", Color3.fromRGB(90, 200, 255), Color3.fromRGB(60, 90, 200), "menu" },
	} do
		-- gradient lives on the button background only; text is a child label so it stays white
		local button = Ui.make("TextButton", {
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0.22),
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = side,
		}, {
			Ui.corner(0.25),
			Ui.make("UIGradient", { Color = ColorSequence.new(entry[2], entry[3]), Rotation = 90 }),
			Ui.make("UIStroke", {
				Color = Color3.new(1, 1, 1),
				Thickness = 2,
				Transparency = 0.4,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.6),
			Text = Strings.get(entry[1]),
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = button,
		}, nil)
		Ui.make("UIStroke", {
			Color = entry[3]:Lerp(Color3.new(0, 0, 0), 0.5),
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = button:FindFirstChildOfClass("TextLabel"),
		})
		local action = entry[4]
		button.Activated:Connect(function()
			local fn = actions[action]
			if fn then
				fn()
			end
		end)
	end

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

	-- seat countdown: time left in the current training set
	local setTimer = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.11),
		Size = UDim2.fromScale(0.3, 0.06),
		BackgroundColor3 = Color3.fromRGB(28, 26, 40),
		BackgroundTransparency = 0.2,
		TextColor3 = Ui.Colors.Accent,
		Visible = false,
		Parent = gui,
	})
	Ui.corner(0.3).Parent = setTimer
	Ui.make("UISizeConstraint", { MinSize = Vector2.new(180, 36), Parent = setTimer })
	task.spawn(function()
		while true do
			local endsAt = player:GetAttribute("SeatEndsAt")
			local coolUntil = player:GetAttribute("SeatCooldownUntil")
			local coolLeft = if typeof(coolUntil) == "number" then math.ceil(coolUntil - workspace:GetServerTimeNow()) else 0
			if typeof(endsAt) ~= "number" and coolLeft > 0 then
				setTimer.Text = Strings.get("hud.sit_cooldown", { n = coolLeft })
				setTimer.TextColor3 = Color3.fromRGB(200, 200, 220)
				setTimer.Visible = true
			elseif typeof(endsAt) == "number" then
				local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
				setTimer.Text = Strings.get("hud.set_timer", { t = string.format("%d:%02d", left // 60, left % 60) })
				setTimer.TextColor3 = if left <= 10 then Color3.fromRGB(255, 110, 110) else Ui.Colors.Accent
				setTimer.Visible = true
			else
				setTimer.Visible = false
			end
			task.wait(0.25)
		end
	end)

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
