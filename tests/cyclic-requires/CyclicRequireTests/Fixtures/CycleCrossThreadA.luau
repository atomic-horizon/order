--[[ File Info

	Author(s): ChiefWildin
	Module: CycleCrossThreadA.luau
	Version: 1.0.0

	Cyclic require test fixture. Loaded on its own thread, yields so that CycleCrossThreadB starts loading on another thread, then requires it.

]]

-- Constants

local DELAY_BEFORE_REQUIRE = 0.1
local DELAY_BEFORE_FINISHING = 0.3

task.wait(DELAY_BEFORE_REQUIRE)
local CycleCrossThreadB = shared("CycleCrossThreadB")
task.wait(DELAY_BEFORE_FINISHING)

export local Value = "CycleCrossThreadA"

export function GetOther()
	return CycleCrossThreadB
end
