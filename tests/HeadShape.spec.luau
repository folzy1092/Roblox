local HeadShape = require("../src/shared/HeadShape")
local A = require("./assert")
local truthy = A.truthy

local tests = {}

tests["round head is close to a circle at mid height"] = function()
	local w = HeadShape.halfWidth(0, 0, 0)
	truthy(math.abs(w - 1) < 0.08, `mid width {w}`)
end

tests["fat face is widest low on the cheeks"] = function()
	local cheeks = HeadShape.halfWidth(-0.35, 1, 0)
	local lean = HeadShape.halfWidth(-0.35, 0, 0)
	truthy(cheeks > lean, "fat cheeks wider than lean")
end

tests["diamond: cheekbones widest, chin narrow, forehead narrower than cheekbones"] = function()
	local cheekbones = HeadShape.halfWidth(0.05, 0, 1)
	local forehead = HeadShape.halfWidth(0.5, 0, 1)
	local jawAngle = HeadShape.halfWidth(-0.4, 0, 1)
	local chin = HeadShape.halfWidth(-0.85, 0, 1)
	truthy(cheekbones > forehead, "cheekbones > forehead")
	truthy(cheekbones > jawAngle, "cheekbones > jaw angle")
	truthy(jawAngle > chin * 1.6, "jaw angle clearly wider than chin")
	truthy(chin < HeadShape.halfWidth(-0.85, 0, 0), "diamond chin narrower than round chin")
end

tests["diamond chin is longer and pushed forward"] = function()
	truthy(HeadShape.bottom(1) < HeadShape.bottom(0), "chin lower")
	truthy(HeadShape.chinForward(-0.9, 1) > HeadShape.chinForward(-0.9, 0), "chin forward")
end

tests["profile is smooth in between tiers"] = function()
	local a = HeadShape.halfWidth(-0.6, 0, 0.5)
	local lo = math.min(HeadShape.halfWidth(-0.6, 0, 0), HeadShape.halfWidth(-0.6, 0, 1))
	local hi = math.max(HeadShape.halfWidth(-0.6, 0, 0), HeadShape.halfWidth(-0.6, 0, 1))
	truthy(a >= lo - 1e-6 and a <= hi + 1e-6, "halfway lies between")
end

return tests
