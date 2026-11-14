--[[ File Info

	Module: DeveloperTopbar.luau
	Version: 1.0.0

	Creates the top bar buttons for the developer tools. When a player can see
	more than one, they are gathered into a single expandable group.

]]

-- Dependencies

local DeveloperToolsConfig = shared("DeveloperToolsConfig")
local Icon = shared("TopbarPlus")

-- Types

type Icon = any

-- Module Declaration

--[=[
	@class DeveloperTopbar
	@client

	Creates the top bar buttons for the developer tools. Respects the
	`TopbarButtons` and `GroupTopbarButtons` settings in
	[DeveloperToolsConfig].
]=]
local DeveloperTopbar = {}

-- Constants

local GROUP_LABEL = "Dev"
local GROUP_CAPTION = "Developer tools"

-- Global Variables

local Buttons: { Icon } = {}
local GroupIcon: Icon? = nil

-- Private Functions

local function updateGroup(): ()
	if not DeveloperToolsConfig.GroupTopbarButtons or #Buttons < 2 then
		return
	end

	if not GroupIcon then
		GroupIcon = Icon.new()
		GroupIcon:setLabel(GROUP_LABEL)
		GroupIcon:setCaption(GROUP_CAPTION)
	end

	GroupIcon:setMenu(Buttons)
end

-- Public Functions

--[=[
	Creates a developer tools top bar button and returns it, or returns `nil`
	when top bar buttons are turned off. Once a second button is added, all of
	them move into one group unless grouping is turned off.

	@return Icon? -- A TopbarPlus icon
]=]
function DeveloperTopbar:AddButton(): Icon?
	if not DeveloperToolsConfig.TopbarButtons then
		return nil
	end

	local button = Icon.new()
	table.insert(Buttons, button)
	updateGroup()

	return button
end

return DeveloperTopbar
