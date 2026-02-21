--[[ File Info

	Author(s): ChiefWildin
	Module: AtomicPane.luau
	Version: 1.2.1

]]

-- Dependencies

local AnimNation = shared("AnimNation") ---@module AnimNation
local GuiTemplates = shared("GuiTemplates") ---@module GuiTemplates
local lerp = shared("lerp") ---@module lerp
local Maid = shared("Maid") ---@module Maid

-- Types

type UIElement =
	GuiObject
	| Frame
	| TextLabel
	| TextBox
	| TextButton
	| ImageLabel
	| ImageButton
	| ViewportFrame
	| CanvasGroup
	| UIStroke
export type AtomicPaneImpl = {
	-- Metatable members

	__index: AtomicPaneImpl,

	-- Public members

	ClassName: string,

	new: (template: string | Instance, instanceKeys: { [string]: string }) -> AtomicPane,
	Destroy: (self: AtomicPane) -> (),
	Link: (self: AtomicPane, parentPane: AtomicPane, linkVisibility: boolean?) -> (),
	IsVisible: (self: AtomicPane) -> boolean,
	SetVisible: (self: AtomicPane, isVisible: boolean, doNotAnimate: boolean?) -> (),
	Show: (self: AtomicPane, doNotAnimate: boolean?) -> (),
	Hide: (self: AtomicPane, doNotAnimate: boolean?) -> (),
	Toggle: (self: AtomicPane, doNotAnimate: boolean?) -> (),
	AddSpring: (self: AtomicPane, name: string, info: AnimNation.SpringInfo?) -> AnimNation.Spring,
	AddSprings: (self: AtomicPane, springs: { string }, info: AnimNation.SpringInfo?) -> (),
	SetSpring: (self: AtomicPane, name: string, value: number, instant: boolean?) -> (),
	SetAlphaAnimationEnabled: (self: AtomicPane, enabled: boolean) -> (),
	MapAlpha: (self: AtomicPane, element: UIElement) -> (),

	-- Private members

	_draw: (self: AtomicPane) -> (),
	_drawMappedAlphas: (self: AtomicPane) -> (),
	_update: (self: AtomicPane) -> (),
	_useStoryControls: (self: AtomicPane) -> (),
}
export type AtomicPane = typeof(setmetatable(
	{} :: {
		-- Constructed public members
		Gui: Frame,
		Maid: Maid.Maid,
		VisibleChanged: RBXScriptSignal,
		Destroying: RBXScriptSignal,

		-- Constructed private members
		_alphaMap: { [UIElement]: { [string]: number } },
		_alphaAnimationDisabled: boolean?,
		_destroyed: boolean?,
		_destroying: BindableEvent,
		_maid: Maid.Maid,
		_springs: { [string]: AnimNation.Spring },
		_visible: boolean,
		_visibleChanged: BindableEvent,
	},
	{} :: AtomicPaneImpl
))
export type Spring = AnimNation.Spring

-- Module Declaration

--[=[
	@class AtomicPane
	@tag UI

	The foundational model for all UI components in the game. Provides
	visibility controls, spring management, automatic alpha mapping, and more.

	A VS Code snippet for creating AtomicPanes quickly is included with the Git
	repository.

	:::note
	The source GUI objects should be located in
	`ReplicatedStorage.GuiTemplates`. They can be of any GuiObject type.
	:::

	### Basic usage
	```lua
	local AtomicPane = shared("AtomicPane") ---@module AtomicPane

	local ExamplePane = setmetatable({}, AtomicPane)
	ExamplePane.__index = ExamplePane
	ExamplePane.ClassName = "ExamplePane"

	function ExamplePane:_draw()
		local alpha = self._springs.Alpha.Position

		self.Gui.Visible = alpha < 0.999
	end

	function ExamplePane.new(parent: Instance)
		local self = setmetatable(AtomicPane.new("ExamplePaneTemplate", {}), ExamplePane)

		self:SetVisible(false, true)

		self.Gui.Parent = parent

		return self
	end

	return ExamplePane
	```
]=]
local AtomicPane: AtomicPaneImpl = {} :: AtomicPaneImpl
AtomicPane.__index = AtomicPane
AtomicPane.ClassName = "AtomicPane"

-- Private Functions

--[=[
	@tag Override
	An overridable function used to update the properties of various UI elements
	using values from the `_springs` table.
]=]
function AtomicPane:_draw() end

--[=[
	@private
	An internal function used to automatically update the alpha values of mapped
	UI elements.
]=]
function AtomicPane:_drawMappedAlphas()
	for element, properties in self._alphaMap do
		for property, visibleAlpha in properties do
			element[property] = lerp(visibleAlpha, 1, self._springs.Alpha.Position)
		end
	end
end

--[=[
	@private
	Runs the specific ordering of draw functions for the AtomicPane.
]=]
function AtomicPane:_update()
	if self._destroyed then
		return
	end

	self:_drawMappedAlphas()
	self:_draw()
end

--[=[
	@private
	Gives the AtomicPane some default controls for working with Hoarcekat or UI
	Labs
]=]
function AtomicPane:_useStoryControls()
	self:SetVisible(true)
	self._maid:GiveTask(game:GetService("UserInputService").InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.V then
			self:Toggle()
		end
	end))
end

-- Public Functions

--[=[
	Allows you to link this AtomicPane to another AtomicPane. This is useful to
	make sure that proper cleanup occurs when a parent pane is destroyed, for
	example.

	@param parentPane AtomicPane -- The AtomicPane to link to
	@param linkVisibility boolean? -- Whether to link the visibility of this pane to the parent pane
]=]
function AtomicPane:Link(parentPane: AtomicPane, linkVisibility: boolean?)
	parentPane.Maid:GiveTask(self)
	if linkVisibility then
		self.Maid:GiveTask(parentPane.VisibleChanged:Connect(function(visible: boolean, doNotAnimate: boolean?)
			self:SetVisible(visible, doNotAnimate)
		end))
	end
end

--[=[
	Caches the current transparency values of the specified instance and all its
	descendants in an internal table for automatic interpolation based on the
	`Alpha` spring.

	@param element Instance -- The top-level instance to map transparencies for
]=]
function AtomicPane:MapAlpha(
	element: GuiObject | Frame | TextLabel | TextBox | TextButton | ImageLabel | ImageButton | ViewportFrame | CanvasGroup | UIStroke
)
	local isCanvas = element:IsA("CanvasGroup")

	if element:IsA("GuiObject") or element:IsA("UIStroke") then
		if not self._alphaMap[element] then
			self._alphaMap[element] = {}
		end

		if element:IsA("GuiObject") then
			self._alphaMap[element].BackgroundTransparency = element.BackgroundTransparency
		end

		if element:IsA("TextLabel") or element:IsA("TextBox") or element:IsA("TextButton") then
			self._alphaMap[element].TextTransparency = element.TextTransparency
		end

		if element:IsA("ImageLabel") or element:IsA("ImageButton") or element:IsA("ViewportFrame") then
			self._alphaMap[element].ImageTransparency = element.ImageTransparency
		end

		if element:IsA("UIStroke") then
			self._alphaMap[element].Transparency = element.Transparency
		end

		if isCanvas then
			self._alphaMap[element].GroupTransparency = element.GroupTransparency
		end
	end

	element.Destroying:Once(function()
		self._alphaMap[element] = nil
	end)

	for _, child in element:GetChildren() do
		if not isCanvas or child:IsA("UIStroke") then
			self:MapAlpha(child)
		end
	end
end

--[=[
	Sets the target value of a spring by name. `Alpha` is available by default.
	AtomicButtons add `Hovered`, `Pressed`, `Selected`, and `Enabled` springs.

	@param name string -- The name of the spring to modify
	@param value number -- The target value to set the spring to
	@param instant boolean? -- Whether to instantly set the spring to the target value
]=]
function AtomicPane:SetSpring(name: string, value: number, instant: boolean?)
	if not self._springs[name] then
		warn(`Attempt to set value for missing spring "{name}" - {value} ({self.ClassName})`)
		return
	end

	self._springs[name].Target = value
	if instant then
		self._springs[name].Position = value
	end
end

--[=[
	Adds a custom spring to the AtomicPane, which will automatically bind to the
	`_draw` function and be available in the `_springs` table.

	@param name string -- The name of the spring to add
	@param info table -- The spring parameters to define the initial spring	values, defaults to { s = 30, d = 1, i = 0 }
]=]
function AtomicPane:AddSpring(name: string, info: AnimNation.SpringInfo?): AnimNation.Spring
	info = info or { s = 30, d = 1, i = 0 }

	if self._springs[name] then
		for key, value in info do
			self._springs[name][key] = value
		end
	else
		self._springs[name] = AnimNation.createSpring(info)

		-- Add spring binds cleanup to maid
		self._maid:GiveTask(self._springs[name])

		-- Bind spring update to gui update
		task.defer(function()
			self._springs[name]:Bind("Update", function()
				self:_update()
			end)
		end)
	end

	return self._springs[name]
end

--[=[
	Adds multiple custom springs to the AtomicPane, which will automatically bind
	to the `_draw` function and be available in the `_springs` table.

	@param springs table -- The list of spring names to add
	@param info table -- The spring parameters to define the initial spring values
]=]
function AtomicPane:AddSprings(springs: { string }, info: AnimNation.SpringInfo)
	for _, spring in springs do
		self:AddSpring(spring, info)
	end
end

--[=[
	Sets the visibility of the AtomicPane.

	@param isVisible boolean -- Whether to make it visible
	@param doNotAnimate boolean? -- Whether the transition is animated or instant
]=]
function AtomicPane:SetVisible(isVisible: boolean, doNotAnimate: boolean?)
	-- Standardize input into boolean type
	isVisible = if not isVisible then false else true

	if isVisible == self._visible then
		return
	end

	if typeof(doNotAnimate) == "table" then
		doNotAnimate = nil
	end

	self:SetSpring("Alpha", isVisible and 0 or 1, doNotAnimate or self._alphaAnimationDisabled)

	self._visible = isVisible
	self._visibleChanged:Fire(isVisible, doNotAnimate)
end

--[=[
	Sets the visibility of the AtomicPane to true.

	@param doNotAnimate boolean? -- Whether the transition is animated or instant
]=]
function AtomicPane:Show(doNotAnimate: boolean?)
	self:SetVisible(true, doNotAnimate)
end

--[=[
	Sets the visibility of the AtomicPane to false.

	@param doNotAnimate boolean? -- Whether the transition is animated or instant
]=]
function AtomicPane:Hide(doNotAnimate: boolean?)
	local success, message = pcall(function()
		self:SetVisible(false, doNotAnimate)
	end)
	if not success then
		warn(`Failed to hide AtomicPane: {message}`, self)
	end
end

--[=[
	Toggles the visibility of the AtomicPane.

	@param doNotAnimate boolean? -- Whether the transition is animated or instant
]=]
function AtomicPane:Toggle(doNotAnimate: boolean?)
	self:SetVisible(not self._visible, doNotAnimate)
end

--[=[
	@return boolean -- Whether the AtomicPane is currently visible
]=]
function AtomicPane:IsVisible(): boolean
	return self._visible
end

--[=[
	When enabled, forces a global override so that all Visible transitions are
	instant. It essentially makes doNotAnimate always true.

	@param enabled boolean
]=]
function AtomicPane:SetAlphaAnimationEnabled(enabled: boolean)
	self._alphaAnimationDisabled = not enabled
end

--[=[
	Destroys the AtomicPane and cleans up all maid tasks.

	@param self AtomicPane
]=]
function AtomicPane.Destroy(self: any | AtomicPane)
	self._destroyed = true
	self._destroying:Fire()
	-- Defer so that the signal connections can process
	task.defer(function()
		self._maid:Destroy()
		self._maid = nil
		self.Maid = nil
		setmetatable(self, nil)

		for _, spring in self._springs do
			spring:Destroy()
		end

		for i in self do
			self[i] = nil
		end

		table.freeze(self)
	end)
end

--[=[
	@tag Constructor
	Creates a new AtomicPane based on the template key or existing frame.
	Instances are mapped based on a simple descendants search, so unique names
	are required for consistency.

	@param template string | Instance -- The name of a GuiObject in ReplicatedStorage.GuiTemplates or an existing instance to use as the pane's Gui.
	@param instanceKeys table -- A mapping of instance names to keys for quick access
]=]
--[=[
	@prop Gui Frame
	@within AtomicPane
	The root GuiObject of a constructed AtomicPane
]=]
--[=[
	@prop Maid Maid
	@within AtomicPane
	The AtomicPane's dedicated Maid, which cleans up when the pane is destroyed,
	or a linked (see AtomicPane:Link()) parent pane is destroyed.
]=]
--[=[
	@prop VisibleChanged RBXScriptSignal<boolean>
	@within AtomicPane
	Fired when the visibility of the pane changes. Provides the new visibility
	state and whether the change was animated or instant.
]=]
--[=[
	@prop Destroying RBXScriptSignal
	@within AtomicPane
	Fired when the pane is being destroyed.
]=]
--[=[
	@prop _springs {[string]: Spring}
	@within AtomicPane
	@private
	A table of all of the pane's springs. Includes the Alpha spring by default.
]=]
function AtomicPane.new(template: string | Instance, instanceKeys: { [string]: string }?)
	assert(
		typeof(template) == "string" or typeof(template) == "Instance",
		"Template must be an existing instance or name of a GuiTemplate."
	)

	instanceKeys = instanceKeys or {}
	assert(typeof(instanceKeys) == "table", "instanceKeys must be a table of string to string.")

	local self = setmetatable({}, AtomicPane)

	-- Private members

	self._maid = Maid.new()
	self._springs = {}
	self._alphaMap = {}
	self._visible = true
	self._visibleChanged = Instance.new("BindableEvent")
	self._destroying = Instance.new("BindableEvent")

	local gui: Instance
	if typeof(template) == "string" then
		gui = GuiTemplates:Clone(template)
	else
		gui = template
	end
	self._gui = gui

	-- Public members

	self.Maid = self._maid
	self.Gui = gui
	self.VisibleChanged = self._visibleChanged.Event
	self.Destroying = self._destroying.Event

	-- Setup

	self._maid:GiveTask(gui)
	self._maid:GiveTask(self._visibleChanged)
	self._maid:GiveTask(self._destroying)

	self:AddSpring("Alpha", { s = 40, d = 1, i = 0 })

	local revKeyToInstances = {}
	for k, v in instanceKeys do
		revKeyToInstances[v] = k
	end

	local name, key
	for _, descendant in gui:GetDescendants() do
		name = descendant.Name
		key = revKeyToInstances[name]
		if key then
			revKeyToInstances[name] = nil
			self[key] = descendant
		end
	end

	local isMissingComponent = false
	for missingName, missingKey in revKeyToInstances do
		warn(`{gui.Name} ({self.ClassName}) couldn't get {missingKey} = "{missingName}"!`)
		isMissingComponent = true
	end
	if isMissingComponent then
		warn("Source instance:", if typeof(template) == "string" then GuiTemplates:Get(template) else template)
	end

	return self
end

return AtomicPane
