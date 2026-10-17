-- Server entry: wires players, remotes and game rules.
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Tools = require(script.Parent.Tools)
local MapBuilder = require(script.Parent.MapBuilder)
local RankLabel = require(script.Parent.RankLabel)
local Face = require(script.Parent.Face)
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
	if not data or not tool or not data.items[tool.Name] or not allowClick(player) then
		return
	end
	data.equipped = tool.Name
	Progression.applyClick(data, {
		trainerMult = Trainers.mult(player, data, ownsPass),
		hasX2 = ownsPass(player, "X2"),
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

Remotes.Rebirth.OnServerEvent:Connect(function(player)
	local data = PlayerData.get(player)
	if not data or not Progression.canRebirth(data) then
		return
	end
	Progression.applyRebirth(data)
	Tools.give(player, data)
	PlayerData.publish(player)
end)

local function onPlayerAdded(player: Player)
	task.spawn(cachePasses, player)
	RankLabel.attach(player)
	Face.attach(player)
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

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
	passCache[player] = nil
	clickWindow[player] = nil
end)

game:BindToClose(PlayerData.saveAll)
