--[[
    CacheService.lua
    ChiefWildin
    Version: 1.3.0

    Simple module for caching any data.
]]

-- Root

local CacheService = {}

-- Types

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

function Cache:GetOrAdd(index: string, addCallback: () -> any?): any?
	local data = self:Get(index)

	if not data then
		data = addCallback()
		self:Set(index, data)
	end

	return data
end

function Cache:Set(index: string, data: any)
	if not index then
		return
	end

	self.Entries[index] = {
		Data = data,
		EntryTime = CLOCK(),
	}
end

function CacheService:CreateCache(cacheName: string, entryLimit: number?, entryAgeLimit: number?): Cache
	local cache = Caches[cacheName]
	if not cache then
		cache = Cache.new(cacheName, entryLimit, entryAgeLimit)
		Caches[cacheName] = cache
	end

	return cache
end

-- Sets a value in a cache.
function CacheService:Set(cacheName: string, index: string, data: any)
	Cache.new(cacheName):Set(index, data)
end

-- Returns a value in a cache
function CacheService:Get(cacheName: string, index: string)
	return Cache.new(cacheName):Get(index)
end

-- Returns a value in a cache, or uses the addCallback to find and add it if it
-- doesn't exist
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
