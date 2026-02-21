--[[ File Info

	Author(s): ChiefWildin
	Module: PermissionService.lua
	Version: 1.0.0

	Handles centralized permissions for different features.

--]]

--[[ Setup

	1. Update the PERMISSIONS table to include appropriate permissions for the
	   new group hosting the project.

]]

-- Dependencies

local CacheService = shared("CacheService") ---@module CacheService
local GetRemote = shared("GetRemote") ---@module GetRemote
local rcall = shared("rcall") ---@module rcall

-- Module Declaration

local PermissionService = {}

-- Constants

-- Whether to allow local test server players (UserId < 0) to have all
-- permissions.
local TEST_PLAYERS_ALL_PERMS = true

-- A list of permissions for each group. The key is the group ID and the value
-- is the minimum rank required in that group to have the permission.
local GROUP_PERMISSIONS = {
	["cmdr"] = {
		[13911975] = 253, -- Atomic Horizon / Developer
	},
	["mod"] = {
		[13911975] = 250, -- Atomic Horizon / Moderator
	},
}

-- A list of user IDs for players who should have all permissions. Skips group
-- check. Will award the developer banner to these players.
local ADMINS = {
	[1924093] = true, -- ChiefWildin
	[35637443] = true, -- TactBacon
	[1964419047] = true, -- rib3ye
	[7234662645] = true, -- DoctorKurtJohnson
}

-- Global Variables

local PermissionsRemote = GetRemote("Permissions")
local PermissionsCache = CacheService:CreateCache("Permissions", 50, 60)

-- Public Functions

-- Checks whether the player has permissions for the given label. Returns true
-- if they do, or false if their rank is too low.
function PermissionService:HasPermission(player: Player, permission: string): boolean
	if (player.UserId < 0 and TEST_PLAYERS_ALL_PERMS) or ADMINS[player.UserId] then
		return true
	end

	if not GROUP_PERMISSIONS[permission] then
		return false
	end

	local cachedCheck = PermissionsCache:Get(`{player.UserId}.{permission}`)
	if cachedCheck ~= nil then
		return cachedCheck
	end

	for groupId, minimumRank in GROUP_PERMISSIONS[permission] do
		local rank = rcall({ retryLimit = 3, retryDelay = 2 }, player.GetRankInGroup, player, groupId)
		if rank and rank >= minimumRank then
			PermissionsCache:Set(`{player.UserId}.{permission}`, true)
			return true
		end
	end

	PermissionsCache:Set(`{player.UserId}.{permission}`, false)
	return false
end

-- Task Initialization

function PermissionService:Run()
	PermissionsRemote:OnInvoke(function(player, permission)
		return self:HasPermission(player, permission)
	end)
end

return PermissionService
