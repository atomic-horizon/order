--[[ File Info

	Author(s): ChiefWildin
	Module: AtomicButton.luau
	Version: 1.3.1

]]

-- Dependencies

local AtomicPane = shared("AtomicPane") ---@module AtomicPane
-- local Sounds = shared("Sounds") ---@module Sounds

-- Types

export type AtomicButtonImpl = ({
	-- Metatable members

	__index: AtomicButtonImpl,

	-- Public members

	new: (template: string | Instance, instanceKeys: { [string]: string }) -> AtomicButton,
	Activate: (self: AtomicButton) -> (),
	IsEnabled: (self: AtomicButton) -> boolean,
	IsHovered: (self: AtomicButton) -> boolean,
	IsPressed: (self: AtomicButton) -> boolean,
	IsSelected: (self: AtomicButton) -> boolean,
	SetEnabled: (self: AtomicButton, enabled: boolean) -> (),
	SetHovered: (self: AtomicButton, hovered: boolean) -> (),
	SetPressed: (self: AtomicButton, pressed: boolean) -> (),
	SetSelected: (self: AtomicButton, selected: boolean) -> (),

	-- Private members

	_addSensor: (self: AtomicButton) -> (),
	_isEnabled: boolean,
	_isHovered: boolean,
	_isPressed: boolean,
	_isSelected: boolean,
} & AtomicPane.AtomicPaneImpl)?

export type AtomicButton = typeof(setmetatable(
	{} :: ({
		-- Constructed public members

		Activated: RBXScriptSignal,
		Hovered: RBXScriptSignal,
		Enabled: RBXScriptSignal,
		Pressed: RBXScriptSignal,
		Selected: RBXScriptSignal,

		-- Constructed private members

		_activated: BindableEvent,
		_hovered: BindableEvent,
		_enabled: BindableEvent,
		_pressed: BindableEvent,
		_selected: BindableEvent,

		_sensor: TextButton,

		[string]: any,
	} & AtomicPane.AtomicPane) | {},
	{} :: AtomicButtonImpl
))

-- Module Declaration

--[=[
	@class AtomicButton
	@tag UI

	The foundational model for all UI button components in the game. On top of
	the AtomicPane base, it adds interaction states such as hover, press,
	selected, and enabled. It also provides events for these interactions.
	Anything can be a button with this class, it will automatically create a
	TextButton if one does not already exist (must be named "Sensor" and a
	direct child of the Gui instance).

	**Inherits from AtomicPane**

	A VS Code snippet for creating AtomicButtons quickly is included with the
	Git repository.

	:::note
	The source GUI objects should be located in
	`ReplicatedStorage.GuiTemplates`, or `Assets.GuiTemplates` if using an
	Enclave package. They can be of any GuiObject type.
	:::

	### Basic usage
	```lua
	local AtomicButton = shared("AtomicButton") ---@module AtomicButton

	local ExampleButton = setmetatable({}, AtomicButton)
	ExampleButton.__index = ExampleButton
	ExampleButton.ClassName = "ExampleButton"

	function ExampleButton:_draw()
		local alpha = self._springs.Alpha.Position

		self.Gui.Visible = alpha < 0.999
	end

	function ExampleButton.new(parent: Instance)
		local self = setmetatable(AtomicButton.new("ExampleButtonTemplate", {}), ExampleButton)

		self:SetVisible(false, true)

		self.Gui.Parent = parent

		return self
	end

	return ExampleButton
	```
]=]
local AtomicButton: AtomicButtonImpl = setmetatable({}, AtomicPane) :: AtomicButtonImpl
AtomicButton.__index = AtomicButton
AtomicButton.ClassName = "AtomicButton"

-- Private Functions

--[=[
	@private
	Adds a sensor to the button or connects to the existing sensor
]=]
function AtomicButton:_addSensor()
	if self._sensor then
		return
	end

	self._sensor = self.Gui:FindFirstChild("Sensor")
	if not self._sensor then
		self._sensor = Instance.new("TextButton")
		self._sensor.Name = "Sensor"
		self._sensor.BackgroundTransparency = 1
		self._sensor.Text = ""
		self._sensor.TextTransparency = 1
		self._sensor.AutoButtonColor = false
		self._sensor.Size = UDim2.fromScale(1, 1)
		self._sensor.ZIndex = 10
		self._sensor.Parent = self.Gui
	end

	self._sensor:GetPropertyChangedSignal("GuiState"):Connect(function()
		self:SetPressed(self._sensor.GuiState == Enum.GuiState.Press)
		self:SetHovered(self._sensor.GuiState == Enum.GuiState.Hover or self._sensor.GuiState == Enum.GuiState.Press)
	end)

	self._sensor.Activated:Connect(function()
		self:Activate()
	end)
end

-- Public Functions

--[=[
	Manually activates the button without requiring the user to click it.
]=]
function AtomicButton:Activate()
	self._activated:Fire()
	-- Sounds:PlaySound("Click")
end

--[=[
	Manually sets the pressed state of the button without requiring the user to
	click it.

	@param pressed boolean -- The new pressed state
]=]
function AtomicButton:SetPressed(pressed: boolean)
	-- Standardize input into boolean type
	pressed = if not pressed then false else true

	if pressed == self._isPressed then
		return
	end

	self._isPressed = pressed
	self._pressed:Fire(pressed)
	self:SetSpring("Pressed", pressed and 1 or 0)
end

--[=[
	Sets the hovered state of the button

	@param hovered boolean
]=]
function AtomicButton:SetHovered(hovered: boolean)
	-- Standardize input into boolean type
	hovered = if not hovered then false else true

	if hovered == self._isHovered then
		return
	end

	self._isHovered = hovered
	self._hovered:Fire(hovered)
	self:SetSpring("Hovered", hovered and 1 or 0)

	-- if hovered then
	-- 	Sounds:PlaySound("Hover")
	-- end
end

--[=[
	Sets the selected state of the button

	@param selected boolean
]=]
function AtomicButton:SetSelected(selected: boolean)
	-- Standardize input into boolean type
	selected = if not selected then false else true

	if selected == self._isSelected then
		return
	end

	self._selected:Fire(selected)
	self._isSelected = selected
	self:SetSpring("Selected", selected and 1 or 0)
end

--[=[
	Sets the enabled state of the button

	@param enabled boolean
]=]
function AtomicButton:SetEnabled(enabled: boolean)
	-- Standardize input into boolean type
	enabled = if not enabled then false else true

	if enabled == self._isEnabled then
		return
	end

	self._sensor.Visible = enabled
	self._isEnabled = enabled
	self._enabled:Fire(enabled)
	self:SetSpring("Enabled", enabled and 1 or 0)
end

--[=[
	@return boolean -- Whether the button is enabled
]=]
function AtomicButton:IsEnabled(): boolean
	return self._isEnabled
end

--[=[
	@return boolean -- Whether the button is hovered
]=]
function AtomicButton:IsHovered(): boolean
	return self._isHovered
end

--[=[
	@return boolean -- Whether the button is pressed
]=]
function AtomicButton:IsPressed(): boolean
	return self._isPressed
end

--[=[
	@return boolean -- Whether the button is selected
]=]
function AtomicButton:IsSelected(): boolean
	return self._isSelected
end

--[=[
	@tag Constructor
	Creates a new AtomicButton based on the template key or existing frame.
	Instances are mapped based on a simple descendants search, so unique names
	are required for consistency.

	@param template string | Instance -- The name of a GuiObject in ReplicatedStorage.GuiTemplates or an existing instance to use as the button's Gui.
	@param instanceKeys table -- A mapping of instance names to keys for quick access
]=]
--[=[
	@prop Activated RBXScriptSignal<boolean>
	@within AtomicButton
	Fires when the button is activated or deactivated.
]=]
--[=[
	@prop Hovered RBXScriptSignal<boolean>
	@within AtomicButton
	Fires when the button is hovered or unhovered.
]=]
--[=[
	@prop Enabled RBXScriptSignal<boolean>
	@within AtomicButton
	Fires when the button is enabled or disabled.
]=]
--[=[
	@prop Pressed RBXScriptSignal<boolean>
	@within AtomicButton
	Fires when the button is pressed or unpressed.
]=]
--[=[
	@prop Selected RBXScriptSignal<boolean>
	@within AtomicButton
	Fires when the button is selected or unselected.
]=]
--[=[
	@prop _springs {[string]: Spring}
	@within AtomicButton
	@private
	A table of all of the pane's springs. Includes the Alpha, Hovered, Pressed,
	Selected and Enabled springs by default.
]=]
function AtomicButton.new(template: string | Instance, instanceKeys: { [string]: string })
	local self = setmetatable(AtomicPane.new(template, instanceKeys), AtomicButton)

	-- Private members

	self._activated = Instance.new("BindableEvent")
	self._hovered = Instance.new("BindableEvent")
	self._enabled = Instance.new("BindableEvent")
	self._pressed = Instance.new("BindableEvent")
	self._selected = Instance.new("BindableEvent")
	self._isEnabled = true
	self._isHovered = false
	self._isPressed = false
	self._isSelected = false

	-- Public members

	self.Activated = self._activated.Event
	self.Hovered = self._hovered.Event
	self.Enabled = self._enabled.Event
	self.Pressed = self._pressed.Event
	self.Selected = self._selected.Event

	-- Setup

	self:AddSprings({ "Hovered", "Pressed", "Selected" }, { s = 40, d = 1, i = 0 })
	self:AddSpring("Enabled", { s = 40, d = 1, i = 1 })

	self:_addSensor()

	return self
end

return AtomicButton
