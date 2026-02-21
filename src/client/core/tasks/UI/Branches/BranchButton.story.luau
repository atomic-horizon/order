--[[ File Info

	Author(s): ChiefWildin
	Module: BranchButton.story.luau
	Version: 1.0.0

]]

local shared = require(game.ReplicatedStorage.Order)
local BranchButton = shared("BranchButton") ---@module BranchButton

local Story = {
	controls = {
		Visible = true,
	},
	render = function(props)
		local pane = BranchButton.new("Example Text")
		pane.Gui.Parent = props.target

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
			unsubscribe()
		end
	end,
}

return Story
