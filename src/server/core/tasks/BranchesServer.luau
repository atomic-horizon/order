--[[ File Info

	Module: BranchesServer.luau
	Version: 1.0.0

	Handles teleport requests from the Branches pane. Only players with the
	"branches" permission are teleported, and only to places in this game.

]]

-- Services

local TeleportService = game:GetService("TeleportService")

-- Dependencies

local GetBranches = shared("GetBranches")
local GetRemote = shared("GetRemote")
local PermissionService = shared("PermissionService")
local rcall = shared("rcall")

-- Module Declaration

local BranchesServer = {}

-- Constants

-- Seconds a player must wait between teleport requests
local REQUEST_INTERVAL = 2

-- Global Variables

local TeleportRequestRemote = GetRemote("BranchesPane:TeleportToPlace")

-- Private Functions

local function isGamePlace(placeId: number): boolean
	for _, branch in GetBranches() do
		if branch.PlaceId == placeId then
			return true
		end
	end

	return false
end

local function onTeleportRequested(player: Player, placeId: any): ()
	if typeof(placeId) ~= "number" then
		return
	end

	if not PermissionService:HasPermission(player, "branches") then
		return
	end

	if not isGamePlace(placeId) then
		warn(`[BranchesServer] {player.Name} requested a place outside this game ({placeId})`)
		return
	end

	rcall({ retryLimit = 3, retryDelay = 2 }, TeleportService.TeleportAsync, TeleportService, placeId, { player })
end

-- Task Initialization

function BranchesServer:Init(): ()
	TeleportRequestRemote:OnEvent(onTeleportRequested, REQUEST_INTERVAL)
end

return BranchesServer
