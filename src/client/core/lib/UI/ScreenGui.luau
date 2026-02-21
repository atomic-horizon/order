--[[ File Info

	Author(s): ChiefWildin
	Module: ScreenGui.luau
	Version: 1.0.0

]]

-- Services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies

-- Types

-- Module Declaration

local ScreenGui = {}

-- Constants

-- Global Variables

-- Objects

local LocalPlayer = Players.LocalPlayer

-- Private Functions

-- Public Functions

function ScreenGui.new(name: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	if not RunService:IsRunning() then
		warn(`Story created ScreenGui "{name}"`)
		gui.Archivable = false
		gui.Parent = game.CoreGui
	else
		task.spawn(function()
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end)
	end

	return gui
end

return ScreenGui
