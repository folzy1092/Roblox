-- Small building helpers shared by the map modules.
local Kit = {}

function Kit.part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape -- before Size: changing shape can resize the part
	end
	for key, value in props do
		if key ~= "Shape" and key ~= "Position" then
			(p :: any)[key] = value
		end
	end
	if props.Position then
		p.CFrame = CFrame.new(props.Position)
	end
	return p
end

-- Flat cylinder (disc) lying on the ground: `radius` wide, `height` thick, top at `topY`.
function Kit.disc(props: { [string]: any }, center: Vector3, radius: number, height: number): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, radius * 2, radius * 2)
	props.CFrame = CFrame.new(center + Vector3.new(0, -height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return Kit.part(props)
end

-- Floating text above a part.
function Kit.sign(parent: Instance, text: string, color: Color3, height: number?, width: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width or 8, 1.5)
	gui.StudsOffset = Vector3.new(0, height or 10, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = parent
end

-- Text painted on one face of a board (unlit, so it reads well at night and in shade).
function Kit.faceText(board: BasePart, face: Enum.NormalId, text: string, color: Color3, stroke: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.Position = UDim2.fromScale(0.03, 0.07)
	label.BackgroundTransparency = 1
	label.AutoLocalize = false
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeColor3 = stroke or Color3.new(0, 0, 0)
	label.TextStrokeTransparency = if stroke then 0 else 0.6
	label.Parent = gui
	gui.Parent = board
end

function Kit.light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

function Kit.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

return Kit
