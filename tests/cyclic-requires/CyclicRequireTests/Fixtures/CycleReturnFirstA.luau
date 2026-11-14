--[[ File Info

	Author(s): ChiefWildin
	Module: CycleReturnFirstA.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses return and requires CycleReturnFirstB (export), which requires this module back.

]]

local CycleReturnFirstB = shared("CycleReturnFirstB")

local CycleReturnFirstA = {
	Value = "CycleReturnFirstA",
}

function CycleReturnFirstA.GetOther()
	return CycleReturnFirstB
end

return CycleReturnFirstA
