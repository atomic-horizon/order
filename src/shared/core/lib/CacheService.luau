--[[ File Info

	Author: ChiefWildin
	Module: CacheService.lua
	Version: 1.3.0

]]

--[=[
	@class CacheService

	Simple module for caching any data.
]=]

-- Root

local CacheService = {}

-- Types

--[=[
	@interface Cache
	@within CacheService

	.EntryLimit number -- Maximum number of entries the cache will hold
	.EntryAgeLimit number -- Number of seconds entries are allowed to exist
	.Entries {[string]: {Data: any, EntryTime: number}} -- The cached entries
]=]
export type Cache = {
	EntryLimit: number,
	EntryAgeLimit: number,
	Entries: { [string]: {
		Data: any,
		EntryTime: number,
	} },
	Get: (self: Cache, index: string) -> any?,
	GetOrAdd: (self: Cache, index: string, addCallback: () -> any?) -> any?,
	Set: (self: Cache, index: string, data: any) -> (),
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
	else
		self.EntryLimit = entryLimit or self.EntryLimit
		self.EntryAgeLimit = entryAgeLimit or self.EntryAgeLimit
	end

	return self
end

--[=[
	Returns the cached value at the given index, or `nil` if the entry is
	missing or expired.

	@param index string -- The cache key to look up
	@return any? -- The cached value, or nil if missing or expired
]=]
function Cache:Get(index: string): any?
	if not index then
		return nil
	end

	if not self.Entries[index] or self.Entries[index].EntryTime + self.EntryAgeLimit < CLOCK() then
		vprint(`[CacheService] Requested data entry ({index}) is expired. Removing.`)
		self.Entries[index] = nil
		return nil
	end

	return self.Entries[index].Data
end

--[=[
	Returns the cached value at the given index. If it is missing or expired,
	calls `addCallback` to produce a value, caches it, and returns it.

	@param index string -- The cache key to look up
	@param addCallback function -- Called to produce the value if not cached
	@return any? -- The cached or newly produced value
]=]
function Cache:GetOrAdd(index: string, addCallback: () -> any?): any?
	local data = self:Get(index)

	if not data then
		data = addCallback()
		self:Set(index, data)
	end

	return data
end

--[=[
	Stores the given value at the specified index.

	@param index string -- The cache key to store the value under
	@param data any -- The value to cache
]=]
function Cache:Set(index: string, data: any)
	if not index then
		return
	end

	self.Entries[index] = {
		Data = data,
		EntryTime = CLOCK(),
	}
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
	@param index string -- The cache key
	@param data any -- The value to cache
]=]
function CacheService:Set(cacheName: string, index: string, data: any)
	Cache.new(cacheName):Set(index, data)
end

--[=[
	Returns the cached value at the given index, or `nil` if missing or expired.

	@param cacheName string -- The name of the cache
	@param index string -- The cache key to look up
	@return any?
]=]
function CacheService:Get(cacheName: string, index: string)
	return Cache.new(cacheName):Get(index)
end

--[=[
	Returns the cached value at the given index. If missing or expired, calls
	`addCallback` to produce a value, caches it, and returns it.

	@param cacheName string -- The name of the cache
	@param index string -- The cache key to look up
	@param addCallback function -- Called to produce the value if not cached
	@return any?
]=]
function CacheService:GetOrAdd(cacheName: string, index: string, addCallback: () -> any?): any?
	return Cache.new(cacheName):GetOrAdd(index, addCallback)
end

-- Cache clearing to prevent memory leakage
task.spawn(function()
	while task.wait(LIMIT_CHECK_INTERVAL) do
		vprint("[CacheService] Validating caches")
		for cacheName: string, cache: Cache in pairs(Caches) do
			local cacheSize = 0

			for entryName, data in pairs(cache.Entries) do
				if CLOCK() - data.EntryTime > cache.EntryAgeLimit then
					vprint(`[CacheService] Cached data entry ({entryName}) in cache {cacheName} is expired. Removing.`)
					cache.Entries[entryName] = nil
				else
					cacheSize += 1
				end
			end

			if cacheSize > cache.EntryLimit then
				vprint(
					`[CacheService] Number of cached entries exceeded limit ({cache.EntryLimit}) in cache {cacheName}, clearing.`
				)
				Caches[cacheName].Entries = {}
			end
		end
	end
end)

return CacheService
