--[[
    Author: ChiefWildin
    Module: CmdrHooks.lua
    Version: 1.1.0
]]

-- Services

-- Dependencies

local Cmdr = shared("Cmdr") ---@module Cmdr

-- Types

-- Module Declaration

local CmdrHooks = {}

-- Constants

-- Global Variables

-- Objects

-- Private Functions

-- Public Functions

-- Job Initialization

function CmdrHooks:Init()
	Cmdr:RegisterDefaultCommands()
    Cmdr:RegisterCommandsIn(script.CustomCommands)
    Cmdr:RegisterTypesIn(script.CustomTypes)
	Cmdr:RegisterHooksIn(script.CustomHooks)
end

return CmdrHooks
