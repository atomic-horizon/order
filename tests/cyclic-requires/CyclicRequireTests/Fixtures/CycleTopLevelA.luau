--[[ File Info

	Author(s): ChiefWildin
	Module: CycleTopLevelA.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and requires CycleTopLevelB, which reads from this module at its top level.

]]

local CycleTopLevelB = shared("CycleTopLevelB")

export local Value = "CycleTopLevelA"

export function GetOther()
	return CycleTopLevelB
end
