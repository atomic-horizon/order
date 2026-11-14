--[[ File Info

	Author(s): ChiefWildin
	Module: CycleTopLevelB.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and reads a field of CycleTopLevelA at its top level while CycleTopLevelA is still loading.

]]

local CycleTopLevelA = shared("CycleTopLevelA")

local topLevelReadSuccess, topLevelReadResult = pcall(function()
	return CycleTopLevelA.Value
end)

export local Value = "CycleTopLevelB"
export local TopLevelReadSucceeded = topLevelReadSuccess
export local TopLevelReadResult = tostring(topLevelReadResult)

export function GetOther()
	return CycleTopLevelA
end
