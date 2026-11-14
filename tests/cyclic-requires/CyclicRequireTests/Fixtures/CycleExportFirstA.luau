--[[ File Info

	Author(s): ChiefWildin
	Module: CycleExportFirstA.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and requires CycleExportFirstB (return), which requires this module back.

]]

local CycleExportFirstB = shared("CycleExportFirstB")

export local Value = "CycleExportFirstA"

export function GetOther()
	return CycleExportFirstB
end
