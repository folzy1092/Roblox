local fs = require("@lune/fs")
local process = require("@lune/process")

local failed, passed = 0, 0
for _, name in fs.readDir("tests") do
	if name:match("%.spec%.luau$") then
		local tests = require("./" .. name:gsub("%.luau$", ""))
		for testName, fn in tests do
			local ok, err = pcall(fn)
			if ok then
				passed += 1
				print(`PASS {name} :: {testName}`)
			else
				failed += 1
				print(`FAIL {name} :: {testName}: {err}`)
			end
		end
	end
end
print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
