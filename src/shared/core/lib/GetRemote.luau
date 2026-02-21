--[[ File Info

	Author: ChiefWildin
	Module: GetRemote.lua
	Version: 1.5.0

	Provides a simple interface for creating and using remotes. The Remote
	object is a wrapper that will dynamically create RemoteEvents,
	UnreliableRemoteEvents and RemoteFunctions based on what it is used for. It
	combines the interface of all three objects into one for ease of use. See
	Remote API section below for details.

	Example usage:
	```lua
		local GetRemote = shared("GetRemote") ---@module GetRemote

		local TestRemote = GetRemote("TestRemote")

		TestRemote:OnEvent(function(player, ...)
			print("TestRemote fired by " .. player.Name .. ", got:", ...)
		end)

		TestRemote:OnInvoke(function()
			return "Working"
		end)

		TestRemote:Fire("Fired to all clients")

		local player = Players:GetPlayers()[1]
		print("Client invoke test returned:", TestRemote:Invoke(player))
		TestRemote:FireClient(player, "Fired to " .. player.Name)
	```

]]

--[[ Remote API
	:OnEvent(self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> RBXScriptConnection
	    Connects the provided callback to the remote's event. Context is
	    determined automatically. If a rate limit interval is provided, then any
	    events fired within that amount of time for this callback will be cached
	    and processed at the next available time.

	    It will only execute the callback with the latest set of arguments if
		placed in a queue. This can be useful for preventing remote spam, but it
		may also cause normal events to be dropped if the interval is set too
		high.

	:OnUnreliableEvent(self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> RBXScriptConnection
		Connects the provided callback to the remote's event using an unreliable
	    connection. Context is determined automatically. If a rate limit
	    interval is provided, then any events fired within that amount of time
	    for this callback will be cached and processed at the next available
	    time.

	    It will only execute the callback with the latest set of arguments if
		placed in a queue. This can be useful for preventing remote spam, but it
		may also cause normal events to be dropped if the interval is set too
		high.

	:OnClientEvent(self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> RBXScriptConnection
	    Compatibility alias for :OnEvent()

	:OnClientUnreliableEvent(self: Remote, callback: (...any) -> (), rateLimitInterval: number?) ->	RBXScriptConnection
		Compatibility alias for :OnUnreliableEvent()

	:OnServerEvent(self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> RBXScriptConnection
	    Compatibility alias for :OnEvent()

	:OnServerUnreliableEvent(self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> RBXScriptConnection
		Compatibility alias for :OnUnreliableEvent()

	:OnInvoke(self: Remote, callback: (player: Player, ...any) -> any) -> ()
	    Connects the provided callback to the remote's function. Context is
	    determined automatically.

	:GetOnEventSignal(self: Remote) -> RBXScriptSignal
	    Returns the signal that is connected to the remote's event.

	:FireClient(self: Remote, player: Player, ...any) -> ()
	    Fires the remote's event to the given player.

	:FireClientUnreliable(self: Remote, player: Player, ...any) -> ()
	    Fires the remote's event to the given player using an unreliable
	    connection.

	:FireClientList(self: Remote, players: {Player}, ...any) -> ()
	    Fires the remote's event to the given list of players.

	:FireClientListUnreliable(self: Remote, players: {Player}, ...any) -> ()
		Fires the remote's event to the given list of players using an
	    unreliable connection.

	:FireAllClients(self: Remote, ...any) -> ()
	    Fires the remote's event to all players.

	:FireAllClientsUnreliable(self: Remote, ...any) -> ()
		Fires the remote's event to all players using an unreliable connection.

	:FireAllExcept(self: Remote, excluded: Player | {Player}, ...any) -> ()
	    Fires the remote's event to all players except the given player or list
	    of players.

	:FireAllExceptUnreliable(self: Remote, excluded: Player | {Player}, ...any) -> ()
		Fires the remote's event to all players except the given player or list
	    of players using an unreliable connection.

	:FireServer(self: Remote, ...any) -> ()
	    Fires the remote's event to the server.

	:FireServerUnreliable(self: Remote, ...any) -> ()
	    Fires the remote's event to the server using an unreliable connection.

	:Fire(self: Remote, ...any) -> ()
	    Fires the remote's event to the server if called from the client, or to
	    all clients if called from the server.

	:FireUnreliable(self: Remote, ...any) -> ()
		Fires the remote's event to the server if called from the client, or to
	    all clients if called from the server using an unreliable connection.

	:InvokeClient(self: Remote, player: Player, ...any) -> any
	    Invokes the remote's function on the given player.

	:InvokeServer(self: Remote, ...any) -> any
	    Invokes the remote's function on the server.

	:Invoke(self: Remote, ...any) -> any
	    Invokes the remote's function on the server if called from the client,
	    or on the client if called from the server.

	:HasRequestedEvent(self: Remote) -> boolean
	    Returns whether or not the RemoteEvent has already requested to the
	    server to get the _event object.
]]

-- Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Constants

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()
local PRINT_CLIENT_EVENTS = false
local PRINT_CLIENT_INVOKES = false
local PRINT_SERVER_EVENTS = false
local PRINT_SERVER_INVOKES = false

-- Global Variables

local AllRemotes = {}
local RemoteFolder: Folder

-- Objects

local RequestFunction: RemoteFunction

-- Types

export type Remote = {
	OnEvent: (self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> (),
	OnUnreliableEvent: (self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> (),
	OnClientEvent: (self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> (),
	OnClientUnreliableEvent: (self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> (),
	OnServerEvent: (self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> (),
	OnServerUnreliableEvent: (self: Remote, callback: (...any) -> (), rateLimitInterval: number?) -> (),
	OnInvoke: (self: Remote, callback: (player: Player, ...any) -> any) -> (),
	FireClient: (self: Remote, player: Player, ...any) -> (),
	FireClientUnreliable: (self: Remote, player: Player, ...any) -> (),
	FireClientList: (self: Remote, players: { Player }, ...any) -> (),
	FireClientListUnreliable: (self: Remote, players: { Player }, ...any) -> (),
	FireAllClients: (self: Remote, ...any) -> (),
	FireAllClientsUnreliable: (self: Remote, ...any) -> (),
	FireAllExcept: (self: Remote, excluded: Player | { Player }, ...any) -> (),
	FireAllExceptUnreliable: (self: Remote, excluded: Player | { Player }, ...any) -> (),
	FireServer: (self: Remote, ...any) -> (),
	FireServerUnreliable: (self: Remote, ...any) -> (),
	Fire: (self: Remote, ...any) -> (),
	FireUnreliable: (self: Remote, ...any) -> (),
	InvokeClient: (self: Remote, player: Player, ...any) -> any,
	InvokeServer: (self: Remote, ...any) -> any,
	Invoke: (self: Remote, ...any) -> (),
}

export type RemoteForceLoad = { Event: boolean, UnreliableEvent: boolean, Function: boolean }

-- Classes

local Remote = {}
Remote.__index = Remote

function Remote.new(name: string, forceLoad: RemoteForceLoad?): Remote
	if AllRemotes[name] then
		return AllRemotes[name]
	end

	local self = setmetatable({}, Remote)

	self._name = name
	self._callbackProcessTimes = {}
	self._callbackArgCache = {}
	self._event = nil :: RemoteEvent?
	self._unreliableEvent = nil :: UnreliableRemoteEvent?
	self._function = nil :: RemoteFunction?

	AllRemotes[name] = self

	if IS_SERVER then
		local function registerPlayerArgs(player: Player)
			self._callbackArgCache[player] = {}
			self._callbackProcessTimes[player] = {}
		end
		Players.PlayerAdded:Connect(registerPlayerArgs)
		for _, player in pairs(Players:GetPlayers()) do
			registerPlayerArgs(player)
		end
		Players.PlayerRemoving:Connect(function(player: Player)
			self._callbackArgCache[player] = nil
			self._callbackProcessTimes[player] = nil
		end)
	end

	if forceLoad and RunService:IsRunning() then
		if forceLoad.Event then
			if IS_SERVER then
				self:_getEventServer()
			else
				self:_getEventClient()
			end
		end

		if forceLoad.UnreliableEvent then
			if IS_SERVER then
				self:_getUnreliableEventServer()
			else
				self:_getUnreliableEventClient()
			end
		end

		if forceLoad.Function then
			if IS_SERVER then
				self:_getFunctionServer()
			else
				self:_getFunctionClient()
			end
		end
	end

	return self
end

function Remote:_getEventServer(): RemoteEvent
	if not self._event then
		self._event = Instance.new("RemoteEvent")
		self._event.Name = self._name .. "Event"
		self._event.Parent = RemoteFolder

		if PRINT_SERVER_EVENTS then
			self._event.OnServerEvent:Connect(function(player, ...)
				print(`[{self._name}] [{player.Name}]`, ...)
			end)
		end
	end

	return self._event
end

function Remote:_getUnreliableEventServer(): UnreliableRemoteEvent
	if not self._unreliableEvent then
		self._unreliableEvent = Instance.new("UnreliableRemoteEvent")
		self._unreliableEvent.Name = self._name .. "UnreliableEvent"
		self._unreliableEvent.Parent = RemoteFolder
	end

	return self._unreliableEvent
end

function Remote:_getEventClient(): RemoteEvent
	local shouldConnectDebug = false
	if PRINT_CLIENT_EVENTS and not self._connectedClientEventsDebug then
		self._connectedClientEventsDebug = true
		shouldConnectDebug = true
	end

	if not self._event and RunService:IsRunning() then
		-- Make sure assets have been retrieved from server
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end

		-- Get event if it exists
		self._event = RemoteFolder:FindFirstChild(self._name .. "Event")

		-- Fall back on server if not found
		if not self._event then
			self._event = RequestFunction:InvokeServer(self._name, "Event")
		end
	end

	if not self._event then
		error(`Client failed to get remote '{self._name}', check that it is being created on the server.`)
	end

	if shouldConnectDebug then
		self._event.OnClientEvent:Connect(function(...)
			print(`[{self._name}]`, ...)
		end)
	end

	return self._event
end

function Remote:_getUnreliableEventClient(): UnreliableRemoteEvent
	if not self._unreliableEvent then
		-- Make sure assets have been retrieved from server
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end

		-- Get event if it exists
		self._unreliableEvent = RemoteFolder:FindFirstChild(self._name .. "UnreliableEvent")

		-- Fall back on server if not found
		if not self._unreliableEvent then
			self._unreliableEvent = RequestFunction:InvokeServer(self._name, "UnreliableEvent")
		end
	end

	return self._unreliableEvent
end

function Remote:_getFunctionServer(): RemoteFunction
	if not self._function then
		self._function = Instance.new("RemoteFunction")
		self._function.Name = self._name .. "Function"
		self._function.Parent = RemoteFolder
	end

	return self._function
end

function Remote:_getFunctionClient(): RemoteFunction
	if not self._function then
		-- Make sure assets have been retrieved from server
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end

		-- Get function if it exists
		self._function = RemoteFolder:FindFirstChild(self._name .. "Function")

		-- Fall back on server if not found
		if not self._function then
			self._function = RequestFunction:InvokeServer(self._name, "Function")
		end
	end

	return self._function
end

function Remote:_connectRateLimitedCallback(
	event: RBXScriptSignal,
	callback: (...any) -> (),
	rateLimitInterval: number
): RBXScriptConnection
	if typeof(rateLimitInterval) ~= "number" then
		warn(
			"Invalid rate limit interval provided to OnUnreliableEvent for remote "
				.. self._name
				.. " - expected number, got "
				.. typeof(rateLimitInterval)
				.. "\n"
				.. debug.traceback()
		)
		return event:Connect(callback)
	end

	return event:Connect(function(...)
		local args = { ... }
		local player = args[1]

		local processTimes = IS_SERVER and self._callbackProcessTimes[player] or self._callbackProcessTimes
		local argCache = IS_SERVER and self._callbackArgCache[player] or self._callbackArgCache

		local lastProcessedTime = processTimes[callback] or 0
		local timeSinceLastProcessed = os.clock() - lastProcessedTime

		if timeSinceLastProcessed >= rateLimitInterval then
			processTimes[callback] = os.clock()
			callback(...)
		else
			local needsCall = argCache[callback] == nil
			argCache[callback] = args
			if needsCall then
				task.delay(rateLimitInterval - timeSinceLastProcessed, function()
					local cachedArgs = argCache[callback]
					if cachedArgs then
						processTimes[callback] = os.clock()
						argCache[callback] = nil
						callback(table.unpack(cachedArgs))
					end
				end)
			end
		end
	end)
end

-- Connects the provided callback to the remote's event. Context is determined
-- automatically. If a rate limit interval is provided, then any events fired
-- within that amount of time for this callback will be cached and processed at
-- the next available time.
--
-- It will only execute the callback with the latest set of arguments if placed
-- in a queue. This can be useful for preventing remote spam, but it may also
-- cause normal events to be dropped if the interval is set too high.
function Remote:OnEvent(callback: (...any) -> (), rateLimitInterval: number?)
	task.spawn(function()
		if not RunService:IsRunning() then
			return
		end

		local event = if IS_SERVER then self:_getEventServer().OnServerEvent else self:_getEventClient().OnClientEvent

		return if rateLimitInterval
			then self:_connectRateLimitedCallback(event, callback, rateLimitInterval)
			else event:Connect(callback)
	end)
end

Remote.OnServerEvent = Remote.OnEvent
Remote.OnClientEvent = Remote.OnEvent

-- Connects the provided callback to the remote's function. Context is
-- determined automatically.
function Remote:GetOnEventSignal(): RBXScriptSignal
	return if IS_SERVER then self:_getEventServer().OnServerEvent else self:_getEventClient().OnClientEvent
end

-- Connects the provided callback to the remote's unreliable event. Context is
-- determined automatically. If a rate limit interval is provided, then any
-- events fired within that amount of time for this callback will be cached and
-- processed at the next available time.
--
-- It will only execute the callback with the latest set of arguments if placed
-- in a queue. This can be useful for preventing remote spam, but it may also
-- cause normal events to be dropped if the interval is set too high.
function Remote:OnUnreliableEvent(callback: (...any) -> (), rateLimitInterval: number?)
	task.spawn(function()
		local event = if IS_SERVER
			then self:_getUnreliableEventServer().OnServerEvent
			else self:_getUnreliableEventClient().OnClientEvent

		return if rateLimitInterval
			then self:_connectRateLimitedCallback(event, callback, rateLimitInterval)
			else event:Connect(callback)
	end)
end

Remote.OnServerUnreliableEvent = Remote.OnUnreliableEvent
Remote.OnClientUnreliableEvent = Remote.OnUnreliableEvent

-- Identical to RemoteEvent:FireClient()
function Remote:FireClient(player: Player, ...)
	assert(IS_SERVER, "FireClient can only be called on the server")

	if not (typeof(player) == "Instance" and player:IsA("Player")) then
		return
	end

	self:_getEventServer():FireClient(player, ...)
end

-- Identical to UnreliableRemoteEvent:FireClient()
function Remote:FireClientUnreliable(player: Player, ...)
	assert(IS_SERVER, "FireClientUnreliable can only be called on the server")

	if not (typeof(player) == "Instance" and player:IsA("Player")) then
		return
	end

	self:_getUnreliableEventServer():FireClient(player, ...)
end

Remote.FireClientFast = Remote.FireClientUnreliable

-- Identical to RemoteEvent:FireAllClients() except it only fires to the players
-- provided in the list
function Remote:FireClientList(playerList: { Player }, ...)
	if typeof(playerList) ~= "table" then
		warn(`Attempt to fire Remote to non-table list ({tostring(playerList)})\n{debug.traceback()}`)
		return
	end

	for _, player in pairs(playerList) do
		if player:IsA("Player") then
			self:FireClient(player, ...)
		else
			warn(`Attempt to fire Remote to non-Player in list ({tostring(player)})\n{debug.traceback()}`)
		end
	end
end

-- Identical to UnreliableRemoteEvent:FireAllClients() except it only fires to
-- the players provided in the list
function Remote:FireClientListUnreliable(playerList: { Player }, ...)
	if typeof(playerList) ~= "table" then
		warn(`Attempt to fire Remote to non-table list ({tostring(playerList)})\n{debug.traceback()}`)
		return
	end

	for _, player in pairs(playerList) do
		if player:IsA("Player") then
			self:FireClientUnreliable(player, ...)
		else
			warn(`Attempt to fire Remote to non-Player in list ({tostring(player)})\n{debug.traceback()}`)
		end
	end
end

Remote.FireClientListFast = Remote.FireClientListUnreliable

-- Identical to RemoteEvent:FireAllClients()
function Remote:FireAllClients(...)
	assert(IS_SERVER, "FireAllClients can only be called on the server")
	self:_getEventServer():FireAllClients(...)
end

-- Identical to UnreliableRemoteEvent:FireAllClients()
function Remote:FireAllClientsUnreliable(...)
	assert(IS_SERVER, "FireAllClientsUnreliable can only be called on the server")
	self:_getUnreliableEventServer():FireAllClients(...)
end

Remote.FireAllClientsFast = Remote.FireAllClientsUnreliable

-- Identical to RemoteEvent:FireAllClients() except it excludes the provided
-- player(s)
function Remote:FireAllExcept(excluded: Player | { Player }, ...)
	if typeof(excluded) == "Instance" and excluded:IsA("Player") then
		excluded = { excluded }
	else
		warn(`Attempt to exclude non-Player from FireAllExcept ({tostring(excluded)})\n{debug.traceback()}`)
		return
	end

	for _, player in pairs(Players:GetPlayers()) do
		if not table.find(excluded, player) then
			self:FireClient(player, ...)
		end
	end
end

Remote.FireAllClientsExcept = Remote.FireAllExcept

-- Identical to UnreliableRemoteEvent:FireAllClients() except it excludes the
-- provided player(s)
function Remote:FireAllExceptUnreliable(excluded: Player | { Player }, ...)
	if typeof(excluded) == "Instance" and excluded:IsA("Player") then
		excluded = { excluded }
	else
		warn(`Attempt to exclude non-Player from FireAllExcept ({tostring(excluded)})\n{debug.traceback()}`)
		return
	end

	for _, player in pairs(Players:GetPlayers()) do
		if not table.find(excluded, player) then
			self:FireClientUnreliable(player, ...)
		end
	end
end

Remote.FireAllExceptFast = Remote.FireAllExceptUnreliable
Remote.FireAllClientsExceptUnreliable = Remote.FireAllExceptUnreliable
Remote.FireAllClientsExceptFast = Remote.FireAllExceptUnreliable

-- Identical to RemoteEvent:FireServer()
function Remote:FireServer(...)
	assert(IS_CLIENT, "FireServer can only be called on the client")
	if not RunService:IsRunning() then
		return
	end

	self:_getEventClient():FireServer(...)
end

-- Identical to UnreliableRemoteEvent:FireServer()
function Remote:FireServerUnreliable(...)
	assert(IS_CLIENT, "FireServerUnreliable can only be called on the client")
	self:_getUnreliableEventClient():FireServer(...)
end

Remote.FireServerFast = Remote.FireServerUnreliable

-- Determines by context where to fire the event - if called from a client it
-- will use `:FireServer()`, if called from the server it will use
-- `:FireAllClients()`
function Remote:Fire(...)
	if not RunService:IsRunning() then
		return
	elseif IS_SERVER then
		self:_getEventServer():FireAllClients(...)
	else
		self:_getEventClient():FireServer(...)
	end
end

-- Determines by context where to fire the event - if called from a client it
-- will use `:FireServerUnreliable()`, if called from the server it will use
-- `:FireAllClientsUnreliable()`
function Remote:FireUnreliable(...)
	if not RunService:IsRunning() then
		return
	elseif IS_SERVER then
		self:_getUnreliableEventServer():FireAllClients(...)
	else
		self:_getUnreliableEventClient():FireServer(...)
	end
end

Remote.FireFast = Remote.FireUnreliable

-- Identical to RemoteFunction:InvokeClient()
function Remote:InvokeClient(player: Player, ...): any
	assert(IS_SERVER, "InvokeClient can only be called on the server")
	return self:_getFunctionServer():InvokeClient(player, ...)
end

-- Identical to RemoteFunction:InvokeServer()
function Remote:InvokeServer(...): any
	assert(IS_CLIENT, "InvokeServer can only be called on the client")
	return self:_getFunctionClient():InvokeServer(...)
end

-- Determines by context where to invoke the function - if called from a client
-- it will use `:InvokeServer()`, if called from the server it will use
-- `:InvokeClient()`. If invoking a client, the first argument should be the
-- target player.
function Remote:Invoke(...): any
	if IS_SERVER then
		local args = { ... }
		local player = table.remove(args, 1)
		return self:_getFunctionServer():InvokeClient(player, table.unpack(args))
	else
		return self:_getFunctionClient():InvokeServer(...)
	end
end

-- Identical to setting RemoteFunction.OnServerInvoke or
-- RemoteFunction.OnClientInvoke to the provided callback function
function Remote:OnInvoke(callback: (any) -> ()?)
	local function callbackWithPrint(...)
		if not callback then
			return
		end

		local results = { callback(...) }

		if IS_SERVER then
			local args = { ... }
			local player = table.remove(args, 1)
			print(`[{self._name}] [{player.Name}]`, table.unpack(args), "->", table.unpack(results))
		elseif IS_CLIENT then
			print(`[{self._name}]`, ..., "->", table.unpack(results))
		end

		return table.unpack(results)
	end

	task.spawn(function()
		if IS_SERVER then
			self:_getFunctionServer().OnServerInvoke = if PRINT_SERVER_INVOKES then callbackWithPrint else callback
		else
			self:_getFunctionClient().OnClientInvoke = if PRINT_CLIENT_INVOKES then callbackWithPrint else callback
		end
	end)
end

Remote.OnServerInvoke = Remote.OnInvoke
Remote.OnClientInvoke = Remote.OnInvoke

-- Returns whether or not the RemoteEvent has already requested to the server to
-- get the _event object
function Remote:HasRequestedEvent(): boolean
	return self._event ~= nil
end

-- Return function

if not RunService:IsRunning() then
	return function(name: string, forceLoad: RemoteForceLoad?): Remote
		return Remote.new("Mock" .. name, forceLoad)
	end
elseif IS_SERVER then
	return function(name: string, forceLoad: RemoteForceLoad?): Remote
		assert(type(name) == "string", "Invalid name '" .. tostring(name) .. "' - remote name must be a string")

		if not RemoteFolder then
			RemoteFolder = Instance.new("Folder")
			RemoteFolder.Name = FOLDER_NAME
			RemoteFolder.Archivable = false
			RemoteFolder.Parent = ReplicatedStorage

			RequestFunction = Instance.new("RemoteFunction")
			RequestFunction.Name = "Request"
			RequestFunction.Parent = RemoteFolder

			RequestFunction.OnServerInvoke = function(_, remoteName, remoteType)
				local remote = AllRemotes[remoteName]
				if remote then
					if remoteType == "Event" then
						return remote:_getEventServer()
					elseif remoteType == "UnreliableEvent" then
						return remote:_getUnreliableEventServer()
					elseif remoteType == "Function" then
						return remote:_getFunctionServer()
					end
				end
			end
		end

		return Remote.new(name, forceLoad)
	end
else -- IS_CLIENT
	return function(name: string, forceLoad: RemoteForceLoad?): Remote
		assert(type(name) == "string", "Invalid name '" .. tostring(name) .. "' - remote name must be a string")

		if not RemoteFolder then
			RemoteFolder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		end

		if not RequestFunction then
			RequestFunction = RemoteFolder:WaitForChild("Request")
		end

		return Remote.new(name, forceLoad)
	end
end
