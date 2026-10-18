-- Server entry: wires players, remotes and game rules.
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local MiniGames = require(ReplicatedStorage.Shared.MiniGames)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Tools = require(script.Parent.Tools)
local MapBuilder = require(script.Parent.MapBuilder)
local RankLabel = require(script.Parent.RankLabel)
local Face = require(script.Parent.Face)
local HeadSwap = require(script.Parent.HeadSwap)
local Trainers = require(script.Parent.Trainers)

MapBuilder.build()

local passCache: { [Player]: { [string]: boolean } } = {}
local clickWindow: { [Player]: { start: number, count: number } } = {}

local function ownsPass(player: Player, passName: string): boolean
	if Config.StudioOwnsAllPasses and RunService:IsStudio() then
		return true
	end
	local cached = passCache[player]
	return cached ~= nil and cached[passName] == true
end

local function cachePasses(player: Player)
	local owned = {}
	for name, id in Config.GamePasses do
		if id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			owned[name] = ok and result == true
		end
	end
	passCache[player] = owned
	for name in Config.GamePasses do
		player:SetAttribute("Pass_" .. name, ownsPass(player, name))
	end
end

Trainers.init(ownsPass)

local function allowClick(player: Player): boolean
	local now = os.clock()
	local window = clickWindow[player]
	if not window or now - window.start >= 1 then
		clickWindow[player] = { start = now, count = 1 }
		return true
	end
	if window.count >= Config.ClickLimitPerSec then
		return false
	end
	window.count += 1
	return true
end

Remotes.Click.OnServerEvent:Connect(function(player)
	local data = PlayerData.get(player)
	local tool = Tools.held(player)
	-- mini-game items only pay through finished reps
	if not data or not tool or not data.items[tool.Name] or MiniGames.kindOf(tool.Name) or not allowClick(player) then
		return
	end
	data.equipped = tool.Name
	Progression.applyClick(data, {
		trainerMult = Trainers.mult(player, data, ownsPass),
		hasX2 = ownsPass(player, "X2"),
	})
	PlayerData.publish(player)
end)

-- One finished mini-game rep (gua sha stroke, bone tapper hit). Rate-limited per kind.
local lastRep: { [Player]: number } = {}
local lastFail: { [Player]: number } = {}

-- Mini-game mistake reported by the client (wrong spot / hit during rest): costs rating + Glow.
Remotes.Fail.OnServerEvent:Connect(function(player, reason)
	local data = PlayerData.get(player)
	local tool = Tools.held(player)
	local factor = if typeof(reason) == "string" then MiniGames.PenaltyFactor[reason] else nil
	if not data or not tool or not factor or not MiniGames.kindOf(tool.Name) or not data.items[tool.Name] then
		return
	end
	local now = os.clock()
	if now - (lastFail[player] or 0) < 0.2 then
		return
	end
	lastFail[player] = now
	data.equipped = tool.Name
	Progression.applyPenalty(data, factor)
	PlayerData.publish(player)
end)
Remotes.Rep.OnServerEvent:Connect(function(player)
	local data = PlayerData.get(player)
	local tool = Tools.held(player)
	local kind = tool and MiniGames.kindOf(tool.Name)
	if not data or not tool or not kind or not data.items[tool.Name] then
		return
	end
	local now = os.clock()
	if now - (lastRep[player] or 0) < MiniGames.MinRepInterval[kind] then
		return
	end
	lastRep[player] = now
	data.equipped = tool.Name
	Progression.applyClick(data, {
		trainerMult = Trainers.mult(player, data, ownsPass),
		hasX2 = ownsPass(player, "X2"),
		factor = MiniGames.RepFactor[kind],
	})
	PlayerData.publish(player)
end)

Remotes.Buy.OnServerEvent:Connect(function(player, itemId)
	local data = PlayerData.get(player)
	if not data or not Progression.canBuy(data, itemId) then
		return
	end
	Progression.applyBuy(data, itemId)
	Tools.give(player, data)
	Tools.equip(player, itemId)
	PlayerData.publish(player)
end)

Remotes.Equip.OnServerEvent:Connect(function(player, itemId)
	local data = PlayerData.get(player)
	if not data or typeof(itemId) ~= "string" or not data.items[itemId] then
		return
	end
	data.equipped = itemId
	Tools.equip(player, itemId)
	PlayerData.publish(player)
end)

-- Studio-only test shortcuts (DEV panel). Ignored in a published game.
Remotes.Dev.OnServerEvent:Connect(function(player, action, value)
	if not RunService:IsStudio() then
		return
	end
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if action == "tier" and typeof(value) == "number" and Config.Tiers[value] then
		-- enough rebirths that this tier is reachable, rating in the middle of the tier
		data.rebirths = math.min(value - 1, Config.MaxRebirths)
		local low = Config.Tiers[value].min
		local nextTier = Config.Tiers[value + 1]
		local high = if nextTier then nextTier.min else Config.TopRating
		data.rating = math.floor((low + high) / 2)
	elseif action == "max" then
		data.rebirths = Config.MaxRebirths
		data.rating = Config.TopRating
	elseif action == "glow" then
		data.glow += 50000
	elseif action == "reset" then
		local fresh = Progression.defaultData()
		data.rating, data.glow, data.rebirths = fresh.rating, fresh.glow, fresh.rebirths
	end
	PlayerData.publish(player)
end)

Remotes.Rebirth.OnServerEvent:Connect(function(player)
	local data = PlayerData.get(player)
	if not data or not Progression.canRebirth(data) then
		return
	end
	Progression.applyRebirth(data)
	Trainers.standUp(player)
	Tools.give(player, data)
	PlayerData.publish(player)
end)

local function onPlayerAdded(player: Player)
	task.spawn(cachePasses, player)
	RankLabel.attach(player)
	Face.attach(player)
	HeadSwap.attach(player)
	PlayerData.load(player)
	player.CharacterAdded:Connect(function()
		local data = PlayerData.get(player)
		if data then
			player:WaitForChild("Backpack")
			Tools.give(player, data)
		end
	end)
	local data = PlayerData.get(player)
	if data and player.Character then
		Tools.give(player, data)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Purchase from the VIP/store panel: unlock right away, no rejoin needed.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for name, id in Config.GamePasses do
		if id == passId then
			passCache[player] = passCache[player] or {}
			passCache[player][name] = true
			player:SetAttribute("Pass_" .. name, true)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
	passCache[player] = nil
	clickWindow[player] = nil
	lastRep[player] = nil
	lastFail[player] = nil
end)

game:BindToClose(PlayerData.saveAll)
