--[[
    GlabalConfig.lua
    TactBacon
    v1.2.0
]]

export type StateConfig = {
	[string]: {
		["BlockedBy"]: { string }?,
		["Requires"]: { string }?,
		["Deactivates"]: { string }?,
		["Activates"]: { string }?,
		["Tags"]: { string }?,
	},
}

return {
	-- Put states here
} :: StateConfig
