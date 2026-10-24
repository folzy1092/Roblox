-- Own tier head pack (tools/blender/make_heads.py): the MeshPart for the player's tier is
-- worn over the avatar head (welded, tinted with the skin color); the original head and its
-- face are hidden, hair and hats stay attached to it. Server-side, so everyone sees it.
-- Expects ReplicatedStorage.TierHeads with MeshParts named Head1 .. Head8 (imported in Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HeadWear = {}

local warned = false

local function template(tier: number): MeshPart?
	local folder = ReplicatedStorage:FindFirstChild("TierHeads")
	local part = folder and folder:FindFirstChild("Head" .. tier)
	if part and part:IsA("MeshPart") then
		return part
	end
	if not warned then
		warned = true
		warn("[HeadWear] ReplicatedStorage.TierHeads.Head1..Head8 not found; keeping default heads")
	end
	return nil
end

local function wear(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local tier = player:GetAttribute("Tier")
	if not head or typeof(tier) ~= "number" then
		return
	end
	local current = character:FindFirstChild("TierHead")
	if current and current:GetAttribute("Tier") == tier then
		return
	end
	local source = template(tier)
	if not source then
		return
	end
	if current then
		current:Destroy()
	end

	local part = source:Clone()
	part.Name = "TierHead"
	part:SetAttribute("Tier", tier)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = true -- exercise markers raycast onto it (still no collisions)
	part.CanTouch = false
	part.Massless = true
	part.Color = head.Color
	-- no uploaded face textures: Roblox auto-moderation flagged the head atlases as "off-site
	-- links". The heads are plain skin-colored meshes; the shape carries the look.
	part.TextureID = ""
	-- fit the model to this avatar's head size (models are built in a 1-stud box)
	local fit = Config.TierHeadFit
	-- keep the model's proportions: scale uniformly so its height matches the avatar head
	local uniform = head.Size.Y * fit.scale[2] / source.Size.Y
	part.Size = source.Size * uniform * Vector3.new(fit.scale[1] / fit.scale[2], 1, fit.scale[3] / fit.scale[2])
	local offset = CFrame.new(0, fit.offsetY, 0) * CFrame.Angles(0, math.rad(fit.rotateY), 0)

	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.CFrame = head.CFrame * offset
	part.Parent = character

	head.Transparency = 1
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end

function HeadWear.attach(player: Player)
	if not Config.UseTierHeadModels then
		return
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		wear(player)
	end)
	player:GetAttributeChangedSignal("Tier"):Connect(function()
		wear(player)
	end)
	if player.Character then
		task.spawn(wear, player)
	end
end

local _ = Players
return HeadWear
