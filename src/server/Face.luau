-- Face sculpt: skin-colored cheek, double-chin and jaw parts welded to the head.
-- Their size follows Looks.shape(rating), so everyone sees the face change by rank.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Looks = require(ReplicatedStorage.Shared.Looks)

local TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MIN_VISIBLE = 0.04

local Face = {}

type Parts = {
	head: BasePart,
	cheekL: Part,
	cheekR: Part,
	chin: Part,
	jaw: Part,
}

local function skinColor(character: Model, head: BasePart): Color3
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	return if bodyColors then bodyColors.HeadColor3 else head.Color
end

local function sculptPart(name: string, shape: Enum.PartType, head: BasePart, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = head.CFrame

	local weld = Instance.new("Weld")
	weld.Name = "SculptWeld"
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = head.Parent
	return part
end

-- Head front is -Z. Offsets scale with head size so any head proportion works.
local function apply(parts: Parts, rating: number, instant: boolean)
	local s = Looks.shape(rating)
	local h = parts.head.Size

	local cheekSize = h.X * 0.5 * s.fat
	local chinSize = h.X * 0.6 * s.fat
	local jawWidth = h.X * (0.55 + 0.4 * s.jaw)
	local jawHeight = h.Y * 0.28 * s.jaw

	local targets = {
		{ parts.cheekL, Vector3.new(cheekSize, cheekSize, cheekSize), CFrame.new(-h.X * 0.38, -h.Y * 0.12, -h.Z * 0.18), s.fat },
		{ parts.cheekR, Vector3.new(cheekSize, cheekSize, cheekSize), CFrame.new(h.X * 0.38, -h.Y * 0.12, -h.Z * 0.18), s.fat },
		{ parts.chin, Vector3.new(chinSize, chinSize * 0.55, chinSize * 0.8), CFrame.new(0, -h.Y * 0.48, -h.Z * 0.12), s.fat },
		{ parts.jaw, Vector3.new(jawWidth, jawHeight, h.Z * 0.75), CFrame.new(0, -h.Y * 0.42 + jawHeight * 0.1, -h.Z * 0.04), s.jaw },
	}
	for _, target in targets do
		local part, size, offset, amount = target[1], target[2], target[3], target[4]
		local weld = part:FindFirstChild("SculptWeld") :: Weld
		weld.C0 = offset
		local visible = amount > MIN_VISIBLE
		local goalSize = if visible then size else Vector3.new(0.05, 0.05, 0.05)
		part.Transparency = if visible then 0 else 1
		if instant then
			part.Size = goalSize
		else
			TweenService:Create(part, TWEEN, { Size = goalSize }):Play()
		end
	end
end

function Face.attach(player: Player)
	local current: Parts? = nil

	player:GetAttributeChangedSignal("Rating"):Connect(function()
		if current and current.head.Parent then
			apply(current, player:GetAttribute("Rating") or 0, false)
		end
	end)

	local function onCharacter(character: Model)
		local head = character:WaitForChild("Head", 10) :: BasePart?
		if not head then
			return
		end
		-- wait for appearance so BodyColors is in place
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		local color = skinColor(character, head)
		current = {
			head = head,
			cheekL = sculptPart("CheekL", Enum.PartType.Ball, head, color),
			cheekR = sculptPart("CheekR", Enum.PartType.Ball, head, color),
			chin = sculptPart("DoubleChin", Enum.PartType.Ball, head, color),
			jaw = sculptPart("Jaw", Enum.PartType.Block, head, color),
		}
		apply(current, player:GetAttribute("Rating") or 0, true)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return Face
