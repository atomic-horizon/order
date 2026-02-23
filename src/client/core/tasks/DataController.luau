--[[ File Info

	Module: DataController.luau
	Author(s): ChiefWildin
	Version: 2.4.0

]]

--[=[
	@class DataController
	@client

	Handles data replication coming from the server.
]=]

-- Services

local RunService = game:GetService("RunService")

-- Task Declaration

local DataController = { Priority = 10 }

-- Dependencies

local ProfileTemplate = shared("ProfileTemplate") ---@module ProfileTemplate
local ReplicaController = if RunService:IsRunning() ---@module ReplicaController
	then shared("ReplicaController")
	else nil

-- Types

type Replica = ReplicaController.Replica

-- Constants

-- Global variables

local PlayerDataReplica: Replica

-- Objects

-- Private functions

local function deepCopy(target: {}): {}
	local copy = {}

	for key, value in pairs(target) do
		if typeof(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

-- Public functions

--[=[
	Returns the `Replica` object that contains player data. Yields until the
	replica is available.

	@return Replica
	@yields
]=]
function DataController:GetDataReplica(): Replica
	while not PlayerDataReplica do
		if not RunService:IsRunning() then
			PlayerDataReplica = {
				Data = deepCopy(shared("ProfileTemplate")),
				ListenToChange = function() end,
			} :: Replica
		else
			task.wait()
		end
	end

	return PlayerDataReplica
end

--[=[
	Returns the top-level player data table containing both session and profile
	data.

	:::warning
	This table is read-only. Do not attempt to write to it directly.
	:::

	@return { [string]: any }
]=]
function DataController:GetData(): { [string]: any }
	return if RunService:IsRunning() then self:GetDataReplica().Data else ProfileTemplate
end

--[=[
	Returns the value at the specified path in the player data table. Paths can
	be dot-separated strings or string arrays.

	```lua
	DataController:GetValue("SomeKey.SomeOtherKey")
	-- OR
	DataController:GetValue({"SomeKey", "SomeOtherKey"})
	```

	@param keyPath string | {string} -- The dot-separated path or array of keys
	@return any?
]=]
function DataController:GetValue(keyPath: string | { string }): any?
	local indices
	if typeof(keyPath) == "string" then
		indices = string.split(keyPath, ".")
	elseif typeof(keyPath) == "table" then
		indices = keyPath
	else
		error("Invalid keyPath type: " .. typeof(keyPath))
	end

	local currentLocation = self:GetData()
	for count, index in indices do
		if count == #indices then
			return currentLocation[index]
		end
		currentLocation = currentLocation[index]
	end
end

--[=[
	Immediately invokes `callback` with the current value at `path`, then
	listens for changes and invokes it again on every subsequent update.

	```lua
	DataController:Observe("SomeKey.SomeOtherKey", function(newValue, oldValue)
		print("Value changed from", oldValue, "to", newValue)
	end)
	```

	@param path string -- The dot-separated path to observe
	@param callback function -- Called with (newValue, oldValue) immediately and on every change
	@return RBXScriptConnection
]=]
function DataController:Observe(path: string, callback: (newValue: any, oldValue: any) -> ()): RBXScriptConnection
	local value = DataController:GetValue(path)
	task.spawn(callback, value, value)
	return self:GetDataReplica():ListenToChange(path, callback)
end

--[=[
	Sets a callback to be run when the value at `path` changes. If
	`runImmediately` is true, behaves identically to `Observe` and invokes the
	callback with the current value right away.

	@param path string | {string} -- The path to listen to
	@param callback function -- Called with (newValue, oldValue) on change
	@param runImmediately boolean? -- Whether to invoke the callback immediately with the current value
	@return RBXScriptConnection
]=]
function DataController:SetValueCallback(
	path: string | { string },
	callback: (newValue: any, oldValue: any) -> (),
	runImmediately: boolean?
)
	if runImmediately then
		return self:Observe(path, callback)
	else
		return self:GetDataReplica():ListenToChange(path, callback)
	end
end

-- Framework callbacks

function DataController:Prep()
	if RunService:IsRunning() then
		ReplicaController.ReplicaOfClassCreated("PlayerData", function(replica: Replica)
			PlayerDataReplica = replica
		end)

		ReplicaController.RequestData()
	end
end

return DataController
