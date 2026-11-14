local GetBranches = shared("GetBranches") ---@module GetBranches

return function(registry)
	-- GetBranches makes a web request. Cmdr registers every type in one loop,
	-- so yielding here would drop any custom types registered after this one.
	task.spawn(function()
		local branchNames = {}

		for _, branch in GetBranches() do
			table.insert(branchNames, branch.Name)
		end

		registry:RegisterType("branch", registry.Cmdr.Util.MakeEnumType("branch", branchNames))
	end)
end
