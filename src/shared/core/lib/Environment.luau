--[[ File Info

	Module: Environment.luau
	Version: 1.1.0

	Answers which environment this server or client runs in, from the place's
	entry in Settings.PlaceTypes, whether it runs in Studio, and the
	UseMockData and ReadOnlyData workspace attributes.

]]

--[=[
	@class Environment

	Answers which environment the current place runs in. A place's environment
	is set by its entry in `Settings.PlaceTypes`:
	```lua
	PlaceTypes = {
		[123456789] = "Lobby", -- Production
		[987654321] = { Type = "Lobby", Environment = "Testing" },
	},
	```
]=]

-- Services

local RunService = game:GetService("RunService")

-- Types

export type EnvironmentName = "Production" | "Testing"

-- Module Declaration

local Environment = {}

-- Global Variables

local WarnedIgnoredAttributes: { [string]: boolean } = {}

-- Private Functions

-- Testing attributes only apply outside live production servers, so a place
-- file published with one left on cannot affect real player data
local function readTestingAttribute(attributeName: string): boolean
	if workspace:GetAttribute(attributeName) ~= true then
		return false
	end

	if Environment.IsProduction() then
		if not WarnedIgnoredAttributes[attributeName] then
			WarnedIgnoredAttributes[attributeName] = true
			warn(`[Environment] {attributeName} is ignored in production servers`)
		end

		return false
	end

	return true
end

-- Public Functions

--[=[
	Returns the environment set for this place in `Settings.PlaceTypes`.
	Places without one are "Production". This does not account for Studio; see
	`IsProduction` for that.

	@return EnvironmentName
]=]
function Environment.GetName(): EnvironmentName
	return shared.Environment or "Production"
end

--[=[
	Whether this is a live server of a production place. False in Studio and in
	places marked "Testing".

	@return boolean
]=]
function Environment.IsProduction(): boolean
	return not RunService:IsStudio() and Environment.GetName() == "Production"
end

--[=[
	Whether this runs in a place marked "Testing" or in Studio.

	@return boolean
]=]
function Environment.IsTesting(): boolean
	return not Environment.IsProduction()
end

--[=[
	Whether data stores are replaced with in-memory mocks, through the
	`UseMockData` attribute on `workspace`. Nothing is saved while this is on.
	Always false in live production servers.

	@return boolean
]=]
function Environment.UsesMockData(): boolean
	return readTestingAttribute("UseMockData")
end

--[=[
	Whether saved data is loaded but never written, through the `ReadOnlyData`
	attribute on `workspace`. Data loads from the store this place would
	normally use, and changes made during the session are discarded, so a test
	can start from the same saved state every time. Always false in live
	production servers.

	@return boolean
]=]
function Environment.UsesReadOnlyData(): boolean
	return readTestingAttribute("ReadOnlyData")
end

return Environment
