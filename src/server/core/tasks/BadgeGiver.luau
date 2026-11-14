--[[ File Info

	Author(s): ChiefWildin
	Module: BadgeGiver.luau
	Version: 2.0.0

	Awards badges through a queue that stays inside BadgeService's request
	limits. A badge is written to the player's PendingBadges before any web
	call, so an award that fails or is cut short by the player leaving is tried
	again on their next join.

]]

-- Services

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies

local PlayerData = shared("PlayerData")

-- Types

type QueuedAward = {
	Player: Player,
	BadgeKey: string,
	Attempts: number,
	NextAttemptTime: number,
}

-- Module Declaration

--[=[
	@class BadgeGiver
	@server

	Handles awarding badges to players.
]=]
local BadgeGiver = {}

-- Constants

local STUDIO_PRINTS_ENABLED = false
-- BadgeService allows 50 + 35 * players requests per minute. The queue keeps
-- below that by SAFETY_FACTOR to leave room for other scripts.
local BUDGET_BASE_REQUESTS_PER_MINUTE = 50
local BUDGET_REQUESTS_PER_PLAYER_PER_MINUTE = 35
local BUDGET_SAFETY_FACTOR = 0.8
local BUDGET_WINDOW_SECONDS = 60
-- Retry delays double from the base up to the maximum, with jitter
local RETRY_BASE_DELAY = 2
local RETRY_MAX_DELAY = 60
-- After this many failed attempts in a session, a badge waits for the
-- player's next join
local MAX_ATTEMPTS_PER_SESSION = 5
-- After this many failures in a row, all requests pause for the cooldown
local CIRCUIT_FAILURE_THRESHOLD = 5
local CIRCUIT_COOLDOWN_SECONDS = 60
local WORKER_IDLE_INTERVAL = 0.5

-- Global Variables

local AwardQueue: { QueuedAward } = {}
local QueuedBadgesByPlayer: { [Player]: { [string]: boolean } } = {}
local RequestTimestamps: { number } = {}
local ConsecutiveFailures = 0
local CircuitOpenUntil = 0
local RandomGenerator = Random.new()

-- Private Functions

local function getRequestBudget(): number
	local playerCount = #Players:GetPlayers()
	local requestsPerMinute = BUDGET_BASE_REQUESTS_PER_MINUTE + BUDGET_REQUESTS_PER_PLAYER_PER_MINUTE * playerCount

	return math.floor(requestsPerMinute * BUDGET_SAFETY_FACTOR)
end

local function pruneRequestTimestamps(): ()
	local windowStart = os.clock() - BUDGET_WINDOW_SECONDS
	while RequestTimestamps[1] and RequestTimestamps[1] < windowStart do
		table.remove(RequestTimestamps, 1)
	end
end

local function hasRequestBudget(): boolean
	pruneRequestTimestamps()
	return #RequestTimestamps < getRequestBudget()
end

local function recordRequest(): ()
	table.insert(RequestTimestamps, os.clock())
end

local function getRetryDelay(attempts: number): number
	local delay = math.min(RETRY_BASE_DELAY * 2 ^ (attempts - 1), RETRY_MAX_DELAY)
	return delay * (0.5 + RandomGenerator:NextNumber() * 0.5)
end

-- Badge IDs are saved as string keys. Number keys in saved data can be turned
-- into a sparse array by the data store and lose entries.
local function getBadgeKey(badgeId: number): string
	return tostring(badgeId)
end

local function hasRecordedAward(player: Player, badgeKey: string): boolean
	local awardedBadges = PlayerData:GetValue(player, "AwardedBadges")
	if typeof(awardedBadges) ~= "table" then
		return false
	end

	return awardedBadges[badgeKey] == true or awardedBadges[tonumber(badgeKey)] == true
end

local function forgetQueuedAward(award: QueuedAward): ()
	local queuedBadges = QueuedBadgesByPlayer[award.Player]
	if queuedBadges then
		queuedBadges[award.BadgeKey] = nil
	end
end

local function finishAward(award: QueuedAward, awarded: boolean): ()
	forgetQueuedAward(award)

	if not award.Player.Parent then
		return
	end

	if awarded then
		PlayerData:SetValue(award.Player, { "AwardedBadges", award.BadgeKey }, true)
	end

	PlayerData:SetValue(award.Player, { "PendingBadges", award.BadgeKey }, nil)
end

local function enqueueAward(player: Player, badgeKey: string, delaySeconds: number): ()
	local queuedBadges = QueuedBadgesByPlayer[player]
	if not queuedBadges then
		queuedBadges = {}
		QueuedBadgesByPlayer[player] = queuedBadges
	end

	if queuedBadges[badgeKey] then
		return
	end

	queuedBadges[badgeKey] = true
	table.insert(AwardQueue, {
		Player = player,
		BadgeKey = badgeKey,
		Attempts = 0,
		NextAttemptTime = os.clock() + delaySeconds,
	})
end

local function onRequestFailed(award: QueuedAward, requestError: any): ()
	ConsecutiveFailures += 1
	if ConsecutiveFailures >= CIRCUIT_FAILURE_THRESHOLD then
		warn(`[BadgeGiver] {ConsecutiveFailures} requests failed in a row, pausing for {CIRCUIT_COOLDOWN_SECONDS}s`)
		CircuitOpenUntil = os.clock() + CIRCUIT_COOLDOWN_SECONDS
		ConsecutiveFailures = 0
	end

	award.Attempts += 1
	if award.Attempts >= MAX_ATTEMPTS_PER_SESSION then
		warn(`[BadgeGiver] Giving up on badge {award.BadgeKey} for {award.Player} this session: {requestError}`)
		forgetQueuedAward(award)
		return
	end

	award.NextAttemptTime = os.clock() + getRetryDelay(award.Attempts)
	table.insert(AwardQueue, award)
end

local function processAward(award: QueuedAward): ()
	local player = award.Player
	if not player.Parent then
		forgetQueuedAward(award)
		return
	end

	local badgeId = tonumber(award.BadgeKey) :: number

	recordRequest()
	local checkSucceeded, ownsBadge = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
	if not checkSucceeded then
		onRequestFailed(award, ownsBadge)
		return
	end

	ConsecutiveFailures = 0

	if ownsBadge then
		finishAward(award, true)
		return
	end

	if not hasRequestBudget() then
		table.insert(AwardQueue, award)
		return
	end

	recordRequest()
	local awardSucceeded, awarded = pcall(BadgeService.AwardBadgeAsync, BadgeService, player.UserId, badgeId)
	if not awardSucceeded then
		onRequestFailed(award, awarded)
		return
	end

	ConsecutiveFailures = 0

	-- A false result is a definite answer, such as a disabled badge or one
	-- this experience does not own, so retrying would not help
	if awarded ~= true then
		warn(`[BadgeGiver] Badge {award.BadgeKey} could not be awarded to {player}`)
	end

	finishAward(award, awarded == true)
end

local function takeReadyAward(): QueuedAward?
	local now = os.clock()
	for index, award in AwardQueue do
		if award.NextAttemptTime <= now then
			table.remove(AwardQueue, index)
			return award
		end
	end

	return nil
end

local function runAwardWorker(): ()
	while true do
		if os.clock() < CircuitOpenUntil or not hasRequestBudget() then
			task.wait(WORKER_IDLE_INTERVAL)
			continue
		end

		local award = takeReadyAward()
		if not award then
			task.wait(WORKER_IDLE_INTERVAL)
			continue
		end

		processAward(award)
	end
end

local function resumePendingBadges(player: Player): ()
	if not PlayerData:WaitForData(player) then
		return
	end

	local pendingBadges = PlayerData:GetValue(player, "PendingBadges")
	if typeof(pendingBadges) ~= "table" then
		return
	end

	for badgeKey in pendingBadges do
		local normalizedKey = tostring(badgeKey)
		if hasRecordedAward(player, normalizedKey) then
			PlayerData:SetValue(player, { "PendingBadges", badgeKey }, nil)
			continue
		end

		enqueueAward(player, normalizedKey, 0)
	end
end

-- Public Functions

--[=[
	Queues the specified badge to be awarded to the player, unless their data
	shows they already have it. Returns once the badge is queued, not once it is
	awarded.

	`spreadSeconds` delays the award by a random time up to that many seconds.
	Useful when many players earn a badge at the same moment, so their requests
	reach BadgeService over time rather than all at once.

	@param player Player -- The player to award the badge to.
	@param badgeId number -- The ID of the badge to award.
	@param spreadSeconds number? -- Longest random delay before the award is attempted.
	@yields
]=]
function BadgeGiver:GiveBadge(player: Player, badgeId: number, spreadSeconds: number?)
	if typeof(badgeId) ~= "number" then
		warn(`[BadgeGiver] GiveBadge expected a badge ID number, got {typeof(badgeId)}`)
		return
	end

	if not RunService:IsRunning() then
		return
	end

	local badgeKey = getBadgeKey(badgeId)
	if hasRecordedAward(player, badgeKey) or not player.Parent then
		return
	end

	if RunService:IsStudio() then
		if STUDIO_PRINTS_ENABLED then
			print("Badge award attempt -", player, badgeId)
		end

		return
	end

	PlayerData:SetValue(player, { "PendingBadges", badgeKey }, true)

	local delaySeconds = if spreadSeconds and spreadSeconds > 0 then RandomGenerator:NextNumber() * spreadSeconds else 0
	enqueueAward(player, badgeKey, delaySeconds)
end

-- Task Initialization

function BadgeGiver:Init()
	if RunService:IsStudio() then
		return
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		QueuedBadgesByPlayer[player] = nil
	end)

	Players.PlayerAdded:Connect(resumePendingBadges)
	for _, player in Players:GetPlayers() do
		task.spawn(resumePendingBadges, player)
	end

	task.spawn(runAwardWorker)
end

return BadgeGiver
