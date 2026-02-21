--[[ File Info

	Author(s): ChiefWildin
	Module: Observe.luau
	Version: 1.0.0

]]

-- Services

-- Dependencies

-- Types

-- Module Declaration

local Observe = {}

-- Constants

-- Global Variables

-- Objects

-- Private Functions

-- Public Functions

function Observe.Property(instance: Instance, property: string, callback: (any) -> ()): RBXScriptConnection
	task.spawn(callback, instance[property])
	return instance:GetPropertyChangedSignal(property):Connect(function()
		task.spawn(callback, instance[property])
	end)
end

function Observe.Attribute(instance: Instance, attribute: string, callback: (any) -> ()): RBXScriptConnection
	task.spawn(callback, instance:GetAttribute(attribute))
	return instance:GetAttributeChangedSignal(attribute):Connect(function()
		task.spawn(callback, instance:GetAttribute(attribute))
	end)
end

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
