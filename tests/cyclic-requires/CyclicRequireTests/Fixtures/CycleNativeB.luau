--[[ File Info

	Author(s): ChiefWildin
	Module: CycleNativeB.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and requires CycleNativeA, which is still loading.

]]

local CycleNativeA = shared("CycleNativeA")

export local Value = "CycleNativeB"

export function GetOther()
	return CycleNativeA
end
