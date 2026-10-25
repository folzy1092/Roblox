-- Own tier head pack (tools/blender/make_heads.py): the MeshPart for the player's tier is
-- worn over the avatar head (welded, tinted with the skin color); the original head and its
-- face are hidden, hair and hats stay attached to it. Server-side, so everyone sees it.
-- Expects ReplicatedStorage.TierHeads.Head1 .. Head8 (imported in Studio): a Model with the skin
-- MeshPart "Head" and colored face parts, or a single MeshPart.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HeadWear = {}

local warned = false

-- texture-free face: each face feature is its own colored mesh (tools/blender/mh_parts.py)
local FEATURE_COLORS = {
	Brows = Color3.fromRGB(48, 34, 26),
	EyeWhites = Color3.fromRGB(238, 236, 230),
	Irises = Color3.fromRGB(74, 46, 28),
}
local LIP_TINT = Color3.fromRGB(176, 72, 74)

-- Head<n> is either a Model (Head + Lips/Brows/EyeWhites/Irises MeshParts, multi-part import)
-- or a single MeshPart (old pack). Returns the skin part and the feature parts.
local function template(tier: number): (MeshPart?, { MeshPart })
	local folder = ReplicatedStorage:FindFirstChild("TierHeads")
	local item = folder and folder:FindFirstChild("Head" .. tier)
	if item and item:IsA("MeshPart") then
		return item, {}
	end
	if item and item:IsA("Model") then
		local skin = item:FindFirstChild("Head", true)
		if skin and skin:IsA("MeshPart") then
			local features = {}
			for _, d in item:GetDescendants() do
				if d:IsA("MeshPart") and d ~= skin then
					table.insert(features, d)
				end
			end
			return skin, features
		end
	end
	if not warned then
		warned = true
		warn("[HeadWear] ReplicatedStorage.TierHeads.Head1..Head8 not found; keeping default heads")
	end
	return nil, {}
end

local function plain(part: BasePart, color: Color3)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	-- no uploaded face textures: Roblox auto-moderation flagged the head atlases as "off-site
	-- links". Imported SurfaceAppearances override Color (pale/blue), so drop them too.
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
	for _, d in part:GetDescendants() do
		if d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		end
	end
end

-- Hair and hats are authored for the standard Roblox head (a rounded ~1-stud box whose
-- HairAttachment sits on top); Roblox scales them together with the head (HeadScale). Our skull
-- is a real human one, narrower than that box, so the same hair floats around it. We measure the
-- worn skull with rays and map the standard head onto it (scale + move about the crown), like
-- HeadScale does, so hair sits on the head.
local originals: { [BasePart]: { size: Vector3, rel: CFrame, meshScale: Vector3? } } = setmetatable({}, { __mode = "k" }) :: any

local function skullBox(head: BasePart, skin: BasePart): (Vector3?, number?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { skin }
	local function hit(from: Vector3, dir: Vector3): Vector3?
		local r = workspace:Raycast(head.CFrame:PointToWorldSpace(from), head.CFrame:VectorToWorldSpace(dir), params)
		return r and head.CFrame:PointToObjectSpace(r.Position)
	end
	local reach = head.Size.Magnitude * 2
	local top = hit(Vector3.new(0, reach, 0), Vector3.new(0, -2 * reach, 0))
	if not top then
		return nil
	end
	-- a band around the upper skull: above the ears, below the crown (where hair rests)
	local y = top.Y - head.Size.Y * Config.HairFit.band
	local l = hit(Vector3.new(-reach, y, 0), Vector3.new(2 * reach, 0, 0))
	local r = hit(Vector3.new(reach, y, 0), Vector3.new(-2 * reach, 0, 0))
	local f = hit(Vector3.new(0, y, -reach), Vector3.new(0, 0, 2 * reach))
	local b = hit(Vector3.new(0, y, reach), Vector3.new(0, 0, -2 * reach))
	if not (l and r and f and b) then
		return nil
	end
	local cx, cz = (l.X + r.X) / 2, (f.Z + b.Z) / 2
	local crown = hit(Vector3.new(cx, reach, cz), Vector3.new(0, -2 * reach, 0)) or top
	local scale = ((r.X - l.X) / head.Size.X + (b.Z - f.Z) / head.Size.Z) / 2
	scale = math.clamp(scale * Config.HairFit.snug, Config.HairFit.min, Config.HairFit.max)
	return Vector3.new(cx, crown.Y, cz), scale
end

-- accessories hanging on the head's attachments (hair, hats, glasses, ...)
local function headAccessories(character: Model, head: BasePart): { BasePart }
	local out = {}
	for _, acc in character:GetChildren() do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			for _, att in handle:GetChildren() do
				if att:IsA("Attachment") and head:FindFirstChild(att.Name) then
					table.insert(out, handle)
					break
				end
			end
		end
	end
	return out
end

local function fitAccessories(character: Model, head: BasePart, skin: BasePart)
	local crown, scale = skullBox(head, skin)
	if not crown or not scale then
		return
	end
	local oldCrown = Vector3.new(0, head.Size.Y / 2, 0) -- standard head: HairAttachment on top
	for _, handle in headAccessories(character, head) do
		local orig = originals[handle]
		if not orig then
			local mesh = handle:FindFirstChildOfClass("SpecialMesh")
			orig = { size = handle.Size, rel = head.CFrame:ToObjectSpace(handle.CFrame), meshScale = mesh and mesh.Scale }
			originals[handle] = orig
		end
		local rel = CFrame.new(crown + (orig.rel.Position - oldCrown) * scale) * orig.rel.Rotation
		handle.Size = orig.size * scale
		local mesh = handle:FindFirstChildOfClass("SpecialMesh")
		if mesh and orig.meshScale then
			mesh.Scale = orig.meshScale * scale
		end
		-- replace the attachment weld by a fixed one at the fitted spot
		for _, joint in handle:GetChildren() do
			if joint.Name == "AccessoryWeld" or joint:IsA("RigidConstraint") then
				joint:Destroy()
			end
		end
		local weld = handle:FindFirstChild("TierFitWeld") :: Weld? or Instance.new("Weld")
		weld.Name = "TierFitWeld"
		weld.Part0 = head
		weld.Part1 = handle
		weld.C0 = rel
		weld.C1 = CFrame.identity
		weld.Parent = handle
	end
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
	local source, features = template(tier)
	if not source then
		return
	end
	if current then
		current:Destroy()
	end
	local oldNeck = character:FindFirstChild("TierNeck")
	if oldNeck then
		oldNeck:Destroy()
	end

	local part = source:Clone()
	part:ClearAllChildren()
	part.Name = "TierHead"
	part:SetAttribute("Tier", tier)
	plain(part, head.Color)
	part.CanQuery = true -- exercise markers raycast onto it (still no collisions)
	-- fit the model to this avatar's head size (models are built in a 1-stud box)
	local fit = Config.TierHeadFit
	-- keep the model's proportions: scale uniformly so its height matches the avatar head
	local uniform = head.Size.Y * fit.scale[2] / source.Size.Y
	local stretch = Vector3.new(fit.scale[1] / fit.scale[2], 1, fit.scale[3] / fit.scale[2]) * uniform
	part.Size = source.Size * stretch
	local topY = head.Size.Y / 2 - part.Size.Y / 2 - fit.topInset
	local offset = CFrame.new(0, topY, 0) * CFrame.Angles(0, math.rad(fit.rotateY), 0)

	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.CFrame = head.CFrame * offset

	-- face features keep their place relative to the skin mesh, scaled the same way
	for _, f in features do
		local rel = source.CFrame:ToObjectSpace(f.CFrame)
		local piece = f:Clone()
		piece:ClearAllChildren()
		piece.Size = f.Size * stretch
		local color = FEATURE_COLORS[f.Name] or head.Color
		if f.Name == "Lips" then
			color = head.Color:Lerp(LIP_TINT, 0.7)
		end
		plain(piece, color)
		piece.CanQuery = false
		local at = CFrame.new(rel.Position * stretch) * rel.Rotation
		local w = Instance.new("Weld")
		w.Part0 = part
		w.Part1 = piece
		w.C0 = at
		w.Parent = piece
		piece.CFrame = part.CFrame * at
		piece.Parent = part
	end
	part.Parent = character
	fitAccessories(character, head, part)

	-- neck: skin-colored column from under the jaw down into the torso, so the jawline reads
	local neckFit = Config.TierNeck
	local neck = Instance.new("Part")
	neck.Name = "TierNeck"
	neck.Shape = Enum.PartType.Cylinder
	neck.Material = Enum.Material.SmoothPlastic
	neck.Color = head.Color
	neck.Anchored = false
	neck.CanCollide = false
	neck.CanQuery = false
	neck.CanTouch = false
	neck.Massless = true
	neck.TopSurface = Enum.SurfaceType.Smooth
	neck.BottomSurface = Enum.SurfaceType.Smooth
	local neckLength = head.Size.Y * neckFit.length
	local neckWidth = head.Size.X * neckFit.width
	neck.Size = Vector3.new(neckLength, neckWidth, neckWidth * neckFit.depth) -- cylinder axis = X
	local neckOffset = CFrame.new(0, -head.Size.Y / 2 + neckFit.y * head.Size.Y, head.Size.Z * neckFit.back)
		* CFrame.Angles(0, 0, math.rad(90))
	local neckWeld = Instance.new("Weld")
	neckWeld.Part0 = head
	neckWeld.Part1 = neck
	neckWeld.C0 = neckOffset
	neckWeld.Parent = neck
	neck.CFrame = head.CFrame * neckOffset
	neck.Parent = character

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
