--[[ File Info

	Author(s): ChiefWildin
	Module: CycleOffExportA.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and requires CycleOffExportB, which requires this module back. Used with NativeCyclicRequires off.

]]

local CycleOffExportB = shared("CycleOffExportB")

export local Value = "CycleOffExportA"

export function GetOther()
	return CycleOffExportB
end
