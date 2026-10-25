-- Duel client: invite popup, 3-2-1 countdown, then a speed race of face workouts on your OWN
-- avatar face (camera on the face, Workout.setDuel drives Bone Tapper / Gua Sha / chew on it),
-- live tug-of-war score bar, combo pops, hit/miss flashes, results screen with confetti.
-- Talks to server/Duels through the "Duel" RemoteEvent; the server owns the real score.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local DuelRules = require(ReplicatedStorage.Shared.DuelRules)
local Strings = require(script.Parent.Strings)
local Ui = require(script.Parent.Ui)
local Workout = require(script.Parent.Workout)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Duel") :: RemoteEvent

local BLUE = Color3.fromRGB(70, 160, 255)
local RED = Color3.fromRGB(255, 75, 95)
local GOLD = Color3.fromRGB(255, 210, 70)
local GREEN = Color3.fromRGB(90, 230, 130)
local KIND_COLORS = { tap = RED, stroke = Color3.fromRGB(200, 130, 255), chew = Color3.fromRGB(255, 120, 200) }

local DuelGame = {}

local gui: ScreenGui
local toastLabel: TextLabel
local root: Frame -- full-screen duel overlay
local myBar: Frame
local myScoreLabel: TextLabel
local theirScoreLabel: TextLabel
local timerLabel: TextLabel
local comboLabel: TextLabel
local bannerLabel: TextLabel
local flash: Frame
local shake: UIScale

local active = false
local schedule: { DuelRules.Segment } = {}
local startAt = 0 -- server time when exercises begin
local duration = 0
local currentKind: string? = nil
local localScore = DuelRules.newScore()
local serverMine, serverTheirs = 0, 0
local heartbeat: RBXScriptConnection? = nil

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function toast(text: string, color: Color3?)
	toastLabel.Text = text
	toastLabel.TextColor3 = color or Color3.new(1, 1, 1)
	toastLabel.Visible = true
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.2
	task.delay(2.5, function()
		if toastLabel.Text == text then
			tween(toastLabel, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
		end
	end)
end

local function circle(parent: Instance, props: { [string]: any }): Frame
	props.Parent = parent
	props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	local f = Ui.make("Frame", props, { Ui.corner(0.5), Ui.make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	return f
end

---------------------------------------------------------------- feedback

local function report(event: string)
	if not active then
		return
	end
	DuelRules.apply(localScore, event)
	remote:FireServer("event", event)
	if event == "hit" then
		comboLabel.Text = "x" .. localScore.combo
		comboLabel.TextColor3 = if localScore.combo >= 10 then GOLD else Color3.new(1, 1, 1)
		comboLabel.Size = UDim2.fromScale(0.2, 0.09)
		tween(comboLabel, 0.18, { Size = UDim2.fromScale(0.14, 0.065) }, Enum.EasingStyle.Back)
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 0.88
		tween(flash, 0.25, { BackgroundTransparency = 1 })
	else
		comboLabel.Text = "x0"
		comboLabel.TextColor3 = RED
		flash.BackgroundColor3 = RED
		flash.BackgroundTransparency = 0.7
		tween(flash, 0.35, { BackgroundTransparency = 1 })
		shake.Scale = 1.03
		tween(shake, 0.25, { Scale = 1 }, Enum.EasingStyle.Elastic)
	end
end

---------------------------------------------------------------- face workout

local function setFace(kind: string?)
	workspace.CurrentCamera:SetAttribute("DuelFace", kind ~= nil)
	Workout.setDuel(kind, report)
end

---------------------------------------------------------------- match flow

-- the side menu, Glow panel and hotbar would sit on top of your face: hidden during the race
local function setHud(visible: boolean)
	local playerGui = player:FindFirstChild("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("Hud")
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = visible
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, visible)
end

-- exercise name: below the face, so it never covers what you're working on
local function showBanner(text: string, color: Color3)
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color
	bannerLabel.Size = UDim2.fromScale(0.8, 0.09)
	bannerLabel.Position = UDim2.fromScale(-0.5, 0.8)
	bannerLabel.Visible = true
	tween(bannerLabel, 0.3, { Position = UDim2.fromScale(0.5, 0.8) }, Enum.EasingStyle.Back)
	task.delay(1.1, function()
		tween(bannerLabel, 0.25, { Position = UDim2.fromScale(1.5, 0.8) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
end

local function updateBars()
	local total = serverMine + serverTheirs
	local share = if total == 0 then 0.5 else serverMine / total
	tween(myBar, 0.3, { Size = UDim2.fromScale(math.clamp(share, 0.04, 0.96), 1) })
	myScoreLabel.Text = tostring(serverMine)
	theirScoreLabel.Text = tostring(serverTheirs)
end

local function stopLoop()
	active = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	setFace(nil)
	setHud(true)
	currentKind = nil
end

local function loop()
	local t = serverNow() - startAt
	if t < 0 then
		return
	end
	local left = math.max(0, duration - t)
	timerLabel.Text = string.format("%d:%02d", left // 60, left % 60)
	timerLabel.TextColor3 = if left <= 10 then RED else Color3.new(1, 1, 1)
	local kind = DuelRules.kindAt(schedule, t)
	if kind ~= currentKind then
		currentKind = kind
		setFace(kind)
		if kind then
			showBanner(Strings.get("duel.kind." .. kind), KIND_COLORS[kind])
		end
	end
end

local function countdown()
	for n = DuelRules.COUNTDOWN, 1, -1 do
		bannerLabel.Text = tostring(n)
		bannerLabel.TextColor3 = GOLD
		bannerLabel.Position = UDim2.fromScale(0.5, 0.42)
		bannerLabel.Size = UDim2.fromScale(0.6, 0.35)
		bannerLabel.Visible = true
		tween(bannerLabel, 0.9, { Size = UDim2.fromScale(0.3, 0.17) }, Enum.EasingStyle.Back)
		task.wait(1)
	end
	bannerLabel.Size = UDim2.fromScale(0.6, 0.17)
	bannerLabel.Text = Strings.get("duel.go")
	bannerLabel.TextColor3 = GREEN
	task.delay(0.6, function()
		if bannerLabel.Text == Strings.get("duel.go") then
			bannerLabel.Visible = false
		end
	end)
end

local onStartHooks: { () -> () } = {}
function DuelGame.onStart(fn: () -> ())
	table.insert(onStartHooks, fn)
end

local function onStart(payload: any)
	for _, fn in onStartHooks do
		fn()
	end
	schedule = DuelRules.schedule(payload.seed, payload.duration)
	startAt = payload.startAt
	duration = payload.duration
	localScore = DuelRules.newScore()
	serverMine, serverTheirs = 0, 0
	root.Visible = true
	root:FindFirstChild("OpponentName").Text = payload.opponent
	comboLabel.Text = "x0"
	updateBars()
	active = true
	-- camera goes to your face during the countdown, so you're ready when it starts
	workspace.CurrentCamera:SetAttribute("DuelFace", true)
	setHud(false)
	task.spawn(countdown)
	heartbeat = RunService.RenderStepped:Connect(loop)
end

local function confetti()
	local colors = { GOLD, RED, BLUE, GREEN, KIND_COLORS.chew }
	for _ = 1, 40 do
		local piece = Ui.make("Frame", {
			Position = UDim2.fromScale(math.random(), -0.05),
			Size = UDim2.fromScale(0.012, 0.025),
			Rotation = math.random(0, 360),
			BackgroundColor3 = colors[math.random(1, #colors)],
			ZIndex = 40,
			Parent = root,
		})
		local time = math.random(15, 30) / 10
		tween(piece, time, { Position = UDim2.fromScale(piece.Position.X.Scale + math.random(-10, 10) / 100, 1.05), Rotation = piece.Rotation + math.random(180, 720) }, Enum.EasingStyle.Linear)
		task.delay(time, piece.Destroy, piece)
	end
end

local function onFinish(payload: any)
	stopLoop()
	serverMine, serverTheirs = payload.mine, payload.theirs
	updateBars()
	local results = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(25, 22, 38),
		ZIndex = 30,
		Parent = root,
	}, {
		Ui.corner(0.06),
		Ui.make("UIStroke", { Color = if payload.result == "win" then GOLD elseif payload.result == "lose" then RED else BLUE, Thickness = 4 }),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(300, 220) }),
	})
	local scale = Ui.make("UIScale", { Scale = 0.3, Parent = results })
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.3),
		Position = UDim2.fromScale(0.05, 0.05),
		Text = Strings.get("duel.result." .. payload.result),
		TextColor3 = if payload.result == "win" then GOLD elseif payload.result == "lose" then RED else BLUE,
		ZIndex = 31,
		Parent = results,
	})
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.14),
		Position = UDim2.fromScale(0.05, 0.38),
		Text = `{payload.mine}  :  {payload.theirs}`,
		ZIndex = 31,
		Parent = results,
	})
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.55),
		Text = Strings.get("duel.accuracy", { n = tostring(math.floor(payload.accuracy * 100)) })
			.. (if payload.forfeit then "  " .. Strings.get("duel.forfeit") else ""),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(210, 210, 230),
		ZIndex = 31,
		Parent = results,
	})
	Ui.label({
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.67),
		Text = Strings.get("duel.reward", { n = Strings.num(payload.glow) }),
		TextColor3 = GOLD,
		ZIndex = 31,
		Parent = results,
	})
	local ok = Ui.button({
		Size = UDim2.fromScale(0.4, 0.13),
		Position = UDim2.fromScale(0.3, 0.83),
		Text = Strings.get("common.close"),
		ZIndex = 31,
		Parent = results,
	})
	ok.Activated:Connect(function()
		results:Destroy()
		root.Visible = false
	end)
	if payload.result == "win" then
		confetti()
	end
end

local function onInvited(name: string, fromId: number, dur: number)
	local box = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, -0.2),
		Size = UDim2.fromScale(0.36, 0.16),
		BackgroundColor3 = Color3.fromRGB(40, 20, 35),
		ZIndex = 20,
		Parent = gui,
	}, { Ui.corner(0.15), Ui.make("UIStroke", { Color = RED, Thickness = 3 }), Ui.make("UISizeConstraint", { MinSize = Vector2.new(280, 110) }) })
	tween(box, 0.35, { Position = UDim2.fromScale(0.5, 0.12) }, Enum.EasingStyle.Back)
	Ui.label({
		Size = UDim2.fromScale(0.92, 0.45),
		Position = UDim2.fromScale(0.04, 0.05),
		Text = Strings.get("duel.invited", { name = name, t = string.format("%d:%02d", dur // 60, dur % 60) }),
		TextWrapped = true,
		ZIndex = 21,
		Parent = box,
	})
	local yes = Ui.button({ Size = UDim2.fromScale(0.44, 0.35), Position = UDim2.fromScale(0.04, 0.58), Text = Strings.get("duel.accept"), BackgroundColor3 = GREEN, ZIndex = 21, Parent = box })
	local no = Ui.button({ Size = UDim2.fromScale(0.44, 0.35), Position = UDim2.fromScale(0.52, 0.58), Text = Strings.get("duel.decline"), BackgroundColor3 = Ui.Colors.Muted, ZIndex = 21, Parent = box })
	local answered = false
	local function answer(accept: boolean)
		if answered then
			return
		end
		answered = true
		remote:FireServer("respond", fromId, accept)
		box:Destroy()
	end
	yes.Activated:Connect(function()
		answer(true)
	end)
	no.Activated:Connect(function()
		answer(false)
	end)
	task.delay(DuelRules.INVITE_SECONDS, function()
		if not answered and box.Parent then
			answered = true
			box:Destroy()
		end
	end)
end

---------------------------------------------------------------- build

local function build()
	gui = Ui.screen("DuelGame", 25)
	toastLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.4, 0.06),
		BackgroundColor3 = Color3.fromRGB(25, 22, 38),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	})
	Ui.corner(0.3).Parent = toastLabel

	-- see-through: the exercises happen on your 3D face behind it, clicks pass through
	root = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		Parent = gui,
	})
	shake = Ui.make("UIScale", { Parent = root })
	flash = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 45, Parent = root })

	-- tug-of-war score bar
	local bar = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.7, 0.05),
		BackgroundColor3 = RED,
		ZIndex = 10,
		Parent = root,
	}, { Ui.corner(0.5), Ui.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }) })
	myBar = Ui.make("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = BLUE, ZIndex = 11, Parent = bar }, { Ui.corner(0.5) })
	myScoreLabel = Ui.label({ Size = UDim2.fromScale(0.3, 1), Position = UDim2.fromScale(0.02, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = bar })
	theirScoreLabel = Ui.label({ Size = UDim2.fromScale(0.3, 1), Position = UDim2.fromScale(0.68, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12, Parent = bar })
	Ui.label({ Name = "MyName", Size = UDim2.fromScale(0.25, 0.035), Position = UDim2.fromScale(0.15, 0.105), Text = player.DisplayName, TextColor3 = BLUE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10, Parent = root })
	Ui.label({ Name = "OpponentName", Size = UDim2.fromScale(0.25, 0.035), Position = UDim2.fromScale(0.6, 0.105), TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10, Parent = root })
	timerLabel = Ui.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.105), Size = UDim2.fromScale(0.15, 0.06), ZIndex = 10, Parent = root })
	comboLabel = Ui.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.5), Size = UDim2.fromScale(0.14, 0.065), Text = "x0", TextStrokeTransparency = 0, ZIndex = 10, Parent = root })

	bannerLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.6, 0.17),
		ZIndex = 35,
		Visible = false,
		TextStrokeTransparency = 0,
		Parent = root,
	})

	local leave = Ui.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.98, 0.97),
		Size = UDim2.fromScale(0.12, 0.06),
		Text = Strings.get("duel.leave"),
		BackgroundColor3 = Ui.Colors.Muted,
		ZIndex = 10,
		Parent = root,
	})
	leave.Activated:Connect(function()
		if active then
			remote:FireServer("leave")
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function DuelGame.invite(userId: number, dur: number)
	remote:FireServer("invite", userId, dur)
end

function DuelGame.isActive(): boolean
	return active
end

function DuelGame.init()
	build()
	remote.OnClientEvent:Connect(function(action, a1, a2, a3)
		if action == "invited" then
			onInvited(a1, a2, a3)
		elseif action == "info" then
			toast(Strings.get(a1), GOLD)
		elseif action == "start" then
			onStart(a1)
		elseif action == "score" then
			serverMine, serverTheirs = a1, a2
			updateBars()
		elseif action == "finish" then
			onFinish(a1)
		end
	end)
end

return DuelGame
