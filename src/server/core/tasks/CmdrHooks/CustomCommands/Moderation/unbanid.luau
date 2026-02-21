return {
	Name = "unbanid",
	Aliases = { "unban" },
	Group = "DefaultAdmin",
	Description = "Unbans a player by ID using Roblox's BanService",
	Args = {
		{
			Type = "number",
			Name = "UserId",
			Description = "The ID of the player to unban."
		},
	}
}