-- Services
local Players = game:GetService("Players")

return function(_, username: string)
	local userId = Players:GetUserIdFromNameAsync(username)

	Players:UnbanAsync({
		UserIds = { userId },
		ApplyToUniverse = true,
	})

	return `Unbanned {username} ({userId})`
end
