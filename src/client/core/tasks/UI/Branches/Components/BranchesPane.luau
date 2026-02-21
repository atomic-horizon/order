--[[ File Info

	Author(s): ChiefWildin
	Module: BranchesPane.luau
	Version: 1.0.0

]]

-- Services

-- Dependencies

local AtomicPane = shared("AtomicPane") ---@module AtomicPane
local BranchButton = shared("BranchButton") ---@module BranchButton
local BranchCloseButton = shared("BranchCloseButton") ---@module BranchCloseButton
local BranchesPaneTemplate = shared("BranchesPaneTemplate") ---@module BranchesPaneTemplate
local GetBranches = shared("GetBranches") ---@module GetBranches
local lerp = shared("lerp") ---@module lerp
local Signal = shared("Signal") ---@module Signal

-- Types

-- Module Declaration

local BranchesPane = setmetatable({}, AtomicPane)
BranchesPane.__index = BranchesPane
BranchesPane.ClassName = "BranchesPane"

-- Constants

-- Global Variables

-- Objects

-- Private Functions

function BranchesPane:_draw()
	local alpha = self._springs.Alpha.Position

	self._canvasGroup.GroupTransparency = alpha
	self._dropShadow.ImageTransparency = lerp(0.4, 1, alpha)
	self.Gui.Position = UDim2.fromScale(0.5, 0.5 + 0.02 * alpha)

	self.Gui.Visible = alpha < 0.999
end

function BranchesPane:_initCloseButton()
	self._closeButton = BranchCloseButton.new()
	self._closeButton.Gui.Parent = self._content

	self.Maid:GiveTask(self._closeButton)
	self.CloseActivated = self._closeButton.Activated
end

function BranchesPane:_createButton(branch: GetBranches.Branch)
	local button = BranchButton.new(branch.DisplayName, `rbxthumb://type=GameThumbnail&id={branch.PlaceId}&w=480&h=270`)
	button.Branch = branch
	button:SetAlphaAnimationEnabled(false)
	button:SetVisible(self._visible, true)
	button.Gui.Parent = self._scrollingFrame

	button.Maid:GiveTask(button.Activated:Connect(function()
		self:_onButtonActivated(button)
	end))
	return button
end

function BranchesPane:_onButtonActivated(button)
	self.BranchActivated:Fire(button.Branch)
	button:SetEnabled(false)
	button.Maid:GiveTask(task.delay(15, function()
		button:SetEnabled(true)
	end))
end

-- Public Functions

function BranchesPane:SetBranches(branches: { GetBranches.Branch })
	self._buttonsMaid:DoCleaning()
	table.clear(self._buttons)

	for _, branch in branches do
		local button = self:_createButton(branch)
		table.insert(self._buttons, button)
		self._buttonsMaid:GiveTask(button)
	end

	table.sort(self._buttons, function(a, b)
		if a.Main ~= b.Main then
			return a.Main
		end
		return a.Branch.DisplayName < b.Branch.DisplayName
	end)

	for index, button in self._buttons do
		button.Gui.LayoutOrder = index
	end
end

function BranchesPane:SetKeyBindHint(hint: string?)
	self._keybindHintLabel.Text = hint or ""
end

function BranchesPane.new(parent: Instance)
	local self = setmetatable(
		AtomicPane.new(BranchesPaneTemplate(), {
			_canvasGroup = "CanvasGroup",
			_content = "Content",
			_dropShadow = "DropShadow",
			_keybindHintLabel = "KeybindHintLabel",
			_scrollingFrame = "ScrollingFrame",
			_layout = "UIListLayout",
		}),
		BranchesPane
	)

	-- Private members

	self._buttonsMaid = self.Maid.new()
	self._buttons = {}

	-- Public members

	self.BranchActivated = Signal.new()

	-- Setup

	self.Maid:GiveTask(self.BranchActivated)
	self.Maid:GiveTask(self._buttonsMaid)

	self:_initCloseButton()

	self.Maid:GiveTask(self.VisibleChanged:Connect(function(visible, doNotAnimate)
		self._closeButton:SetVisible(visible, doNotAnimate)
		for _, button in self._buttons do
			button:SetVisible(visible, doNotAnimate)
		end

		self._scrollingFrame.CanvasSize = UDim2.fromOffset(0, self._layout.AbsoluteContentSize.Y + 32)
	end))

	self:SetVisible(false, true)

	self.Gui.Parent = parent

	return self
end

return BranchesPane
