--[[ File Info

	PlayerData.lua
	ChiefWildin
	Version: 3.0.0

	Handles the implementation of ProfileStore and ReplicaService for
	managing player data.
]]

-- Services

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Task Declaration

--[=[
	@class PlayerData

	Provides an interface for managing player data using ProfileStore and
	ReplicaService.
]=]
local PlayerData = {}

-- Dependencies

local Environment = shared("Environment")
local ProfileStore = shared("ProfileStore")
local ProfileTemplate = shared("ProfileTemplate")
local rcall = shared("rcall")
local ReplicaServiceListeners = shared("ReplicaServiceListeners")

-- Types

type Replica = ReplicaServiceListeners.Replica

-- Constants

-- Whether or not the system warns about infinite yields on player data fetch
local INFINITE_YIELD_WARNING_ENABLED = false
-- How long to wait before warning about infinite yields on player data fetch
local INFINITE_YIELD_WARNING_TIME = 5
-- Attempts and seconds to wait for each one when RequestSave is called, since
-- ProfileStore does not repeat a failed save on its own
local REQUESTED_SAVE_ATTEMPTS = 3
local REQUESTED_SAVE_TIMEOUT = 15
-- How long a rejoining player's load waits for their previous session in this
-- server to release its profile
local PREVIOUS_SESSION_RELEASE_TIMEOUT = 15
-- Every testing place and Studio session shares the testing store
local STORE_NAME = if Environment.IsProduction() and not Environment.UsesMockData()
	then "PlayerData_Prod"
	else "PlayerData_Testing2"
-- Loads saved data without a session lock and never writes it back
local READ_ONLY_DATA = Environment.UsesReadOnlyData()

-- Global variables

local PlayerCache = {}
local PlayerProfiles = {}
local ProcessedPlayers = {}
local FailedPlayers: { [Player]: boolean } = {}
local LoadedProfilesByUserId: { [number]: any } = {}
local ProfileHolds: { [Player]: { [string]: number } } = {}
local PlayerDataToken = ReplicaServiceListeners.NewClassToken("PlayerData")
local PlayerDataStore

-- Objects

-- Private functions

local function deepTableCopy(originalTable: {}): {}
	local copy = {}
	for key: any, value: any in originalTable do
		if typeof(value) == "table" then
			copy[key] = deepTableCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function describeKeyPath(keyPath: string | { string }): string
	return if typeof(keyPath) == "table" then table.concat(keyPath, ".") else tostring(keyPath)
end

-- Players who have already left are expected to have no data, so only players
-- still in the server are worth a warning
local function warnMissingData(player: Player, action: string, keyPath: string | { string }): ()
	if not player.Parent then
		return
	end

	warn(
		`[PlayerData] Attempt to {action} ({describeKeyPath(keyPath)}) without loaded data for {player}\n{debug.traceback()}`
	)
end

local function clearPlayerSession(player: Player, profile: any): ()
	if PlayerCache[player] then
		PlayerCache[player]:Destroy()
	end

	PlayerCache[player] = nil
	PlayerProfiles[player] = nil

	if LoadedProfilesByUserId[player.UserId] == profile then
		LoadedProfilesByUserId[player.UserId] = nil
	end
end

local function profileReleased(player: Player, profile: any)
	clearPlayerSession(player, profile)

	-- Kick the player, just in case
	player:Kick()
end

-- Stands in for a profile when read-only data finds nothing saved. It has the
-- methods PlayerData calls and none of them write.
local function createUnsavedProfile(): any
	return {
		Data = deepTableCopy(ProfileTemplate),
		AddUserId = function() end,
		Reconcile = function() end,
		OnSessionEnd = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		},
		IsActive = function()
			return false
		end,
		Save = function() end,
		EndSession = function() end,
	}
end

-- The store sessions and reads go through: the in-memory mock while
-- UseMockData is on, otherwise the real store
local function getActiveStore(): any
	return if Environment.UsesMockData() then PlayerDataStore.Mock else PlayerDataStore
end

-- GetAsync loads a profile without a session lock, and the profile it returns
-- never auto-saves or writes when its session ends
local function loadReadOnlyProfile(userId: number): any?
	local activeStore = getActiveStore()
	local viewSucceeded, profile = pcall(activeStore.GetAsync, activeStore, tostring(userId))
	if not viewSucceeded then
		warn(`[PlayerData] Failed to load read-only data for {userId}: {profile}`)
		return nil
	end

	return profile or createUnsavedProfile()
end

-- A player who rejoins the same server quickly can arrive before the previous
-- session's profile is released, and ProfileStore refuses to load a profile
-- that is already loaded in this server
local function waitForPreviousSessionRelease(userId: number): boolean
	local waitStartTime = os.clock()
	while LoadedProfilesByUserId[userId] do
		if os.clock() - waitStartTime > PREVIOUS_SESSION_RELEASE_TIMEOUT then
			return false
		end

		task.wait(0.1)
	end

	return true
end

local function failPlayerLoad(player: Player): ()
	FailedPlayers[player] = true

	if not RunService:IsStudio() then
		player:Kick("An error occurred while loading. Please try again.")
	end
end

local function setUpLoadedProfile(player: Player, profile: any): ()
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profileReleased(player, profile)
	end)

	local data: Replica = ReplicaServiceListeners.NewReplica({
		ClassToken = PlayerDataToken,
		Tags = { Player = player },
		Data = profile.Data,
		Replication = { [player] = typeof(player) == "Instance" },
	})

	PlayerCache[player] = data
	PlayerProfiles[player] = profile
end

local function processPlayer(player: Player)
	if ProcessedPlayers[player] then
		return
	end

	ProcessedPlayers[player] = true

	if not waitForPreviousSessionRelease(player.UserId) then
		warn(`[PlayerData] Previous session for {player} did not release in time`)
		failPlayerLoad(player)
		return
	end

	local profile = if READ_ONLY_DATA
		then loadReadOnlyProfile(player.UserId)
		else getActiveStore():StartSessionAsync(tostring(player.UserId), {
			Cancel = function(): boolean
				return not player:IsDescendantOf(Players)
			end,
		})

	if not player:IsDescendantOf(Players) then
		if profile then
			profile:EndSession()
		end

		return
	end

	if profile == nil then
		failPlayerLoad(player)
		return
	end

	LoadedProfilesByUserId[player.UserId] = profile

	local setupSucceeded, setupError = pcall(setUpLoadedProfile, player, profile)
	if not setupSucceeded then
		warn(`[PlayerData] Failed to set up data for {player}: {setupError}`)
		profile:EndSession()
		failPlayerLoad(player)
	end
end

-- Public functions

--[=[
	Returns the `Replica` object associated with the given player. Modifying
	tables/arrays should be done through the Replica instead of
	`GetValue`/`SetValue` in order to make sure they replicate properly. The
	Replica API can be found at:
	https://madstudioroblox.github.io/ReplicaService/api/#replica

	NOTE: Can return `nil` if the player has left the game or their data failed
	to load, otherwise it will yield until the replica is available.

	@param player Player -- The player whose data Replica is being requested.
	@return Replica? -- The Replica object associated with the given player, or nil if the player has left.
	@yields
]=]
function PlayerData:GetPlayerDataReplica(player: Player): Replica
	local startFetchTick = os.clock()
	local warned = false
	local playerVariableType = typeof(player)

	if playerVariableType ~= "Instance" or not player:IsA("Player") then
		error("Bad argument #1 to PlayerData:GetPlayerDataReplica, Player expected, got " .. playerVariableType)
	end

	while not PlayerCache[player] and player.Parent and not FailedPlayers[player] do
		task.wait()
		if
			INFINITE_YIELD_WARNING_ENABLED
			and os.clock() - startFetchTick > INFINITE_YIELD_WARNING_TIME
			and not warned
		then
			warn("Infinite yield possible on player data fetch for", player)
			warned = true
		end
	end

	return PlayerCache[player]
end

--[=[
	Returns the value at the given `keyPath`. Keys can be passed in any of the
	following ways:
	```lua
	PlayerData:GetValue(player, "Tokens")
	PlayerData:GetValue(player, "Powerups.ExtraLives")
	PlayerData:GetValue(player, { "Powerups", "ExtraLives" })
	```

	@param player Player -- The player whose data is being accessed.
	@param keyPath string | { string } -- The path to the value being accessed, either as a dot-separated string or an array of strings.
	@return any? -- The value at the given `keyPath`, or nil if it doesn't exist.
]=]
function PlayerData:GetValue(player: Player, keyPath: string | { string }): any?
	local dataReplica = self:GetPlayerDataReplica(player)

	if not dataReplica then
		warnMissingData(player, "get value", keyPath)
		return nil
	end

	local indices
	if typeof(keyPath) == "string" then
		indices = string.split(keyPath, ".")
	elseif typeof(keyPath) == "table" then
		indices = keyPath
	else
		error("Invalid keyPath type: " .. typeof(keyPath))
	end

	local currentLocation = dataReplica.Data
	for count, index in indices do
		if count == #indices then
			return currentLocation[index]
		end
		currentLocation = currentLocation[index]
	end

	return nil
end

--[=[
	Sets the value at the given `keyPath` to the given `newValue`. Keys can be
	passed in any of the following ways:
	```lua
	PlayerData:SetValue(player, "Tokens", 0)
	PlayerData:SetValue(player, "Powerups.ExtraLives", 1)
	PlayerData:SetValue(player, { "Powerups", "ExtraLives" }, 1)
	```

	@param player Player -- The player whose data is being modified.
	@param keyPath string | { string } -- The path to the value being modified, either as a dot-separated string or an array of strings.
	@param newValue any -- The new value to set at the given `keyPath`.
]=]
function PlayerData:SetValue(player: Player, keyPath: string | { string }, newValue: any)
	local dataReplica = self:GetPlayerDataReplica(player)
	if not dataReplica then
		warnMissingData(player, "set value", keyPath)
		return
	end

	dataReplica:SetValue(keyPath, newValue)
end

--[=[
	Increments the value at the given `keyPath` by the given `increment`. The
	current stored value must be a number or nil. If the current value is nil,
	it is first initialized to 0, then incremented. The increment must be a
	non-zero number. Keys can be passed in any of the following ways:
	```lua
	PlayerData:IncrementNumValue(player, "Tokens", 1)
	PlayerData:IncrementNumValue(player, "Powerups.ExtraLives", 1)
	PlayerData:IncrementNumValue(player, { "Powerups", "ExtraLives" }, 1)
	```

	@param player Player -- The player whose data is being modified.
	@param keyPath string | { string } -- The path to the value being modified, either as a dot-separated string or an array of strings.
	@param increment number -- The amount to increment the value by. Must be a non-zero number.
	@return number? -- The new value after incrementing, or nil if the increment was invalid.
]=]
function PlayerData:IncrementNumValue(player: Player, keyPath: string | { string }, increment: number): number?
	if typeof(increment) ~= "number" or increment == 0 then
		return nil
	end

	local currentValue = self:GetValue(player, keyPath) or 0
	if typeof(currentValue) == "number" then
		self:SetValue(player, keyPath, currentValue + increment)
		return currentValue + increment
	else
		warn("Attempted to increment a non-number value at keyPath", keyPath)
	end

	return nil
end

--[=[
	Immediately processes the callback on the current value at the given `keyPath`
	and listens for changes. Keys can be passed in any of the following ways:
	```lua
	PlayerData:Observe(player, "Tokens", callback)
	PlayerData:Observe(player, "Powerups.ExtraLives", callback)
	PlayerData:Observe(player, { "Powerups", "ExtraLives" }, callback)
	```

	@param player Player -- The player whose data is being observed.
	@param keyPath string | { string } -- The path to the value being observed, either as a dot-separated string or an array of strings.
	@param callback (newValue: any, oldValue: any) -> () -- The function to call when the value changes. Will also be called immediately with the current value.
	@return RBXScriptConnection? -- The connection object for the change listener, or nil if the player has left.
]=]
function PlayerData:Observe(
	player: Player,
	keyPath: string | { string },
	callback: (newValue: any, oldValue: any) -> ()
): RBXScriptConnection?
	local dataReplica = self:GetPlayerDataReplica(player)
	if not dataReplica then
		warnMissingData(player, "observe value", keyPath)
		return
	end

	local value = self:GetValue(player, keyPath)
	task.spawn(callback, value, value)
	return dataReplica:ListenToChange(keyPath, callback) :: RBXScriptConnection
end

--[=[
	Sets a callback function to be run when the value in path is changed. If
	`runImmediately` is true, the callback will also be run immediately with the
	current value. Keys can be passed in any of the following ways:
	```lua
	PlayerData:SetValueCallback(player, "Tokens", callback, true)
	PlayerData:SetValueCallback(player, "Powerups.ExtraLives", callback, true)
	PlayerData:SetValueCallback(player, { "Powerups", "ExtraLives" }, callback, true)
	```
]=]
function PlayerData:SetValueCallback(
	player: Player,
	keyPath: string | { string },
	callback: (newValue: any, oldValue: any) -> (),
	runImmediately: boolean?
): RBXScriptConnection?
	if runImmediately then
		return self:Observe(player, keyPath, callback)
	end

	local dataReplica = self:GetPlayerDataReplica(player)
	if not dataReplica then
		warnMissingData(player, "observe value", keyPath)
		return
	end
	return dataReplica:ListenToChange(keyPath, callback) :: RBXScriptConnection
end

--[=[
	Creates a hold on the player's profile, preventing it from being released until
	the hold is released. This can be used to prevent the player's data from being
	unloaded while asynchronous operations are still pending. Returns a unique
	hold ID that can be used to release the hold.

	@param player Player -- The player whose profile hold is being created.
	@return string? -- A unique hold ID that can be used to release the hold, or nil if the player's profile doesn't exist.
]=]
function PlayerData:CreateProfileHold(player: Player): string?
	if not PlayerProfiles[player] then
		return
	end

	local holdId = HttpService:GenerateGUID(false)

	if not ProfileHolds[player] then
		ProfileHolds[player] = {}
	end

	ProfileHolds[player][holdId] = tick()

	return holdId
end

--[=[
	Releases a hold on the player's profile with the given hold ID. If the hold
	ID is invalid or doesn't exist, this function does nothing.

	@param holdId string -- The unique hold ID that was returned by `CreateProfileHold`.
]=]
function PlayerData:ReleaseProfileHold(holdId: string)
	if not holdId then
		return
	end

	for player, holds in ProfileHolds do
		if holds[holdId] then
			holds[holdId] = nil

			if next(holds) == nil then
				ProfileHolds[player] = nil
			end

			break
		end
	end
end

--[=[
	Yields until the player's data has loaded, their data failed to load, or
	they left the game.

	@param player Player -- The player whose data is being waited for.
	@return boolean -- Whether the player's data is loaded.
	@yields
]=]
function PlayerData:WaitForData(player: Player): boolean
	return self:GetPlayerDataReplica(player) ~= nil
end

--[=[
	Saves the player's data now instead of waiting for the regular auto-save,
	retrying a few times if the save does not succeed. Useful after an
	important change such as a purchase. Does nothing if the player's profile
	is not loaded or data is read-only.

	@param player Player -- The player whose data should be saved.
	@return boolean -- Whether a save was requested.
]=]
function PlayerData:RequestSave(player: Player): boolean
	local profile = PlayerProfiles[player]
	if not profile or not profile:IsActive() then
		return false
	end

	task.spawn(function()
		for _ = 1, REQUESTED_SAVE_ATTEMPTS do
			if not profile:IsActive() then
				return
			end

			local saveSucceeded = false
			local saveConnection = profile.OnAfterSave:Connect(function()
				saveSucceeded = true
			end)

			profile:Save()

			local saveStartTime = os.clock()
			while not saveSucceeded and os.clock() - saveStartTime < REQUESTED_SAVE_TIMEOUT do
				task.wait(0.5)
			end

			saveConnection:Disconnect()

			if saveSucceeded then
				return
			end
		end

		warn(`[PlayerData] Requested save for {player} did not succeed after {REQUESTED_SAVE_ATTEMPTS} attempts`)
	end)

	return true
end

--[=[
	Reads the saved data of any user without loading their profile, so it does
	not interfere with a session they may have in another server. The returned
	data is a copy and changes to it are not saved.

	@param userId number -- The UserId whose data is being read.
	@return {[string]: any}? -- A copy of the saved data, or nil if there is none or the read failed.
	@yields
]=]
function PlayerData:ViewProfileAsync(userId: number): { [string]: any }?
	if typeof(userId) ~= "number" then
		warn(`[PlayerData] ViewProfileAsync expected a number, got {typeof(userId)}`)
		return nil
	end

	local activeStore = getActiveStore()
	local viewSucceeded, profile = pcall(activeStore.GetAsync, activeStore, tostring(userId))
	if not viewSucceeded then
		warn(`[PlayerData] Failed to view profile for {userId}: {profile}`)
		return nil
	end

	if profile == nil then
		return nil
	end

	return deepTableCopy(profile.Data)
end

-- Task Initialization

function PlayerData:Prep()
	PlayerDataStore = ProfileStore.New(STORE_NAME, ProfileTemplate)

	if READ_ONLY_DATA then
		warn(`[PlayerData] ReadOnlyData is on. Data loads from {STORE_NAME} and nothing is saved.`)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = PlayerProfiles[player]
		if profile ~= nil then
			rcall({ retryLimit = 10, retryDelay = 1, requireResult = true, silent = true }, function()
				return if ProfileHolds[player] then nil else true
			end)

			ProfileHolds[player] = nil

			-- A read-only profile never ends a session, so OnSessionEnd never fires
			if READ_ONLY_DATA then
				clearPlayerSession(player, profile)
			else
				profile:EndSession()
			end
		else
			PlayerCache[player] = nil
		end

		ProcessedPlayers[player] = nil
		FailedPlayers[player] = nil
	end)
	Players.PlayerAdded:Connect(processPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(processPlayer, player)
	end
end

return PlayerData
