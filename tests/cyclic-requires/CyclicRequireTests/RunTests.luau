--[[ File Info

	Author(s): ChiefWildin
	Module: RunTests.luau
	Version: 1.0.0

	Runs the cyclic require test matrix against Order's hybrid cyclic require handling and prints a pass/fail report. Needs the Luau Modularity Studio beta for the cases that use export syntax.

]]

-- Services

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types

type TestResult = {
	Name: string,
	Passed: boolean,
	Message: string?,
}

type TestCase = {
	Name: string,
	NativeCyclicRequires: boolean,
	Run: () -> string?,
}

-- Module Declaration

local RunTests = {}

-- Constants

local CROSS_THREAD_TIMEOUT = 5
local REPORT_PREFIX = "[CyclicRequireTests]"

-- Global Variables

local Order = require(ReplicatedStorage:WaitForChild("Order"))
local Settings = require(ReplicatedStorage.Order:WaitForChild("Settings"))
local CrossThreadPlaceholder: any = nil

-- Private Functions

local function expect(condition: any, failureMessage: string)
	if not condition then
		error(failureMessage, 0)
	end
end

-- Order's placeholders keep the module's name as a raw field and carry a
-- metatable that forwards to the real module
local function isPlaceholder(moduleTable: any): boolean
	return typeof(moduleTable) == "table" and rawget(moduleTable, "Name") ~= nil and getmetatable(moduleTable) ~= nil
end

local function describeModuleTable(moduleTable: any): string
	if isPlaceholder(moduleTable) then
		return "Order placeholder"
	elseif typeof(moduleTable) == "table" and table.isfrozen(moduleTable) then
		return "Luau export table"
	end
	return typeof(moduleTable)
end

local function requireOnSeparateThreads(moduleNames: { string }, timeout: number): boolean
	local remainingModules = #moduleNames
	for _, moduleName in moduleNames do
		task.spawn(function()
			shared(moduleName)
			remainingModules -= 1
		end)
	end

	local startTime = os.clock()
	while remainingModules > 0 and os.clock() - startTime < timeout do
		task.wait()
	end

	return remainingModules == 0
end

-- Objects

local TestCases: { TestCase } = {
	{
		Name = "Setting off: return cycle uses Order's placeholder",
		NativeCyclicRequires = false,
		Run = function()
			local moduleA = shared("CycleOffReturnA")
			local moduleB = shared("CycleOffReturnB")
			expect(moduleA ~= nil and moduleB ~= nil, "a module in the cycle failed to load")

			local heldReference = moduleB.GetOther()
			expect(moduleA.Value == "CycleOffReturnA", "CycleOffReturnA is missing its values")
			expect(isPlaceholder(heldReference), `expected a placeholder, got {describeModuleTable(heldReference)}`)
			expect(heldReference.Value == "CycleOffReturnA", "placeholder does not forward reads")
			expect(moduleA.GetOther().Value == "CycleOffReturnB", "CycleOffReturnA cannot reach CycleOffReturnB")
			return nil
		end,
	},
	{
		Name = "Setting off: export cycle uses Order's placeholder",
		NativeCyclicRequires = false,
		Run = function()
			local moduleA = shared("CycleOffExportA")
			local moduleB = shared("CycleOffExportB")
			expect(moduleA ~= nil and moduleB ~= nil, "a module in the cycle failed to load")

			local heldReference = moduleB.GetOther()
			expect(moduleA.Value == "CycleOffExportA", "CycleOffExportA is missing its values")
			expect(isPlaceholder(heldReference), `expected a placeholder, got {describeModuleTable(heldReference)}`)
			expect(heldReference.Value == "CycleOffExportA", "placeholder does not forward reads")
			return nil
		end,
	},
	{
		Name = "Setting on: export cycle on one thread uses Luau's export table",
		NativeCyclicRequires = true,
		Run = function()
			local moduleA = shared("CycleNativeA")
			local moduleB = shared("CycleNativeB")
			expect(moduleA ~= nil and moduleB ~= nil, "a module in the cycle failed to load")

			local heldReference = moduleB.GetOther()
			expect(
				not isPlaceholder(heldReference),
				`expected Luau's export table, got {describeModuleTable(heldReference)}`
			)
			expect(rawequal(heldReference, moduleA), "held reference is not the same table shared() returns")
			expect(table.isfrozen(heldReference), "export table is not frozen after loading")
			expect(heldReference.Value == "CycleNativeA", "export table is missing its values")
			expect(moduleA.GetOther().Value == "CycleNativeB", "CycleNativeA cannot reach CycleNativeB")
			return nil
		end,
	},
	{
		Name = "Setting on: return module first in a mixed cycle falls back to the placeholder",
		NativeCyclicRequires = true,
		Run = function()
			local moduleA = shared("CycleReturnFirstA")
			local moduleB = shared("CycleReturnFirstB")
			expect(moduleA ~= nil and moduleA.Value == "CycleReturnFirstA", "CycleReturnFirstA did not load")
			expect(moduleB ~= nil and moduleB.Value == "CycleReturnFirstB", "CycleReturnFirstB did not load")

			local heldReference = moduleB.GetOther()
			expect(isPlaceholder(heldReference), `expected a placeholder, got {describeModuleTable(heldReference)}`)
			expect(heldReference.Value == "CycleReturnFirstA", "placeholder does not forward reads")
			return nil
		end,
	},
	{
		Name = "Setting on: export module first in a mixed cycle loads both modules",
		NativeCyclicRequires = true,
		Run = function()
			local moduleA = shared("CycleExportFirstA")
			local moduleB = shared("CycleExportFirstB")
			expect(moduleA ~= nil and moduleA.Value == "CycleExportFirstA", "CycleExportFirstA did not load")
			expect(moduleB ~= nil and moduleB.Value == "CycleExportFirstB", "CycleExportFirstB did not load")

			local heldReference = moduleB.GetOther()
			expect(heldReference.Value == "CycleExportFirstA", "held reference does not reach CycleExportFirstA")
			return `CycleExportFirstB holds a {describeModuleTable(heldReference)}`
		end,
	},
	{
		Name = "Setting on: cycle across task threads uses the placeholder without hanging",
		NativeCyclicRequires = true,
		Run = function()
			local finished =
				requireOnSeparateThreads({ "CycleCrossThreadA", "CycleCrossThreadB" }, CROSS_THREAD_TIMEOUT)
			expect(finished, `modules did not finish loading within {CROSS_THREAD_TIMEOUT} seconds`)

			local moduleA = shared("CycleCrossThreadA")
			local moduleB = shared("CycleCrossThreadB")
			expect(moduleA ~= nil and moduleB ~= nil, "a module in the cycle failed to load")

			local referenceHeldByA = moduleA.GetOther()
			local referenceHeldByB = moduleB.GetOther()

			expect(isPlaceholder(referenceHeldByA), `A holds a {describeModuleTable(referenceHeldByA)}`)
			expect(isPlaceholder(referenceHeldByB), `B holds a {describeModuleTable(referenceHeldByB)}`)
			expect(referenceHeldByA.Value == "CycleCrossThreadB", "A's placeholder does not forward reads")
			expect(referenceHeldByB.Value == "CycleCrossThreadA", "B's placeholder does not forward reads")

			CrossThreadPlaceholder = referenceHeldByB
			return nil
		end,
	},
	{
		Name = "Setting on: top-level read of a native cyclic module errors, reads in functions work",
		NativeCyclicRequires = true,
		Run = function()
			local moduleA = shared("CycleTopLevelA")
			local moduleB = shared("CycleTopLevelB")
			expect(moduleA ~= nil and moduleB ~= nil, "a module in the cycle failed to load")

			expect(
				moduleB.TopLevelReadSucceeded == false,
				`top-level read should have errored, but returned {moduleB.TopLevelReadResult}`
			)
			expect(moduleB.GetOther().Value == "CycleTopLevelA", "read inside a function failed")
			return `Luau's error: {moduleB.TopLevelReadResult}`
		end,
	},
	{
		Name = "Writing to a frozen module through a placeholder warns instead of erroring",
		NativeCyclicRequires = true,
		Run = function()
			expect(CrossThreadPlaceholder ~= nil, "skipped: needs the cross-thread case to pass first")

			local sawReadOnlyWarning = false
			local messageConnection = LogService.MessageOut:Connect(function(message: string)
				if string.find(message, "read-only", 1, true) then
					sawReadOnlyWarning = true
				end
			end)

			local writeSuccess, writeError = pcall(function()
				CrossThreadPlaceholder.WrittenByTest = true
			end)
			task.wait()
			messageConnection:Disconnect()

			expect(writeSuccess, `write raised an error: {writeError}`)
			expect(sawReadOnlyWarning, "no read-only warning was printed")
			expect(CrossThreadPlaceholder.WrittenByTest == nil, "the write went through")
			return nil
		end,
	},
}

-- Public Functions

function RunTests.Run(contextName: string)
	Order.IndexModulesOf(script.Parent:WaitForChild("Fixtures"))

	local originalSetting = Settings.NativeCyclicRequires
	local results: { TestResult } = {}

	for _, testCase in TestCases do
		Settings.NativeCyclicRequires = testCase.NativeCyclicRequires
		local runSuccess, runResult = pcall(testCase.Run)
		table.insert(results, {
			Name = testCase.Name,
			Passed = runSuccess,
			Message = if runResult ~= nil then tostring(runResult) else nil,
		})
	end

	Settings.NativeCyclicRequires = originalSetting

	local passedCount = 0
	print(`{REPORT_PREFIX} ===== {contextName} =====`)
	for index, result in results do
		if result.Passed then
			passedCount += 1
		end
		local status = if result.Passed then "PASS" else "FAIL"
		local details = if result.Message then ` - {result.Message}` else ""
		local output = `{REPORT_PREFIX} [{contextName}] {status} {index}. {result.Name}{details}`
		if result.Passed then
			print(output)
		else
			warn(output)
		end
	end
	print(`{REPORT_PREFIX} [{contextName}] {passedCount}/{#results} passed`)
end

return RunTests
