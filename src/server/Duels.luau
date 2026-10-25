-- Duels: invite -> accept -> both players are put on a duel station in the arena, a 3-2-1
-- countdown, then the same exercise schedule for both (shared/DuelRules). Clients report
-- hits/misses; the server rate-limits them, keeps the score, broadcasts live scores and picks
-- the winner. Rewards: Glow/rating for both (more for the winner) and +1 saved duel win.
-- One RemoteEvent "Duel": client -> ("invite", userId, duration) | ("respond", userId, accept)
--   | ("event", "hit"/"miss") | ("leave")
-- server -> ("invited", name, userId, duration) | ("info", key) | ("start", payload)
--   | ("score", mine, theirs, combo) | ("finish", payload)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DuelRules = require(ReplicatedStorage.Shared.DuelRules)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)

local Duels = {}

type Match = {
	players: { Player },
	seed: number,
	duration: number,
	startAt: number, -- os.clock() when exercises begin (after countdown)
	endAt: number,
	scores: { [Player]: DuelRules.Score },
	windows: { [Player]: { number } },
	station: number,
	saved: { [Player]: { walk: number, jump: number } },
	done: boolean,
}

local remote: RemoteEvent
local matches: { [Player]: Match } = {}
local invites: { [Player]: { from: Player, duration: number, expires: number } } = {}
local stationBusy: { [number]: boolean } = {}

local WIN_FACTOR = 40 -- rating/Glow reward in "clicks" per 90 s for the winner
local LOSE_FACTOR = 8
local DRAW_FACTOR = 20

-- Duel pads grouped into stations: { [station] = { padA, padB } }.
local function stations(): { { BasePart } }
	local arena = workspace:FindFirstChild("DuelArena")
	local byZ: { [number]: { BasePart } } = {}
	local keys = {}
	if arena then
		for _, d in arena:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "DuelPad" then
				local key = math.floor(d.Position.Z + 0.5)
				if not byZ[key] then
					byZ[key] = {}
					table.insert(keys, key)
				end
				table.insert(byZ[key], d)
			end
		end
	end
	table.sort(keys)
	local out = {}
	for _, key in keys do
		local pads = byZ[key]
		if #pads >= 2 then
			table.sort(pads, function(a, b)
				return a.Position.X < b.Position.X
			end)
			table.insert(out, { pads[1], pads[#pads] })
		end
	end
	return out
end

local function freeStation(): number?
	for i in stations() do
		if not stationBusy[i] then
			return i
		end
	end
	return nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function freeze(match: Match, player: Player, pad: BasePart, lookAt: Vector3)
	local character = player.Character
	local humanoid = humanoidOf(player)
	if not character or not humanoid then
		return
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	humanoid:UnequipTools()
	match.saved[player] = { walk = humanoid.WalkSpeed, jump = humanoid.JumpPower }
	local spot = pad.Position + Vector3.new(0, 3.5, 0)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(lookAt.X, spot.Y, lookAt.Z)))
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
end

local function unfreeze(match: Match, player: Player)
	local humanoid = humanoidOf(player)
	local saved = match.saved[player]
	if humanoid and saved then
		humanoid.WalkSpeed = saved.walk
		humanoid.JumpPower = saved.jump
	end
end

local function reward(player: Player, factor: number, duration: number): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local _, glow = Progression.applyClick(data, {
		trainerMult = 1,
		hasX2 = false,
		factor = factor * duration / 90,
	})
	return math.floor(glow)
end

local function finish(match: Match, forfeit: Player?)
	if match.done then
		return
	end
	match.done = true
	local a, b = match.players[1], match.players[2]
	local fa, fb = DuelRules.final(match.scores[a]), DuelRules.final(match.scores[b])
	local winner: Player? = nil
	if forfeit then
		winner = if forfeit == a then b else a
	elseif fa ~= fb then
		winner = if fa > fb then a else b
	end
	for _, p in match.players do
		matches[p] = nil
		if p.Parent then
			unfreeze(match, p)
			local other = if p == a then b else a
			local won = winner == p
			local factor = if winner == nil then DRAW_FACTOR elseif won then WIN_FACTOR else LOSE_FACTOR
			local glow = reward(p, factor, match.duration)
			local data = PlayerData.get(p)
			if data and won then
				data.duelWins += 1
			end
			PlayerData.publish(p)
			remote:FireClient(p, "finish", {
				result = if winner == nil then "draw" elseif won then "win" else "lose",
				mine = DuelRules.final(match.scores[p]),
				theirs = DuelRules.final(match.scores[other]),
				accuracy = DuelRules.accuracy(match.scores[p]),
				opponent = other.DisplayName,
				glow = glow,
				forfeit = forfeit ~= nil,
			})
		end
	end
	stationBusy[match.station] = nil
end

local function start(a: Player, b: Player, duration: number)
	local station = freeStation()
	if not station then
		remote:FireClient(a, "info", "duels.busy")
		remote:FireClient(b, "info", "duels.busy")
		return
	end
	stationBusy[station] = true
	local pads = stations()[station]
	local now = os.clock()
	local match: Match = {
		players = { a, b },
		seed = math.random(1, 1e6),
		duration = duration,
		startAt = now + DuelRules.COUNTDOWN,
		endAt = now + DuelRules.COUNTDOWN + duration,
		scores = { [a] = DuelRules.newScore(), [b] = DuelRules.newScore() },
		windows = { [a] = {}, [b] = {} },
		station = station,
		saved = {},
		done = false,
	}
	matches[a], matches[b] = match, match
	freeze(match, a, pads[1], pads[2].Position)
	freeze(match, b, pads[2], pads[1].Position)
	local serverStart = workspace:GetServerTimeNow() + DuelRules.COUNTDOWN
	for _, p in match.players do
		local other = if p == a then b else a
		remote:FireClient(p, "start", {
			seed = match.seed,
			duration = duration,
			startAt = serverStart,
			opponent = other.DisplayName,
			opponentId = other.UserId,
		})
	end
end

local function onInvite(player: Player, targetId: any, duration: any)
	local target = if typeof(targetId) == "number" then Players:GetPlayerByUserId(targetId) else nil
	if not target or target == player or not table.find(DuelRules.DURATIONS, duration) then
		return
	end
	if matches[player] or matches[target] then
		remote:FireClient(player, "info", "duels.in_match")
		return
	end
	invites[target] = { from = player, duration = duration, expires = os.clock() + DuelRules.INVITE_SECONDS }
	remote:FireClient(target, "invited", player.DisplayName, player.UserId, duration)
	remote:FireClient(player, "info", "duels.sent")
end

local function onRespond(player: Player, fromId: any, accept: any)
	local invite = invites[player]
	if not invite or invite.from.UserId ~= fromId or os.clock() > invite.expires then
		return
	end
	invites[player] = nil
	local from = invite.from
	if not from.Parent then
		return
	end
	if accept ~= true then
		remote:FireClient(from, "info", "duels.declined")
		return
	end
	if matches[player] or matches[from] then
		remote:FireClient(player, "info", "duels.in_match")
		return
	end
	start(from, player, invite.duration)
end

local function onEvent(player: Player, event: any)
	local match = matches[player]
	if not match or match.done then
		return
	end
	local now = os.clock()
	if now < match.startAt or now > match.endAt + 0.5 then
		return
	end
	if not DuelRules.allowEvent(match.windows[player], now) then
		return
	end
	DuelRules.apply(match.scores[player], event)
end

function Duels.init(remoteEvent: RemoteEvent)
	remote = remoteEvent
	remote.OnServerEvent:Connect(function(player, action, a1, a2)
		if action == "invite" then
			onInvite(player, a1, a2)
		elseif action == "respond" then
			onRespond(player, a1, a2)
		elseif action == "event" then
			onEvent(player, a1)
		elseif action == "leave" then
			local match = matches[player]
			if match then
				finish(match, player)
			end
		end
	end)

	-- live scores + end of match
	task.spawn(function()
		while true do
			task.wait(0.4)
			local seen = {}
			for _, match in matches do
				if not seen[match] then
					seen[match] = true
					local a, b = match.players[1], match.players[2]
					for _, p in match.players do
						local other = if p == a then b else a
						remote:FireClient(p, "score", DuelRules.final(match.scores[p]),
							DuelRules.final(match.scores[other]), match.scores[p].combo)
					end
					if os.clock() >= match.endAt then
						finish(match)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		local match = matches[player]
		if match then
			finish(match, player)
		end
	end)

	-- leaderboard column
	local function stats(player: Player)
		local board = Instance.new("Folder")
		board.Name = "leaderstats"
		local wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Value = player:GetAttribute("DuelWins") or 0
		wins.Parent = board
		board.Parent = player
		player:GetAttributeChangedSignal("DuelWins"):Connect(function()
			wins.Value = player:GetAttribute("DuelWins") or 0
		end)
	end
	Players.PlayerAdded:Connect(stats)
	for _, p in Players:GetPlayers() do
		task.spawn(stats, p)
	end
end

return Duels
