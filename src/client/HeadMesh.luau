-- Real 3D head for every character, built on this client with EditableMesh + EditableImage.
-- Shape: round puffy Sub-3 head morphs into a sharp diamond (HeadShape profile) with sculpted
-- relief: nose, brow ridge, eye sockets, cheekbones, hollow cheeks, jaw angles, square chin.
-- Texture: painted face (FacePaint) that also changes by tier.
-- The original head is hidden locally; hair/hats stay attached to it.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeadShape = require(ReplicatedStorage.Shared.HeadShape)
local Looks = require(ReplicatedStorage.Shared.Looks)
local FacePaint = require(script.Parent.FacePaint)

local LAT = 44 -- rings from crown to chin
local LON = 56 -- segments around (+1 duplicated seam column for clean UVs)
local UPDATE_SECONDS = 0.4
local REPAINT_DELTA = 0.02 -- repaint the texture only on visible changes

local HeadMesh = {}

type Entry = {
	head: BasePart,
	part: MeshPart,
	weld: Weld,
	mesh: EditableMesh,
	image: EditableImage,
	verts: { number },
	shape: { fat: number, jaw: number },
	painted: { fat: number, jaw: number },
	lastUpdate: number,
}

local entries: { [Player]: Entry } = {}
local supported = true

-- Ring i (0 = crown .. LAT = chin), column j (0..LON, column LON == column 0 in space).
local function vertexAt(h: Vector3, i: number, j: number, fat: number, jaw: number): Vector3
	local bottom = HeadShape.bottom(jaw)
	local y = 1 - (i / LAT) * (1 - bottom)
	local unitY = math.clamp(y, -1, 1)
	local a = (j % LON) / LON * math.pi * 2
	local cx, sz = math.cos(a), math.sin(a)
	local front = math.max(0, -sz)
	local push = HeadShape.relief(cx, unitY, front, fat, jaw) + HeadShape.sideRelief(unitY, math.abs(cx), jaw)
	local hw = HeadShape.halfWidth(unitY, fat, jaw) * (1 + push)
	local hd = HeadShape.halfDepth(unitY, fat, jaw) * (1 + push)
	local z = hd * sz - HeadShape.chinForward(unitY, jaw) * front
	return Vector3.new(hw * cx * h.X / 2, y * h.Y / 2, z * h.Z / 2)
end

local function index(i: number, j: number): number
	return i * (LON + 1) + j + 1
end

local function buildPositions(h: Vector3, fat: number, jaw: number): ({ Vector3 }, Vector3, Vector3)
	local positions = {}
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	for i = 0, LAT do
		for j = 0, LON do
			local p = vertexAt(h, i, j, fat, jaw)
			positions[index(i, j)] = p
			minV = minV:Min(p)
			maxV = maxV:Max(p)
		end
	end
	return positions, minV, maxV
end

local function createMesh(h: Vector3, fat: number, jaw: number): (EditableMesh, { number })
	local mesh = AssetService:CreateEditableMesh()
	local positions = buildPositions(h, fat, jaw)
	local verts, uvs = {}, {}
	for i = 0, LAT do
		for j = 0, LON do
			local k = index(i, j)
			verts[k] = mesh:AddVertex(positions[k])
			uvs[k] = mesh:AddUV(Vector2.new(j / LON, i / LAT))
		end
	end
	for i = 0, LAT - 1 do
		for j = 0, LON - 1 do
			local a, b = index(i, j), index(i, j + 1)
			local c, d = index(i + 1, j), index(i + 1, j + 1)
			local f1 = mesh:AddTriangle(verts[a], verts[b], verts[d])
			mesh:SetFaceUVs(f1, { uvs[a], uvs[b], uvs[d] })
			local f2 = mesh:AddTriangle(verts[a], verts[d], verts[c])
			mesh:SetFaceUVs(f2, { uvs[a], uvs[d], uvs[c] })
		end
	end
	return mesh, verts
end

local function paint(entry: Entry, fat: number, jaw: number)
	FacePaint.paint(entry.image, entry.head.Color, fat, jaw, HeadShape.bottom(jaw))
	entry.painted = { fat = fat, jaw = jaw }
end

-- Push new vertex positions, refresh the MeshPart, repaint when the look changed enough.
local function reshape(entry: Entry, fat: number, jaw: number)
	local positions, minV, maxV = buildPositions(entry.head.Size, fat, jaw)
	for k, id in entry.verts do
		entry.mesh:SetPosition(id, positions[k])
	end
	local fresh = AssetService:CreateMeshPartAsync(Content.fromObject(entry.mesh))
	entry.part:ApplyMesh(fresh)
	fresh:Destroy()
	entry.part.Size = maxV - minV
	entry.weld.C0 = CFrame.new((minV + maxV) / 2)
	entry.shape = { fat = fat, jaw = jaw }
	if math.abs(fat - entry.painted.fat) + math.abs(jaw - entry.painted.jaw) > REPAINT_DELTA then
		paint(entry, fat, jaw)
	end
end

local function hideOriginal(head: BasePart)
	head.Transparency = 1
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end

local function remove(player: Player)
	local entry = entries[player]
	if entry then
		entry.part:Destroy()
		entry.mesh:Destroy()
		entry.image:Destroy()
		entries[player] = nil
	end
end

local function attach(player: Player, character: Model)
	remove(player)
	if not supported then
		return
	end
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait() -- skin color settles after appearance loads
	end
	local s = Looks.shape(player:GetAttribute("Rating") or 0)
	local ok, err = pcall(function()
		local mesh, verts = createMesh(head.Size, s.fat, s.jaw)
		local image = AssetService:CreateEditableImage({ Size = Vector2.new(FacePaint.SIZE, FacePaint.SIZE) })
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
		part.Name = "LooksHead"
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1)
		part.TextureContent = Content.fromObject(image)

		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.CFrame = head.CFrame
		part.Parent = character

		local entry: Entry = {
			head = head,
			part = part,
			weld = weld,
			mesh = mesh,
			image = image,
			verts = verts,
			shape = { fat = -1, jaw = -1 },
			painted = { fat = -1, jaw = -1 },
			lastUpdate = 0,
		}
		entries[player] = entry
		reshape(entry, s.fat, s.jaw)
		hideOriginal(head)
	end)
	if not ok then
		-- e.g. mesh/image APIs disabled for this experience: keep the normal head
		supported = false
		warn(`[HeadMesh] EditableMesh unavailable, using default heads: {err}`)
	end
end

local function track(player: Player)
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
	-- throttled reshape; a trailing update makes sure the final rating is applied
	local pending = false
	local function update()
		local entry = entries[player]
		if not entry or not entry.head.Parent then
			return
		end
		local s = Looks.shape(player:GetAttribute("Rating") or 0)
		if math.abs(s.fat - entry.shape.fat) + math.abs(s.jaw - entry.shape.jaw) < 0.004 then
			return
		end
		local wait = UPDATE_SECONDS - (os.clock() - entry.lastUpdate)
		if wait > 0 then
			if not pending then
				pending = true
				task.delay(wait, function()
					pending = false
					update()
				end)
			end
			return
		end
		entry.lastUpdate = os.clock()
		pcall(reshape, entry, s.fat, s.jaw)
	end
	player:GetAttributeChangedSignal("Rating"):Connect(update)
end

function HeadMesh.init()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(remove)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return HeadMesh
