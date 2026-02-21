--[[ File Info

	PlayerData.lua
	ChiefWildin
	Version: 2.4.1

	Handles the implementation of ProfileService and ReplicaService for
	managing player data.
]]

-- Services

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Task Declaration

local PlayerData = {}

-- Dependencies

local ProfileService = shared("ProfileService") ---@module ProfileService
local ProfileTemplate = shared("ProfileTemplate") ---@module ProfileTemplate
local rcall = shared("rcall") ---@module rcall
local ReplicaServiceListeners = shared("ReplicaServiceListeners") ---@module ReplicaServiceListeners

-- Types

type Replica = ReplicaServiceListeners.Replica

-- Constants

-- Whether or not the system warns about infinite yields on player data fetch
local INFINITE_YIELD_WARNING_ENABLED = false
-- How long to wait before warning about infinite yields on player data fetch
local INFINITE_YIELD_WARNING_TIME = 5
local STORE_NAME = if not RunService:IsStudio() and not workspace:GetAttribute("UseMockData")
	then "PlayerData_Prod"
	else "PlayerData_Testing2"

-- Global variables
local PlayerCache = {}
local PlayerProfiles = {}
local ProcessedPlayers = {}
local ProfileHolds: { [Player]: { [string]: number } } = {}
local PlayerDataToken = ReplicaServiceListeners.NewClassToken("PlayerData")
local ProfileStore

-- Objects

-- Private functions

local function deepTableCopy(originalTable: {}): {}
	local copy = {}
	for i: any, v: any in pairs(originalTable) do
		if typeof(v) == "table" then
			copy[i] = deepTableCopy(v)
		else
			copy[i] = v
		end
	end
	return copy
end

local function profileReleased(player: Player)
	if PlayerCache[player] then
		-- Destroy player data Replica
		PlayerCache[player]:Destroy()
	end

	-- Dereference the Replica
	PlayerCache[player] = nil
	PlayerProfiles[player] = nil

	-- Kick the player, just in case
	player:Kick()
end

local function processPlayer(player: Player)
	if ProcessedPlayers[player] then
		return
	end

	ProcessedPlayers[player] = true

	local profile = ProfileStore:LoadProfileAsync(tostring(player.UserId), "ForceLoad")
	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			profileReleased(player)
		end)

		if player:IsDescendantOf(Players) then
			local data: Replica = ReplicaServiceListeners.NewReplica({
				ClassToken = PlayerDataToken,
				Tags = { Player = player },
				Data = profile.Data,
				Replication = { [player] = typeof(player) == "Instance" },
			})

			PlayerCache[player] = data
			PlayerProfiles[player] = profile
		else
			profile:Release()
		end
	elseif not RunService:IsStudio() then
		player:Kick("An error occurred while loading. Please try again.")
	end
end

-- Public functions

--[=[
	Returns the `Replica` object associated with the given player. Modifying
	tables/arrays should be done through the Replica instead of
	`GetValue`/`SetValue` in order to make sure they replicate properly. The
	Replica API can be found at:
	https://madstudioroblox.github.io/ReplicaService/api/#replica

	NOTE: Can return `nil` if the player has left the game, otherwise it will
	yield until the replica is available.

	@param player Player -- The player whose data Replica is being requested.
	@return Replica? -- The Replica object associated with the given player, or nil if the player has left.
]=]
function PlayerData:GetPlayerDataReplica(player: Player): Replica
	local startFetchTick = os.clock()
	local warned = false
	local playerVariableType = typeof(player)

	if playerVariableType ~= "Instance" or not player:IsA("Player") then
		error("Bad argument #1 to PlayerData:GetPlayerDataReplica, Player expected, got " .. playerVariableType)
	end

	while not PlayerCache[player] and player.Parent do
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
		warn(
			`Attempt to get value ({if typeof(keyPath) == "table" then table.concat(keyPath, ".") else keyPath}) from removed player\n{debug.traceback()}`
		)
		return
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
		warn(
			`Attempt to set value ({if typeof(keyPath) == "table" then table.concat(keyPath, ".") else keyPath}) for removed player\n{debug.traceback()}`
		)
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
		return
	end

	local currentValue = self:GetValue(player, keyPath) or 0
	if typeof(currentValue) == "number" then
		self:SetValue(player, keyPath, currentValue + increment)
		return currentValue + increment
	else
		warn("Attempted to increment a non-number value at keyPath", keyPath)
	end
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
		warn(
			`Attempt to set value callback ({if typeof(keyPath) == "table" then table.concat(keyPath) else keyPath}) for removed player`
		)
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
		warn(
			`Attempt to set value callback ({if typeof(keyPath) == "table" then table.concat(keyPath) else keyPath}) for removed player`
		)
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

-- Task Initialization

function PlayerData:Prep()
	ProfileStore = ProfileService.GetProfileStore(STORE_NAME, ProfileTemplate)

	Players.PlayerRemoving:Connect(function(player)
		local profile = PlayerProfiles[player]
		if profile ~= nil then
			rcall({ retryLimit = 10, retryDelay = 1, requireResult = true, silent = true }, function()
				return if ProfileHolds[player] then nil else true
			end)

			ProfileHolds[player] = nil

			profile:Release()
		else
			PlayerCache[player] = nil
		end

		ProcessedPlayers[player] = nil
	end)
	Players.PlayerAdded:Connect(processPlayer)
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(processPlayer, player)
	end
end

return PlayerData
