--[[ File Info

	Author(s): ChiefWildin
	Module: BranchCloseButton.luau
	Version: 1.0.0

]]

-- Services

-- Dependencies

local AtomicButton = shared("AtomicButton") ---@module AtomicButton
local BranchCloseButtonTemplate = shared("BranchCloseButtonTemplate") ---@module BranchCloseButtonTemplate

-- Types

-- Module Declaration

local BranchButton = setmetatable({}, AtomicButton)
BranchButton.__index = BranchButton
BranchButton.ClassName = "BranchButton"

-- Constants

local DESIGN_COLOR = Color3.fromRGB(50, 50, 50)
local DESIGN_DISABLED_COLOR = Color3.fromRGB(34, 34, 34)
local DESIGN_HIGHLIGHT_COLOR = Color3.fromRGB(133, 133, 133)
local DESIGN_PRESS_COLOR = Color3.fromRGB(212, 212, 212)

-- Global Variables

-- Objects

-- Private Functions

function BranchButton:_draw()
	local alpha = self._springs.Alpha.Position
	local hover = self._springs.Hovered.Position
	local press = self._springs.Pressed.Position
	local enabled = self._springs.Enabled.Position

	self._scale.Scale = 0.96 + 0.04 * hover - 0.1 * press

	self._design.BackgroundColor3 = DESIGN_COLOR:Lerp(DESIGN_HIGHLIGHT_COLOR, hover)
		:Lerp(DESIGN_PRESS_COLOR, press)
		:Lerp(DESIGN_DISABLED_COLOR, 1 - enabled)

	self.Gui.Visible = alpha < 0.999
end

-- Public Functions

function BranchButton.new()
	local self = setmetatable(
		AtomicButton.new(BranchCloseButtonTemplate(), {
			_design = "Design",
			_scale = "UIScale",
		}),
		BranchButton
	)

	-- Private members

	-- Public members

	-- Setup

	self.Maid:GiveTask(self.Hovered:Connect(function(hovered)
		self.Gui.ZIndex = if hovered then 2 else 1
	end))

	self:SetVisible(false, true)

	return self
end

return BranchButton
