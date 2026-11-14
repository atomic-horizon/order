--[[ File Info

	Author(s): ChiefWildin
	Module: CycleOffExportB.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and requires CycleOffExportA, which is still loading. Used with NativeCyclicRequires off.

]]

local CycleOffExportA = shared("CycleOffExportA")

export local Value = "CycleOffExportB"

export function GetOther()
	return CycleOffExportA
end
