local assert = {}

function assert.eq(actual, expected, msg)
	if actual ~= expected then
		error(`{msg or "eq"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function assert.truthy(v, msg)
	if not v then
		error(`{msg or "truthy"}: got {tostring(v)}`, 2)
	end
end

return assert
