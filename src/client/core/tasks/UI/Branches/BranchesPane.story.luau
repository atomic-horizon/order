--[[ File Info

	Author(s): ChiefWildin
	Module: BranchesPane.story.luau
	Version: 1.0.0

]]

local shared = require(game.ReplicatedStorage.Order)
local BranchesPane = shared("BranchesPane") ---@module BranchesPane
local GetBranches = shared("GetBranches") ---@module GetBranches

local Story = {
	controls = {
		Visible = true,
	},
	render = function(props)
		local pane = BranchesPane.new(props.target)

		task.spawn(function()
			local branches = GetBranches()
			pane:SetBranches(branches)
		end)
		local closeConnection = pane.CloseActivated:Connect(function()
			pane:Hide()
		end)

		-- Define controls

		local controlCallbacks = {
			Visible = function(value: boolean)
				pane:SetVisible(value)
			end,
		}

		-- Subscribe to control changes (don't edit)

		local unsubscribe = props.subscribe(function(_, infos)
			for control, value in pairs(infos) do
				if controlCallbacks[control] and value.__new ~= value.__old then
					controlCallbacks[control](value.__new)
				end
			end
		end)

		-- Initialize control values (don't edit)

		for control, value in pairs(props.controls) do
			if controlCallbacks[control] then
				controlCallbacks[control](value)
			end
		end

		-- Cleanup

		return function() -- Cleanup your story here
			pane:Destroy()
			closeConnection:Disconnect()
			unsubscribe()
		end
	end,
}

return Story
