--[[ File Info

	Author(s): ChiefWildin
	Module: AtomicPane.luau
	Version: 1.3.0

]]

-- Dependencies

local AnimNation = shared("AnimNation")
local GuiTemplates = shared("GuiTemplates")
local lerp = shared("lerp")
local Maid = shared("Maid")

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
export type AtomicPane = {
	-- Metatable members

	__index: AtomicPane,

	-- Public members

	ClassName: string,
	Destroying: RBXScriptSignal,
	Gui: Frame,
	Maid: Maid.Maid,
	VisibleChanged: RBXScriptSignal,

	new: (template: string | Instance, instanceKeys: { [string]: string }) -> AtomicPane,
	Destroy: (self: AtomicPane) -> (),
	Link: (self: AtomicPane, parentPane: AtomicPane, linkVisibility: boolean?) -> (),
	IsVisible: (self: AtomicPane) -> boolean,
	SetVisible: (self: AtomicPane, isVisible: boolean, doNotAnimate: boolean?) -> (),
	Show: (self: AtomicPane, doNotAnimate: boolean?) -> (),
	Hide: (self: AtomicPane, doNotAnimate: boolean?) -> (),
	Toggle: (self: AtomicPane, doNotAnimate: boolean?) -> (),
	AddSpring: (self: AtomicPane, name: string, info: AnimNation.SpringInfo) -> AnimNation.Spring,
	AddSprings: (self: AtomicPane, springs: { string }, info: AnimNation.SpringInfo) -> (),
	SetSpring: (self: AtomicPane, name: string, value: number, instant: boolean?) -> (),
	SetAlphaAnimationEnabled: (self: AtomicPane, enabled: boolean) -> (),
	MapAlpha: (self: AtomicPane, element: UIElement, exclusions: { Instance }?) -> (),
	UnmapAlpha: (self: AtomicPane, element: Instance) -> (),
	SetMappedAlpha: (self: AtomicPane, element: Instance, property: string, visibleAlpha: number) -> (),

	-- Private members

	_alphaMap: { [UIElement]: { [string]: number } },
	_alphaAnimationDisabled: boolean?,
	_destroying: BindableEvent,
	_draw: (self: AtomicPane) -> (),
	_drawMappedAlphas: (self: AtomicPane) -> (),
	_drawMappedElement: (self: AtomicPane, element: Instance) -> (),
	_mapAlphaRecursive: (self: AtomicPane, element: Instance, excludedSet: { [Instance]: boolean }) -> (),
	_maid: Maid.Maid,
	_springs: { [string]: AnimNation.Spring },
	_update: (self: AtomicPane) -> (),
	_useStoryControls: (self: AtomicPane) -> (),
	_visible: boolean,
	_visibleChanged: BindableEvent,
}
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
local AtomicPane = {}
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
	for element in self._alphaMap do
		self:_drawMappedElement(element)
	end
end

--[=[
	@private
	Draws one mapped element at the pane's current alpha. Springs overshoot, so
	the result is clamped to the range transparency accepts.
]=]
function AtomicPane:_drawMappedElement(element: Instance)
	local properties = self._alphaMap[element]
	if not properties then
		return
	end

	local alpha = self._springs.Alpha.Position
	for property, visibleAlpha in properties do
		(element :: any)[property] = math.clamp(lerp(visibleAlpha, 1, alpha), 0, 1)
	end
end

--[=[
	@private
	Maps one element and its descendants, skipping any excluded subtree.
]=]
function AtomicPane:_mapAlphaRecursive(element: Instance, excludedSet: { [Instance]: boolean })
	if excludedSet[element] then
		return
	end

	local isCanvas = element:IsA("CanvasGroup")

	if element:IsA("GuiObject") or element:IsA("UIStroke") then
		local isNewlyMapped = self._alphaMap[element] == nil
		local properties = self._alphaMap[element] or {}
		self._alphaMap[element] = properties

		if element:IsA("GuiObject") then
			properties.BackgroundTransparency = element.BackgroundTransparency
		end

		if element:IsA("TextLabel") or element:IsA("TextBox") or element:IsA("TextButton") then
			properties.TextTransparency = element.TextTransparency
		end

		if element:IsA("ImageLabel") or element:IsA("ImageButton") or element:IsA("ViewportFrame") then
			properties.ImageTransparency = element.ImageTransparency
		end

		if element:IsA("UIStroke") then
			properties.Transparency = element.Transparency
		end

		if element:IsA("CanvasGroup") then
			properties.GroupTransparency = element.GroupTransparency
		end

		if isNewlyMapped then
			element.Destroying:Once(function()
				-- Destroying handlers are deferred, so this can run after the
				-- pane itself was destroyed and its fields cleared
				if self._alphaMap then
					self._alphaMap[element] = nil
				end
			end)
		end

		self:_drawMappedElement(element)
	end

	for _, child in element:GetChildren() do
		if not isCanvas or child:IsA("UIStroke") then
			self:_mapAlphaRecursive(child, excludedSet)
		end
	end
end

--[=[
	@private
	Runs the specific ordering of draw functions for the AtomicPane.
]=]
function AtomicPane:_update()
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
	`Alpha` spring, then draws them at the pane's current alpha.

	The cached values are what each element shows when the pane is fully
	visible, so map elements while they look the way they should when visible.

	@param element Instance -- The top-level instance to map transparencies for
	@param exclusions {Instance}? -- Instances whose subtrees are skipped, such as nested components that drive their own transparencies
]=]
function AtomicPane:MapAlpha(
	element: GuiObject | Frame | TextLabel | TextBox | TextButton | ImageLabel | ImageButton | ViewportFrame | CanvasGroup | UIStroke,
	exclusions: { Instance }?
)
	local excludedSet = {}
	for _, excludedInstance in exclusions or {} do
		excludedSet[excludedInstance] = true
	end

	self:_mapAlphaRecursive(element, excludedSet)
end

--[=[
	Stops driving the specified instance and its descendants from the `Alpha`
	spring. Their transparencies are left as they are, for when another
	animation takes them over.

	@param element Instance -- The top-level instance to stop driving
]=]
function AtomicPane:UnmapAlpha(element: Instance)
	self._alphaMap[element] = nil

	for _, descendant in element:GetDescendants() do
		self._alphaMap[descendant] = nil
	end
end

--[=[
	Changes the transparency a mapped property shows when the pane is fully
	visible, and draws it at the pane's current alpha. For elements whose
	resting look changes after they were mapped.

	@param element Instance -- A mapped instance
	@param property string -- The transparency property, such as "BackgroundTransparency"
	@param visibleAlpha number -- The value it shows when the pane is fully visible
]=]
function AtomicPane:SetMappedAlpha(element: Instance, property: string, visibleAlpha: number)
	local properties = self._alphaMap[element]
	if not properties or properties[property] == nil then
		warn(`[AtomicPane] {element:GetFullName()}.{property} is not mapped`)
		return
	end

	properties[property] = visibleAlpha
	self:_drawMappedElement(element)
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
	@param info SpringInfo? -- The spring parameters to define the initial spring values
]=]
function AtomicPane:AddSpring(name: string, info: AnimNation.SpringInfo?): AnimNation.Spring
	if name == "Visible" then
		warn(
			`{self.ClassName} is adding a spring with the name "Visible", recommended to use "Alpha" instead to avoid accidental conflict with :SetVisible()`
		)
	end

	local springInfo = info or { s = 30, d = 1, i = 0 }

	if self._springs[name] then
		for key, value in springInfo do
			self._springs[name][key] = value
		end
	else
		self._springs[name] = AnimNation.createSpring(springInfo)

		-- Add spring binds cleanup to maid
		self._maid:GiveTask(self._springs[name])

		-- Bind spring update to gui update
		self._springs[name]:Bind("Update", function()
			self:_update()
		end)

		task.defer(self._update, self)
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
	self:SetVisible(false, doNotAnimate)
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
function AtomicPane.Destroy(self: AtomicPane)
	if not self._maid then
		return
	end

	self._destroying:Fire()
	-- Defer so that the signal connections can process
	task.defer(function()
		if not self._maid then
			return
		end

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
	Instances are found breadth first, so when names repeat the shallowest
	match wins. Unique names are still recommended for consistency.

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
function AtomicPane.new(template: string | Instance, instanceKeys: { [string]: string }?): AtomicPane
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

	local searchQueue = { gui }
	local queueIndex = 1
	while queueIndex <= #searchQueue and next(revKeyToInstances) do
		local searchedInstance = searchQueue[queueIndex]
		queueIndex += 1

		for _, child in searchedInstance:GetChildren() do
			local key = revKeyToInstances[child.Name]
			if key then
				revKeyToInstances[child.Name] = nil
				self[key] = child
			end

			table.insert(searchQueue, child)
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
