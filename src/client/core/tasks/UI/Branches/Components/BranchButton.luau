--[[ File Info

	Author(s): ChiefWildin
	Module: BranchButton.luau
	Version: 1.0.0

]]

-- Services

-- Dependencies

local AtomicButton = shared("AtomicButton") ---@module AtomicButton
local BranchButtonTemplate = shared("BranchButtonTemplate") ---@module BranchButtonTemplate

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

local LABEL_COLOR = Color3.fromRGB(245, 245, 245)
local LABEL_DISABLED_COLOR = Color3.fromRGB(127, 127, 127)

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
	self._label.TextColor3 = LABEL_COLOR:Lerp(LABEL_DISABLED_COLOR, 1 - enabled)

	self.Gui.Visible = alpha < 0.999
end

-- Public Functions

function BranchButton.new(text: string?, image: string?)
	local self = setmetatable(
		AtomicButton.new(BranchButtonTemplate(), {
			_designStroke = "DesignStroke",
			_design = "Design",
			_label = "Label",
			_scale = "UIScale",
			_thumbnail = "Thumbnail",
		}),
		BranchButton
	)

	-- Private members

	-- Public members

	-- Setup

	self._label.Text = text or "[Unknown]"
	self._thumbnail.Image = image or ""

	self.Maid:GiveTask(self.Hovered:Connect(function(hovered)
		self.Gui.ZIndex = if hovered then 2 else 1
	end))

	self:SetVisible(false, true)

	return self
end

return BranchButton
