--[[ File Info

	Author: ChiefWildin
	Module: CacheService.lua
	Version: 1.4.0

]]

--[=[
	@class CacheService

	Simple module for caching any data.
]=]

-- Root

local CacheService = {}

-- Types

type CacheEntry = {
	Data: any,
	EntryTime: number,
	Cleanup: (() -> ())?,
}

--[=[
	@type AddCallback () -> (any?, (() -> ())?)
	@within CacheService

	Produces a value to cache. It may return a cleanup function as a second
	value, which runs once when the entry leaves the cache.
]=]
export type AddCallback = () -> (any?, (() -> ())?)

--[=[
	@interface Cache
	@within CacheService

	.EntryLimit number -- Maximum number of entries the cache will hold
	.EntryAgeLimit number -- Number of seconds entries are allowed to exist
	.Entries {[any]: {Data: any, EntryTime: number, Cleanup: (() -> ())?}} -- The cached entries
]=]
export type Cache = {
	EntryLimit: number,
	EntryAgeLimit: number,
	Entries: { [any]: CacheEntry },
	Get: (self: Cache, index: any) -> any?,
	GetOrAdd: (self: Cache, index: any, addCallback: AddCallback) -> any?,
	Set: (self: Cache, index: any, data: any, cleanup: (() -> ())?) -> (),
	Remove: (self: Cache, index: any) -> (),
	_pendingLoads: { [any]: { thread } },
}

-- Variables

local Caches: { [string]: Cache } = {}

-- Constants

-- The total number of entries allowed in a cache
local DEFAULT_CACHE_ENTRY_LIMIT = 1000
-- The number of seconds that entries are allowed to exist for
local DEFAULT_ENTRY_AGE_LIMIT = 60 * 60 -- One hour
-- The number of seconds between cache limit checks
local LIMIT_CHECK_INTERVAL = 30
local VERBOSE_OUTPUT = false
local CLOCK = tick

-- Private Functions

local function vprint(...)
	if VERBOSE_OUTPUT then
		print(...)
	end
end

local function cleanUpEntry(entry: CacheEntry?)
	if entry and entry.Cleanup then
		task.spawn(entry.Cleanup)
	end
end

local function isExpired(cache: Cache, entry: CacheEntry): boolean
	return CLOCK() - entry.EntryTime > cache.EntryAgeLimit
end

-- API Functions

--[=[
	@class Cache

	A named cache object returned by [CacheService:CreateCache()](/api/CacheService#CreateCache). Stores
	key-value pairs with an age limit and entry limit.
]=]

local Cache = {} :: Cache
Cache.__index = Cache

function Cache.new(name: string, entryLimit: number?, entryAgeLimit: number?): Cache
	local self = Caches[name]

	if not self then
		self = setmetatable({}, Cache)

		self.EntryLimit = entryLimit or DEFAULT_CACHE_ENTRY_LIMIT
		self.EntryAgeLimit = entryAgeLimit or DEFAULT_ENTRY_AGE_LIMIT
		self.Entries = {}
		self._pendingLoads = {}
	else
		self.EntryLimit = entryLimit or self.EntryLimit
		self.EntryAgeLimit = entryAgeLimit or self.EntryAgeLimit
	end

	return self
end

--[=[
	Returns the cached value at the given index, or `nil` if the entry is
	missing or expired.

	@param index any -- The cache key to look up
	@return any? -- The cached value, or nil if missing or expired
]=]
function Cache:Get(index: any): any?
	if index == nil then
		return nil
	end

	local entry = self.Entries[index]
	if not entry then
		return nil
	end

	if isExpired(self, entry) then
		vprint(`[CacheService] Requested data entry ({index}) is expired. Removing.`)
		self:Remove(index)
		return nil
	end

	return entry.Data
end

--[=[
	Returns the cached value at the given index. If it is missing or expired,
	calls `addCallback` to produce a value, caches it, and returns it.

	Only one `addCallback` runs per index at a time. Callers that arrive while
	a value is being produced wait for that result instead of producing their
	own. If `addCallback` errors, every waiting caller receives the error and
	nothing is cached.

	`addCallback` may return a cleanup function as a second value, which runs
	once when the entry is removed, replaced, or expires.

	@param index any -- The cache key to look up
	@param addCallback AddCallback -- Called to produce the value if not cached
	@return any? -- The cached or newly produced value
	@yields
]=]
function Cache:GetOrAdd(index: any, addCallback: AddCallback): any?
	local data = self:Get(index)
	if data ~= nil then
		return data
	end

	local waitingThreads = self._pendingLoads[index]
	if waitingThreads then
		table.insert(waitingThreads, coroutine.running())

		local loadSucceeded, loadResult = coroutine.yield()
		if not loadSucceeded then
			error(loadResult, 0)
		end

		return loadResult
	end

	waitingThreads = {}
	self._pendingLoads[index] = waitingThreads

	local loadSucceeded, loadResult, cleanup = pcall(addCallback)
	self._pendingLoads[index] = nil

	if loadSucceeded and loadResult ~= nil then
		self:Set(index, loadResult, if typeof(cleanup) == "function" then cleanup else nil)
	end

	for _, waitingThread in waitingThreads do
		task.spawn(waitingThread, loadSucceeded, loadResult)
	end

	if not loadSucceeded then
		error(loadResult, 0)
	end

	return loadResult
end

--[=[
	Stores the given value at the specified index. Any entry it replaces is
	cleaned up.

	@param index any -- The cache key to store the value under
	@param data any -- The value to cache
	@param cleanup (() -> ())? -- Runs once when this entry leaves the cache
]=]
function Cache:Set(index: any, data: any, cleanup: (() -> ())?)
	if index == nil then
		return
	end

	local previousEntry = self.Entries[index]

	self.Entries[index] = {
		Data = data,
		EntryTime = CLOCK(),
		Cleanup = cleanup,
	}

	if previousEntry and previousEntry.Cleanup ~= cleanup then
		cleanUpEntry(previousEntry)
	end
end

--[=[
	Removes the entry at the given index and runs its cleanup, if any.

	@param index any -- The cache key to remove
]=]
function Cache:Remove(index: any)
	if index == nil then
		return
	end

	local entry = self.Entries[index]
	self.Entries[index] = nil

	cleanUpEntry(entry)
end

--[=[
	Returns the named `Cache`, creating it if it does not already exist.

	@param cacheName string -- The name of the cache
	@param entryLimit number? -- Maximum number of entries (default 1000)
	@param entryAgeLimit number? -- Entry lifetime in seconds (default 3600)
	@return Cache
]=]
function CacheService:CreateCache(cacheName: string, entryLimit: number?, entryAgeLimit: number?): Cache
	local cache = Caches[cacheName]
	if not cache then
		cache = Cache.new(cacheName, entryLimit, entryAgeLimit)
		Caches[cacheName] = cache
	end

	return cache
end

--[=[
	Stores a value at the given index in the named cache.

	@param cacheName string -- The name of the cache
	@param index any -- The cache key
	@param data any -- The value to cache
	@param cleanup (() -> ())? -- Runs once when this entry leaves the cache
]=]
function CacheService:Set(cacheName: string, index: any, data: any, cleanup: (() -> ())?)
	CacheService:CreateCache(cacheName):Set(index, data, cleanup)
end

--[=[
	Returns the cached value at the given index, or `nil` if missing or expired.

	@param cacheName string -- The name of the cache
	@param index any -- The cache key to look up
	@return any?
]=]
function CacheService:Get(cacheName: string, index: any)
	return CacheService:CreateCache(cacheName):Get(index)
end

--[=[
	Returns the cached value at the given index. If missing or expired, calls
	`addCallback` to produce a value, caches it, and returns it. See
	[Cache:GetOrAdd] for details.

	@param cacheName string -- The name of the cache
	@param index any -- The cache key to look up
	@param addCallback AddCallback -- Called to produce the value if not cached
	@return any?
	@yields
]=]
function CacheService:GetOrAdd(cacheName: string, index: any, addCallback: AddCallback): any?
	return CacheService:CreateCache(cacheName):GetOrAdd(index, addCallback)
end

--[=[
	Removes a value from the named cache right away and runs its cleanup.
	Values are also removed automatically when they expire or when the cache
	exceeds its entry limit.

	@param cacheName string -- The name of the cache
	@param index any -- The cache key to remove
]=]
function CacheService:Remove(cacheName: string, index: any)
	local cache = Caches[cacheName]
	if cache then
		cache:Remove(index)
	end
end

-- Cache clearing to prevent memory leakage
task.spawn(function()
	while task.wait(LIMIT_CHECK_INTERVAL) do
		vprint("[CacheService] Validating caches")
		for cacheName: string, cache: Cache in Caches do
			local cacheSize = 0

			for entryName, entry in cache.Entries do
				if isExpired(cache, entry) then
					vprint(`[CacheService] Cached data entry ({entryName}) in cache {cacheName} is expired. Removing.`)
					cache:Remove(entryName)
				else
					cacheSize += 1
				end
			end

			if cacheSize > cache.EntryLimit then
				vprint(
					`[CacheService] Number of cached entries exceeded limit ({cache.EntryLimit}) in cache {cacheName}, clearing.`
				)

				local clearedEntries = cache.Entries
				cache.Entries = {}

				for _, clearedEntry in clearedEntries do
					cleanUpEntry(clearedEntry)
				end
			end
		end
	end
end)

return CacheService
