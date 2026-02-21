local GetBranches = shared("GetBranches") ---@module GetBranches

return function (registry)
	local currentBranches = GetBranches()
	local arrayOfBranches = {}

	for _, branch in currentBranches do
		table.insert(arrayOfBranches, branch.Name)
	end

	return registry:RegisterType("branch", registry.Cmdr.Util.MakeEnumType("branch", arrayOfBranches))
end