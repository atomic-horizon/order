--[[ File Info

	Author(s): ChiefWildin
	Module: CycleCrossThreadB.luau
	Version: 1.0.0

	Cyclic require test fixture. Loaded on its own thread, yields, then requires CycleCrossThreadA while it is still loading on another thread.

]]

-- Constants

local DELAY_BEFORE_REQUIRE = 0.2

task.wait(DELAY_BEFORE_REQUIRE)
local CycleCrossThreadA = shared("CycleCrossThreadA")

export local Value = "CycleCrossThreadB"

export function GetOther()
	return CycleCrossThreadA
end
