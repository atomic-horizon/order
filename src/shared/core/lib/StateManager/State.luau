--[[
    State.lua
    TactBacon
    v1.2.0
]]

-- Services

local HttpService = game:GetService("HttpService")

-- Dependencies

local Maid = shared("Maid") ---@module Maid

-- Constants

local USE_OS_CLOCK_OVER_TICK = true

-- Typings

export type State = {
	Name: string,
	LastActivatedAt: number,
	LastDeactivatedAt: number,
	Maid: {},

	Activate: (self: State) -> (),
	Deactivate: (self: State) -> (),
	BindHandler: (self: State, handler: (self: State) -> (), handlerName: string?) -> string,
	UnbindHandler: (self: State, handlerName: string) -> (),
	ClearHandlers: (self: State) -> (),
	IsActive: (self: State) -> boolean,
	SetDeactivates: (self: State, state: string, deactivates: boolean) -> (),
	SetActivates: (self: State, state: string, activates: boolean) -> (),
	SetBlockedBy: (self: State, state: string, blocked: boolean) -> (),
	GetStatesToActivate: (self: State) -> { [string]: boolean },
	ShouldDeactivate: (self: State, state: string) -> boolean,
	IsConflictingWith: (self: State, state: string) -> boolean,

	new: (stateName: string) -> State,
	__index: State,

	Activated: RBXScriptSignal,
	Deactivated: RBXScriptSignal,

	_activated: BindableEvent,
	_deactivated: BindableEvent,
	_isActive: boolean,
	_handlers: { [string]: (self: State) -> () },
	_blockedBy: { [string]: boolean },
	_deactivates: { [string]: boolean },
	_activates: { [string]: boolean },
	_statesToDeactivate: { [string]: boolean },
	_statesToActivate: { [string]: boolean },

	_callHandlers: (self: State) -> (),
}

-- Main module table

local State: State = {} :: State
State.__index = State

-- Private Functions

function State:_callHandlers()
	for _, handler in self._handlers do
		task.spawn(function()
			handler(self)
		end)
	end
end

-- Public Functions

--Activates the state.
function State:Activate()
	self._isActive = true
	self.LastActivatedAt = USE_OS_CLOCK_OVER_TICK and os.clock() or tick()
	self:_callHandlers()
	self._activated:Fire(self._statesToDeactivate, self._statesToActivate)
end

--Deactivates the state.
function State:Deactivate()
	self._isActive = false
	self.LastDeactivatedAt = USE_OS_CLOCK_OVER_TICK and os.clock() or tick()
	self:_callHandlers()
	self._deactivated:Fire()
end

--Binds a handler to the state.  Handlers are called when the state is
--activated or deactivated and are passed the state and a maid.
--@param handler function The handler `(self: State) -> ()`
--@param handlerName string? The name of the handler.  If not provided, a GUID will be generated.
--@return string HandlerName The name of the handler.
function State:BindHandler(handler: (self: State) -> (), handlerName: string?): string
	local id = handlerName or HttpService:GenerateGUID(false)
	self._handlers[id] = handler
	return id
end

--Unbinds a handler from the state.
--@param handlerName string The name of the handler to unbind.
function State:UnbindHandler(handlerName: string)
	self._handlers[handlerName] = nil
end

--Clears all handlers from the state.
function State:ClearHandlers()
	self._handlers = {}
end

--Returns whether or not the state is active.
--@return boolean IsActive Whether or not the state is active.
function State:IsActive(): boolean
	return self._isActive
end

--Sets whether or not the state is blocked by another state.
--@param state string The name of the state to set the blocked value.
--@param blocked boolean Whether or not the state is blocked by the other state.
function State:SetBlockedBy(state: string, blocked: boolean)
	self._blockedBy[state] = blocked
end

--Sets whether or not the state deactivates another state.
--@param state string The name of the state to set the deactivates value.
--@param deactivates boolean Whether or not the state deactivates the other state.
function State:SetDeactivates(state: string, deactivates: boolean)
	self._deactivates[state] = deactivates
end

--Sets whether or not the state activates another state.
--@param state string The name of the state to set the activate value.
--@param activates boolean Whether or not the state activates the other state.
function State:SetActivates(state: string, activates: boolean)
	self._activates[state] = activates
end

--Returns whether or not the state is conflicting with another state.
--@param state string The name of the state to check.
--@return boolean IsConflictingWith Whether or not the state is conflicting with the other state.
function State:IsConflictingWith(state: string): boolean
	return self._blockedBy[state] == true or self._deactivates[state] == true
end

--Returns whether or not the state deactivates another state.
--@param state string The name of the state to check.
--@return boolean ShouldDeactivate Whether or not the state deactivates the other state.
function State:ShouldDeactivate(state: string): boolean
	return self._deactivates[state] ~= nil
end

--Returns a table of state names that will be activated as well if this one is activated.
--@return table StatesToActivate The states that would be activated.
function State:GetStatesToActivate(): { [string]: boolean }
	local statesToActivate = {}
	for key, value in self._activates do
		if value then
			statesToActivate[key] = true
		end
	end
	return statesToActivate
end

-- Constructor

--Creates a new state.
--@param stateName string The name of the state to create.
--@return table State The newly created state.
function State.new(stateName: string): State
	local self = setmetatable({}, State)

	self.Name = stateName
	self._isActive = false

	self.Maid = Maid.new()

	self._activated = Instance.new("BindableEvent")
	self.Activated = self._activated.Event

	self._deactivated = Instance.new("BindableEvent")
	self.Deactivated = self._deactivated.Event

	self._handlers = {}
	self._blockedBy = {}
	self._deactivates = {}
	self._activates = {}

	self.LastActivatedAt = 0
	self.LastDeactivatedAt = 0

	return self
end

-- Return

return State
