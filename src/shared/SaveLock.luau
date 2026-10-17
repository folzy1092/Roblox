-- Session lock for DataStore records: only one server may write a player's data.
-- Stored record shape: { data = Data?, lock = { jobId: string, time: number }? }
-- Pure functions, used inside UpdateAsync transforms. Unit-tested with Lune.
local SaveLock = {}

-- Autosave refreshes the lock every 60 s; a lock older than this is from a dead server.
SaveLock.LOCK_TTL = 150

local function lockedByOther(stored: any, jobId: string, now: number): boolean
	local lock = stored and stored.lock
	return lock ~= nil and lock.jobId ~= jobId and now - lock.time < SaveLock.LOCK_TTL
end

-- Returns the record to write and whether we now own the lock.
function SaveLock.tryClaim(stored: any, jobId: string, now: number): (any, boolean)
	if lockedByOther(stored, jobId, now) then
		return nil, false
	end
	return { data = stored and stored.data, lock = { jobId = jobId, time = now } }, true
end

-- Returns the record to write, or nil to cancel (we no longer own the lock).
function SaveLock.prepareSave(stored: any, data: any, jobId: string, now: number, release: boolean): any
	local lock = stored and stored.lock
	if not lock or lock.jobId ~= jobId then
		return nil
	end
	return {
		data = data,
		lock = if release then nil else { jobId = jobId, time = now },
	}
end

return SaveLock
