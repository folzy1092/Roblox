-- Loads/saves player progress in DataStore and mirrors it to player attributes.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)

local STORE_NAME = "PlayerData_v1"
local RETRY_DELAYS = { 1, 2, 4 }
local AUTOSAVE_SECONDS = 60

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

type Session = { data: Progression.Data, canSave: boolean }

local sessions: { [Player]: Session } = {}

local PlayerData = {}

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function withRetries(fn: () -> any): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, #RETRY_DELAYS + 1 do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt <= #RETRY_DELAYS then
			task.wait(RETRY_DELAYS[attempt])
		end
	end
	return false, result
end

-- Fill missing fields from defaults so older saves keep working.
local function merge(saved: any): Progression.Data
	local data = Progression.defaultData()
	if typeof(saved) ~= "table" then
		return data
	end
	for key, value in saved do
		if data[key] ~= nil and typeof(value) == typeof(data[key]) then
			data[key] = value
		end
	end
	return data
end

function PlayerData.load(player: Player)
	local ok, saved = false, nil
	if store then
		ok, saved = withRetries(function()
			return store:GetAsync(keyFor(player))
		end)
	end
	if not ok then
		warn(`[PlayerData] load failed for {player.Name}, progress will not be saved: {saved}`)
	end
	sessions[player] = { data = merge(if ok then saved else nil), canSave = ok }
	player:SetAttribute("DataLoaded", ok)
	PlayerData.publish(player)
end

function PlayerData.get(player: Player): Progression.Data?
	local session = sessions[player]
	return session and session.data
end

function PlayerData.publish(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	local owned = {}
	for id in data.items do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("Rating", data.rating)
	player:SetAttribute("Glow", data.glow)
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("Equipped", data.equipped)
	player:SetAttribute("Tier", Progression.tierIndex(data.rating))
	player:SetAttribute("Items", table.concat(owned, ","))
end

function PlayerData.save(player: Player)
	local session = sessions[player]
	if not session or not session.canSave or not store then
		return
	end
	local ok, err = withRetries(function()
		store:SetAsync(keyFor(player), session.data)
	end)
	if not ok then
		warn(`[PlayerData] save failed for {player.Name}: {err}`)
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	sessions[player] = nil
end

function PlayerData.saveAll()
	local threads = {}
	for player in sessions do
		table.insert(threads, task.spawn(PlayerData.save, player))
	end
	-- give spawned saves time to finish during shutdown
	local deadline = os.clock() + 20
	while os.clock() < deadline do
		local busy = false
		for _, thread in threads do
			if coroutine.status(thread) ~= "dead" then
				busy = true
			end
		end
		if not busy then
			break
		end
		task.wait(0.5)
	end
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player in sessions do
			task.spawn(PlayerData.save, player)
		end
	end
end)

return PlayerData
