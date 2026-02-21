--[[

	Author(s): ChiefWildin
	Module: PlayerUtils.lua
	Version: 2.0.0

	Provides utility functions for working with players.

]]

--[[ API

	::OnPlayerAdded(callback: function, callbackName: string): function
		Add a callback for any player, existing and future, that joins.
		Example:
		```lua
			PlayerUtils:OnPlayerAdded(function(player, playerMaid)
				print(`Hello, {player.Name}!`)
			end, "CallbackName")
		```

	::RemoveJoinCallback(callbackName: string)
		Remove a spawn callback by name.
		Example:
		```lua
			PlayerUtils:RemoveJoinCallback("Callback")
		```

	::GetPlayerMaid(player: Player): Maid
        Returns the maid associated with a specific player, which cleans up
		when the player disconnects.
		Example:
		```lua
			local character = PlayerUtils:GetPlayerMaid(player, true)
		```

	::FetchUserInfo(userId: number): table?
        Fetch the user info for the user with the specified UserId from the
		Roblox website.
		Example:
		```lua
			local character = PlayerUtils:GetUserInfo(player, true)
		```
]]

-- Services

local Players = game:GetService("Players")
local UserService = game:GetService("UserService")

-- Dependencies

local Maid = shared("Maid") ---@module Maid
local rcall = shared("rcall") ---@module rcall

-- Types

type Maid = Maid.Maid
type UserInfo = {
	Id: number,
	Username: string,
	DisplayName: string,
	HasVerifiedBadge: boolean,
}

-- Module

local PlayerUtils = {}

-- Global Variables

local JoinCallbacks = {} :: { [string | number]: (player: Player, playerMaid: Maid) -> () }
local PlayerMaids = {} :: { [Player]: { Maid } }
local UserInfo = {} :: { [number]: UserInfo }

-- Public Functions

-- Adds a callback for any player, existing and future, that joins.
--@param callback function (player: Player, playerMaid: Maid) -> ()
--@param callbackName string? The name of the callback to add (optional)
function PlayerUtils:OnPlayerAdded(callback: (player: Player, maid: Maid) -> (), callbackName: string?)
	if not callbackName then
		table.insert(JoinCallbacks, callback)
	else
		JoinCallbacks[callbackName] = callback
	end

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			callback(player, self:GetPlayerMaid(player))
		end)
	end
end

-- Remove a callback for all players when they spawn, future and existing
--@param callbackName string The name of the callback to remove
function PlayerUtils:RemoveJoinCallback(callbackName: string)
	if not JoinCallbacks[callbackName] then
		return
	end

	JoinCallbacks[callbackName] = nil
end

-- Get the maid for the player
--@param player Player The player to get the maid for
--@return table Maid The PlayerMaid for the player
function PlayerUtils:GetPlayerMaid(player: Player): Maid
	assert(player, "Must provide a Player object to fetch maid")

	if not PlayerMaids[player] then
		PlayerMaids[player] = Maid.new()
	end

	return PlayerMaids[player]
end

-- Fetch the user info for the user with the specified UserId from the Roblox
-- website
--@param userId number The UserId to get the user info from
--@return table UserInfo The users info
function PlayerUtils:FetchUserInfo(userId: number): UserInfo?
	local cachedInfo = UserInfo[userId]
	if cachedInfo then
		return cachedInfo
	end

	local success, result = rcall({ retryLimit = 3, retryDelay = 5 }, function()
		return UserService:GetUserInfosByUserIdsAsync({ userId })
	end)

	if not success then
		return nil
	end

	if result and typeof(result) == "table" and #result > 0 then
		local userInfo = result[1]
		UserInfo[userId] = userInfo

		return userInfo
	end

	return nil
end

-- Initialization

function PlayerUtils:Init()
	Players.PlayerAdded:Connect(function(player)
		local playerMaid = PlayerUtils:GetPlayerMaid(player)

		for _, callback in JoinCallbacks do
			task.spawn(callback, player, playerMaid)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if PlayerMaids[player] then
			PlayerMaids[player]:Destroy()
			PlayerMaids[player] = nil
		end
	end)
end

return PlayerUtils
