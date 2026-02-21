return {
	Name = "banuser",
	Aliases = {},
	Group = "DefaultAdmin",
	Description = "Bans a player by username using Roblox's BanService",
	Args = {
		{
			Type = "string",
			Name = "Username",
			Description = "The username of the player to ban."
		},
		{
			Type = "number",
			Name = "Duration",
			Description = "How long to ban the user for in days. Set to 0 for a permanent ban."
		},
		{
			Type = "string",
			Name = "PublicReason",
			Description = "The reason for the ban that will be shown to the user. (make sure to type this in quotes)"
		},
		{
			Type = "string",
			Name = "PrivateReason",
			Description = "The reason for the ban for our internal notes. (make sure to type this in quotes)"
		},
		{
			Type = "boolean",
			Name = "AlsoBanAlts",
			Description = "Whether to ban the user's known alt accounts as well."
		}
	}
}