--[[ File Info

	Authors: ChiefWildin
	Module: rcall.luau
	Version: 1.4.0

	Retrying call. Provides a way to call functions with a retry limit and
	delay to protect against calls that fail occasionally, such as web API
	calls.

	See end of file for usage information.

]]

-- Types

type rcallOptions = {
	async: boolean?,
	failWarning: string?,
	retryDelay: number?,
	retryLimit: number?,
	requireResult: boolean?,
	silent: boolean?,
	traceback: boolean?,
	backoff: boolean?,
}

-- Constants

local BASE_DELAY_OFFSET = 1
-- Whether we should force rcall to print a stack trace for debugging
local FORCE_TRACEBACK = false

-- Private Functions

local function MainLoop(params: rcallOptions, callback: (...any) -> ...any, ...: any): ...any | nil
	local retryDelay = params.retryDelay or 2
	local retryLimit = params.retryLimit
	local customMessage = params.failWarning

	local success, result
	local retries = 0
	while not success or (params.requireResult and result == nil) do
		if retryLimit and retries >= retryLimit then
			return nil
		end

		local callResults = table.pack(pcall(callback, ...))
		success = table.remove(callResults, 1)
		result = callResults[1]

		if not success or (params.requireResult and result == nil) then
			if not params.silent then
				if customMessage then
					warn(customMessage)
				end
				-- result might be nil if requiring result, so convert to string
				local errorMessage = tostring(result)
				if params.traceback or FORCE_TRACEBACK then
					errorMessage ..= "\n" .. debug.traceback()
				end
				warn("[rcall] Failed attempt, params:", params, "error:", errorMessage)
			end

			retries += 1
			if retryLimit and retries == retryLimit then
				return nil
			end

			local actualDelay = math.max(
				if params.backoff
					then ((retryDelay + BASE_DELAY_OFFSET) ^ (math.max(retries * 0.5, 1))) - BASE_DELAY_OFFSET
					else retryDelay,
				retryDelay
			)
			task.wait(actualDelay)
		else
			return table.unpack(callResults)
		end
	end

	return nil
end

-- Main Function

--[[
	Repeatedly calls the provided `callback` function until successful. Any
	parameters provided after `callback` will be passed to it. Will return the
	results of `callback` if successful, unless it is run asynchronously.

	---

	`params` is a table with the following optional fields:
	```lua
	{
	    async: boolean, -- Whether to run the callback asynchronously. Defaults to false.
		failWarning: string, -- A custom warning to print with the system-provided warning if the callback fails.
		retryDelay: number, -- The number of seconds to wait between retries. Defaults to 2.
		retryLimit: number, -- The number of times to retry the callback before giving up. If not provided, retries infinitely.
	    requireResult: boolean, -- Whether the callback must return a result to be considered successful. Defaults to false.
		silent: boolean, -- Whether the error warning should be silent. Defaults to false.
	    traceback: boolean, -- Whether the error warning should include a traceback. Defaults to false.
		backoff: boolean, -- Whether to use exponential backoff for retry delays. Defaults to false.
	}
	```

	---

	Example:
	```lua
		rcall({retryLimit = 3}, myFunction, "hello", "world")
	```
]]
local rcall = function(params: rcallOptions, callback: (...any) -> ...any, ...: any): ...any
	local async = params.async or false

	if async then
		task.spawn(MainLoop, params, callback, ...)
		return nil
	else
		return MainLoop(params, callback, ...)
	end
end

return rcall
