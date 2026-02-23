--[[ File Info

	Author(s): ChiefWildin
	Module: Observe.luau
	Version: 1.0.0

]]

--[=[
	@class Observe

	Provides utility functions for observing instance properties, attributes,
	and children, immediately invoking callbacks with the current value and
	then again on every subsequent change.
]=]

local Observe = {}

-- Public Functions

--[=[
	Observes the given property on an instance, immediately calling `callback`
	with the current value and again whenever the property changes.

	@param instance Instance -- The instance to observe
	@param property string -- The name of the property to observe
	@param callback function -- Called with the current value immediately and on every change
	@return RBXScriptConnection
]=]
function Observe.Property(instance: Instance, property: string, callback: (any) -> ()): RBXScriptConnection
	task.spawn(callback, instance[property])
	return instance:GetPropertyChangedSignal(property):Connect(function()
		task.spawn(callback, instance[property])
	end)
end

--[=[
	Observes the given attribute on an instance, immediately calling `callback`
	with the current value and again whenever the attribute changes.

	@param instance Instance -- The instance to observe
	@param attribute string -- The name of the attribute to observe
	@param callback function -- Called with the current value immediately and on every change
	@return RBXScriptConnection
]=]
function Observe.Attribute(instance: Instance, attribute: string, callback: (any) -> ()): RBXScriptConnection
	task.spawn(callback, instance:GetAttribute(attribute))
	return instance:GetAttributeChangedSignal(attribute):Connect(function()
		task.spawn(callback, instance:GetAttribute(attribute))
	end)
end

--[=[
	Observes the children of an instance, immediately calling `callback` with
	the current children and again whenever a child is added or removed.

	Returns a connection-like table with `Disconnect()` and `Connected` members,
	compatible with standard connection cleanup patterns.

	@param instance Instance -- The instance to observe
	@param callback function -- Called with the full children list immediately and on every change
	@return RBXScriptConnection
]=]
function Observe.Children(instance: Instance, callback: (children: { Instance }) -> ()): RBXScriptConnection
	local children = instance:GetChildren()
	task.spawn(callback, children)

	local addedConnection = instance.ChildAdded:Connect(function()
		callback(instance:GetChildren())
	end)
	local removedConnection = instance.ChildRemoved:Connect(function()
		callback(instance:GetChildren())
	end)

	local connection
	connection = {
		Disconnect = function()
			connection.Connected = false
			addedConnection:Disconnect()
			removedConnection:Disconnect()
		end,
		Connected = true,
	}

	return connection
end

return Observe
