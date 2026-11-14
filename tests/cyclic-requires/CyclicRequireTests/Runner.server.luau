--[[ File Info

	Author(s): ChiefWildin
	Module: Runner.server.luau
	Version: 1.0.0

	Runs the cyclic require test matrix on the server once Order has initialized.

]]

local RunTests = require(script.Parent:WaitForChild("RunTests"))

RunTests.Run("Server")
