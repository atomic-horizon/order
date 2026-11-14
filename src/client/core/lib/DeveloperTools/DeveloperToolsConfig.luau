--[[ File Info

	Module: DeveloperToolsConfig.luau
	Version: 1.0.0

	Settings for how players with the right permissions open the developer tools
	(the Cmdr console and the Branches pane).

]]

--[=[
	@class DeveloperToolsConfig
	@client

	Settings for how players with the right permissions open the developer
	tools. Edit the values in this module to change them for a project.
]=]

return {
	-- Adds the /cmdr (also /console) and /branches chat commands for players
	-- with the "cmdr" and "branches" permissions. Chat is the only way to open
	-- these tools on touch devices without the top bar buttons.
	ChatCommands = true,

	-- Adds top bar buttons for the Cmdr console and the Branches pane for
	-- players with the matching permission.
	TopbarButtons = true,

	-- When a player can see more than one developer top bar button, puts them in
	-- one top bar group that expands when selected, instead of separate buttons.
	GroupTopbarButtons = true,
}
