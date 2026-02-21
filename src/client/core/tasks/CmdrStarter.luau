--[[ File Info

    Author(s): ChiefWildin
    Module: CmdrStarter.lua
    Version: 1.0.0

]]

-- Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Declaration

local CmdrStarter = {}

-- Task Initialization

function CmdrStarter:Init()
	local CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient")) ---@module CmdrClient
	CmdrClient:SetActivationKeys({ Enum.KeyCode.F2 })
end

return CmdrStarter
