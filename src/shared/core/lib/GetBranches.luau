local AssetService = game:GetService("AssetService")

export type Branch = {
	DisplayName: string,
	Name: string,
	PlaceId: number,
}

local Branches: { Branch }

--[=[
	@class GetBranches

	Return an array of places in this game using GetGamePlacesAsync.

	```lua
	--	Print all branches in this game.
	local branches = GetBranches()
	for index, branch in branches do
		print(`Branch "{branch.Name}" PlaceId: {branch.PlaceId}`)
	end
	```
]=]
local function GetBranches(): { Branch }
	if Branches then
		return Branches -- This function ran already.
	end

	local allPlaces: { Branch } = {}
	local placePages: StandardPages = AssetService:GetGamePlacesAsync()

	while true do
		for _, placeInfo in placePages:GetCurrentPage() do
			table.insert(allPlaces, placeInfo)
		end
		if placePages.IsFinished then
			break
		end
		placePages:AdvanceToNextPageAsync()
	end

	for _, placeInfo in allPlaces do
		--	Removes non-alphnumeric characters
		placeInfo.DisplayName = placeInfo.Name
		placeInfo.Name = string.gsub(placeInfo.Name, "[^%w]", "")
	end

	Branches = allPlaces

	return Branches
end

return GetBranches
