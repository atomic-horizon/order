--[[ File Info

	Module: PermissionsConfig.luau
	Version: 1.0.0

	Who holds which permission. PermissionService reads this module, so a
	project changes its permissions here without editing the service.

]]

--[=[
	@class PermissionsConfig

	Who holds which permission. Every table is keyed by permission label, such
	as "cmdr", except `Admins`. Edit the values in this module to set up
	permissions for a project.

	A check resolves in this order, and the first rule that applies wins:
	1. A runtime grant or revoke from `PermissionService:SetRuntimePermission()`
	2. `UserDeniedPermissions`
	3. `Admins`, then the test player and Studio settings
	4. `UserPermissions`
	5. `GroupPermissions`, checked with `GroupService:GetRolesInGroupAsync()`
]=]

return {
	-- Group roles that grant a permission:
	-- [label] = { [groupId] = { RoleIds = { roleId, ... } } }
	--
	-- Role IDs come from the "Copy Role ID" button at the bottom of a role's
	-- settings page. Roblox recommends matching role IDs, since rank values no
	-- longer decide a role's place in the hierarchy.
	-- Only public roles can be checked; GroupService does not return private
	-- roles.
	--
	-- `{ MinimumRank = number }`, or a bare number, matches any role at or above
	-- that rank instead. Rank is kept for groups that still rely on it, but it
	-- is deprecated by Roblox and should move to role IDs.
	GroupPermissions = {
		["cmdr"] = {
			[13911975] = { MinimumRank = 253 }, -- Atomic Horizon / Developer
		},
		["mod"] = {
			[13911975] = { MinimumRank = 250 }, -- Atomic Horizon / Moderator
		},
		["branches"] = {
			[13911975] = { MinimumRank = 253 }, -- Atomic Horizon / Developer
		},
	} :: { [string]: { [number]: GroupRule } },

	-- Users granted a permission regardless of their groups:
	-- [label] = { [userId] = true }
	UserPermissions = {} :: { [string]: { [number]: boolean } },

	-- Users denied a permission even when a group or admin entry would grant it:
	-- [label] = { [userId] = true }
	UserDeniedPermissions = {} :: { [string]: { [number]: boolean } },

	-- Users who hold every permission without a group check
	Admins = {
		[1924093] = true, -- ChiefWildin
		[35637443] = true, -- TactBacon
		[1964419047] = true, -- rib3ye
		[7234662645] = true, -- DoctorKurtJohnson
	} :: { [number]: boolean },

	-- Whether local test server players (UserId < 0) hold every permission
	TestPlayersHaveAllPermissions = true,

	-- Whether every player holds every permission in Studio play tests
	StudioHasAllPermissions = false,
}
