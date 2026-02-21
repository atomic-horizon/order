--[[ File Info

	Author(s): ChiefWildin
	Module: BadgeGiver.luau
	Version: 1.0.1

]]

-- Services

local BadgeService = game:GetService("BadgeService")
local RunService = game:GetService("RunService")

-- Dependencies

local PlayerData = shared("PlayerData") ---@module PlayerData
local rcall = shared("rcall") ---@module rcall

-- Module Declaration

--[=[
	@class BadgeGiver

	Handles awarding badges to players.
]=]
local BadgeGiver = {}

-- Constants

local STUDIO_PRINTS_ENABLED = false

-- Public Functions

--[=[
	Awards the specified badge to the player if they do not already have it.
	Otherwise, records that we've already given the badge to this player in
	their data profile.

	@yields
	@param player Player -- The player to award the badge to.
	@param badgeId number -- The ID of the badge to award.
]=]
function BadgeGiver:GiveBadge(player: Player, badgeId: number)
	-- Don't even try if we already know it's been awarded
	if not RunService:IsRunning() or PlayerData:GetValue(player, { "AwardedBadges", badgeId }) then
		return
	end

	if RunService:IsStudio() then
		if STUDIO_PRINTS_ENABLED then
			print("Badge award attempt -", player, badgeId)
		end

		return
	end

	if rcall({ retryLimit = 3 }, BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId) then
		-- Need to double check because player might have left during ownership
		-- check
		if player.Parent then
			PlayerData:SetValue(player, { "AwardedBadges", badgeId }, true)
		end

		return
	end

	-- Need to double check because player might have left during ownership
	-- check
	rcall({ retryLimit = 3 }, BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)

	if player.Parent then
		PlayerData:SetValue(player, { "AwardedBadges", badgeId }, true)
	end
end

return BadgeGiver
