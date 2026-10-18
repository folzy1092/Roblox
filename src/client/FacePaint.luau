-- Paints the face texture for a head mesh (EditableImage) by tier:
-- eyes (round/droopy on Sub-3, narrow hunter eyes with positive tilt on Chad), brows,
-- nose, mouth, under-eye bags, cheekbone contour shadows and stubble.
-- Pixel (u, v) uses the same cylindrical mapping as HeadMesh's UVs.
local FacePaint = {}

FacePaint.SIZE = 256

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function g(dx: number, dy: number): number
	return math.exp(-(dx * dx + dy * dy))
end

-- Soft edge: 1 inside (d < 1), fading to 0 at d = 1 + soft.
local function inside(d: number, soft: number): number
	return math.clamp((1 + soft - d) / soft, 0, 1)
end

local function hash(x: number, y: number): number
	local n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
	return n - math.floor(n)
end

local function mix(c: { number }, target: { number }, a: number)
	if a <= 0 then
		return
	end
	c[1] = lerp(c[1], target[1], a)
	c[2] = lerp(c[2], target[2], a)
	c[3] = lerp(c[3], target[3], a)
end

local SCLERA = { 240, 238, 235 }
local IRIS = { 85, 58, 38 }
local PUPIL = { 15, 12, 10 }
local LINE = { 35, 25, 22 }
local BROW = { 45, 33, 26 }
local LIP = { 175, 90, 90 }
local MOUTH = { 95, 40, 40 }

-- One eye at (cx, cy); `side` = +1 right, -1 left (outer corner is away from the nose).
local function eye(c: { number }, x: number, y: number, side: number, jaw: number, fat: number)
	local cx, cy = 0.33 * side, 0.11
	local rx = lerp(0.12, 0.115, jaw)
	local ry = lerp(0.06, 0.03, jaw) * (1 - 0.15 * fat)
	local tilt = lerp(-0.14, 0.2, jaw) * side -- outer corner up on chad, droopy on sub-3
	local dx, dy = x - cx, y - cy
	local lx = dx * math.cos(tilt) + dy * math.sin(tilt)
	local ly = -dx * math.sin(tilt) + dy * math.cos(tilt)
	local d = math.sqrt((lx / rx) ^ 2 + (ly / ry) ^ 2)
	-- upper lid line, heavier on the top edge
	if d > 0.9 and d < 1.3 and ly > -ry * 0.3 then
		mix(c, LINE, inside(math.abs(d - 1.08) / 0.2, 0.4) * 0.9)
	end
	local fill = inside(d, 0.15)
	if fill <= 0 then
		return
	end
	mix(c, SCLERA, fill)
	local ir = ry * 0.95
	local id = math.sqrt(lx * lx + (ly + ry * 0.1) ^ 2) / ir
	mix(c, IRIS, inside(id, 0.2) * fill)
	mix(c, PUPIL, inside(id / 0.45, 0.3) * fill)
end

local function brow(c: { number }, x: number, y: number, jaw: number)
	local ax = math.abs(x)
	if ax < 0.19 or ax > 0.5 then
		return
	end
	local t = (ax - 0.19) / 0.31
	local base = lerp(0.275, 0.215, jaw)
	local arch = 0.035 * math.sin(math.pi * t) * (1 - jaw) -- sub-3: high arch
	local slope = (t - 0.4) * 0.05 * jaw -- chad: low, straight, angled down to the nose
	local centerY = base + arch + slope
	local thick = lerp(0.016, 0.038, jaw) * (1 - 0.35 * t)
	local d = math.abs(y - centerY) / thick
	mix(c, BROW, inside(d, 0.5) * 0.95)
end

local function mouth(c: { number }, x: number, y: number, jaw: number)
	local ax = math.abs(x)
	local half = lerp(0.12, 0.16, jaw)
	if ax > half + 0.02 then
		return
	end
	local frown = 0.02 * (ax / half) ^ 2 * (1 - jaw)
	local lineY = -0.53 - frown
	local edge = inside(ax / half, 0.15)
	mix(c, LIP, inside(math.abs(y - (lineY - 0.022)) / 0.022, 0.6) * 0.45 * edge)
	mix(c, LIP, inside(math.abs(y - (lineY + 0.015)) / 0.013, 0.6) * 0.3 * edge)
	mix(c, MOUTH, inside(math.abs(y - lineY) / 0.008, 0.8) * edge)
end

-- Color of one texel. `bottom` = lowest y of the head mesh (HeadShape.bottom).
local function texel(skin: { number }, u: number, v: number, px: number, py: number, fat: number, jaw: number, bottom: number): { number }
	local c = { skin[1], skin[2], skin[3] }
	local a = u * math.pi * 2
	local front = -math.sin(a)
	if front <= 0.05 then
		return c
	end
	local x = math.cos(a)
	local y = 1 - v * (1 - bottom)
	local ax = math.abs(x)
	local dark = { skin[1] * 0.55, skin[2] * 0.48, skin[3] * 0.5 }
	-- shading: cheekbone contour, nose sides, under-eye bags, jaw edge
	mix(c, dark, g((ax - 0.56) / 0.17, (y + 0.22) / 0.08) * 0.35 * jaw)
	mix(c, dark, g((ax - 0.11) / 0.035, (y + 0.08) / 0.14) * 0.22)
	mix(c, { skin[1] * 0.75, skin[2] * 0.62, skin[3] * 0.78 }, g((ax - 0.33) / 0.12, (y - 0.015) / 0.035) * 0.45 * fat)
	mix(c, dark, g((ax - 0.08) / 0.026, (y + 0.275) / 0.018) * 0.9) -- nostrils
	-- stubble on the lower face for high tiers
	if jaw > 0.55 and y < -0.36 and ax < 0.8 then
		local amount = (jaw - 0.55) / 0.45
		mix(c, dark, 0.12 * amount)
		if hash(px, py) > 0.55 then
			mix(c, dark, 0.35 * amount)
		end
	end
	eye(c, x, y, 1, jaw, fat)
	eye(c, x, y, -1, jaw, fat)
	brow(c, x, y, jaw)
	mouth(c, x, y, jaw)
	return c
end

-- Writes the whole texture into `image` (EditableImage of SIZE x SIZE).
function FacePaint.paint(image: EditableImage, skinColor: Color3, fat: number, jaw: number, bottom: number)
	local size = FacePaint.SIZE
	local skin = { skinColor.R * 255, skinColor.G * 255, skinColor.B * 255 }
	local buf = buffer.create(size * size * 4)
	for py = 0, size - 1 do
		local v = (py + 0.5) / size
		for px = 0, size - 1 do
			local u = (px + 0.5) / size
			local c = texel(skin, u, v, px, py, fat, jaw, bottom)
			local o = (py * size + px) * 4
			buffer.writeu8(buf, o, math.clamp(math.floor(c[1]), 0, 255))
			buffer.writeu8(buf, o + 1, math.clamp(math.floor(c[2]), 0, 255))
			buffer.writeu8(buf, o + 2, math.clamp(math.floor(c[3]), 0, 255))
			buffer.writeu8(buf, o + 3, 255)
		end
	end
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), buf)
end

return FacePaint
