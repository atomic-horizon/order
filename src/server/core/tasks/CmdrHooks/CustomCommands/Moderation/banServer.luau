-- Services
local Players = game:GetService("Players")

return function(_, players: {Player}, duration: number, publicReason: string, privateReason: string, alsoBanAlts: boolean)
	if #publicReason > 400 then
		return "Public reason is too long. Please keep it under 400 characters."
	end
	if #privateReason > 1000 then
		return "Private reason is too long. Please keep it under 1000 characters."
	end
	if duration < 0 then
		return "Duration must be a positive number."
	end

	local ids = {}
	for _, player in ipairs(players) do
		table.insert(ids, player.UserId)
	end

	Players:BanAsync({
		UserIds = ids,
		ApplyToUniverse = true,
		Duration = if duration == 0 then -1 else duration * 86400,
		DisplayReason = publicReason,
		PrivateReason = privateReason,
		ExcludeAltAccounts = not alsoBanAlts,
	})

	return `Banned {#players} players {if duration == 0 then "permanently." else "for " .. duration .. " days."}`
end