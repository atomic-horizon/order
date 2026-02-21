--[[
	File: UIStateManager.lua
	Author(s): Refactor
	Version: 1.0.0-order

	https://github.com/rfct0r/UIStateManager

	It should be noted that this is supposed to be a standalone State Manager
	for handling ONLY UI States for BasicPane derivatives.
]]

--[ Roblox Services ]--

local GamepadService = game:GetService("GamepadService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

--[ Root ]--

local UIStateManager = { Priority = 9999 }

--[ Exports & Types & Defaults ]--

export type StateProperties = {
	Hides: { string }?,
	Shows: { string }?,
	CoreGui: {
		Shows: { string }?,
		Hides: { string }?,
	}?,
	Blocks: { string }?,
	GamepadCursorEnabled: boolean?,
}

--[ Object References ]--

--[ Constants ]--

local DEBUG_MODE = false
local COMPONENT_NOT_FOUND_STR = "[UIStateManager] UIComponent %s could not be found."
local MISSING_METHOD_STR = "[UIStateManager] UIComponent %s is missing method %s."
local STATE_NOT_FOUND_STR = "[UIStateManager]State %s could not be found."

--[ Variables ]--

local Components = {}
local States: { [string]: StateProperties } = {}

local EventHooks = {
	StateChange = {},
	BeforeStateChange = {},
	AfterStateChange = {},
	CoreGuiChange = {},
}

--[ Shorthands ]--

--[ Local Functions ]--

local function runHook(hookName: string, newState: string, oldState: string?): ()
	if EventHooks[hookName] then
		for _, hook in EventHooks[hookName] do
			hook(newState, oldState)
		end
	end
end

local function hideComponents(state: string, uiState: { [string]: any }): ()
	local toHide = uiState.Hides or {}
	local toShow = uiState.Shows or {}

	if table.find(toHide, "*") then
		for name, component in Components do
			if name == state or table.find(toShow, name) ~= nil then
				continue
			end
			task.spawn(component.Hide, component)
		end
	else
		for _, name in toHide do
			if table.find(toShow, name) ~= nil then
				continue
			end

			-- check if an entry is a group "GROUPNAME_*"
			local isComponentGroup = name:sub(-2) == "_*"

			if isComponentGroup then
				-- support for component groups (ex: HUD_BottomBar)
				for id, component in Components do
					if id:find(name:sub(1, -1)) then
						task.spawn(function()
							component:Hide()
						end)
					end
				end
			else
				local component = Components[name]
				if not component then
					-- warn(COMPONENT_NOT_FOUND_STR:format(name))
					continue
				end

				if table.find(toShow, name) ~= nil then
					continue
				end

				task.spawn(component.Hide, component)
			end
		end
	end
end

local function showComponents(state: string, uiState: { [string]: any }): ()
	local toShow = uiState.Shows or {}

	if table.find(toShow, "*") then
		for name, component in Components do
			if name == state then
				continue
			end
			task.spawn(component.Show, component)
		end
	else
		for _, name in toShow do
			-- check if an entry is a group "GROUPNAME_*"
			local isComponentGroup = name:sub(-2) == "_*"

			if isComponentGroup then
				-- support for component groups (ex: HUD_BottomBar)
				for id, component in Components do
					if id:find(name:sub(1, -1)) then
						task.spawn(component.Show, component)
					end
				end
			else
				local component = Components[name]
				if not component then
					-- warn(COMPONENT_NOT_FOUND_STR:format(name))
					continue
				end

				task.spawn(component.Show, component)
			end
		end
	end
end

local function hideCoreUI(toHide: {}): ()
	if table.find(toHide, "*") then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	else
		for _, name in toHide do
			StarterGui:SetCoreGuiEnabled(name, false)
		end
	end
end

local function showCoreUI(toShow: {}): ()
	if table.find(toShow, "*") then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	else
		for _, name in toShow do
			StarterGui:SetCoreGuiEnabled(name, true)
		end
	end
end

local function updateGamepadCursor(uiState: StateProperties, targetGuiObject: Instance?)
	if UserInputService:GetLastInputType() ~= Enum.UserInputType.Gamepad1 then
		GamepadService:DisableGamepadCursor()
		return
	end

	if uiState.GamepadCursorEnabled == nil then
		return
	end

	if uiState.GamepadCursorEnabled then
		GamepadService:EnableGamepadCursor(targetGuiObject)
	else
		GamepadService:DisableGamepadCursor()
	end
end

--[ Public Functions ]--

--[[
   Set the UIState to the desired state.

   Parameters:
    - state (string): The name of the state to set.

   Returns:
    - success (boolean): Returns a state to inform if state was set or blocked. If false, state was blocked.
	- reason (string?): Returns the reason as to why the state was blocked.

   Description:
    This function sets the UIState to the specified state and performs associated operations,
    such as hiding/showing components based on the configuration of that state.
    If the specified state does not exist, a warning is issued and no state change occurs.
    If the state configuration includes CoreGui changes, the corresponding CoreGui components
    are shown/hidden accordingly.
]]
function UIStateManager:SetState(state: string, forceState: boolean?, targetGuiObject: Instance?): ()
	local uiState = States[state]

	if not uiState then
		warn(STATE_NOT_FOUND_STR:format(state))
		return false, `State {state} was not found.`
	end

	if self.currentState then
		local currentStateObject = States[self.currentState]

		if not forceState and currentStateObject.Blocks then
			if table.find(currentStateObject.Blocks, "*") or table.find(currentStateObject.Blocks, state) then
				return false, `State was blocked by {self.currentState}`
			end
		end

		self.previousState = self.currentState
	end

	self.currentState = state

	-- reversed so we can get the prior state
	runHook("BeforeStateChange", self.previousState, state)

	if DEBUG_MODE then
		print(`[UIStateManager] Changing UI State to {state}`)
		print(debug.traceback())
	end

	hideComponents(state, uiState)
	showComponents(state, uiState)
	updateGamepadCursor(uiState, targetGuiObject)

	runHook("AfterStateChange", state, self.previousState)

	if uiState.CoreGui then
		showCoreUI(uiState.CoreGui.Shows or {})
		hideCoreUI(uiState.CoreGui.Hides or {})
		runHook("CoreGuiChange", state, self.previousState)
	end

	runHook("StateChange", state, self.previousState)

	return true
end

--[[
   Register a new UIState with the specified name and properties.

   Parameters:
    - name (string): The name of the UIState to register.
    - properties (StateProperties): The properties and configuration for the UIState.

   Returns:
    - None

   Description:
    This function registers a new UIState with the given name and properties.
    If a UIState with the same name already exists, a warning is issued, and the registration is skipped.
    The UIState properties define the configuration for the state, including the components to hide/show
    and any CoreGui changes.
]]
function UIStateManager:RegisterState(name: string, properties: StateProperties): ()
	if States[name] then
		warn(`UIState {name} already exists.`)
		return
	end

	States[name] = properties
end

--[[
   Register a new UIComponent with the specified name and class.

   Parameters:
    - name (string): The name of the UIComponent to register.
    - class ({}): The class representing the UIComponent.

   Returns:
    - None

   Description:
    This function registers a new UIComponent with the given name and class.
    If a UIComponent with the same name already exists, a warning is issued, and the registration is skipped.
    The UIComponent class represents the behavior and functionality of the component.
    The class should include the methods :Hide() and :Show() to control the visibility of the component.
    Once registered, the UIComponent can be used in the configuration of UIStates to show or hide the component as needed.
]]
function UIStateManager:RegisterComponent(name: string, class: { [any]: any }): ()
	if Components[name] then
		warn(`UIComponent {name} already exists.`)
		return
	end

	if not class.Show then
		warn(MISSING_METHOD_STR:format("Show"))
	end

	if not class.Hide then
		warn(MISSING_METHOD_STR:format("Hide"))
	end

	Components[name] = class
end

function UIStateManager:UnregisterComponent(name: string, class: { [any]: any }): ()
	if not Components[name] then
		return
	end

	if Components[name] ~= class then
		return
	end

	Components[name] = nil
end

--[[
   Returns the current UI State.

   Parameters:
    - None

   Returns:
    - string

   Description:
	If there is a current state this method will return it as a string.
]]
function UIStateManager:GetState(): string
	return self.currentState
end

function UIStateManager:IsComponentShowing(name: string): boolean
	local component = Components[name]
	if not component then
		warn(COMPONENT_NOT_FOUND_STR:format(name))
		return false
	end

	return component:IsVisible()
end

--[[
   Revert to the previous UIState.

   Parameters:
    - None

   Returns:
    - None

   Description:
    This function reverts the UIState to the previous state if available.
    It checks if a previous state exists and calls the `SetState` function with the previous state as the parameter.
]]
function UIStateManager:PreviousState(): ()
	if self.previousState then
		self:SetState(self.previousState)
	end
end

--[[
	Set state to default state.

   Parameters:
    - None

   Returns:
    - boolean | nil `success state`
	- string? `failure reason`

   Description:
	Checks if a DefaultState is registered and if there is a default state it will set current state to it.
]]
function UIStateManager:SetDefault(): (boolean | nil, string?)
	if not self.defaultState then
		return nil, "Could not set state to default. No default state registered."
	end

	self:SetState(self.defaultState)
	return true
end

--[[
	Registers a default state for `:SetDefault()` method.

   Parameters:
    - string `state name`

   Returns:
    - boolean | nil `success state`
	- string? `failure reason`

   Description:
]]
function UIStateManager:RegisterDefaultState(name: string): (boolean | nil, string?)
	if not States[name] then
		return nil, "Could not set default UI state. State did not exist."
	end

	self.defaultState = name
	return true
end

--[[
	Registers an event hook to listen for specific events triggered by the UIStateManager
	and execute custom callback functions in response.


	Valid States & Argument Order for Callback:
	- StateChange(newState, oldState)
	- BeforeStateChange (oldState, newState)
	- AfterStateChange (newState, oldState)
	- CoreGuiChange (newState, oldState)

	Parameters:
    - eventName (string): The name of the event hook.
    - callback (function): The callback function to be executed when the event occurs. It should accept a string parameter representing the state associated with the event.

   Returns:
    - None

   Description:
    This function allows you to register an event hook to listen for specific events triggered by the UIStateManager. The event hook can be used to execute custom logic or trigger additional actions in response to the events.

   Example:
    UIStateManager:RegisterEventHook("StateChange", function(state)
      print("UI State changed to:", state)
      -- Perform additional actions based on the state change
    end)
]]
function UIStateManager:RegisterEventHook(eventName: string, callback: (newState: string, oldState: string) -> ()): ()
	if EventHooks[eventName] then
		table.insert(EventHooks[eventName], callback)
	else
		warn(`Unsupported event hook {eventName}`)
	end
end

--[ Initializers ]--

function UIStateManager:Prep()
	-- Default State to show hud elements for gameplay
	self:RegisterState("Gameplay", {
		Shows = {},
		Hides = {},
		CoreGui = {
			Shows = { "*" },
			Hides = {},
		},
		GamepadCursorEnabled = false,
	})

	self:RegisterDefaultState("Gameplay")

	UserInputService.LastInputTypeChanged:Connect(function()
		updateGamepadCursor(States[self.currentState] or {})
	end)
end

return UIStateManager
