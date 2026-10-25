-- Loads/saves player progress in DataStore and mirrors it to player attributes.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local SaveLock = require(ReplicatedStorage.Shared.SaveLock)

local STORE_NAME = "PlayerData_v1"
local RETRY_DELAYS = { 1, 2, 4 }
local AUTOSAVE_SECONDS = 60
local CLAIM_ATTEMPTS = 8
local CLAIM_RETRY_SECONDS = 4

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

type Session = { data: Progression.Data, canSave: boolean, released: boolean }

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

-- Claims the session lock and loads data. Waits while another server still holds it.
function PlayerData.load(player: Player)
	local ok, saved, claimed = false, nil, false
	local errors = 0
	if store then
		for attempt = 1, CLAIM_ATTEMPTS do
			local callOk, err = pcall(function()
				store:UpdateAsync(keyFor(player), function(stored)
					local record
					record, claimed = SaveLock.tryClaim(stored, game.JobId, os.time())
					saved = stored and stored.data
					return record
				end)
			end)
			ok = callOk and claimed
			if ok or player.Parent == nil then
				break
			end
			if not callOk then
				-- DataStore error (e.g. Studio without API access): fail fast, don't hold the player
				warn(`[PlayerData] load attempt {attempt} failed for {player.Name}: {err}`)
				errors += 1
				if errors >= 3 or string.find(tostring(err), "403") then
					break
				end
				task.wait(1)
			else
				-- another server still holds the lock (player just hopped): wait for its release save
				task.wait(CLAIM_RETRY_SECONDS)
			end
		end
	end

	if player.Parent == nil then
		-- left while loading: give the lock back, keep stored data untouched
		if ok then
			pcall(function()
				store:UpdateAsync(keyFor(player), function(stored)
					return SaveLock.prepareSave(stored, saved, game.JobId, os.time(), true)
				end)
			end)
		end
		return
	end

	if not ok then
		warn(`[PlayerData] could not load {player.Name}, progress will not be saved`)
	end
	sessions[player] = { data = merge(if ok then saved else nil), canSave = ok, released = false }
	if Config.StudioGrantAllItems and RunService:IsStudio() then
		-- Studio testing: every item unlocked; never saved so real progress stays clean
		for id in Config.Items do
			sessions[player].data.items[id] = true
		end
		sessions[player].canSave = false
		ok = false
	end
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
	player:SetAttribute("DuelWins", data.duelWins)
	local nextDay, ready = Progression.dailyStatus(data, os.time())
	player:SetAttribute("DailyNext", nextDay)
	player:SetAttribute("DailyReady", ready)
	local inv = {}
	for id, count in data.inventory do
		table.insert(inv, id .. ":" .. count)
	end
	table.sort(inv)
	player:SetAttribute("Inventory", table.concat(inv, ","))
	local now = workspace:GetServerTimeNow()
	player:SetAttribute("VipUntil", if data.vipLeft > 0 then now + data.vipLeft else 0)
	player:SetAttribute("AutoUntil", if data.autoLeft > 0 then now + data.autoLeft else 0)
	-- boost as an absolute server time so the client can count down smoothly
	player:SetAttribute("BoostUntil", if data.boostLeft > 0 then workspace:GetServerTimeNow() + data.boostLeft else 0)
end

function PlayerData.save(player: Player, release: boolean?)
	local session = sessions[player]
	if not session or not session.canSave or not store then
		return
	end
	local written = false
	local ok, err = withRetries(function()
		store:UpdateAsync(keyFor(player), function(stored)
			local record = SaveLock.prepareSave(stored, session.data, game.JobId, os.time(), release == true)
			written = record ~= nil
			return record
		end)
	end)
	if not ok then
		warn(`[PlayerData] save failed for {player.Name}: {err}`)
	elseif not written then
		-- another server took over this player: never write stale data again
		session.canSave = false
		warn(`[PlayerData] lost session lock for {player.Name}, saving disabled`)
	end
end

function PlayerData.release(player: Player)
	local session = sessions[player]
	if not session or session.released then
		return
	end
	session.released = true
	PlayerData.save(player, true)
	sessions[player] = nil
end

function PlayerData.saveAll()
	local threads = {}
	for player, session in sessions do
		if not session.released then
			table.insert(threads, task.spawn(PlayerData.release, player))
		end
	end
	-- give spawned saves time to finish during shutdown
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local busy = false
		for _, thread in threads do
			if coroutine.status(thread) ~= "dead" then
				busy = true
			end
		end
		if not busy and next(sessions) == nil then
			break
		end
		task.wait(0.5)
	end
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player, session in sessions do
			if not session.released then
				task.spawn(PlayerData.save, player)
			end
		end
	end
end)

return PlayerData
