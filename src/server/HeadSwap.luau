-- Ready-made catalog heads per PSL tier (Config.TierHeads): when a player's tier changes,
-- their avatar head is swapped through HumanoidDescription. Skin color is kept, so
-- recolorable heads take the player's skin tone. Runs on the server, so everyone sees it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HeadSwap = {}

local applied: { [Player]: number } = {} -- head asset currently on the character
local busy: { [Player]: boolean } = {}

local function headFor(player: Player): number?
	local tier = player:GetAttribute("Tier")
	return if typeof(tier) == "number" then Config.TierHeads[tier] else nil
end

local function apply(player: Player)
	if busy[player] then
		return -- the running apply re-checks the tier when it finishes
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local headId = headFor(player)
	if not humanoid or not headId or applied[player] == headId then
		return
	end
	busy[player] = true
	local ok, err = pcall(function()
		local description = humanoid:GetAppliedDescription()
		description.Head = headId
		description.Face = 0 -- dynamic heads carry their own face
		humanoid:ApplyDescription(description)
	end)
	busy[player] = false
	if ok then
		applied[player] = headId
	else
		warn(`[HeadSwap] could not apply head {headId} for {player.Name}: {err}`)
	end
	-- tier may have moved on while the description was loading
	if headFor(player) ~= applied[player] and ok then
		task.defer(apply, player)
	end
end

function HeadSwap.attach(player: Player)
	if not Config.UseCatalogHeads then
		return
	end
	player.CharacterAdded:Connect(function()
		applied[player] = nil
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		apply(player)
	end)
	player:GetAttributeChangedSignal("Tier"):Connect(function()
		apply(player)
	end)
	if player.Character then
		task.spawn(apply, player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	applied[player] = nil
	busy[player] = nil
end)

return HeadSwap
