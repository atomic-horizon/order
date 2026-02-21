local function BranchesPaneTemplate()
	local branchesPane = Instance.new("Frame")
	branchesPane.Name = "BranchesPane"
	branchesPane.AnchorPoint = Vector2.new(0.5, 0.5)
	branchesPane.BackgroundTransparency = 1
	branchesPane.Position = UDim2.fromScale(0.5, 0.5)
	branchesPane.Size = UDim2.fromScale(1, 0.4)

	local uIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	uIAspectRatioConstraint.Name = "UIAspectRatioConstraint"
	uIAspectRatioConstraint.AspectRatio = 1.4
	uIAspectRatioConstraint.Parent = branchesPane

	local dropShadow = Instance.new("ImageLabel")
	dropShadow.Name = "DropShadow"
	dropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	dropShadow.AutoLocalize = false
	dropShadow.BackgroundTransparency = 1
	dropShadow.Image = "rbxassetid://6150493168"
	dropShadow.ImageColor3 = Color3.new()
	dropShadow.ImageTransparency = 0.5
	dropShadow.Position = UDim2.fromScale(0.5, 0.5)
	dropShadow.ScaleType = Enum.ScaleType.Slice
	dropShadow.Size = UDim2.new(1, 32, 1, 32)
	dropShadow.SliceCenter = Rect.new(88, 88, 112, 112)
	dropShadow.SliceScale = 0.35
	dropShadow.ZIndex = -10
	dropShadow.Parent = branchesPane

	local canvasGroup = Instance.new("CanvasGroup")
	canvasGroup.Name = "CanvasGroup"
	canvasGroup.BackgroundTransparency = 1
	canvasGroup.Size = UDim2.fromScale(1, 1)

	local design = Instance.new("Frame")
	design.Name = "Design"
	design.AnchorPoint = Vector2.new(0.5, 0.5)
	design.BackgroundColor3 = Color3.new()
	design.Position = UDim2.fromScale(0.5, 0.5)
	design.Size = UDim2.new(1, -4, 1, -4)

	local designStroke = Instance.new("UIStroke")
	designStroke.Name = "DesignStroke"
	designStroke.Color = Color3.new(1, 1, 1)
	designStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	designStroke.Thickness = 0.005

	local uIGradient = Instance.new("UIGradient")
	uIGradient.Name = "UIGradient"
	uIGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 85, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 148, 94)),
	})
	uIGradient.Rotation = 90
	uIGradient.Parent = designStroke

	designStroke.Parent = design

	local uICorner = Instance.new("UICorner")
	uICorner.Name = "UICorner"
	uICorner.CornerRadius = UDim.new(0, 12)
	uICorner.Parent = design

	design.Parent = canvasGroup

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)

	local headerRow = Instance.new("Frame")
	headerRow.Name = "HeaderRow"
	headerRow.AnchorPoint = Vector2.new(0.5, 0.5)
	headerRow.BackgroundTransparency = 1
	headerRow.Position = UDim2.fromScale(0.5, 0.065)
	headerRow.Size = UDim2.fromScale(0.9, 0.13)

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Name = "HeaderLabel"
	headerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	headerLabel.BackgroundTransparency = 1
	headerLabel.FontFace = Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	headerLabel.Position = UDim2.fromScale(0.5, 0.5)
	headerLabel.Size = UDim2.fromScale(1, 0.8)
	headerLabel.Text = "Branches"
	headerLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	headerLabel.TextScaled = true
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Parent = headerRow

	headerRow.Parent = content

	local keybindHintLabel = Instance.new("TextLabel")
	keybindHintLabel.Name = "KeybindHintLabel"
	keybindHintLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	keybindHintLabel.BackgroundTransparency = 1
	keybindHintLabel.FontFace = Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	keybindHintLabel.Position = UDim2.fromScale(0.5, 0.13)
	keybindHintLabel.Size = UDim2.fromScale(0.9, 0.05)
	keybindHintLabel.Text = "Quick open clue."
	keybindHintLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	keybindHintLabel.TextScaled = true
	keybindHintLabel.TextXAlignment = Enum.TextXAlignment.Left
	keybindHintLabel.Parent = content

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "ScrollingFrame"
	scrollingFrame.Active = true
	scrollingFrame.AnchorPoint = Vector2.new(0.5, 1)
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.BottomImage = "rbxassetid://100367069969300"
	scrollingFrame.MidImage = "rbxassetid://127907951252823"
	scrollingFrame.Position = UDim2.fromScale(0.5, 1)
	scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(115, 59, 26)
	scrollingFrame.ScrollBarThickness = 10
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Size = UDim2.new(1, 0, 0.84, -4)
	scrollingFrame.TopImage = "rbxassetid://135229472772535"
	scrollingFrame.ZIndex = 2

	local uIPadding = Instance.new("UIPadding")
	uIPadding.Name = "UIPadding"
	uIPadding.PaddingLeft = UDim.new(0, 12)
	uIPadding.PaddingRight = UDim.new(0, 12)
	uIPadding.Parent = scrollingFrame

	local uIListLayout = Instance.new("UIListLayout")
	uIListLayout.Name = "UIListLayout"
	uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uIListLayout.Parent = scrollingFrame

	scrollingFrame.Parent = content

	local uIPadding1 = Instance.new("UIPadding")
	uIPadding1.Name = "UIPadding"
	uIPadding1.PaddingBottom = UDim.new(0, 8)
	uIPadding1.PaddingLeft = UDim.new(0, 8)
	uIPadding1.PaddingRight = UDim.new(0, 8)
	uIPadding1.PaddingTop = UDim.new(0, 8)
	uIPadding1.Parent = content

	content.Parent = canvasGroup

	canvasGroup.Parent = branchesPane

	local uISizeConstraint = Instance.new("UISizeConstraint")
	uISizeConstraint.Name = "UISizeConstraint"
	uISizeConstraint.MinSize = Vector2.new(0, 300)
	uISizeConstraint.Parent = branchesPane

	return branchesPane
end

-- BranchesPaneTemplate().Parent = game.StarterGui

return BranchesPaneTemplate
