--[[
	AnalyticsClient.lua
	ChiefWildin
	Version: 1.3.0
]]

-- Services

-- Main job table

local AnalyticsClient = { Priority = 5000 }

-- Dependencies

local GamebeastSDK = shared("GamebeastSDK") ---@module GamebeastSDK

-- Constants

-- Set on workspace by AnalyticsServer once it knows whether a Gamebeast key
-- was found
local GAMEBEAST_ENABLED_ATTRIBUTE = "GamebeastEnabled"

-- Global variables

-- Objects

-- Private functions

-- Public functions

-- Framework callbacks

function AnalyticsClient:Init()
	while workspace:GetAttribute(GAMEBEAST_ENABLED_ATTRIBUTE) == nil do
		workspace:GetAttributeChangedSignal(GAMEBEAST_ENABLED_ATTRIBUTE):Wait()
	end

	-- The client SDK waits for remotes that the server only creates in Setup
	if workspace:GetAttribute(GAMEBEAST_ENABLED_ATTRIBUTE) ~= true then
		return
	end

	GamebeastSDK:Setup()
end

return AnalyticsClient
