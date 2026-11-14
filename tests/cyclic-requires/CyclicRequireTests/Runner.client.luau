--[[ File Info

	Author(s): ChiefWildin
	Module: Runner.client.luau
	Version: 1.0.0

	Runs the cyclic require test matrix on the client once Order has initialized.

]]

local RunTests = require(script.Parent:WaitForChild("RunTests"))

RunTests.Run("Client")
