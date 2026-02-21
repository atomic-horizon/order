--[[
	Author(s): ChiefWildin
	Module: Permissions.lua
	Version: 1.1.0

	Determines who is allowed to run commands with cmdr.
]]

-- Dependencies

local PermissionService = shared("PermissionService") ---@module PermissionService

-- Constants

local MOD_COMMANDS = {
	"kick",
	"boot",
	"ban",
	"banid",
	"banuser",
	"unban",
	"unbanid",
	"unbanuser",
}

-- Public Functions

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		local hasPermission: boolean = PermissionService:HasPermission(context.Executor, "cmdr")
			or (
				table.find(MOD_COMMANDS, context.Alias) ~= nil
				and PermissionService:HasPermission(context.Executor, "mod")
			)
		if not hasPermission then
			return "You don't have permission to run this command"
		end
	end)
end
