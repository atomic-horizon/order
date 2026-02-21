local function BranchCloseButtonTemplate(): GuiBase2d
	local branchCloseButton = Instance.new("Frame")
	branchCloseButton.Name = "BranchCloseButton"
	branchCloseButton.AnchorPoint = Vector2.new(1, 0)
	branchCloseButton.BackgroundTransparency = 1
	branchCloseButton.Position = UDim2.new(1, 0, 0, 0)
	branchCloseButton.Size = UDim2.new(0.08, 16, 0.08, 16)
	branchCloseButton.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local uIScale = Instance.new("UIScale")
	uIScale.Scale = 1
	uIScale.Parent = branchCloseButton

	local design = Instance.new("Frame")
	design.Name = "Design"
	design.AnchorPoint = Vector2.new(0.5, 0.5)
	design.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	design.Position = UDim2.fromScale(0.5, 0.5)
	design.Size = UDim2.new(1, -8, 1, -8)

	local uICorner = Instance.new("UICorner")
	uICorner.Name = "UICorner"
	uICorner.CornerRadius = UDim.new(0.15, 0)
	uICorner.Parent = design

	local designStroke = Instance.new("UIStroke")
	designStroke.Name = "DesignStroke"
	designStroke.Color = Color3.fromRGB(127, 127, 127)
	designStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	designStroke.Thickness = 0.02

	local uIGradient = Instance.new("UIGradient")
	uIGradient.Name = "UIGradient"
	uIGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 85, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 148, 94)),
	})
	uIGradient.Rotation = 90
	uIGradient.Parent = designStroke

	designStroke.Parent = design

	local uIGradient1 = Instance.new("UIGradient")
	uIGradient1.Name = "UIGradient"
	uIGradient1.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 85, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 148, 94)),
	})
	uIGradient1.Rotation = 90
	uIGradient1.Parent = design

	design.Parent = branchCloseButton

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.AutoLocalize = false
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.925, 0.5)
	label.Text = "X"
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = branchCloseButton

	return branchCloseButton
end

-- BranchButtonTemplate().Parent = game.StarterGui

return BranchCloseButtonTemplate
