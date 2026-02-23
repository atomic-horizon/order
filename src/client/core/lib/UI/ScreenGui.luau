--[[ File Info

	Author(s): ChiefWildin
	Module: ScreenGui.luau
	Version: 1.0.0

]]

--[=[
	@class ScreenGui
	@client

	Utility for creating `ScreenGui` instances with sensible defaults.
	Automatically parents to `PlayerGui` at runtime, or to `CoreGui` when
	running inside a story environment.
]=]

-- Services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Module Declaration

local ScreenGui = {}

-- Objects

local LocalPlayer = Players.LocalPlayer

-- Public Functions

--[=[
	Creates a new `ScreenGui` with `ResetOnSpawn` disabled and
	`ZIndexBehavior` set to `Sibling`, then parents it to `PlayerGui`.

	@param name string -- The name to assign to the ScreenGui
	@return ScreenGui
]=]
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
