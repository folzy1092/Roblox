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

return HeadShape
