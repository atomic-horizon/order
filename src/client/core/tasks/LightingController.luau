--[[ File Info

    Author(s): TactBacon, ChiefWildin
    Module: LightingController.lua
	Version: 2.2.0

]]

-- Services

local Lighting = game:GetService("Lighting")

-- Main Job Declaration

--[=[
	@class LightingController

	Controls the lighting in the game.
]=]
local LightingController = {}

-- Dependencies

local AnimNation = shared("AnimNation") ---@module AnimNation
local Get = shared("Get") ---@module Get

-- Types

export type LightingChild = Atmosphere | Sky | PostEffect
type CumulativeState = {
	Effects: { [string]: { [string]: any } }?,
	Lighting: { [string]: any }?,
	MaterialColors: { [string]: Color3 }?,
	Terrain: { [string]: any }?,
	Clouds: { [string]: any }?,
	Durations: { [string]: number }?,
}

-- Constants

local DEFAULT_TRANSITION_TIME = 2
local TRANSITION_STYLE = Enum.EasingStyle.Quad
local TRANSITIONAL_DEFAULTS = {
	["Atmosphere"] = {
		Density = 0,
		Offset = 0,
		Color = Color3.fromRGB(199, 199, 199),
		Decay = Color3.fromRGB(106, 112, 125),
		Glare = 0,
		Haze = 0,
	},
	["Sky"] = {
		SunAngularSize = 4,
		MoonAngularSize = 4,
		StarCount = 3000,
	},
	["ColorCorrectionEffect"] = {
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
		TintColor = Color3.fromRGB(255, 255, 255),
	},
	["DepthOfFieldEffect"] = {
		FocusDistance = 0,
		FarIntensity = 0,
		NearIntensity = 0,
		InFocusRadius = 0,
	},
	["SunRaysEffect"] = {
		Intensity = 0,
		Spread = 0,
	},
	["BloomEffect"] = {
		Intensity = 1,
		Size = 24,
		Threshold = 2,
	},
	["BlurEffect"] = {
		Size = 0,
	},
}
local INSTANT_PROPERTIES = {
	["Sky"] = {
		SkyboxBk = "rbxassetid://6444884337",
		SkyboxDn = "rbxassetid://6444884785",
		SkyboxFt = "rbxassetid://6444884337",
		SkyboxLf = "rbxassetid://6444884337",
		SkyboxRt = "rbxassetid://6444884337",
		SkyboxUp = "rbxassetid://6412503613",
		SunTextureId = "rbxassetid://6196665106",
		MoonTextureId = "rbxassetid://6444320592",
		CelestialBodiesShown = true,
	},
	["ColorCorrectionEffect"] = {
		Enabled = true,
	},
	["DepthOfFieldEffect"] = {
		Enabled = true,
	},
	["SunRaysEffect"] = {
		Enabled = true,
	},
	["BloomEffect"] = {
		Enabled = true,
	},
	["BlurEffect"] = {
		Enabled = true,
	},
}
local SETTINGS_TO_SAVE = {
	"Ambient",
	"Brightness",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"GlobalShadows",
	"OutdoorAmbient",
	"ShadowSoftness",
	"ClockTime",
	"GeographicLatitude",
	"ExposureCompensation",
}

-- Global Variables

local AppliedFiltersStack: { { Name: string, Duration: number } } = {}
local ControlledEffects: { [string]: { [string]: any } } = {}
local CurrentLighting: Configuration? = nil
local Filters: { [string]: Configuration } = {}
local MaterialColors: { [string]: Color3 } = {}
local PendingTransitions: { [string]: { Target: any, Duration: number, StartTime: number } } = {} -- Track ongoing transitions
local PreviousLighting: Configuration? = nil

-- Objects

local Terrain = workspace.Terrain
local ProfileFolder: Folder, FilterFolder: Folder

-- Private Functions

--[=[
	Computes the cumulative lighting state by applying all filters in the stack
	to the base lighting profile.

	@private
	@return CumulativeState? -- A table containing the cumulative properties for all effects
]=]
function LightingController:_computeCumulativeState(): CumulativeState?
	if not CurrentLighting then
		return {}
	end

	local cumulativeState = {
		Effects = {},
		Lighting = {},
		MaterialColors = {},
		Terrain = {},
		Clouds = nil,
		Durations = {},
	}

	-- Start with base lighting properties
	for key in CurrentLighting:GetAttributes() do
		cumulativeState.Lighting[key] = CurrentLighting:GetAttribute(key)
	end

	-- Start with base material colors
	local materialColors = CurrentLighting:FindFirstChild("MaterialColors")
	if materialColors then
		for _, value in materialColors:GetChildren() do
			cumulativeState.MaterialColors[value.Name] = value.Value
		end
	end

	-- Start with base terrain config
	local terrainConfig = CurrentLighting:FindFirstChild("TerrainConfiguration")
	if terrainConfig then
		for key, value in terrainConfig:GetAttributes() do
			cumulativeState.Terrain[key] = value
		end
	end

	-- Start with base effect properties
	for className in pairs(TRANSITIONAL_DEFAULTS) do
		local baseEffect = CurrentLighting:FindFirstChildWhichIsA(className)
		if baseEffect then
			cumulativeState.Effects[className] = {}
			for property in pairs(TRANSITIONAL_DEFAULTS[className]) do
				cumulativeState.Effects[className][property] = baseEffect[property]
			end
			if INSTANT_PROPERTIES[className] then
				for property in pairs(INSTANT_PROPERTIES[className]) do
					cumulativeState.Effects[className][property] = baseEffect[property]
				end
			end
		end
	end

	-- Start with base clouds config
	local cloudConfig = CurrentLighting:FindFirstChild("Clouds")
	if cloudConfig then
		cumulativeState.Clouds = cloudConfig:GetAttributes()
	end

	-- Apply each filter in the stack
	for _, filterEntry in ipairs(AppliedFiltersStack) do
		local filterName = filterEntry.Name
		local filterDuration = filterEntry.Duration
		local filter = Filters[filterName]
		if filter then
			for _, child in filter:GetChildren() do
				local className = child.ClassName

				-- Handle clouds separately - skip effect processing for cloud configs
				if className == "Configuration" and child.Name == "Clouds" then
					cumulativeState.Clouds = child:GetAttributes()
					cumulativeState.Durations["Clouds"] = filterDuration
					continue
				end

				-- Initialize effect entry if needed
				if not cumulativeState.Effects[className] then
					cumulativeState.Effects[className] = {}
				end

				-- Override properties with filter values and track duration
				if TRANSITIONAL_DEFAULTS[className] then
					for property in pairs(TRANSITIONAL_DEFAULTS[className]) do
						cumulativeState.Effects[className][property] = child[property]
						cumulativeState.Durations[className .. "." .. property] = filterDuration
					end
				end
				if INSTANT_PROPERTIES[className] then
					for property in pairs(INSTANT_PROPERTIES[className]) do
						cumulativeState.Effects[className][property] = child[property]
					end
				end
			end
		end
	end

	return cumulativeState
end

--[=[
	Applies the cumulative state to the actual lighting and effects.

	@private
	@param cumulativeState CumulativeState -- The computed cumulative state
	@param transitionTime number? -- The time to transition to the new state
	@param overrideDurations table? -- Optional table of property keys to durations that override computed durations
]=]
function LightingController:_applyCumulativeState(
	cumulativeState,
	transitionTime: number?,
	overrideDurations: { [string]: number }?
)
	local defaultTransitionTime = transitionTime or DEFAULT_TRANSITION_TIME
	local defaultTweenInfo = TweenInfo.new(defaultTransitionTime, TRANSITION_STYLE)
	local currentTime = os.clock()

	-- Apply lighting properties (use default transition time for base properties)
	if next(cumulativeState.Lighting) then
		AnimNation.tween(Lighting, defaultTweenInfo, cumulativeState.Lighting)
	end

	-- Apply material colors (use default transition time)
	for materialName, color in pairs(cumulativeState.MaterialColors) do
		if Enum.Material[materialName] then
			local currentValue = MaterialColors[materialName]
			if not currentValue then
				currentValue = Instance.new("Color3Value")
				MaterialColors[materialName] = currentValue
				currentValue.Value = Terrain:GetMaterialColor(Enum.Material[materialName])
				currentValue:GetPropertyChangedSignal("Value"):Connect(function()
					Terrain:SetMaterialColor(Enum.Material[materialName], currentValue.Value)
				end)
			end
			AnimNation.tween(currentValue, defaultTweenInfo, { Value = color })
		end
	end

	-- Apply terrain properties (use default transition time)
	if next(cumulativeState.Terrain) then
		AnimNation.tween(Terrain, defaultTweenInfo, cumulativeState.Terrain)
	end

	-- Apply effect properties
	for className, properties in pairs(cumulativeState.Effects) do
		local current = ControlledEffects[className]
		if current then
			-- Separate instant and transitional properties
			local instantProps = {}
			local transitionPropsByDuration = {} -- Group by duration

			for property, value in pairs(properties) do
				local propKey = className .. "." .. property

				if INSTANT_PROPERTIES[className] and INSTANT_PROPERTIES[className][property] then
					instantProps[property] = value
					PendingTransitions[propKey] = nil -- Clear any pending transition
				else
					-- Check if there's an ongoing transition to this same target
					local pending = PendingTransitions[propKey]
					if pending and pending.Target == value and currentTime < pending.StartTime + pending.Duration then
						-- Already transitioning to this value, don't override
						continue
					end

					-- Determine duration: override > stored > default
					local duration = (overrideDurations and overrideDurations[propKey])
						or cumulativeState.Durations[propKey]
						or defaultTransitionTime

					if not transitionPropsByDuration[duration] then
						transitionPropsByDuration[duration] = {}
					end
					transitionPropsByDuration[duration][property] = value

					-- Track this transition
					PendingTransitions[propKey] = {
						Target = value,
						Duration = duration,
						StartTime = currentTime,
					}
				end
			end

			-- Apply instant properties
			for property, value in pairs(instantProps) do
				current[property] = value
			end

			-- Tween transitional properties grouped by duration
			for duration, props in pairs(transitionPropsByDuration) do
				local tweenInfo = TweenInfo.new(duration, TRANSITION_STYLE)
				AnimNation.tween(current, tweenInfo, props)
			end
		else
			-- Create new effect
			local new = Instance.new(className)
			ControlledEffects[className] = new
			for property, value in pairs(properties) do
				new[property] = value
			end
			new.Parent = Lighting
		end
	end

	-- Handle effects that should revert to defaults if not in cumulative state
	for className, defaults in pairs(TRANSITIONAL_DEFAULTS) do
		if not cumulativeState.Effects[className] and ControlledEffects[className] then
			local propsByDuration = {}

			for property, value in pairs(defaults) do
				local propKey = className .. "." .. property

				-- Check if already transitioning to default
				local pending = PendingTransitions[propKey]
				if pending and pending.Target == value and currentTime < pending.StartTime + pending.Duration then
					-- Already reverting, don't override
					continue
				end

				-- Determine duration for reverting
				local duration = (overrideDurations and overrideDurations[propKey]) or defaultTransitionTime

				if not propsByDuration[duration] then
					propsByDuration[duration] = {}
				end
				propsByDuration[duration][property] = value

				-- Track this transition
				PendingTransitions[propKey] = {
					Target = value,
					Duration = duration,
					StartTime = currentTime,
				}
			end

			-- Apply reversions grouped by duration
			for duration, props in pairs(propsByDuration) do
				local tweenInfo = TweenInfo.new(duration, TRANSITION_STYLE)
				AnimNation.tween(ControlledEffects[className], tweenInfo, props)
			end

			-- Handle instant properties
			if INSTANT_PROPERTIES[className] then
				for property, value in pairs(INSTANT_PROPERTIES[className]) do
					ControlledEffects[className][property] = value
					local propKey = className .. "." .. property
					PendingTransitions[propKey] = nil
				end
			end
		end
	end

	-- Handle clouds
	local existingClouds: Clouds? = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local clouds = existingClouds or Instance.new("Clouds", workspace.Terrain)

	local previousCloudsEnabled = clouds.Enabled
	clouds.Enabled = cumulativeState.Clouds ~= nil

	if cumulativeState.Clouds then
		-- Check if already transitioning to these exact cloud settings
		local pending = PendingTransitions["Clouds"]
		local alreadyTransitioning = false

		if pending and currentTime < pending.StartTime + pending.Duration then
			-- Check if target matches
			alreadyTransitioning = true
			for key, value in pairs(cumulativeState.Clouds) do
				if pending.Target[key] ~= value then
					alreadyTransitioning = false
					break
				end
			end
		end

		if not alreadyTransitioning then
			local cloudDuration = (overrideDurations and overrideDurations["Clouds"])
				or cumulativeState.Durations["Clouds"]
				or defaultTransitionTime
			local cloudTweenInfo = TweenInfo.new(cloudDuration, TRANSITION_STYLE)
			AnimNation.tween(clouds, cloudTweenInfo, cumulativeState.Clouds)

			-- Track this transition
			PendingTransitions["Clouds"] = {
				Target = table.clone(cumulativeState.Clouds),
				Duration = cloudDuration,
				StartTime = currentTime,
			}
		end
	elseif previousCloudsEnabled then
		-- Clouds are being disabled, clear pending transition
		PendingTransitions["Clouds"] = nil
	end
end

--[=[
	A private function used to generate a new LightingSave given the current
	Lighting.

	@private
	@return Configuration -- The new LightingSave Configuration folder.
]=]
function LightingController:_createSave(): Configuration
	local config: Configuration = Instance.new("Configuration")
	config.Name = "LightingSave"

	for _, propertyKey: string in ipairs(SETTINGS_TO_SAVE) do
		config:SetAttribute(propertyKey, Lighting[propertyKey])
	end

	local materialColors = Instance.new("Configuration")
	materialColors.Name = "MaterialColors"
	for _, material in pairs(Enum.Material:GetEnumItems()) do
		local success, color = pcall(function()
			return Terrain:GetMaterialColor(material)
		end)
		if success then
			local value = Instance.new("Color3Value")
			value.Name = material.Name
			value.Value = color
			value.Parent = materialColors
		end
	end
	materialColors.Parent = config

	local terrainConfig = Instance.new("Configuration")
	terrainConfig.Name = "TerrainConfiguration"
	terrainConfig:SetAttribute("WaterWaveSize", Terrain.WaterWaveSize)
	terrainConfig:SetAttribute("WaterWaveSpeed", Terrain.WaterWaveSpeed)
	terrainConfig:SetAttribute("WaterReflectance", Terrain.WaterReflectance)
	terrainConfig:SetAttribute("WaterTransparency", Terrain.WaterTransparency)
	terrainConfig:SetAttribute("WaterColor", Terrain.WaterColor)
	terrainConfig.Parent = config

	for _, child in Lighting:GetChildren() do
		if
			(child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect"))
			and not child:GetAttribute("ExcludeFromController")
		then
			local clone = child:Clone()
			clone.Parent = config
		end
	end

	config.Parent = ProfileFolder

	return config :: Configuration
end

-- Public Functions

--[=[
	Loads a lighting save given a Configuration object that holds all the
	properties of the lighting as attributes. This will also load any children
	of the Configuration object that apply to the `LightingChild` type.

	@param save Configuration -- The Configuration object that holds all the properties of the lighting as attributes.
	@param transitionTime number? -- The time it takes to transition to the new lighting.
]=]
function LightingController:LoadSave(save: Configuration, transitionTime: number?)
	assert(save, "Cannot load lighting, invalid save specified (" .. tostring(save) .. ")")

	PreviousLighting = CurrentLighting
	CurrentLighting = save

	-- Keep existing filters in the stack and recompute cumulative state
	local cumulativeState = self:_computeCumulativeState()
	self:_applyCumulativeState(cumulativeState, transitionTime)
end

--[=[
	Used to load in the default lighting settings. These default settings are
	set by either having a LightingSave named DefaultLighting under Lighting or
	is automatically created at runtime.

	@param transitionTime number? -- The time it takes to transition from the current lighting settings to the default lighting settings.
]=]
function LightingController:LoadDefault(transitionTime: number?)
	self._defaultLighting = self._defaultLighting or ProfileFolder:FindFirstChild("DefaultLighting")
	if self._defaultLighting then
		self:LoadSave(self._defaultLighting, transitionTime)
	else
		warn("Default lighting not found, cannot load")
	end
end

--[=[
	Returns to the previous lighting settings that were active before the last
	call to LoadSave.

	@param transitionTime number? -- The time it takes to transition from the current lighting settings to the previous lighting settings.
]=]
function LightingController:ReturnToPrevious(transitionTime: number?)
	if PreviousLighting then
		self:LoadSave(PreviousLighting, transitionTime)
	else
		self:LoadDefault(transitionTime)
	end
end

--[=[
	Returns an array of the currently applied filters in stack order.

	@return { string } -- An array of the currently applied filter names.
]=]
function LightingController:GetAppliedFilters(): { string }
	local filterNames = {}
	for _, entry in ipairs(AppliedFiltersStack) do
		table.insert(filterNames, entry.Name)
	end
	return filterNames
end

--[=[
	Checks if a filter is currently applied.

	@param filterName string -- The name of the filter to check.
	@return boolean -- Whether or not the filter is currently applied.
]=]
function LightingController:IsFilterApplied(filterName: string): boolean
	for _, entry in ipairs(AppliedFiltersStack) do
		if entry.Name == filterName then
			return true
		end
	end
	return false
end

--[=[
	Applies a filter to the current lighting settings by pushing it onto the
	filter stack. The cumulative state is recomputed with all filters.

	@param filterName string -- The name of the filter to apply.
	@param duration number? -- The time it takes to transition to the new filter settings.
]=]
function LightingController:ApplyFilter(filterName: string, duration: number?)
	local filter = Filters[filterName]
	if not filter then
		warn("Filter not found:", filterName)
		return
	end

	-- Don't add duplicate filters
	if self:IsFilterApplied(filterName) then
		return
	end

	-- Push filter onto stack with its duration
	table.insert(AppliedFiltersStack, { Name = filterName, Duration = duration or DEFAULT_TRANSITION_TIME })
	self._filterAdded:Fire(filterName)

	-- Recompute and apply cumulative state
	local cumulativeState = self:_computeCumulativeState()
	self:_applyCumulativeState(cumulativeState, duration)
end

--[=[
	Removes a filter from the filter stack by name and recomputes the cumulative
	state.

	@param filterName string -- The name of the filter to remove.
	@param duration number? -- The time it takes to transition after removing the filter.
]=]
function LightingController:RemoveFilter(filterName: string, duration: number?)
	local foundIndex = nil
	for i = #AppliedFiltersStack, 1, -1 do
		if AppliedFiltersStack[i].Name == filterName then
			foundIndex = i
			break
		end
	end

	if not foundIndex then
		return
	end

	self._filterRemoved:Fire(filterName)

	-- Compute state WITH filter first, then remove and compute WITHOUT
	local stateWith = self:_computeCumulativeState()
	table.remove(AppliedFiltersStack, foundIndex)
	local stateBefore = self:_computeCumulativeState()

	-- Identify properties that changed due to removal
	local overrideDurations = {}
	local removalDuration = duration or DEFAULT_TRANSITION_TIME

	-- Check effect properties
	for className, properties in pairs(stateWith.Effects) do
		for property in pairs(properties) do
			local propKey = className .. "." .. property
			local beforeValue = stateBefore.Effects[className] and stateBefore.Effects[className][property]
			local withValue = properties[property]

			if beforeValue ~= withValue then
				-- This property is reverting due to removal
				overrideDurations[propKey] = removalDuration
			end
		end
	end

	-- Check for effects that are reverting to defaults
	for className in pairs(stateWith.Effects) do
		if not stateBefore.Effects[className] then
			-- This entire effect is reverting
			for property in pairs(TRANSITIONAL_DEFAULTS[className] or {}) do
				local propKey = className .. "." .. property
				overrideDurations[propKey] = removalDuration
			end
		end
	end

	-- Check clouds
	if stateWith.Clouds and not stateBefore.Clouds then
		overrideDurations["Clouds"] = removalDuration
	end

	-- Apply cumulative state with override durations for reverting properties
	local cumulativeState = stateBefore
	self:_applyCumulativeState(cumulativeState, duration, overrideDurations)
end

--[=[
	Removes the most recently applied filter from the stack.

	@param duration number? -- The time it takes to transition after popping the filter.
	@return string? -- The name of the removed filter, or nil if the stack was empty.
]=]
function LightingController:PopFilter(duration: number?): string?
	if #AppliedFiltersStack == 0 then
		return nil
	end

	local filterName = table.remove(AppliedFiltersStack)
	self._filterRemoved:Fire(filterName)

	-- Recompute and apply cumulative state
	local cumulativeState = self:_computeCumulativeState()
	self:_applyCumulativeState(cumulativeState, duration)

	return filterName
end

--[=[
	Resets the current lighting settings to the last loaded lighting save.
	This will also clear any applied filters from the stack.

	@param duration number? -- The time it takes to transition to the reset lighting settings.
]=]
function LightingController:ResetCurrentProfile(duration: number?)
	if CurrentLighting then
		AppliedFiltersStack = {}
		self._filtersReset:Fire()

		-- Recompute and apply cumulative state (with empty filter stack)
		local cumulativeState = self:_computeCumulativeState()
		self:_applyCumulativeState(cumulativeState, duration or 0)
	end
end

--[=[
	Clears all filters from the stack without resetting the lighting profile.

	@param duration number? -- The time it takes to transition after clearing filters.
]=]
function LightingController:ClearFilters(duration: number?)
	if #AppliedFiltersStack == 0 then
		return
	end

	AppliedFiltersStack = {}
	self._filtersReset:Fire()

	-- Recompute and apply cumulative state (with empty filter stack)
	local cumulativeState = self:_computeCumulativeState()
	self:_applyCumulativeState(cumulativeState, duration or 0)
end

-- Initialization

function LightingController:Init()
	ProfileFolder = shared.Assets:WaitForChild("LightingProfiles", 5)
	FilterFolder = shared.Assets:WaitForChild("LightingFilters", 5)

	if not ProfileFolder then
		warn("No LightingProfiles folder found in Assets. Set one up before using LightingController.")
	end

	if not FilterFolder then
		warn("No LightingFilters folder found in Assets. Set one up before using LightingController.")
	end

	if not ProfileFolder or not FilterFolder then
		return
	end

	local function addFilter(filter)
		Filters[filter.Name] = filter
	end
	FilterFolder.ChildAdded:Connect(addFilter)
	for _, child in FilterFolder:GetChildren() do
		addFilter(child)
	end

	self._defaultLighting = ProfileFolder:FindFirstChild("DefaultLighting")

	self._filterAdded = Instance.new("BindableEvent")
	self.FilterAdded = self._filterAdded.Event

	self._filterRemoved = Instance.new("BindableEvent")
	self.FilterRemoved = self._filterRemoved.Event

	self._filtersReset = Instance.new("BindableEvent")
	self.FiltersReset = self._filtersReset.Event

	for _, child in pairs(Lighting:GetChildren()) do
		if
			not child:GetAttribute("ExcludeFromController")
			and (child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky"))
		then
			ControlledEffects[child.ClassName] = child
		end
	end
end

return LightingController
