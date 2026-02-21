--[[

	order.

	A configurable module-based framework for Roblox, written by @ChiefWildin.
	Full documentation - https://michaeldougal.github.io/order/

]]

-- Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- The metatable that provides functionality for detecting bare code referencing
-- cyclic dependencies
local CycleMetatable = require(script:WaitForChild("CycleMetatable")) ---@module CycleMetatable
-- The configuration for this instance of the framework
local Settings = require(script:WaitForChild("Settings")) ---@module Settings

-- Setup

local Order = {
	PlaceType = Settings.PlaceTypes[game.PlaceId] or "Generic",
	Version = "3.0.0",
}

type Initializer = Settings.Initializer
type Dictionary = { [string]: any }

-- Override all debug modes if silent mode is active
if Settings.SilentMode then
	for key in Settings.Debug do
		Settings.Debug[key] = false
	end
end

-- Output formatting

local standardPrint = print
local function print(...)
	standardPrint("[Order]:", ...)
end
-- Debug print (print if debug mode is active)
local function dprint(...)
	if Settings.Debug.VerboseLoading then
		standardPrint("[Order] [Debug]:", ...)
	end
end
-- Verbose print (print if not on silent mode)
local function vprint(...)
	if not Settings.SilentMode then
		print(...)
	end
end

local standardWarn = warn
local function warn(...)
	standardWarn("[Order]:", ...)
end

-- Initialization

if RunService:IsServer() then
	vprint("Version:", Order.Version)
	vprint("PlaceType:", Order.PlaceType)
end
vprint("Framework initializing...")

-- The current number of ancestry levels that have been indexed
local AncestorLevelsExpanded = 0
-- The set of all code groups that are active in the current place type
local ActiveCodeGroups: { [string]: true }? = Settings.CodeGroups[Order.PlaceType]
-- A dictionary of asset names and their corresponding constructors
local AssetModules: { [string]: ModuleScript } = {}
-- A dictionary that tracks all cyclic modules for debug analysis
local CyclesFound: { string } = {}
-- A dictionary of loaded ModuleScripts and the values they returned
local LoadedModules: { [ModuleScript]: any } = {}
-- A dictionary of known module aliases and the ModuleScripts they point to
local Modules: { [string]: ModuleScript | { ModuleScript } } = {}
-- The set of all currently loading modules
local ModulesLoading: { [ModuleScript]: boolean } = {}
-- An array that contains the order in which modules are being loaded
local ModuleLoadOrder: { ModuleScript } = {}
-- A dictionary that relates module data tables to the modules' names
local NameRegistry: { [{}]: string } = {}
-- An array that contains all currently loaded task module data
local Tasks: { any } = {}
-- The total number of discovered (but not necessarily loaded) modules
local TotalModules = 0

-- Private functions

-- Adds a metatable to a temporary module table to let access operations fall
-- through to the original module table. AKA the ol' switcheroo.
local function replaceTempModule(alias: string, data: any)
	local module = Modules[alias]

	LoadedModules[module].IsFakeModule = nil

	if typeof(data) == "table" then
		setmetatable(LoadedModules[module], {
			__index = function(_, requestedKey)
				return data[requestedKey]
			end,
			__newindex = function(_, requestedKey, requestedValue)
				data[requestedKey] = requestedValue
			end,
			__tostring = function(_)
				local result = "\nModule " .. alias .. ":\n"

				for key, value in pairs(data) do
					result = result .. "\t" .. tostring(key) .. ": " .. tostring(value) .. "\n"
				end

				return result
			end,
		})
	else
		LoadedModules[module] = data
	end
end

-- Loads the given ModuleScript with error handling. Returns the loaded data.
local function load(module: ModuleScript): any?
	local moduleData: any?

	if not CycleMetatable.CurrentModuleLoading then
		CycleMetatable.CurrentModuleLoading = module.Name
	end

	local loadSuccess, loadMessage = pcall(function()
		moduleData = require(module)
	end)
	if not loadSuccess then
		warn("Failed to load module", module.Name, "-", loadMessage)
	end

	-- This part has to be done in pcall because sometimes developers set their
	-- modules to be read-only
	local renameSuccess, renameMessage = pcall(function()
		if typeof(moduleData) == "table" then
			NameRegistry[moduleData] = module.Name
		end
	end)
	if not renameSuccess then
		warn("Failed to add internal name to module", module.Name, "-", renameMessage)
	end

	if CycleMetatable.CurrentModuleLoading == module.Name then
		CycleMetatable.CurrentModuleLoading = nil
	end

	return moduleData
end

-- Returns a table of all of the provided Instance's ancestors in ascending
-- order
local function getAncestors(descendant: Instance): { Instance }
	local ancestors = {}
	local current = descendant.Parent

	while current do
		table.insert(ancestors, current)
		current = current.Parent
	end

	return ancestors
end

-- Adds all available aliases for a ModuleScript to the internal index registry,
-- up to the specified number of ancestors (0 refers to the script itself,
-- indexes all ancestors if no cap specified)
local function indexNames(child: ModuleScript, levelCap: number?)
	-- Tables were getting passed in as a result of a bug where it would
	-- reindex level 0 on an expansion pass and attempt to store a reference to
	-- a duplicate module table instead of an actual module. This is now
	-- patched, but the guard is left here just in case.
	if typeof(child) ~= "Instance" then
		return
	end

	dprint("Indexing names for", child.Name, "up to", levelCap or "all levels")

	local function indexName(index: string)
		if Modules[index] and Modules[index] ~= child then
			local existing = Modules[index]
			if typeof(existing) == "table" and not table.find(existing, child) then
				table.insert(existing, child)
			else
				Modules[index] = { existing, child }
			end
		else
			Modules[index] = child
		end
	end

	if levelCap == 0 then
		indexName(child.Name)
	end

	local ancestors = getAncestors(child)
	local currentIndex = child.Name
	for level: number, ancestor: Instance in pairs(ancestors) do
		if levelCap and level > levelCap then
			break
		end

		currentIndex = ancestor.Name .. "/" .. currentIndex
		indexName(currentIndex)

		if ancestor.Name == "ServerScriptService" or ancestor.Name == "PlayerScripts" or ancestor.Name == "Shared" then
			break
		end
	end
end

local function expandNameIndex(levelCap: number)
	if levelCap <= AncestorLevelsExpanded then
		return
	end

	dprint("Expanding ancestry name index to level", levelCap, "- previous index:", Modules)

	for _, moduleData in Modules do
		-- Tables are used to store modules with duplicate names
		if typeof(moduleData) == "table" then
			for _, module in moduleData do
				indexNames(module, levelCap)
			end
		elseif typeof(moduleData) == "Instance" then
			indexNames(moduleData, levelCap)
		end
	end

	dprint("Expansion complete. New ancestry name index:", Modules)

	AncestorLevelsExpanded = levelCap
end

-- Public functions

-- Metatable override to load modules when calling the Order table as a
-- function.
function Order.__call(_: {}, target: string | ModuleScript, suppressWarnings: boolean?): any?
	dprint("\tRequest to load", target)

	if typeof(target) == "Instance" then
		return load(target)
	end

	local module = Modules[target]

	if module and LoadedModules[module] then
		return LoadedModules[module]
	end

	if module and not ModulesLoading[module] then
		if typeof(module) == "table" then
			-- A table represents multiple possible modules for the given alias
			-- string, it's unclear which the developer wants
			local trace = debug.traceback()
			local trim = string.sub(trace, string.find(trace, "__call") + 7, string.len(trace) - 1)
			local warning = trim .. ": Multiple modules found for '" .. target .. "' - please be more specific:\n"
			local numDuplicates = #module

			for index, duplicate in ipairs(module) do
				if typeof(duplicate) == "table" then
					continue
				end
				local formattedName = string.gsub(duplicate:GetFullName(), "[.]", "/")
				warning ..= "\t\t\t\t\t\t- " .. formattedName .. if index ~= numDuplicates then "\n" else ""
			end

			warn(warning)

			return nil
		end

		ModulesLoading[module] = true
		table.insert(ModuleLoadOrder, module)
		local moduleData = load(module)

		if LoadedModules[module] then
			-- Found temporary placeholder due to cyclic dependency
			replaceTempModule(target, moduleData)
		else
			LoadedModules[module] = moduleData
			dprint("\tLoaded", target)
		end

		table.remove(ModuleLoadOrder, table.find(ModuleLoadOrder, module))
		ModulesLoading[module] = nil
	else
		if not module then
			dprint("Cache miss for", target)

			local _, ancestorLevels = string.gsub(target, "/", "")
			if ancestorLevels > AncestorLevelsExpanded then
				-- Expand the number of name aliases for known modules to
				-- include number of levels potentially referenced and retry
				expandNameIndex(ancestorLevels)
				return Order:__call(target)
			elseif not suppressWarnings then
				-- Ancestor index expansion has already reached all possibly
				-- referenced levels, so we just don't know where the module is
				local trace = debug.traceback()
				local trim = string.sub(trace, string.find(trace, "__call") + 7, string.len(trace) - 1)
				warn(`{trim}: Attempt to require unknown module '{target}' ({typeof(target)})`)
			end

			return nil
		end

		local fakeModule = {
			IsFakeModule = true,
			Name = module.Name,
		}
		setmetatable(fakeModule, CycleMetatable)
		LoadedModules[module] = fakeModule

		if Settings.Debug.CyclicAnalysis then
			local cycle = ""
			local foundStart = false
			for _, loadingModule in ModuleLoadOrder do
				if not foundStart and loadingModule.Name ~= module.Name then
					continue
				end

				foundStart = true

				cycle ..= loadingModule.Name .. " -> "
			end
			cycle ..= module.Name
			table.insert(CyclesFound, cycle)
		end

		dprint("\tSet", target, "to fake module")
	end

	return LoadedModules[module]
end

-- Indexes any ModuleScript children of the specified Instance
function Order.IndexModulesOf(location: Instance, shallow: boolean?)
	dprint("Indexing modules -", location:GetFullName())

	local discovered = 0
	for _: number, child: Instance in ipairs(if shallow then location:GetChildren() else location:GetDescendants()) do
		if child:IsA("ModuleScript") and child ~= script then
			discovered += 1
			TotalModules += 1
			indexNames(child, 0)
		end
	end

	if discovered > 0 then
		dprint("\tDiscovered", discovered, if discovered == 1 then "module" else "modules")
	end
end

-- Asynchronously loads all ModuleScript children of the specified task Folder,
-- and queues them for initialization. Recursively loads all children of any
-- discovered Folders as well.
function Order.LoadTasks(location: Folder)
	dprint("Loading tasks -", location:GetFullName())

	local tasksLoading = 0
	for _: number, child: ModuleScript | Folder in location:GetChildren() do
		if child:IsA("ModuleScript") then
			tasksLoading += 1
			task.spawn(function()
				-- We might have two or more tasks with the same name, so we
				-- find the shortest unique path to the task. We must require by
				-- name in order to facilitate cyclical dependencies.
				local taskName = child.Name
				local nextParent = child.Parent

				while Modules[taskName] and typeof(Modules[taskName]) == "table" do
					taskName = nextParent.Name .. "/" .. taskName
					nextParent = nextParent.Parent
				end

				local taskData = Order:__call(taskName)
				if taskData then
					table.insert(Tasks, taskData)
				else
					warn(`Task {child.Name} failed to load - requested as {taskName}`)
				end

				tasksLoading -= 1
			end)
		elseif child:IsA("Folder") then
			Order.LoadTasks(child)
		end
	end

	while tasksLoading > 0 do
		task.wait()
	end
end

-- Initializes all currently loaded tasks. Clears the task initialization queue
-- after all tasks have been initialized.
function Order.InitializeTasks()
	vprint("Initializing tasks...")

	table.sort(Tasks, function(a, b)
		local aPriority = a.Priority or 0
		local bPriority = b.Priority or 0
		return aPriority > bPriority
	end)

	-- Don't use dprint to avoid too much unnecessary work
	if Settings.Debug.VerboseLoading then
		print("\tCurrent initialization order:")
		for index: number, moduleData: {} in pairs(Tasks) do
			print("\t\t" .. index .. ")", NameRegistry[moduleData] or moduleData)
		end
	end

	local function initialize(moduleData: Dictionary, initializer: Initializer)
		if moduleData[initializer.Name] then
			local finished = false
			local success = true
			local message

			if not initializer.Async then
				local startTime = os.clock()
				task.spawn(function()
					while not finished do
						if os.clock() - startTime > initializer.WarnDelay then
							warn(
								"Slow module detected -",
								NameRegistry[moduleData] or moduleData,
								"has been initializing for more than",
								initializer.WarnDelay,
								`second{if initializer.WarnDelay == 1 then "" else "s"} in the`,
								initializer.Name,
								"phase"
							)
							break
						end
						task.wait()
					end
				end)

				if initializer.Protected then
					success, message = pcall(moduleData[initializer.Name], moduleData)
				else
					moduleData[initializer.Name](moduleData)
				end
			else
				task.spawn(moduleData[initializer.Name], moduleData)
			end

			finished = true

			if not success then
				warn(
					"Failed to execute " .. initializer.Name .. " phase for module",
					NameRegistry[moduleData] or moduleData,
					"-",
					message
				)
			else
				dprint(
					"\t::" .. initializer.Name .. "() executed successfully for",
					NameRegistry[moduleData] or moduleData
				)
			end
		end
	end

	if Settings.InitOrder == "Individual" then
		for _: number, moduleData: Dictionary in ipairs(Tasks) do
			local config = moduleData.InitConfigOverride or Settings.InitFunctionConfig
			for _, initializer: Initializer in ipairs(config) do
				initialize(moduleData, initializer)
			end
			dprint("Initialized task -", NameRegistry[moduleData] or moduleData)
		end
	elseif Settings.InitOrder == "Project" then
		-- Figure out how many total stages there are since tasks can
		-- individually specify more than the global config does
		local maxInitStages = #Settings.InitFunctionConfig
		for _: number, moduleData: Dictionary in ipairs(Tasks) do
			maxInitStages =
				math.max(maxInitStages, moduleData.InitConfigOverride and #moduleData.InitConfigOverride or 0)
		end
		dprint("Initializing tasks in", maxInitStages, "stages...")

		-- Execute each stage
		for i = 1, maxInitStages do
			for _: number, moduleData: Dictionary in ipairs(Tasks) do
				local config = moduleData.InitConfigOverride or Settings.InitFunctionConfig
				local initializer = config[i]
				if initializer then
					initialize(moduleData, initializer)
				end
			end
			dprint("Initialization stage", i, "complete.")
		end
	else
		warn("Cannot initialize tasks - unsupported initialization order specified:", Settings.InitOrder)
	end

	table.clear(Tasks)

	vprint("All tasks initialized.")
end

function Order.New(assetName: string): Instance?
	local module = AssetModules[assetName]
	if not module then
		local instance = shared.Assets:FindFirstChild(assetName, true)
		if not instance then
			warn("Failed to find asset module or instance with name", assetName)
			return nil
		end
		return instance:Clone()
	end

	local instance: Instance = require(module).new()
	return instance
end

-- Keyword linking

shared.Assets = ReplicatedStorage:WaitForChild("Assets", 999)
shared.new = Order.New
shared.PlaceType = Order.PlaceType

-- Enables shared keyword to act as require()
setmetatable(shared, Order)
-- Enables this module to act as require() when required
setmetatable(Order, Order)

-- Auto initialization

local SharedContext = ReplicatedStorage:WaitForChild("Shared")
local PackageContext = ReplicatedStorage:WaitForChild("Packages")
local LocalContext
if RunService:IsClient() then
	local LocalPlayer = game:GetService("Players").LocalPlayer
	if LocalPlayer and RunService:IsRunning() then
		LocalContext = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
	else
		LocalContext = game:GetService("StarterPlayer").StarterPlayerScripts.Client
	end
else
	LocalContext = game:GetService("ServerScriptService"):WaitForChild("Server")
end

local function IndexContext(contextRoot: Instance)
	for _, codeGroup: Folder in contextRoot:GetChildren() do
		if codeGroup:IsA("Folder") and (not ActiveCodeGroups or ActiveCodeGroups[codeGroup.Name]) then
			Order.IndexModulesOf(codeGroup)
		end
	end
end
IndexContext(LocalContext)
IndexContext(SharedContext)
Order.IndexModulesOf(PackageContext, true)

local function IndexAssetModules(root: Instance)
	for _, child: ModuleScript | Folder in root:GetChildren() do
		if child:IsA("ModuleScript") then
			if AssetModules[child.Name] then
				warn("Duplicate asset module name detected:", child.Name, "- overwriting previous module reference.")
			end
			AssetModules[child.Name] = child
		elseif child:IsA("Folder") then
			IndexAssetModules(child)
		end
	end
end
for _, codeGroup: Folder in SharedContext:WaitForChild("AssetModules", 999):GetChildren() do
	if codeGroup:IsA("Folder") and (not ActiveCodeGroups or ActiveCodeGroups[codeGroup.Name]) then
		IndexAssetModules(codeGroup)
	end
end

if RunService:IsRunning() then
	local function loadContextTasks(context: Instance)
		for _, codeGroup: Folder in context:GetChildren() do
			if ActiveCodeGroups and not ActiveCodeGroups[codeGroup.Name] then
				continue
			end

			for _, child: Folder in codeGroup:GetChildren() do
				if not child:IsA("Folder") then
					continue
				end

				if child.Name == "tasks" then
					Order.LoadTasks(child)
				else
					loadContextTasks(child)
				end
			end
		end
	end

	loadContextTasks(LocalContext)
	loadContextTasks(SharedContext)

	Order.InitializeTasks()
end

Order._initialized = true
shared._OrderInitialized = true

vprint("Framework initialized.")

if Settings.Debug.CyclicAnalysis then
	table.sort(CyclesFound)

	print("============================================")
	print(` Cyclic Dependency Analysis Report - {RunService:IsServer() and "Server" or "Client"} `)
	print("--------------------------------------------")
	for _, entry in CyclesFound do
		print(`\t{entry}`)
	end
	print("============================================")
end

return Order
