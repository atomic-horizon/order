--[[ File Info

	Author(s): ChiefWildin
	Module: DebugPart.lua
	Version: 1.0.0

]]

-- Services

local Debris = game:GetService("Debris")

-- Types

export type DebugPartProperties = {
	Parent: Instance?,
	Size: Vector3?,
	CFrame: CFrame?,
	Name: string?,
	Position: Vector3?,
	Orientation: Vector3?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Transparency: number?,
	Color: Color3?,
	Lifetime: number?,
}

-- Module Declaration

local DebugPart = {}
DebugPart.__index = DebugPart

-- Global Variables

local Count = 0

-- Public Functions

function DebugPart.new(properties: DebugPartProperties)
	Count += 1

	local self = setmetatable({}, DebugPart)

	self._part = Instance.new("Part")
	self._part.Size = properties.Size or Vector3.new(1, 1, 1)
	self._part.Position = properties.Position or Vector3.new(0, 0, 0)
	self._part.Orientation = properties.Orientation or Vector3.new(0, 0, 0)
	self._part.Anchored = properties.Anchored or true
	self._part.CanCollide = properties.CanCollide or false
	self._part.Transparency = properties.Transparency or 0.5
	self._part.Color = properties.Color or Color3.fromRGB(255, 0, 0)
	self._part.Name = properties.Name or "DebugPart" .. Count

	if properties.CFrame then
		self._part.CFrame = properties.CFrame
	end

	if properties.Lifetime then
		Debris:AddItem(self._part, properties.Lifetime)
	end

	self._part.Parent = properties.Parent or workspace

	return self
end

return DebugPart
