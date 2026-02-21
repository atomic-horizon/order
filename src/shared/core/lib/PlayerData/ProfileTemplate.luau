local ProfileTemplate = {
	AwardedBadges = {},
	PendingBadges = {},
}

-- Prevents accidental modification of the template
local function freezeData(data: {}): ()
	table.freeze(data)

	for _, value: any in pairs(data) do
		if typeof(value) == "table" then
			freezeData(value)
		end
	end
end
freezeData(ProfileTemplate)

return ProfileTemplate
