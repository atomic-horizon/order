--[[ File Info

	Author(s): ChiefWildin
	Module: ProcessQueue.luau
	Version: 1.1.0

]]

--[=[
	@class ProcessQueue

	Enables processing of a queue of items with an optional delay between each
	item.
]=]
local ProcessQueue = {}
ProcessQueue.__index = ProcessQueue

-- Private Functions

function ProcessQueue:_processQueue()
	if self._isProcessing then
		return
	end

	self._isProcessing = true

	while #self._queue > 0 do
		local item = table.remove(self._queue, 1)

		local success, result = pcall(self._callback, item)

		if not success then
			if self.RetryFailures then
				self:Add(item)
			end

			warn(`Failed to process item ({item}) - {result}`)
		end

		if self._delay > 0 then
			task.wait(self._delay)
		end
	end

	self._isProcessing = false
end

-- Public Functions

--[=[
	Checks if the queue is currently being processed.

	@return boolean
]=]
function ProcessQueue:IsProcessing(): boolean
	return self._isProcessing
end

--[=[
	Adds an item to the queue and begins processing if not already in progress.

	@param item any -- The item to add to the queue.
]=]
function ProcessQueue:Add(item: any)
	table.insert(self._queue, item)
	self:_processQueue()
end

--[=[
	Clears all current items in the queue.
]=]
function ProcessQueue:Clear()
	table.clear(self._queue)
end

--[=[
	Clears the queue and references.
]=]
function ProcessQueue:Destroy()
	table.clear(self._queue)
	self._callback = nil
	setmetatable(self, nil)
end

--[=[
	Creates a new ProcessQueue.

	@param callback (any) -> any -- The function to call for each item in the queue.
	@param delay number? -- Optional delay in seconds between processing each item.
	@return ProcessQueue
]=]
function ProcessQueue.new(callback: (any) -> any, delay: number?)
	local self = setmetatable({}, ProcessQueue)

	self._callback = callback
	self._delay = delay or 0

	self._queue = {}
	self._isProcessing = false

	self.RetryFailures = false

	return self
end

return ProcessQueue
