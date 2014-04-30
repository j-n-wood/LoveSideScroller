math.clamp = function(val, mn, mx)
	if (val < mn) then return mn end
	if (val > mx) then return mx end
	return val
end

math.clampModulo = function(val, mn, mx)
	if (val < mn) then return mn end
	if (val > mx) then return val - mx end
	return val
end

math.sign = function(val)
	if (val > 0.0) then return 1.0 end
	if (val < 0.0) then return -1.0 end
	return 0.0
end

math.reduceMagnitude = function(val, by)
	if (val > 0.0) then
		return math.max(0.0, val - by)
	else
		return math.min(0.0, val + by)
	end
end

math.distance = function(v1, v2)
	local	dx = v2.x - v1.x
	local	dy = v2.y - v1.y
	return math.sqrt(dx * dx + dy * dy)
end

math.distance2 = function(v1, v2)
	local	dx = v2.x - v1.x
	local	dy = v2.y - v1.y
	return (dx * dx + dy * dy)
end
