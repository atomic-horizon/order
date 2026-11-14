--[[ File Info

	Module: UserIdOrPlayer.luau
	Version: 1.0.0

	A Cmdr argument type for commands whose target does not have to be in the
	server. A name picks a player in this server, with the same matching and
	autocomplete as the built-in player type, and a number is taken as a UserId.
	"." or "me" is the player running the command. Always parses to a UserId.

]]

-- Services

local Players = game:GetService("Players")

-- Task Initialization

return function(registry)
	local Util = registry.Cmdr.Util
	local findPlayers = Util.MakeFuzzyFinder(Players)

	local userIdOrPlayerType = {
		Transform = function(text: string, executor: Player)
			if text == "." or string.lower(text) == "me" then
				return { UserId = executor.UserId }
			end

			local userId = tonumber(text)
			if userId then
				return { UserId = userId }
			end

			local matches = findPlayers(text)
			return { UserId = if matches[1] then matches[1].UserId else nil, Matches = matches }
		end,

		Validate = function(result)
			if result.UserId == nil then
				return false, "No player with that name is in this server. Use their UserId instead."
			end

			-- Local test servers give players negative UserIds
			if result.UserId ~= math.floor(result.UserId) or result.UserId == 0 then
				return false, "UserIds are non-zero whole numbers."
			end

			return true
		end,

		Autocomplete = function(result)
			return if result.Matches then Util.GetNames(result.Matches) else {}
		end,

		Parse = function(result): number
			return result.UserId
		end,
	}

	registry:RegisterType("userIdOrPlayer", userIdOrPlayerType)
	registry:RegisterType("userIdsOrPlayers", Util.MakeListableType(userIdOrPlayerType))
end
