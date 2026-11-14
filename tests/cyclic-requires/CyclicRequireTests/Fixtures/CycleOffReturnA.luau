--[[ File Info

	Author(s): ChiefWildin
	Module: CycleOffReturnA.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses return and requires CycleOffReturnB, which requires this module back.

]]

local CycleOffReturnB = shared("CycleOffReturnB")

local CycleOffReturnA = {
	Value = "CycleOffReturnA",
}

function CycleOffReturnA.GetOther()
	return CycleOffReturnB
end

return CycleOffReturnA
