return {
	Name = "branch",
	Aliases = { "build" },
	Group = "DefaultAdmin",
	Description = "Teleport to a specific development branch.",
	Args = {
		{
			Type = "branch",
			Name = "branch",
			Description = "The branch to teleport to."
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players who will be teleported to the branch."
		}
	}
}