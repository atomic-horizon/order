--[[
	AnalyticsServer.luau
	ChiefWildin
    Version: 1.2.0
]]

-- Services

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Dependencies

local GamebeastSDK = shared("GamebeastSDK") ---@module GamebeastSDK

local GamebeastMarkers = GamebeastSDK:GetService("Markers")

-- Main job table

local AnalyticsServer = {}

-- Constants

-- Global Variables

local FunnelSessionIds: { [Player]: string } = {}

-- Local functions

-- Public functions

-- Framework callbacks

function AnalyticsServer:Prep()
	local fetchSuccess, gamebeastSecret = pcall(HttpService.GetSecret, HttpService, "Gamebeast")
	if fetchSuccess then
		GamebeastSDK:Setup({
			key = gamebeastSecret,
			sdkSettings = {
				sdkDebugEnabled = false,
				sdkWarningsEnabled = false,
				includeWarningStackTrace = false,
			},
		})
	else
		print("[AnalyticsServer]: Gamebeast API secret not found. Gamebeast analytics will be disabled.")
	end

	local function setupPlayer(player: Player)
		if player:IsA("Configuration") then
			return
		end

		FunnelSessionIds[player] = HttpService:GenerateGUID(false)
	end
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		if player:IsA("Configuration") then
			return
		end

		FunnelSessionIds[player] = nil
	end)
end

function AnalyticsServer:Init() end

return AnalyticsServer
