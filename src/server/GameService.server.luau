-- Server entry: wires players, remotes and game rules.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Tools = require(script.Parent.Tools)

local passCache: { [Player]: { [string]: boolean } } = {}
local clickWindow: { [Player]: { start: number, count: number } } = {}

local function ownsPass(player: Player, passName: string): boolean
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

-- Multiplier from the trainer zone the player stands in, matching their held item.
local function getTrainerMult(player: Player, data: Progression.Data): number
	local trainers = workspace:FindFirstChild("Trainers")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not trainers or not root then
		return 1
	end
	local best = 1
	for _, model in trainers:GetChildren() do
		local zone = model:FindFirstChild("Zone")
		if zone and model:GetAttribute("ItemId") == data.equipped then
			local localPos = zone.CFrame:PointToObjectSpace(root.Position)
			local half = zone.Size / 2
			local inside = math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z and math.abs(localPos.Y) <= 6
			if inside then
				if model:GetAttribute("Vip") then
					if ownsPass(player, "Vip") then
						best = math.max(best, Config.Mult.Vip)
					end
				else
					best = math.max(best, Config.Mult.Trainer)
				end
			end
		end
	end
	return best
end

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
		trainerMult = getTrainerMult(player, data),
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
