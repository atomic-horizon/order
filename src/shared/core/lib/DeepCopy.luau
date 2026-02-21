local function DeepCopy(target: {}): {}
	local copy = {}

	for key, value in pairs(target) do
		if typeof(value) == "table" then
			copy[key] = DeepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

return DeepCopy
