-- Real 3D head shape for every character, built on this client with EditableMesh.
-- Round puffy Sub-3 head morphs into a sharp diamond (cheekbones, jaw angles, narrow chin)
-- as the player's Rating grows (HeadShape + Looks). The original head is hidden locally;
-- hair/hats stay attached to it, and a classic face decal is drawn on the new head.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeadShape = require(ReplicatedStorage.Shared.HeadShape)
local Looks = require(ReplicatedStorage.Shared.Looks)

local LAT = 22 -- rings from crown to chin
local LON = 28 -- segments around
local UPDATE_SECONDS = 0.4
local FACE_TEXTURE = "rbxasset://textures/face.png"

local HeadMesh = {}

type Entry = {
	head: BasePart,
	part: MeshPart,
	weld: Weld,
	mesh: EditableMesh,
	verts: { number },
	shape: { fat: number, jaw: number },
	lastUpdate: number,
}

local entries: { [Player]: Entry } = {}
local supported = true

-- Vertex positions (head-local studs, front = -Z) for a shape, plus bounds.
local function buildPositions(h: Vector3, fat: number, jaw: number): ({ Vector3 }, Vector3, Vector3)
	local positions = {}
	local bottom = HeadShape.bottom(jaw)
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	local function add(p: Vector3)
		table.insert(positions, p)
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	add(Vector3.new(0, h.Y / 2, 0)) -- crown pole
	for i = 1, LAT - 1 do
		local t = i / LAT
		local y = 1 - t * (1 - bottom)
		local unitY = math.clamp(y, -1, 1)
		local hw = HeadShape.halfWidth(unitY, fat, jaw)
		local hd = HeadShape.halfDepth(unitY, fat, jaw)
		local forward = HeadShape.chinForward(unitY, jaw)
		for j = 0, LON - 1 do
			local a = j / LON * math.pi * 2
			local cx, sz = math.cos(a), math.sin(a)
			local z = hd * sz
			if sz < 0 then
				z -= forward * -sz -- push only the front of the lower face forward
			end
			add(Vector3.new(hw * cx * h.X / 2, y * h.Y / 2, z * h.Z / 2))
		end
	end
	add(Vector3.new(0, bottom * h.Y / 2, -HeadShape.chinForward(-1, jaw) * h.Z / 2)) -- chin pole
	return positions, minV, maxV
end

local function createMesh(h: Vector3, fat: number, jaw: number): (EditableMesh, { number })
	local mesh = AssetService:CreateEditableMesh()
	local positions = buildPositions(h, fat, jaw)
	local verts = {}
	for i, p in positions do
		verts[i] = mesh:AddVertex(p)
	end
	local top, bottom = verts[1], verts[#verts]
	local function ring(i: number, j: number): number
		return verts[1 + (i - 1) * LON + (j % LON) + 1]
	end
	for j = 0, LON - 1 do
		mesh:AddTriangle(top, ring(1, j + 1), ring(1, j))
		mesh:AddTriangle(bottom, ring(LAT - 1, j), ring(LAT - 1, j + 1))
	end
	for i = 1, LAT - 2 do
		for j = 0, LON - 1 do
			local a, b = ring(i, j), ring(i, j + 1)
			local c, d = ring(i + 1, j), ring(i + 1, j + 1)
			mesh:AddTriangle(a, b, d)
			mesh:AddTriangle(a, d, c)
		end
	end
	return mesh, verts
end

-- Push new vertex positions and refresh the visible MeshPart.
local function reshape(entry: Entry, fat: number, jaw: number)
	local h = entry.head.Size
	local positions, minV, maxV = buildPositions(h, fat, jaw)
	for i, id in entry.verts do
		entry.mesh:SetPosition(id, positions[i])
	end
	local fresh = AssetService:CreateMeshPartAsync(Content.fromObject(entry.mesh))
	entry.part:ApplyMesh(fresh)
	fresh:Destroy()
	entry.part.Size = maxV - minV
	entry.weld.C0 = CFrame.new((minV + maxV) / 2)
	entry.shape = { fat = fat, jaw = jaw }
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
	local s = Looks.shape(player:GetAttribute("Rating") or 0)
	local h = head.Size
	local ok, err = pcall(function()
		local mesh, verts = createMesh(h, s.fat, s.jaw)
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
		part.Name = "LooksHead"
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Material = Enum.Material.SmoothPlastic
		part.Color = head.Color

		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = FACE_TEXTURE
		face.Parent = part

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
			verts = verts,
			shape = { fat = -1, jaw = -1 },
			lastUpdate = 0,
		}
		entries[player] = entry
		reshape(entry, s.fat, s.jaw)
		hideOriginal(head)
	end)
	if not ok then
		-- e.g. mesh APIs disabled for this experience: keep the normal head
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
