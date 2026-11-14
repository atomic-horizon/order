--[[ File Info

	Author(s): ChiefWildin
	Module: CycleReturnFirstB.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses export and requires CycleReturnFirstA (return), which is still loading.

]]

local CycleReturnFirstA = shared("CycleReturnFirstA")

export local Value = "CycleReturnFirstB"

export function GetOther()
	return CycleReturnFirstA
end
