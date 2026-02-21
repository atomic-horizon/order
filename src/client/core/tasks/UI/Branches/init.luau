local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local BranchesPane = shared("BranchesPane") ---@module BranchesPane
local GetBranches = shared("GetBranches") ---@module GetBranches
local GetRemote = shared("GetRemote") ---@module GetRemote
local Icon = shared("TopbarPlus") ---@module TopbarPlus
local PermissionService = shared("PermissionService") ---@module PermissionService

--[=[
	@class Branches
]=]
local Branches = {}

local TOGGLE_KEY_BIND = Enum.KeyCode.F3
local TOGGLE_KEY_HINT = "Press F3 to Toggle"

local LocalPlayer = Players.LocalPlayer
local Pane
local Remote = GetRemote("BranchesPane:TeleportToPlace")

function Branches:_updatePaneKeyBindHint()
	if not UserInputService.KeyboardEnabled then
		Pane:SetKeyBindHint(nil)
		return
	end
	Pane:SetKeyBindHint(TOGGLE_KEY_HINT)
end

function Branches:_setupKeyCombo()
	ContextActionService:BindActionAtPriority("BranchesKeyCombo", function(actionName, state, input)
		if state == Enum.UserInputState.Begin then
			Pane:Toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.Low.Value, TOGGLE_KEY_BIND)

	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(function()
		self:_updatePaneKeyBindHint()
	end)
	self:_updatePaneKeyBindHint()
end

function Branches:_setupBranches()
	local branches = GetBranches()
	Pane:SetBranches(branches)

	Pane.BranchActivated:Connect(function(branch)
		Remote:FireServer(branch.PlaceId)
	end)
end

function Branches:_setupIcon()
	Icon.setDisplayOrder(1_001)
	Icon.highlightKey = Enum.KeyCode.ButtonR3

	local branchButton = Icon.new()
	branchButton:setCaption("Teleport to a branch.")
	branchButton:setImageScale(0.6)
	branchButton:setImage("rbxassetid://75313622855437") -- Branch icon.
	branchButton.selected:Connect(function()
		Pane:Show()
	end)
	branchButton.deselected:Connect(function()
		Pane:Hide()
	end)
	Pane.VisibleChanged:Connect(function(visible)
		branchButton:setState(if visible then "Selected" else "Deselected")
	end)
end

function Branches:_setupGui()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Branches"
	screenGui.DisplayOrder = 1_001
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = LocalPlayer.PlayerGui

	Pane = BranchesPane.new()
	Pane.CloseActivated:Connect(function()
		Pane:Hide()
	end)
	Pane.Gui.Parent = screenGui
	Pane:SetVisible(false, true)
end

function Branches:Init()
	local admin = PermissionService:HasPermission(LocalPlayer, "branches")
	if not admin then
		return
	end

	self:_setupGui()
	self:_setupIcon()
	self:_setupBranches()
	self:_setupKeyCombo()
end

return Branches
