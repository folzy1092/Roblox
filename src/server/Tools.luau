-- Keeps one Tool per owned item in the player's Backpack.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local COLORS = {
	gum = Color3.fromRGB(255, 120, 190),
	mewing = Color3.fromRGB(120, 200, 255),
	jawball = Color3.fromRGB(90, 220, 120),
	guasha = Color3.fromRGB(190, 120, 255),
	bonetapper = Color3.fromRGB(200, 200, 210),
}

local Tools = {}

local function makeTool(itemId: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = itemId
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("ItemId", itemId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 0.6)
	handle.Shape = Enum.PartType.Ball
	handle.Color = COLORS[itemId] or Color3.new(1, 1, 1)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

-- Tools currently held or in backpack, by name.
local function existing(player: Player): { [string]: Tool }
	local found = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemId") then
					found[child.Name] = child
				end
			end
		end
	end
	return found
end

function Tools.give(player: Player, data: Progression.Data)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local have = existing(player)
	for name, tool in have do
		if not data.items[name] then
			tool:Destroy()
		end
	end
	local ids = {}
	for id in data.items do
		if Config.Items[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Config.Items[a].order < Config.Items[b].order
	end)
	for _, id in ids do
		if not have[id] then
			makeTool(id).Parent = backpack
		end
	end
end

function Tools.held(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("ItemId") then
		return tool
	end
	return nil
end

function Tools.equip(player: Player, itemId: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = existing(player)[itemId]
	if humanoid and tool then
		humanoid:EquipTool(tool)
	end
end

return Tools
