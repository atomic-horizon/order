local function BranchButtonTemplate(): GuiBase2d
	local branchButton = Instance.new("Frame")
	branchButton.Name = "BranchButton"
	branchButton.AnchorPoint = Vector2.new(0.5, 0.5)
	branchButton.BackgroundTransparency = 1
	branchButton.Position = UDim2.fromScale(0.5, 0.5)
	branchButton.Size = UDim2.new(1, 0, 0, 80)

	local uIScale = Instance.new("UIScale")
	uIScale.Scale = 1
	uIScale.Parent = branchButton

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

	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.AnchorPoint = Vector2.new(0.5, 0.5)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Image = "rbxthumb://type=GameThumbnail&id=15694891095&w=480&h=270"
	thumbnail.ImageTransparency = 0.5
	thumbnail.Position = UDim2.fromScale(0.5, 0.5)
	thumbnail.ScaleType = Enum.ScaleType.Crop
	thumbnail.Size = UDim2.fromScale(1, 1)

	local uICorner1 = Instance.new("UICorner")
	uICorner1.Name = "UICorner"
	uICorner1.CornerRadius = UDim.new(0.15, 0)
	uICorner1.Parent = thumbnail

	thumbnail.Parent = design

	design.Parent = branchButton

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.AutoLocalize = false
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	label.Position = UDim2.fromScale(0.5, 0.9)
	label.Size = UDim2.fromScale(0.925, 0.5)
	label.Text = "Main Place"
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = branchButton

	return branchButton
end

-- BranchButtonTemplate().Parent = game.StarterGui

return BranchButtonTemplate
