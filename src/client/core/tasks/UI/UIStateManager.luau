--[[ File Info

	File: UIStateManager.lua
	Author(s): Refactor
	Version: 1.0.0-atomicui

	https://github.com/rfct0r/UIStateManager

]]

--[=[
	@class UIStateManager
	@client

	Handles UI state management for [AtomicPanes](/api/AtomicPane). Designed as
	a standalone state manager that controls which UI components are visible
	based on named states.
]=]

--[ Roblox Services ]--

local GamepadService = game:GetService("GamepadService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

--[ Root ]--

local UIStateManager = { Priority = 9999 }

--[ Exports & Types & Defaults ]--

--[=[
	@interface StateProperties
	@within UIStateManager

	.Hides {string}? -- Component names to hide when this state is active. Use `"*"` to hide all.
	.Shows {string}? -- Component names to show when this state is active. Use `"*"` to show all.
	.CoreGui {Shows: {string}?, Hides: {string}?}? -- CoreGui elements to show or hide
	.Blocks {string}? -- State names that cannot be transitioned to from this state. Use `"*"` to block all.
	.GamepadCursorEnabled boolean? -- Whether the gamepad cursor should be enabled in this state
]=]
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

--[=[
	Sets the current UI state. Hides and shows registered components according
	to the state's `StateProperties`. Returns `false` and a reason string if
	the transition is blocked by the current state.

	@param state string -- The name of the state to transition to
	@param forceState boolean? -- If true, bypasses any block rules on the current state
	@param targetGuiObject Instance? -- The GuiObject to target for gamepad cursor focus
	@return boolean -- Whether the state was successfully set
	@return string? -- The reason the state was blocked, if applicable
]=]
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

--[=[
	Registers a new UI state with the given name and properties. If a state
	with the same name already exists, registration is skipped with a warning.

	@param name string -- The name to register the state under
	@param properties StateProperties -- The configuration for the state
]=]
function UIStateManager:RegisterState(name: string, properties: StateProperties): ()
	if States[name] then
		warn(`UIState {name} already exists.`)
		return
	end

	States[name] = properties
end

--[=[
	Registers a UI component under the given name so it can be referenced in
	state configurations. The component must implement `:Show()` and `:Hide()`
	methods. If a component with the same name is already registered, the
	registration is skipped with a warning.

	@param name string -- The name to register the component under
	@param class {} -- The component object, must have `:Show()` and `:Hide()` methods
]=]
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

--[=[
	Unregisters a previously registered UI component by name. Does nothing if
	the component is not registered or was registered under a different class
	reference.

	@param name string -- The name the component was registered under
	@param class {} -- The original class reference used during registration
]=]
function UIStateManager:UnregisterComponent(name: string, class: { [any]: any }): ()
	if not Components[name] then
		return
	end

	if Components[name] ~= class then
		return
	end

	Components[name] = nil
end

--[=[
	Returns the name of the current UI state.

	@return string
]=]
function UIStateManager:GetState(): string
	return self.currentState
end

--[=[
	Returns whether the named component is currently visible.

	@param name string -- The name of the registered component to check
	@return boolean
]=]
function UIStateManager:IsComponentShowing(name: string): boolean
	local component = Components[name]
	if not component then
		warn(COMPONENT_NOT_FOUND_STR:format(name))
		return false
	end

	return component:IsVisible()
end

--[=[
	Reverts to the previous UI state, if one exists.
]=]
function UIStateManager:PreviousState(): ()
	if self.previousState then
		self:SetState(self.previousState)
	end
end

--[=[
	Sets the current state to the registered default state. Returns `nil` and
	a reason string if no default state has been registered.

	@return boolean? -- `true` on success, `nil` if no default is registered
	@return string? -- The reason for failure, if applicable
]=]
function UIStateManager:SetDefault(): (boolean | nil, string?)
	if not self.defaultState then
		return nil, "Could not set state to default. No default state registered."
	end

	self:SetState(self.defaultState)
	return true
end

--[=[
	Registers the named state as the default state for `:SetDefault()`. Returns
	`nil` and a reason string if the state has not been registered.

	@param name string -- The name of the state to use as the default
	@return boolean? -- `true` on success, `nil` if the state does not exist
	@return string? -- The reason for failure, if applicable
]=]
function UIStateManager:RegisterDefaultState(name: string): (boolean | nil, string?)
	if not States[name] then
		return nil, "Could not set default UI state. State did not exist."
	end

	self.defaultState = name
	return true
end

--[=[
	Registers a callback to be invoked when the specified event occurs.

	Valid event names and their callback argument order:
	- `StateChange(newState, oldState)`
	- `BeforeStateChange(oldState, newState)`
	- `AfterStateChange(newState, oldState)`
	- `CoreGuiChange(newState, oldState)`

	```lua
	UIStateManager:RegisterEventHook("StateChange", function(newState, oldState)
		print("UI State changed to:", newState)
	end)
	```

	@param eventName string -- The name of the event to hook into
	@param callback function -- Called with (newState, oldState) when the event fires
]=]
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
