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

-- Use the rendered head color so sculpt parts blend in (no pale patches).
local function skinColor(_character: Model, head: BasePart): Color3
	return head.Color
end

-- Ellipsoid (SpecialMesh sphere fills the part box) or plain block.
local function sculptPart(name: string, round: boolean, head: BasePart, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	if round then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
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

	-- Sub-3: puffy cheeks sunk half into the head, soft double chin, no jawline.
	local f = s.fat
	local cheek = Vector3.new(h.X * 0.34, h.Y * 0.42, h.Z * 0.5) * (0.35 + 0.65 * f)
	local chin = Vector3.new(h.X * 0.62, h.Y * 0.26, h.Z * 0.5) * (0.3 + 0.7 * f)
	local jawWidth = h.X * (0.6 + 0.35 * s.jaw)
	local jawHeight = h.Y * 0.22 * s.jaw

	local targets = {
		{ parts.cheekL, cheek, CFrame.new(-h.X * 0.31, -h.Y * 0.16, -h.Z * 0.16), f },
		{ parts.cheekR, cheek, CFrame.new(h.X * 0.31, -h.Y * 0.16, -h.Z * 0.16), f },
		{ parts.chin, chin, CFrame.new(0, -h.Y * 0.44, -h.Z * 0.1), f },
		{ parts.jaw, Vector3.new(jawWidth, jawHeight, h.Z * 0.7), CFrame.new(0, -h.Y * 0.4, -h.Z * 0.04), s.jaw },
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
			cheekL = sculptPart("CheekL", true, head, color),
			cheekR = sculptPart("CheekR", true, head, color),
			chin = sculptPart("DoubleChin", true, head, color),
			jaw = sculptPart("Jaw", false, head, color),
		}
		apply(current, player:GetAttribute("Rating") or 0, true)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return Face
