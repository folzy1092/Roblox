-- 3D models of the training items, built from parts (no uploads). Used for the held Tool
-- (server/Tools) and for the shop card previews (client/Shop).
-- Every model is built around a "Handle" part at the grip point; the long axis points up (+Y).
local ItemModels = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function ellipsoid(props: { [string]: any }): Part
	local p = part(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cylinder(props: { [string]: any }): Part
	props.Shape = Enum.PartType.Cylinder
	return part(props)
end

-- Weld `piece` to `handle` at `offset` (in handle space) and parent it to `model`.
local function attach(model: Model, handle: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = model
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinder X axis -> Y

local BUILDERS: { [string]: (Model, BasePart) -> () } = {}

-- Gum: pink pack with a white wrapper band, one stick poking out, a bubble on top.
BUILDERS.gum = function(m, h)
	attach(m, h, part({ Name = "Pack", Size = Vector3.new(0.75, 0.95, 0.22), Color = Color3.fromRGB(255, 110, 180) }), CFrame.new(0, 0.2, 0))
	attach(m, h, part({ Name = "Wrapper", Size = Vector3.new(0.77, 0.28, 0.24), Color = Color3.fromRGB(255, 245, 250) }), CFrame.new(0, 0.25, 0))
	attach(m, h, part({ Name = "Stick", Size = Vector3.new(0.18, 0.4, 0.16), Color = Color3.fromRGB(255, 190, 220) }), CFrame.new(0.15, 0.82, 0))
	attach(m, h, ellipsoid({
		Name = "Bubble",
		Size = Vector3.new(0.7, 0.7, 0.7),
		Color = Color3.fromRGB(255, 150, 205),
		Transparency = 0.25,
		Material = Enum.Material.Glass,
	}), CFrame.new(-0.2, 1.15, 0))
end

-- Mewing trainer: blue U-shaped mouth guard (tongue-posture trainer) with a grip tab.
BUILDERS.mewing = function(m, h)
	local blue = Color3.fromRGB(90, 170, 255)
	attach(m, h, part({ Name = "Tab", Size = Vector3.new(0.22, 0.5, 0.12), Color = blue }), CFrame.new(0, 0.15, 0))
	local segments = 9
	for i = 0, segments - 1 do
		local a = math.rad(-100 + i * (200 / (segments - 1)))
		local r = 0.42
		attach(m, h, part({
			Name = "Arch",
			Size = Vector3.new(0.18, 0.22, 0.2),
			Color = blue,
			Transparency = 0.15,
			Material = Enum.Material.Glass,
		}), CFrame.new(math.sin(a) * r, 0.55, -math.cos(a) * r + 0.42) * CFrame.Angles(0, -a, 0))
	end
	attach(m, h, ellipsoid({ Name = "TongueSpot", Size = Vector3.new(0.3, 0.08, 0.3), Color = Color3.fromRGB(255, 120, 150) }), CFrame.new(0, 0.66, 0.1))
end

-- Jaw ball: green silicone jaw exerciser, ball with two bite tabs.
BUILDERS.jawball = function(m, h)
	local green = Color3.fromRGB(80, 210, 120)
	attach(m, h, ellipsoid({ Name = "Ball", Size = Vector3.new(0.75, 0.75, 0.75), Color = green }), CFrame.new(0, 0.45, 0))
	for _, x in { -1, 1 } do
		attach(m, h, part({ Name = "BiteTab", Size = Vector3.new(0.32, 0.18, 0.36), Color = green:Lerp(Color3.new(0, 0, 0), 0.2) }), CFrame.new(x * 0.45, 0.45, 0))
	end
	attach(m, h, cylinder({ Name = "Stripe", Size = Vector3.new(0.05, 0.78, 0.78), Color = Color3.fromRGB(240, 255, 245) }), CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(90), 0))
end

-- Gua sha: flat jade stone, heart/wing outline with a notched edge.
BUILDERS.guasha = function(m, h)
	local jade = Color3.fromRGB(170, 120, 230)
	attach(m, h, ellipsoid({
		Name = "Stone",
		Size = Vector3.new(0.9, 0.7, 0.12),
		Color = jade,
		Material = Enum.Material.Glass,
		Transparency = 0.05,
	}), CFrame.new(0, 0.5, 0))
	for _, x in { -0.2, 0.2 } do
		attach(m, h, ellipsoid({ Name = "Lobe", Size = Vector3.new(0.5, 0.5, 0.12), Color = jade, Material = Enum.Material.Glass }), CFrame.new(x, 0.72, 0))
	end
	attach(m, h, ellipsoid({ Name = "Notch", Size = Vector3.new(0.18, 0.18, 0.14), Color = jade:Lerp(Color3.new(0, 0, 0), 0.35) }), CFrame.new(0, 0.9, 0))
	attach(m, h, ellipsoid({ Name = "Shine", Size = Vector3.new(0.25, 0.1, 0.02), Color = Color3.new(1, 1, 1), Transparency = 0.4 }), CFrame.new(-0.18, 0.62, -0.07))
end

-- Bone tapper: red rubber mallet head on a wooden handle (matches the exercise animation).
BUILDERS.bonetapper = function(m, h)
	attach(m, h, cylinder({ Name = "Shaft", Size = Vector3.new(1.4, 0.12, 0.12), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood }), CFrame.new(0, 0.55, 0) * UP)
	attach(m, h, cylinder({ Name = "Grip", Size = Vector3.new(0.45, 0.17, 0.17), Color = Color3.fromRGB(40, 36, 44) }), CFrame.new(0, 0, 0) * UP)
	attach(m, h, cylinder({ Name = "Head", Size = Vector3.new(0.75, 0.42, 0.42), Color = Color3.fromRGB(225, 65, 75) }), CFrame.new(0, 1.3, 0))
	for _, x in { -0.38, 0.38 } do
		attach(m, h, cylinder({ Name = "Cap", Size = Vector3.new(0.06, 0.44, 0.44), Color = Color3.fromRGB(245, 245, 250) }), CFrame.new(x, 1.3, 0))
	end
end

-- Where the hand holds each model (height along its +Y axis, studs).
local GRIP_HEIGHT = {
	gum = 0.15,
	mewing = 0.15,
	jawball = 0.1,
	guasha = 0.25,
	bonetapper = 0.05,
}

-- Tool.Grip that holds the model upright in the fist at its grip point.
function ItemModels.grip(itemId: string): CFrame
	return CFrame.new(0, GRIP_HEIGHT[itemId] or 0.1, 0)
end

function ItemModels.has(itemId: string): boolean
	return BUILDERS[itemId] ~= nil
end

-- Builds the model into `container` (a Tool or a Model). Returns the Handle part.
function ItemModels.build(itemId: string, container: Instance): BasePart
	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.3, 0.3, 0.3),
		Transparency = 1,
	})
	handle.CFrame = CFrame.new()
	handle.Parent = container
	local builder = BUILDERS[itemId]
	if builder then
		builder(container :: any, handle)
	end
	return handle
end

return ItemModels
