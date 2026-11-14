--[[
    Author: ChiefWildin
    Module: CmdrHooks.lua
    Version: 1.1.1
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
	Cmdr.Registry:RegisterDefaultCommands()
	Cmdr.Registry:RegisterCommandsIn(script.CustomCommands)
	Cmdr.Registry:RegisterTypesIn(script.CustomTypes)
	Cmdr.Registry:RegisterHooksIn(script.CustomHooks)
end

return CmdrHooks
