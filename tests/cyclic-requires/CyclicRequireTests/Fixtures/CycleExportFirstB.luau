--[[ File Info

	Author(s): ChiefWildin
	Module: CycleExportFirstB.luau
	Version: 1.0.0

	Cyclic require test fixture. Uses return and requires CycleExportFirstA (export), which is still loading.

]]

local CycleExportFirstA = shared("CycleExportFirstA")

local CycleExportFirstB = {
	Value = "CycleExportFirstB",
}

function CycleExportFirstB.GetOther()
	return CycleExportFirstA
end

return CycleExportFirstB
