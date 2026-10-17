local L = require("../src/shared/SaveLock")
local A = require("./assert")
local eq, truthy = A.eq, A.truthy

local tests = {}

tests["claim empty key"] = function()
	local stored, claimed = L.tryClaim(nil, "A", 100)
	truthy(claimed)
	eq(stored.lock.jobId, "A")
	eq(stored.lock.time, 100)
	eq(stored.data, nil)
end

tests["claim blocked by fresh foreign lock"] = function()
	local current = { data = { rating = 5 }, lock = { jobId = "B", time = 100 } }
	local stored, claimed = L.tryClaim(current, "A", 100 + L.LOCK_TTL - 1)
	eq(claimed, false)
	eq(stored, nil)
end

tests["claim steals expired lock and keeps data"] = function()
	local current = { data = { rating = 5 }, lock = { jobId = "B", time = 100 } }
	local stored, claimed = L.tryClaim(current, "A", 100 + L.LOCK_TTL)
	truthy(claimed)
	eq(stored.lock.jobId, "A")
	eq(stored.data.rating, 5)
end

tests["claim own lock again"] = function()
	local current = { data = { rating = 5 }, lock = { jobId = "A", time = 1 } }
	local _, claimed = L.tryClaim(current, "A", 999999)
	truthy(claimed)
end

tests["save refused when another server owns lock"] = function()
	local current = { data = { rating = 50 }, lock = { jobId = "B", time = 100 } }
	eq(L.prepareSave(current, { rating = 5 }, "A", 101, false), nil)
end

tests["save writes data and refreshes lock"] = function()
	local current = { data = { rating = 1 }, lock = { jobId = "A", time = 100 } }
	local stored = L.prepareSave(current, { rating = 5 }, "A", 160, false)
	eq(stored.data.rating, 5)
	eq(stored.lock.time, 160)
end

tests["release save clears lock"] = function()
	local current = { data = { rating = 1 }, lock = { jobId = "A", time = 100 } }
	local stored = L.prepareSave(current, { rating = 5 }, "A", 160, true)
	eq(stored.data.rating, 5)
	eq(stored.lock, nil)
end

tests["save refused when lock already released"] = function()
	-- our lock is gone (released or stolen after expiry): do not write stale data
	local current = { data = { rating = 9 } }
	eq(L.prepareSave(current, { rating = 5 }, "A", 160, false), nil)
end

return tests
