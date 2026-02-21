--[[
	AnalyticsClient.lua
	ChiefWildin
	Version: 1.2.0
]]

-- Services

-- Main job table

local AnalyticsClient = { Priority = 5000 }

-- Dependencies

local GamebeastSDK = shared("GamebeastSDK") ---@module GamebeastSDK

-- Constants

-- Global variables

-- Objects

-- Private functions

-- Public functions

-- Framework callbacks

function AnalyticsClient:Init()
	GamebeastSDK:Setup()
end

return AnalyticsClient
