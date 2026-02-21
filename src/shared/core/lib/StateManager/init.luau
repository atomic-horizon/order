--[[
    StateManager.lua
    TactBacon
    v1.2.0
]]

-- Dependencies

local GlobalConfig = require(script.Configs.GlobalConfig) ---@module GlobalConfig
local State = require(script.State) ---@module State

-- Typings

type State = State.State
type StateConfig = GlobalConfig.StateConfig
export type StateManager = {
	ActiveStates: { [string]: State },
	Config: StateConfig,
	States: { [string]: State },
	TaggedStates: { [string]: { State } },

	ActivateState: (self: StateManager, stateName: string) -> (boolean, State),
	DeactivateState: (self: StateManager, stateName: string) -> State,
	GetActiveStates: (self: StateManager) -> { [string]: State },
	GetAllStates: (self: StateManager) -> { [string]: State },
	GetState: (self: StateManager, stateName: string) -> State,
	IsStateActive: (self: StateManager, stateName: string) -> boolean,
	IsStateActivatable: (self: StateManager, stateName: string) -> (boolean, string),
	IsAnyStateActive: (self: StateManager, stateNames: { string }) -> boolean,
	GetStatesActiveWithTag: (self: StateManager, tag: string) -> { State },
	GetStateActivatedSignal: (self: StateManager, stateName: string) -> RBXScriptSignal,
	GetStateDeactivatedSignal: (self: StateManager, stateName: string) -> RBXScriptSignal,
	ActivateStatesWithTag: (self: StateManager, tag: string) -> (boolean, { State }, { State }),
	DeactivateStatesWithTag: (self: StateManager, tag: string) -> { State },
	ActivateStatesWithTagExcept: (
		self: StateManager,
		tagName: string,
		stateName: string | { string }
	) -> (boolean, { State }, { State }),
	DeactivateStatesWithTagExcept: (self: StateManager, tag: string, stateName: string | { string }) -> (),
	ToggleState: (self: StateManager, stateName: string) -> State?,

	new: (config: StateConfig) -> StateManager,
	__index: StateManager,

	StateActivated: RBXScriptSignal,
	StateDeactivated: RBXScriptSignal,

	_stateActivated: BindableEvent,
	_stateDeactivated: BindableEvent,
}

-- StateManager Declaration

local StateManager: StateManager = {} :: StateManager
StateManager.__index = StateManager

-- Public Functions

--Activate a state given a name if possible.  If the state is already active,
--this will do nothing.  If a conflicting state is active and this state
--does not have permission to override it, this will return false and the
--state will not be activated.
--@param stateName string The name of the state to activate.
--@return boolean DidSucceed Whether or not the state was activated.
--@return table State The conflicting state if the state was not activated or the state that caused the EnterState to fail.
function StateManager:ActivateState(stateName: string): (boolean, State)
	local state = self.States[stateName]
	if not state then
		error(`Attempt to activate state {stateName} but it does not exist!`)
	end

	if state:IsActive() then
		return true, state
	end

	local requiresNeeded = {}
	if self.Config[stateName] and self.Config[stateName].Requires then
		for otherStateName in self.Config[stateName].Requires do
			requiresNeeded[otherStateName] = true
		end
	end

	local statesToDeactivate = {}
	for otherStateName: string, otherState: State in self.ActiveStates do
		if requiresNeeded[otherStateName] then
			requiresNeeded[otherStateName] = nil
		end
		if state:IsConflictingWith(otherStateName) then
			if state:ShouldDeactivate(otherStateName) then
				statesToDeactivate[otherStateName] = true
			else
				return false, otherState
			end
		end
	end

	for requireStateName in requiresNeeded do
		return false, requireStateName
	end

	for deactivateStateName, _ in statesToDeactivate do
		self:DeactivateState(deactivateStateName)
	end

	state:Activate()
	self.ActiveStates[stateName] = state
	self._stateActivated:Fire(stateName)

	for stateToActivate in state:GetStatesToActivate() do
		self:ActivateState(stateToActivate)
	end

	return true, state
end

--Deactivate a state given a name.
--@param stateName string The name of the state to deactivate.
--@return table State The deactivated state.
function StateManager:DeactivateState(stateName: string): State?
	local state = self.States[stateName]
	if not state then
		warn(`Attempt to deactivate state {stateName} but it does not exist!`)
		return
	end

	if not state:IsActive() then
		return state
	end

	state:Deactivate()
	self.ActiveStates[stateName] = nil
	self._stateDeactivated:Fire(stateName)

	return state
end

--Deactivate a state given a name.
--@param stateName string The name of the state to deactivate.
--@return table State The deactivated state.
function StateManager:ToggleState(stateName: string): State?
	local state = self.States[stateName]
	if not state then
		warn(`Attempt to toggle state {stateName} but it does not exist!`)
		return
	end

	if state:IsActive() then
		self:DeactivateState(stateName)
	else
		self:ActivateState(stateName)
	end

	return state
end

--Return all currently active states.
--@return table ActiveStates The currently active states.
function StateManager:GetActiveStates()
	return self.ActiveStates
end

--Get a state given a name.
--@param stateName string The name of the state to get.
--@return table State The state returned.
function StateManager:GetState(stateName: string): State
	return self.States[stateName]
end

--Return whether or not a state is active.
--@param stateName string The name of the state to check.  If a table is passed, this will return whether or not all states in the table are active.
--@return boolean IsActive Whether or not the state is active.
function StateManager:IsStateActive(stateName: string | { string }): boolean
	if typeof(stateName) == "table" then
		local allActive = true

		for _, name in stateName do
			if not self.ActiveStates[name] then
				allActive = false
				break
			end
		end

		return allActive
	end

	return self.ActiveStates[stateName] ~= nil
end

--Return a dictionary of all creaeed states.  This is not a copy of the
--internal table, so be careful when modifying it.
--@return table States The created states.
function StateManager:GetAllStates()
	return self.States
end

--Returns whether or not this state could be activated (or is already
--activated)
--@param stateName string The name of the state to check.
--@return boolean IsActivatable Whether or not the state is activatable.
--@return string BlockingStateName The name of the state that is blocking this state from being activated.
function StateManager:IsStateActivatable(stateName: string): (boolean, string?)
	local state = self.States[stateName]
	if not state then
		warn(`Attempt to activate state {stateName} but it does not exist!`)
		return false
	end

	if state:IsActive() then
		return true
	end

	for otherStateName in self.ActiveStates do
		if state:IsConflictingWith(otherStateName) then
			if not state:ShouldDeactivate(otherStateName) then
				return false, otherStateName
			end
		end
	end

	return true
end

--Returns whether or not any of the states in the table are active.
--@param stateNames table The names of the states to check.
--@return boolean IsAnyStateActive Whether or not any of the states are active.
function StateManager:IsAnyStateActive(stateNames: { string }): boolean
	for _, stateName in stateNames do
		if self:IsStateActive(stateName) then
			return true
		end
	end

	return false
end

--Returns the StateActivated signal for a specified state.  This signal
--will return any states that were deactivated by the activation of
--this state as well as any new states that were activated by this
--state.
--@param stateName string The name of the state to get the signal for.
--@return RBXScriptSignal StateActivated The StateActivated signal.
function StateManager:GetStateActivatedSignal(stateName: string): RBXScriptSignal
	return self:GetState(stateName).Activated
end

--Returns the StateDeactivated signal for a specified state.
--@param stateName string The name of the state to get the signal for.
--@return RBXScriptSignal StateDeactivated The StateDeactivated signal.
function StateManager:GetStateDeactivatedSignal(stateName: string): RBXScriptSignal
	return self:GetState(stateName).Deactivated
end

--Returns a list of all states that are active and have the given tag.
--@param tag string The tag to get states with.
--@return table States A list of all states that are active and have the given tag.  This list contains the state objects.
function StateManager:GetStatesActiveWithTag(tag: string): { State }
	if not self.TaggedStates[tag] then
		warn("Tried to get states with invalid tag, given;", tag)
		return {}
	end

	local states = {}
	for _, state in self.TaggedStates[tag] do
		if self:IsStateActive(state.Name) then
			table.insert(states, state)
		end
	end

	return states
end

--Attempts to activate all states with the given tag.  Returns whether or not
--all succeeded or if any failed, as well as a list of all states that were
--successfully activated and a list of all states that failed to activate.
--@param tag string The tag to activate states with.
--@return boolean DidAnyFail Whether or not any states failed to activate.
--@return table ActivatedStates A list of all states that were successfully activated.
--@return table FailedStates A list of all states that failed to activate.
function StateManager:ActivateStatesWithTag(tag: string): (boolean, { State }, { State })
	if not self.TaggedStates[tag] then
		warn("Tried to activate states with invalid tag, given;", tag)
		return true, {}, {}
	end

	local activatedStates = {}
	local failedStates = {}
	local didAnyFail = false
	for _, state in self.TaggedStates[tag] do
		local success, activatedState = self:ActivateState(state.Name)
		if success then
			table.insert(activatedStates, activatedState)
		else
			didAnyFail = true
			table.insert(failedStates, state)
		end
	end

	return didAnyFail, activatedStates, failedStates
end

--Deactivates all states with the given tag.
--@param tag string The tag to deactivate states with.
--@return table DeactivatedStates A list of all states that were successfully deactivated.  This list contains the state objects.
function StateManager:DeactivateStatesWithTag(tag: string): { State }
	if not self.TaggedStates[tag] then
		warn("Tried to deactivate states with invalid tag, given;", tag)
		return {}
	end

	for _, state in self.TaggedStates[tag] do
		self:DeactivateState(state.Name)
	end

	return self.TaggedStates[tag]
end

--Attempts to activate all states with the given tag except for the provided
--state or table of states.  Returns whether or not all succeeded or if any
--failed, as well as a list of all states that were successfully activated
--and a list of all states that failed to activate.
--@param tagName string The tag to activate states with.
--@param stateName string | { string } The state or states to not activate.
--@return boolean DidSucceed Whether or not all states were activated.
--@return table ActivatedStates A list of all states that were successfully activated.
--@return table FailedStates A list of all states that failed to activate.
function StateManager:ActivateStatesWithTagExcept(
	tagName: string,
	stateName: string | { string }
): (boolean, { State }, { State })
	if not self.TaggedStates[tagName] then
		warn("Tried to activate states with invalid tag, given;", tagName)
		return false, {}, {}
	end

	local activatedStates = {}
	local failedStates = {}
	local didAnyFail = false
	if typeof(stateName) == "string" then
		for _, state in self.TaggedStates[tagName] do
			if state.Name ~= stateName then
				local success, activatedState = self:ActivateState(state.Name)
				if success then
					table.insert(activatedStates, activatedState)
				else
					didAnyFail = true
					table.insert(failedStates, state)
				end
			end
		end
	else
		for _, state in self.TaggedStates[tagName] do
			local shouldActivate = true
			for _, name in stateName do
				if state.Name == name then
					shouldActivate = false
					break
				end
			end

			if shouldActivate then
				local success, activatedState = self:ActivateState(state.Name)
				if success then
					table.insert(activatedStates, activatedState)
				else
					didAnyFail = true
					table.insert(failedStates, state)
				end
			end
		end
	end

	return not didAnyFail, activatedStates, failedStates
end

--Deactivates all states with the given tag except for the given state or table
--of states.
--@param tag string The tag to deactivate states with.
--@param stateName string | { string } The name of the state to not deactivate, or a table of state names to not deactivate.
function StateManager:DeactivateStatesWithTagExcept(tag: string, stateName: string | { string })
	if not self.TaggedStates[tag] then
		warn("Tried to deactivate states with invalid tag, given:", tag)
		return
	end

	if typeof(stateName) == "string" then
		for _, state in self.TaggedStates[tag] do
			if state.Name ~= stateName then
				self:DeactivateState(state.Name)
			end
		end
	else
		for _, state in self.TaggedStates[tag] do
			local shouldDeactivate = true
			for _, name in stateName do
				if state.Name == name then
					shouldDeactivate = false
					break
				end
			end

			if shouldDeactivate then
				self:DeactivateState(state.Name)
			end
		end
	end
end

-- Constructor

--Creates a new StateManager that can be used to manage states.
--Config is a dictionary of state names that corresponds with a table of
--different reactions to other states.
--@param config table The configuration for the StateManager.
--@return table StateManager The new StateManager object.
function StateManager.new(config: StateConfig): StateManager
	local self: StateManager = setmetatable({}, StateManager)

	self.Config = config

	self.ActiveStates = {} :: { [string]: State }
	self.States = {} :: { [string]: State }
	self.TaggedStates = {} :: { [string]: { State } }

	for state, stateData in config do
		local newState: State = State.new(state)
		self.States[state] = newState

		if stateData.BlockedBy then
			for _, blockedState in stateData.BlockedBy do
				newState:SetBlockedBy(blockedState, true)
			end
		end

		if stateData.Deactivates then
			for _, deactivatesState in stateData.Deactivates do
				newState:SetDeactivates(deactivatesState, true)
			end
		end

		if stateData.Activates then
			for _, activatesState in stateData.Activates do
				newState:SetActivates(activatesState, true)
			end
		end

		if stateData.Tags then
			for _, tag in stateData.Tags do
				if not self.TaggedStates[tag] then
					self.TaggedStates[tag] = {}
				end

				table.insert(self.TaggedStates[tag], newState)
			end
		end
	end

	self._stateActivated = Instance.new("BindableEvent")
	self.StateActivated = self._stateActivated.Event

	self._stateDeactivated = Instance.new("BindableEvent")
	self.StateDeactivated = self._stateDeactivated.Event

	return self
end

-- Return

return StateManager.new(GlobalConfig) :: StateManager
