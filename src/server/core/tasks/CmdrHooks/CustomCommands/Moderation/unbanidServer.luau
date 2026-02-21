-- Services
local Players = game:GetService("Players")

return function(_, userId: number)
	Players:UnbanAsync({
		UserIds = { userId },
		ApplyToUniverse = true,
	})

	local username = Players:GetNameFromUserIdAsync(userId)

	return `Unbanned {username} ({userId})`
end
