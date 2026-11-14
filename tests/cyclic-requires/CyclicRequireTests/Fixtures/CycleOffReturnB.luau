--[[ File Info

	Author(s): ChiefWildin
	Module: CycleOffReturnB.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses return and requires CycleOffReturnA, which is still loading.

]]

local CycleOffReturnA = shared("CycleOffReturnA")

local CycleOffReturnB = {
	Value = "CycleOffReturnB",
}

function CycleOffReturnB.GetOther()
	return CycleOffReturnA
end

return CycleOffReturnB
