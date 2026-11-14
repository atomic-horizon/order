--[[ File Info

	Author: ChiefWildin
	Module: GetRemote.lua
	Version: 1.6.0

]]

--[=[
	@class GetRemote

	Provides a simple interface for creating and using remotes. The [Remote](/api/Remote)
	object is a wrapper that will dynamically create `RemoteEvents`,
	`UnreliableRemoteEvents`, and `RemoteFunctions` based on how it is used,
	combining the interface of all three into one for ease of use.

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
]=]

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

-- The stream used by rate limited callbacks without a key getter. A table, so
-- no key sent by a client can collide with it.
local DEFAULT_RATE_LIMIT_STREAM = {}
-- Owns the client's rate limit state, where there is no player to key it by
local CLIENT_RATE_LIMIT_OWNER = {}

-- Global Variables

local AllRemotes = {}
local RemoteFolder: Folder

-- Objects

local RequestFunction: RemoteFunction

-- Types

-- Receives an event's arguments and returns the key of the rate limit stream
-- the event belongs to. Each stream is rate limited separately.
export type RateLimitKeyGetter = (...any) -> any

type RateLimitStream = {
	LastProcessedTime: number,
	PendingArgs: { n: number, [number]: any }?,
}

-- Returned by the event connection methods. The underlying connection is made
-- asynchronously, so this handle stands in for it and can be given to a Maid.
export type RemoteConnection = {
	Connected: boolean,
	Disconnect: (self: RemoteConnection) -> (),
}

export type Remote = {
	OnEvent: (
		self: Remote,
		callback: (...any) -> (),
		rateLimitInterval: number?,
		getRateLimitKey: RateLimitKeyGetter?
	) -> RemoteConnection,
	OnUnreliableEvent: (
		self: Remote,
		callback: (...any) -> (),
		rateLimitInterval: number?,
		getRateLimitKey: RateLimitKeyGetter?
	) -> RemoteConnection,
	OnClientEvent: (
		self: Remote,
		callback: (...any) -> (),
		rateLimitInterval: number?,
		getRateLimitKey: RateLimitKeyGetter?
	) -> RemoteConnection,
	OnClientUnreliableEvent: (
		self: Remote,
		callback: (...any) -> (),
		rateLimitInterval: number?,
		getRateLimitKey: RateLimitKeyGetter?
	) -> RemoteConnection,
	OnServerEvent: (
		self: Remote,
		callback: (...any) -> (),
		rateLimitInterval: number?,
		getRateLimitKey: RateLimitKeyGetter?
	) -> RemoteConnection,
	OnServerUnreliableEvent: (
		self: Remote,
		callback: (...any) -> (),
		rateLimitInterval: number?,
		getRateLimitKey: RateLimitKeyGetter?
	) -> RemoteConnection,
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
	Destroy: (self: Remote) -> (),
}

export type RemoteForceLoad = { Event: boolean, UnreliableEvent: boolean, Function: boolean }

--[=[
	@class Remote

	A wrapper around `RemoteEvent`, `UnreliableRemoteEvent`, and `RemoteFunction`
	that combines their interfaces into a single object. Instances are created
	and retrieved via [GetRemote](/api/GetRemote).
]=]

-- Private Functions

-- Runs `connect` in a new thread and returns a handle for the connection it
-- makes. Disconnecting the handle before the connection exists disconnects it
-- as soon as it is made.
local function connectDeferred(connect: () -> RBXScriptConnection?): RemoteConnection
	local underlyingConnection: RBXScriptConnection? = nil
	local handle = {
		Connected = true,
	}

	function handle.Disconnect(_self: RemoteConnection)
		handle.Connected = false

		if underlyingConnection then
			underlyingConnection:Disconnect()
			underlyingConnection = nil
		end
	end

	task.spawn(function()
		local newConnection = connect()
		if not newConnection then
			handle.Connected = false
			return
		end

		if handle.Connected then
			underlyingConnection = newConnection
		else
			newConnection:Disconnect()
		end
	end)

	return handle :: RemoteConnection
end

-- Turns a Player or a list of Players into a set, or nil if neither was given
local function toExcludedSet(excluded: Player | { Player }): { [Player]: true }?
	if typeof(excluded) == "Instance" and excluded:IsA("Player") then
		return { [excluded] = true }
	end

	if typeof(excluded) ~= "table" then
		return nil
	end

	local excludedSet = {}
	for _, player in excluded do
		if typeof(player) == "Instance" and player:IsA("Player") then
			excludedSet[player] = true
		end
	end

	return excludedSet
end

-- Classes

local Remote = {}
Remote.__index = Remote

-- Every method of a destroyed remote does nothing. The connection methods still
-- return a handle, already disconnected, so callers can treat it as usual.
local DestroyedRemote = {}
DestroyedRemote.__index = function(_, key: string): any
	if typeof(Remote[key]) ~= "function" then
		return nil
	end

	if string.sub(key, 1, 2) == "On" and string.find(key, "Event", 1, true) then
		return function(): RemoteConnection
			return {
				Connected = false,
				Disconnect = function() end,
			} :: any
		end
	end

	return function() end
end

function Remote.new(name: string, forceLoad: RemoteForceLoad?): Remote
	if AllRemotes[name] then
		return AllRemotes[name]
	end

	local self = setmetatable({}, Remote)

	self._name = name
	-- Rate limit streams by owner (a player, or the client), then callback, then stream key
	self._rateLimitStreams = {} :: { [any]: { [any]: { [any]: RateLimitStream } } }
	self._connections = {} :: { RBXScriptConnection }
	self._event = nil :: RemoteEvent?
	self._unreliableEvent = nil :: UnreliableRemoteEvent?
	self._function = nil :: RemoteFunction?

	AllRemotes[name] = self

	if IS_SERVER then
		table.insert(
			self._connections,
			Players.PlayerRemoving:Connect(function(player: Player)
				self._rateLimitStreams[player] = nil
			end)
		)
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
	rateLimitInterval: number,
	getRateLimitKey: RateLimitKeyGetter?
): RBXScriptConnection
	if typeof(rateLimitInterval) ~= "number" then
		local intervalType = typeof(rateLimitInterval)
		warn(
			`Invalid rate limit interval provided for remote {self._name} - expected number, got {intervalType}\n{debug.traceback()}`
		)
		return event:Connect(callback)
	end

	return event:Connect(function(...)
		local owner = if IS_SERVER then (...) else CLIENT_RATE_LIMIT_OWNER
		local now = os.clock()

		local ownerStreams = self._rateLimitStreams[owner]
		if not ownerStreams then
			-- A player who has already left has nothing left to process
			if IS_SERVER and not (owner :: Player).Parent then
				return
			end

			ownerStreams = {}
			self._rateLimitStreams[owner] = ownerStreams
		end

		local callbackStreams = ownerStreams[callback]
		if not callbackStreams then
			callbackStreams = {}
			ownerStreams[callback] = callbackStreams
		end

		local streamKey = if getRateLimitKey then getRateLimitKey(...) else nil
		if streamKey == nil then
			streamKey = DEFAULT_RATE_LIMIT_STREAM
		end

		-- A stream with nothing queued whose interval has passed behaves the
		-- same as one never seen, so it is dropped. This keeps the table to the
		-- keys in use rather than every key a client has ever sent.
		for otherKey, otherStream in callbackStreams do
			if
				otherKey ~= streamKey
				and not otherStream.PendingArgs
				and now - otherStream.LastProcessedTime >= rateLimitInterval
			then
				callbackStreams[otherKey] = nil
			end
		end

		local stream = callbackStreams[streamKey]
		if not stream then
			stream = { LastProcessedTime = -math.huge }
			callbackStreams[streamKey] = stream
		end

		local timeSinceLastProcessed = now - stream.LastProcessedTime
		if timeSinceLastProcessed >= rateLimitInterval then
			stream.LastProcessedTime = now
			callback(...)
			return
		end

		-- Only the latest arguments are kept while a stream is waiting
		local alreadyScheduled = stream.PendingArgs ~= nil
		stream.PendingArgs = table.pack(...)
		if alreadyScheduled then
			return
		end

		task.delay(rateLimitInterval - timeSinceLastProcessed, function()
			local pendingArgs = stream.PendingArgs
			if not pendingArgs then
				return
			end

			stream.PendingArgs = nil
			stream.LastProcessedTime = os.clock()
			callback(table.unpack(pendingArgs, 1, pendingArgs.n))
		end)
	end)
end

--[=[
	Connects the provided callback to the remote's event. Context is determined
	automatically. If a `rateLimitInterval` is provided, events fired within
	that duration will be queued and only the latest arguments processed. This
	can prevent remote spam, but may cause events to be dropped if set too high.

	`OnServerEvent` and `OnClientEvent` are aliases for this method.

	@param callback function -- The callback to invoke when the event fires
	`getRateLimitKey` receives the event's arguments and returns a key. Each key
	is rate limited separately, so a remote whose payload names what it acts
	on (a setting, an item) keeps the latest event for each name rather than
	only the latest event overall.

	```lua
	SettingRemote:OnEvent(function(player, settingName, value)
		-- ...
	end, 0.5, function(player, settingName)
		return settingName
	end)
	```

	@param rateLimitInterval number? -- If provided, rate-limits the callback to this interval in seconds
	@param getRateLimitKey RateLimitKeyGetter? -- If provided, rate-limits each key it returns separately
	@return RemoteConnection -- A handle that disconnects the callback, safe to give to a Maid
]=]
function Remote:OnEvent(
	callback: (...any) -> (),
	rateLimitInterval: number?,
	getRateLimitKey: RateLimitKeyGetter?
): RemoteConnection
	return connectDeferred(function()
		if not RunService:IsRunning() then
			return nil
		end

		local event = if IS_SERVER then self:_getEventServer().OnServerEvent else self:_getEventClient().OnClientEvent

		return if rateLimitInterval
			then self:_connectRateLimitedCallback(event, callback, rateLimitInterval, getRateLimitKey)
			else event:Connect(callback)
	end)
end

Remote.OnServerEvent = Remote.OnEvent
Remote.OnClientEvent = Remote.OnEvent

--[=[
	Connects the provided callback to the remote's unreliable event. Context is
	determined automatically. If a `rateLimitInterval` is provided, events fired
	within that duration will be queued and only the latest arguments processed.
	This can prevent remote spam, but may cause events to be dropped if set too
	high.

	`OnServerUnreliableEvent` and `OnClientUnreliableEvent` are aliases for this method.

	@param callback function -- The callback to invoke when the event fires
	See [Remote:OnEvent] for `getRateLimitKey`.

	@param rateLimitInterval number? -- If provided, rate-limits the callback to this interval in seconds
	@param getRateLimitKey RateLimitKeyGetter? -- If provided, rate-limits each key it returns separately
	@return RemoteConnection -- A handle that disconnects the callback, safe to give to a Maid
]=]
function Remote:OnUnreliableEvent(
	callback: (...any) -> (),
	rateLimitInterval: number?,
	getRateLimitKey: RateLimitKeyGetter?
): RemoteConnection
	return connectDeferred(function()
		if not RunService:IsRunning() then
			return nil
		end

		local event = if IS_SERVER
			then self:_getUnreliableEventServer().OnServerEvent
			else self:_getUnreliableEventClient().OnClientEvent

		return if rateLimitInterval
			then self:_connectRateLimitedCallback(event, callback, rateLimitInterval, getRateLimitKey)
			else event:Connect(callback)
	end)
end

Remote.OnServerUnreliableEvent = Remote.OnUnreliableEvent
Remote.OnClientUnreliableEvent = Remote.OnUnreliableEvent

--[=[
	Fires the remote's event to the given player. Identical to `RemoteEvent:FireClient()`.

	@server
	@param player Player -- The player to fire the event to
	@param ... any -- The arguments to pass to the client
]=]
function Remote:FireClient(player: Player, ...)
	assert(IS_SERVER, "FireClient can only be called on the server")

	if not (typeof(player) == "Instance" and player:IsA("Player")) then
		return
	end

	self:_getEventServer():FireClient(player, ...)
end

--[=[
	Fires the remote's event to the given player using an unreliable connection.
	Identical to `UnreliableRemoteEvent:FireClient()`.

	Also accessible as `FireClientFast`.

	@server
	@param player Player -- The player to fire the event to
	@param ... any -- The arguments to pass to the client
]=]
function Remote:FireClientUnreliable(player: Player, ...)
	assert(IS_SERVER, "FireClientUnreliable can only be called on the server")

	if not (typeof(player) == "Instance" and player:IsA("Player")) then
		return
	end

	self:_getUnreliableEventServer():FireClient(player, ...)
end

Remote.FireClientFast = Remote.FireClientUnreliable

--[=[
	Fires the remote's event to each player in the provided list.

	@server
	@param playerList {Player} -- The list of players to fire the event to
	@param ... any -- The arguments to pass to the clients
]=]
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

--[=[
	Fires the remote's event to each player in the provided list using an
	unreliable connection.

	Also accessible as `FireClientListFast`.

	@server
	@param playerList {Player} -- The list of players to fire the event to
	@param ... any -- The arguments to pass to the clients
]=]
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

--[=[
	Fires the remote's event to all players. Identical to `RemoteEvent:FireAllClients()`.

	@server
	@param ... any -- The arguments to pass to the clients
]=]
function Remote:FireAllClients(...)
	assert(IS_SERVER, "FireAllClients can only be called on the server")
	self:_getEventServer():FireAllClients(...)
end

--[=[
	Fires the remote's event to all players using an unreliable connection.
	Identical to `UnreliableRemoteEvent:FireAllClients()`.

	Also accessible as `FireAllClientsFast`.

	@server
	@param ... any -- The arguments to pass to the clients
]=]
function Remote:FireAllClientsUnreliable(...)
	assert(IS_SERVER, "FireAllClientsUnreliable can only be called on the server")
	self:_getUnreliableEventServer():FireAllClients(...)
end

Remote.FireAllClientsFast = Remote.FireAllClientsUnreliable

--[=[
	Fires the remote's event to all players except the given player or list of
	players.

	Also accessible as `FireAllClientsExcept`.

	@server
	@param excluded Player | {Player} -- The player(s) to exclude
	@param ... any -- The arguments to pass to the clients
]=]
function Remote:FireAllExcept(excluded: Player | { Player }, ...)
	local excludedSet = toExcludedSet(excluded)
	if not excludedSet then
		warn(`Attempt to exclude non-Player from FireAllExcept ({tostring(excluded)})\n{debug.traceback()}`)
		return
	end

	for _, player in Players:GetPlayers() do
		if not excludedSet[player] then
			self:FireClient(player, ...)
		end
	end
end

Remote.FireAllClientsExcept = Remote.FireAllExcept

--[=[
	Fires the remote's event to all players except the given player or list of
	players using an unreliable connection.

	Also accessible as `FireAllExceptFast`, `FireAllClientsExceptUnreliable`, and `FireAllClientsExceptFast`.

	@server
	@param excluded Player | {Player} -- The player(s) to exclude
	@param ... any -- The arguments to pass to the clients
]=]
function Remote:FireAllExceptUnreliable(excluded: Player | { Player }, ...)
	local excludedSet = toExcludedSet(excluded)
	if not excludedSet then
		warn(`Attempt to exclude non-Player from FireAllExceptUnreliable ({tostring(excluded)})\n{debug.traceback()}`)
		return
	end

	for _, player in Players:GetPlayers() do
		if not excludedSet[player] then
			self:FireClientUnreliable(player, ...)
		end
	end
end

Remote.FireAllExceptFast = Remote.FireAllExceptUnreliable
Remote.FireAllClientsExceptUnreliable = Remote.FireAllExceptUnreliable
Remote.FireAllClientsExceptFast = Remote.FireAllExceptUnreliable

--[=[
	Fires the remote's event to the server. Identical to `RemoteEvent:FireServer()`.

	@client
	@param ... any -- The arguments to pass to the server
]=]
function Remote:FireServer(...)
	assert(IS_CLIENT, "FireServer can only be called on the client")
	if not RunService:IsRunning() then
		return
	end

	self:_getEventClient():FireServer(...)
end

--[=[
	Fires the remote's event to the server using an unreliable connection.
	Identical to `UnreliableRemoteEvent:FireServer()`.

	Also accessible as `FireServerFast`.

	@client
	@param ... any -- The arguments to pass to the server
]=]
function Remote:FireServerUnreliable(...)
	assert(IS_CLIENT, "FireServerUnreliable can only be called on the client")
	self:_getUnreliableEventClient():FireServer(...)
end

Remote.FireServerFast = Remote.FireServerUnreliable

--[=[
	Fires the remote's event, automatically routing by context: uses
	`:FireServer()` on the client, or `:FireAllClients()` on the server.

	@param ... any -- The arguments to pass
]=]
function Remote:Fire(...)
	if not RunService:IsRunning() then
		return
	elseif IS_SERVER then
		self:_getEventServer():FireAllClients(...)
	else
		self:_getEventClient():FireServer(...)
	end
end

--[=[
	Fires the remote's event using an unreliable connection, automatically
	routing by context: uses `:FireServerUnreliable()` on the client, or
	`:FireAllClientsUnreliable()` on the server.

	Also accessible as `FireFast`.

	@param ... any -- The arguments to pass
]=]
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

--[=[
	Invokes the remote's function on the given player. Identical to
	`RemoteFunction:InvokeClient()`.

	@server
	@param player Player -- The player to invoke the function on
	@param ... any -- The arguments to pass
	@return any
	@yields
]=]
function Remote:InvokeClient(player: Player, ...): any
	assert(IS_SERVER, "InvokeClient can only be called on the server")
	if not RunService:IsRunning() then
		return nil
	end

	return self:_getFunctionServer():InvokeClient(player, ...)
end

--[=[
	Invokes the remote's function on the server. Identical to
	`RemoteFunction:InvokeServer()`.

	@client
	@param ... any -- The arguments to pass
	@return any
	@yields
]=]
function Remote:InvokeServer(...): any
	assert(IS_CLIENT, "InvokeServer can only be called on the client")
	if not RunService:IsRunning() then
		return nil
	end

	return self:_getFunctionClient():InvokeServer(...)
end

--[=[
	Invokes the remote's function, automatically routing by context: uses
	`:InvokeServer()` on the client, or `:InvokeClient()` on the server. When
	calling from the server, the first argument should be the target `Player`.

	@param ... any -- The arguments to pass (first arg is the target Player when called from server)
	@return any
	@yields
]=]
function Remote:Invoke(...): any
	if not RunService:IsRunning() then
		return nil
	end

	if IS_SERVER then
		local args = { ... }
		local player = table.remove(args, 1)
		return self:_getFunctionServer():InvokeClient(player, table.unpack(args))
	else
		return self:_getFunctionClient():InvokeServer(...)
	end
end

--[=[
	Sets the callback for the remote's function. Equivalent to setting
	`RemoteFunction.OnServerInvoke` or `RemoteFunction.OnClientInvoke`.
	Context is determined automatically.

	`OnServerInvoke` and `OnClientInvoke` are aliases for this method.

	@param callback function -- The callback to invoke when the function is called
]=]
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

--[=[
	Tears the remote down for good. It is removed from the registry, and on the
	server its instances are destroyed, which disconnects every client's
	listeners as well. Use this for remotes named after something that goes
	away, such as a per-round or per-object remote, so they do not build up.

	Any later call on this object does nothing. Calling `GetRemote` with the
	same name afterwards creates a new remote.
]=]
function Remote:Destroy(): ()
	if AllRemotes[self._name] == self then
		AllRemotes[self._name] = nil
	end

	for _, connection in self._connections do
		connection:Disconnect()
	end

	table.clear(self._connections)
	table.clear(self._rateLimitStreams)

	if IS_SERVER then
		for _, instance in { self._event, self._unreliableEvent, self._function } do
			instance:Destroy()
		end
	end

	setmetatable(self, DestroyedRemote)
end

--[=[
	@function GetRemote
	@within GetRemote

	Returns a [Remote](/api/Remote) object for the given name, creating it if it does not
	already exist. The same object is returned for repeated calls with the same
	name.

	@param name string -- The name of the remote
	@param forceLoad RemoteForceLoad? -- Optionally pre-create specific underlying remote instances
	@return Remote
]=]

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
