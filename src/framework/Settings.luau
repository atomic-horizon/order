export type Initializer = {
	Name: string,
	Async: boolean,
	Protected: boolean,
	WarnDelay: number,
}

export type Environment = "Production" | "Testing"

export type PlaceTypeEntry = {
	Type: string,
	Environment: Environment?,
}

export type OrderSettings = {
	Debug: {
		CyclicAnalysis: boolean,
		VerboseLoading: boolean,
	},
	PlaceTypes: { [number]: string | PlaceTypeEntry },
	CodeGroups: { [string]: { [string]: true } },
	InitOrder: "Individual" | "Project",
	InitFunctionConfig: { Initializer },
	NativeCyclicRequires: boolean,
	SilentMode: boolean,
}

return {
	Debug = {
		-- When true, performs analysis to detect and report on cyclic
		-- dependency chains.
		CyclicAnalysis = false,
		-- When true, outputs detailed information about the module loading
		-- process.
		VerboseLoading = false,
	},

	-- A mapping of PlaceIds to their place type aliases. This determines the
	-- code groups that are loaded for the current place.
	--
	-- An entry can also be a table that sets the place's environment:
	-- "Production" (the default) or "Testing". Testing places share one
	-- testing data store instead of the production store. Places that are not
	-- listed are "Generic" and "Production".
	PlaceTypes = {
		-- [123456789] = "MyPlaceType",
		-- [987654321] = { Type = "MyPlaceType", Environment = "Testing" },
	},

	-- A mapping of place type aliases to the active code groups for that type.
	CodeGroups = {
		Generic = {
			core = true,
		},
	},

	-- "Individual" means that each task will run its initializers in order
	-- before moving on to the next task. "Project" means that all tasks will
	-- run their first initializers, then all tasks will run their second
	-- initializers, and so on.
	InitOrder = "Project",

	-- Initializers will be executed in the order in which they appear in this
	-- array. The options are as follows:
	--
	-- Name: The name of the initialization function.
	-- Async: When true, if this function yields during execution, the thread
	--     will continue to the next initializer while waiting.
	-- Protected: When true, the function will not halt the initialization
	--     process if it errors. Async initializers are always protected.
	-- WarnDelay: The number of seconds to wait before warning about a slow
	--     execution time. Has no effect on async initializers.
	--
	-- Modules can override this configuration by defining a table named
	-- InitConfigOverride that contains the same structure as this table.
	InitFunctionConfig = {
		[1] = {
			Name = "Prep",
			Async = false,
			Protected = true,
			WarnDelay = 1,
		},
		[2] = {
			Name = "Init",
			Async = true,
			Protected = true,
			WarnDelay = 5,
		},
	},

	-- When true, cyclic requires between modules that use Luau's `export`
	-- syntax resolve to Luau's own export tables instead of Order's
	-- placeholders. Requires the Luau Modularity feature (export values and
	-- cyclic requires). Modules that `return` a value, and cycles between
	-- tasks loading on different threads, always use Order's placeholders.
	NativeCyclicRequires = false,

	-- Disables regular output (does not disable warnings)
	SilentMode = not game:GetService("RunService"):IsStudio(),
} :: OrderSettings
