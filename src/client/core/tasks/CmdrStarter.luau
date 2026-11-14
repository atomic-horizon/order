--[[ File Info

    Author(s): ChiefWildin
    Module: CmdrStarter.lua
    Version: 1.1.0

    Sets up the Cmdr console and the ways to open it: the F2 key for everyone,
    and for players with the "cmdr" permission, the /cmdr chat command and a
    top bar button (see DeveloperToolsConfig).

]]

-- Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

-- Dependencies

local DeveloperToolsConfig = shared("DeveloperToolsConfig")
local DeveloperTopbar = shared("DeveloperTopbar")
local PermissionService = shared("PermissionService")

-- Module Declaration

local CmdrStarter = {}

-- Constants

local CHAT_COMMAND_PRIMARY_ALIAS = "/cmdr"
local CHAT_COMMAND_SECONDARY_ALIAS = "/console"
local TOPBAR_LABEL = ">_"
local TOPBAR_CAPTION = "Open the command console."
-- Cmdr hides itself when a press lands outside its window, which happens before
-- the top bar registers the click. A hide this recent means the press on the
-- top bar button already closed the console, so it should stay closed.
local CLOSED_BY_BUTTON_PRESS_SECONDS = 0.5

-- Global Variables

local LocalPlayer = Players.LocalPlayer
local CmdrClient

-- Private Functions

local function setupChatCommand(): ()
	local chatCommand = Instance.new("TextChatCommand")
	chatCommand.Name = "CmdrConsole"
	chatCommand.PrimaryAlias = CHAT_COMMAND_PRIMARY_ALIAS
	chatCommand.SecondaryAlias = CHAT_COMMAND_SECONDARY_ALIAS

	chatCommand.Triggered:Connect(function(textSource: TextSource)
		if textSource.UserId ~= LocalPlayer.UserId then
			return
		end

		-- Deferred so the chat bar has released focus before the console's
		-- text box takes it
		task.defer(function()
			CmdrClient:Toggle()
		end)
	end)

	chatCommand.Parent = TextChatService
end

local function setupTopbarButton(): ()
	local button = DeveloperTopbar:AddButton()
	if not button then
		return
	end

	button:setLabel(TOPBAR_LABEL)
	button:setCaption(TOPBAR_CAPTION)

	local consoleWindow = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Cmdr"):WaitForChild("Frame")
	local lastHiddenTime = 0

	consoleWindow:GetPropertyChangedSignal("Visible"):Connect(function()
		if not consoleWindow.Visible then
			lastHiddenTime = os.clock()
		end

		button:setState(if consoleWindow.Visible then "Selected" else "Deselected")
	end)

	button.selected:Connect(function()
		if consoleWindow.Visible then
			return
		end

		if os.clock() - lastHiddenTime < CLOSED_BY_BUTTON_PRESS_SECONDS then
			button:setState("Deselected")
			return
		end

		CmdrClient:Show()
	end)

	button.deselected:Connect(function()
		if consoleWindow.Visible then
			CmdrClient:Hide()
		end
	end)
end

-- Task Initialization

function CmdrStarter:Init()
	CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient")) ---@module CmdrClient
	CmdrClient:SetActivationKeys({ Enum.KeyCode.F2 })

	if not PermissionService:HasPermission(LocalPlayer, "cmdr") then
		return
	end

	if DeveloperToolsConfig.ChatCommands then
		setupChatCommand()
	end

	setupTopbarButton()
end

return CmdrStarter
