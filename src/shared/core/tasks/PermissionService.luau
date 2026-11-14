--[[ File Info

	Author(s): ChiefWildin
	Module: PermissionService.lua
	Version: 1.2.0

]]

--[=[
	@class PermissionService

	Handles centralized permissions for different features.

	:::note
	Permissions are set in the `PermissionsConfig` module. See it for the order
	in which rules apply.
	:::
]=]

-- Services

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies

local CacheService = shared("CacheService")
local GetRemote = shared("GetRemote")
local PermissionsConfig = shared("PermissionsConfig")
local rcall = shared("rcall")

-- Types

type GroupRule = PermissionsConfig.GroupRule
type GroupRoles = {
	IsMember: boolean,
	Roles: { { Id: number, Name: string, Rank: number } },
}

-- Module Declaration

local PermissionService = {}

-- Constants

-- Runtime grants reach clients through a player attribute with this prefix
-- followed by the permission label
local RUNTIME_PERMISSION_ATTRIBUTE_PREFIX = "RuntimePermission_"
local IS_STUDIO = RunService:IsStudio()

-- Global Variables

local PermissionsRemote = GetRemote("Permissions")
-- One entry per player per label. CacheService clears a cache outright once it
-- passes its limit, so the limit must hold a full server checking every label.
local PermissionsCache = CacheService:CreateCache("Permissions", 1024, 60)
local UserGroupRolesCache = CacheService:CreateCache("Permissions.UserGroupRoles", 1024, 60)
local WarnedLegacyGroupRules: { [string]: boolean } = {}
-- [label] = { [userId] = granted }, set by SetRuntimePermission on the server
local RuntimePermissions: { [string]: { [number]: boolean } } = {}

-- Private Functions

local function getRuntimePermissionAttribute(label: string): string
	return `{RUNTIME_PERMISSION_ATTRIBUTE_PREFIX}{label}`
end

-- Answers every rule except group roles, or nil when group roles decide
local function resolveWithoutGroups(userId: number, label: string): boolean?
	local runtimeGrants = RuntimePermissions[label]
	if runtimeGrants and runtimeGrants[userId] ~= nil then
		return runtimeGrants[userId]
	end

	local deniedUsers = PermissionsConfig.UserDeniedPermissions[label]
	if deniedUsers and deniedUsers[userId] then
		return false
	end

	if PermissionsConfig.Admins[userId] then
		return true
	end

	if userId < 0 and PermissionsConfig.TestPlayersHaveAllPermissions then
		return true
	end

	if IS_STUDIO and PermissionsConfig.StudioHasAllPermissions then
		return true
	end

	local grantedUsers = PermissionsConfig.UserPermissions[label]
	if grantedUsers and grantedUsers[userId] then
		return true
	end

	if not PermissionsConfig.GroupPermissions[label] then
		return false
	end

	return nil
end

-- Returns the user's public roles in a group, or nil if the lookup failed
local function getUserGroupRoles(userId: number, groupId: number): GroupRoles?
	local cacheKey = `{userId}.{groupId}`
	local cachedRoles = UserGroupRolesCache:Get(cacheKey)
	if cachedRoles ~= nil then
		return cachedRoles
	end

	local groupRoles = rcall(
		{ retryLimit = 3, retryDelay = 2, jitter = true },
		GroupService.GetRolesInGroupAsync,
		GroupService,
		userId,
		groupId
	)
	if typeof(groupRoles) ~= "table" then
		return nil
	end

	UserGroupRolesCache:Set(cacheKey, groupRoles)
	return groupRoles
end

local function warnLegacyGroupRule(label: string, groupId: number): ()
	local warningKey = `{label}.{groupId}`
	if WarnedLegacyGroupRules[warningKey] then
		return
	end

	WarnedLegacyGroupRules[warningKey] = true
	warn(
		`[PermissionService] "{label}" uses a minimum rank for group {groupId}. Rank is deprecated by Roblox; use RoleIds in PermissionsConfig.`
	)
end

local function rolesMatchRule(groupRoles: GroupRoles, groupRule: GroupRule, label: string, groupId: number): boolean
	if not groupRoles.IsMember then
		return false
	end

	local roleIds = if typeof(groupRule) == "table" then groupRule.RoleIds else nil
	local minimumRank = if typeof(groupRule) == "number" then groupRule else groupRule.MinimumRank

	if roleIds then
		for _, role in groupRoles.Roles do
			if table.find(roleIds, role.Id) then
				return true
			end
		end
	end

	if minimumRank then
		warnLegacyGroupRule(label, groupId)

		for _, role in groupRoles.Roles do
			if role.Rank >= minimumRank then
				return true
			end
		end
	end

	return false
end

-- Checks the group roles a label requires. A failed lookup denies without
-- being cached, so a brief API outage does not lock anyone out for the
-- cache's lifetime.
local function resolveGroups(userId: number, label: string): boolean
	local cacheKey = `{userId}.{label}`
	local cachedCheck = PermissionsCache:Get(cacheKey)
	if cachedCheck ~= nil then
		return cachedCheck
	end

	local everyLookupAnswered = true
	for groupId, groupRule in PermissionsConfig.GroupPermissions[label] do
		local groupRoles = getUserGroupRoles(userId, groupId)
		if groupRoles == nil then
			everyLookupAnswered = false
			continue
		end

		if rolesMatchRule(groupRoles, groupRule, label, groupId) then
			PermissionsCache:Set(cacheKey, true)
			return true
		end
	end

	if everyLookupAnswered then
		PermissionsCache:Set(cacheKey, false)
	end

	return false
end

local function applyRuntimePermissionAttributes(player: Player): ()
	for label, runtimeGrants in RuntimePermissions do
		player:SetAttribute(getRuntimePermissionAttribute(label), runtimeGrants[player.UserId])
	end
end

-- Public Functions

--[=[
	Checks whether the player has the given permission. Returns `true` if they
	do, or `false` if no rule grants it.

	On the client, runtime grants are seen through a replicated attribute, so
	a check made before the attribute arrives can miss one.

	@param player Player -- The player to check
	@param permission string -- The permission label to check against
	@return boolean -- Whether the player has the permission
	@yields
]=]
function PermissionService:HasPermission(player: Player, permission: string): boolean
	local runtimeGrant = player:GetAttribute(getRuntimePermissionAttribute(permission))
	if typeof(runtimeGrant) == "boolean" then
		return runtimeGrant
	end

	local resolved = resolveWithoutGroups(player.UserId, permission)
	if resolved ~= nil then
		return resolved
	end

	return resolveGroups(player.UserId, permission)
end

--[=[
	Checks whether any user has the given permission, including users who are
	not in this server.

	Runtime grants are only known to the server, so on the client this
	answers from `PermissionsConfig` and group roles alone.

	@param userId number -- The UserId to check
	@param permission string -- The permission label to check against
	@return boolean -- Whether the user has the permission
	@yields
]=]
function PermissionService:UserHasPermission(userId: number, permission: string): boolean
	if typeof(userId) ~= "number" then
		warn(`[PermissionService] UserHasPermission expected a number, got {typeof(userId)}`)
		return false
	end

	local playerInServer = Players:GetPlayerByUserId(userId)
	if playerInServer then
		return self:HasPermission(playerInServer, permission)
	end

	local resolved = resolveWithoutGroups(userId, permission)
	if resolved ~= nil then
		return resolved
	end

	return resolveGroups(userId, permission)
end

--[=[
	@server

	Grants or revokes a permission for a user until the server shuts down,
	overriding `PermissionsConfig` and group roles. Pass `nil` to remove the
	override. Not saved, so a grant lasts only for this server.

	@param permission string -- The permission label to override
	@param userId number -- The UserId to override it for
	@param granted boolean? -- true grants, false revokes, nil removes the override
]=]
function PermissionService:SetRuntimePermission(permission: string, userId: number, granted: boolean?): ()
	if not RunService:IsServer() then
		warn("[PermissionService] SetRuntimePermission can only be called on the server")
		return
	end

	if typeof(permission) ~= "string" or typeof(userId) ~= "number" then
		warn("[PermissionService] SetRuntimePermission expected a permission label and a UserId")
		return
	end

	local runtimeGrants = RuntimePermissions[permission]
	if not runtimeGrants then
		runtimeGrants = {}
		RuntimePermissions[permission] = runtimeGrants
	end

	runtimeGrants[userId] = granted

	local playerInServer = Players:GetPlayerByUserId(userId)
	if playerInServer then
		playerInServer:SetAttribute(getRuntimePermissionAttribute(permission), granted)
	end
end

-- Task Initialization

function PermissionService:Init()
	if not RunService:IsServer() then
		return
	end

	Players.PlayerAdded:Connect(applyRuntimePermissionAttributes)
	for _, player in Players:GetPlayers() do
		applyRuntimePermissionAttributes(player)
	end

	PermissionsRemote:OnInvoke(function(player, permission)
		if typeof(permission) ~= "string" then
			return false
		end

		return self:HasPermission(player, permission)
	end)
end

return PermissionService
