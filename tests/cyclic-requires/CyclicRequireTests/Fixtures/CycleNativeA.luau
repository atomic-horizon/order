--[[ File Info

	Author(s): ChiefWildin
	Module: CycleNativeA.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and requires CycleNativeB, which requires this module back.

]]

local CycleNativeB = shared("CycleNativeB")

export local Value = "CycleNativeA"

export function GetOther()
	return CycleNativeB
end
