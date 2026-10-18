-- Head silhouette as a function of height. Pure math, unit-tested with Lune.
-- y runs from +1 (crown) to -1 (chin) in head units; widths are half-widths (1 = head radius).
-- fat 1..0 melts the cheeks (Looks.shape.fat), jaw 0..1 sharpens the face into a diamond.
local HeadShape = {}

-- Piecewise-linear diamond: wide cheekbones, angled jaw, narrow long chin.
-- Straight segments on purpose: they give the sharp "chiselled" edges.
local DIAMOND = {
	{ 1.0, 0.0 },
	{ 0.85, 0.5 },
	{ 0.5, 0.82 },
	{ 0.05, 0.98 }, -- cheekbones
	{ -0.4, 0.8 }, -- jaw angle
	{ -0.8, 0.36 },
	{ -0.95, 0.22 }, -- chin
	{ -1.0, 0.0 },
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function piecewise(keys: { { number } }, y: number): number
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if y <= a[1] and y >= b[1] then
			return lerp(a[2], b[2], (a[1] - y) / (a[1] - b[1]))
		end
	end
	return 0
end

local function round(y: number, fat: number): number
	local circle = math.sqrt(math.max(0, 1 - y * y))
	-- puffy cheeks / soft double chin: extra width on the lower face
	local bulge = if y < 0.1 then fat * 0.18 * math.sin(math.clamp((0.1 - y) / 1.0, 0, 1) * math.pi) else 0
	return circle + bulge
end

function HeadShape.halfWidth(y: number, fat: number, jaw: number): number
	return lerp(round(y, fat), piecewise(DIAMOND, y), jaw)
end

-- Half-depth (front-back) follows the round head; the diamond only flattens it a little.
function HeadShape.halfDepth(y: number, fat: number, jaw: number): number
	return lerp(round(y, fat * 0.6), math.sqrt(math.max(0, 1 - y * y)) * 0.92, jaw * 0.5)
end

-- Lowest point of the chin (more negative = longer face).
function HeadShape.bottom(jaw: number): number
	return lerp(-1.0, -1.12, jaw)
end

-- How far the lower face is pushed forward (toward the front, in head units).
function HeadShape.chinForward(y: number, jaw: number): number
	if y > -0.4 then
		return 0
	end
	return jaw * 0.12 * ((-0.4 - y) / 0.6)
end

local function g(dx: number, dy: number): number
	return math.exp(-(dx * dx + dy * dy))
end

-- Facial relief: extra outward push (fraction of head radius) at a point of the face.
-- x = left/right across the face (-1..1), y = height (+1 crown .. -1 chin),
-- front = how much the point faces forward (0 back/side .. 1 straight ahead).
function HeadShape.relief(x: number, y: number, front: number, fat: number, jaw: number): number
	if front <= 0 then
		return 0
	end
	local ax = math.abs(x)
	local r = 0
	-- nose: bridge from the brows down, rounder tip at the bottom
	r += g(x / 0.09, 0) * math.clamp((0.2 - y) / 0.1, 0, 1) * math.clamp((y + 0.3) / 0.06, 0, 1) * 0.16
	r += g(x / 0.12, (y + 0.24) / 0.07) * 0.1
	-- brow ridge: heavier on chad
	r += g(0, (y - 0.28) / 0.06) * math.clamp((0.75 - ax) / 0.2, 0, 1) * (0.03 + 0.07 * jaw)
	-- eye sockets sink in
	r -= g((ax - 0.33) / 0.13, (y - 0.11) / 0.07) * (0.03 + 0.05 * jaw)
	-- cheekbones: high and sharp on chad
	r += g((ax - 0.62) / 0.14, (y + 0.02) / 0.09) * (0.02 + 0.1 * jaw)
	-- under the cheekbones: puffy when fat, hollow (buccal) when lean
	r += g((ax - 0.5) / 0.17, (y + 0.36) / 0.13) * (0.14 * fat - 0.08 * jaw)
	-- lips
	r += g(x / 0.2, (y + 0.52) / 0.05) * 0.035
	-- chin: square, forward, with a small cleft on chad
	r += g(x / 0.26, (y + 0.83) / 0.09) * 0.1 * jaw
	r -= g(x / 0.035, (y + 0.86) / 0.06) * 0.035 * jaw
	-- soft double chin under the face when fat
	r += g(x / 0.5, (y + 0.95) / 0.12) * 0.16 * fat
	return r * math.clamp(front * 1.6, 0, 1)
end

-- Sharp jaw corner (gonial angle) on the sides, below the ears.
function HeadShape.sideRelief(y: number, side: number, jaw: number): number
	return g(0, (y + 0.45) / 0.09) * side * 0.09 * jaw
end

return HeadShape
