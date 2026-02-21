local TeleportService = game:GetService("TeleportService")

local GetBranches = shared("GetBranches") ---@module GetBranches

return function(_, branch: string, players: { Player })
	if not branch then
		return
	end

	local branches = GetBranches()

	local branchId = nil
	for _, branchInfo in branches do
		if string.lower(branchInfo.Name) == branch:lower() then
			branchId = branchInfo.PlaceId
			break
		end
	end

	if not branchId then
		return "Invalid branch"
	end

	TeleportService:TeleportAsync(branchId, players)

	return `Teleporting {#players} players to branch {branch}`
end
