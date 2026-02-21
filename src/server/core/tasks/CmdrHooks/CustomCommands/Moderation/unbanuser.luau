return {
	Name = "unbanuser",
	Aliases = {},
	Group = "DefaultAdmin",
	Description = "Unbans a player by username using Roblox's BanService",
	Args = {
		{
			Type = "string",
			Name = "Username",
			Description = "The username of the player to unban."
		},
	}
}