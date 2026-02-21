--[[
	Author: ChiefWildin

	A utility module that provides functions that make it easier to get multiple
	objects in one call.
]]

--[=[
	Takes an `Instance` value followed by any number of strings that represent
	child `Instance` names and returns the final child. If the last argument is
	a table, it will return a tuple of the children specified by that table.

	```lua
	--- Single instance
	local keystone = Get(workspace, "Arch", "Keystone")
	--- Multiple children
	local keystone, door = Get(workspace, "Arch", { "Keystone", "Door" })
	```

	@class Get
]=]

--[=[
	@function Get
	@within Get
	@param initalObject Instance The object to start navigating from.
	@param ... string | {string} The names of the children to navigate through.
	@return ...Instance A tuple of all the requested children at the final location.
]=]
return function(initialObject: Instance, ...): ...Instance
	local object = initialObject
	local args: { string | { string } } = { ... }

	if typeof(args[#args]) == "table" then
		local namesToFind: { string } = table.remove(args, #args)
		local foundObjects: { Instance } = table.create(#namesToFind)

		-- Traverse to the target object
		for _, childName in ipairs(args) do
			object = object:WaitForChild(childName)
		end

		-- Wait for specified children
		for _, childName in ipairs(namesToFind) do
			table.insert(foundObjects, object:WaitForChild(childName))
		end

		return table.unpack(foundObjects)
	else
		-- Traverse to the target object
		for _, childName in ipairs(args) do
			object = object:WaitForChild(childName)
		end

		return object
	end
end
