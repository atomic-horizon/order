---
sidebar_position: 3
title: Usage
---

# Usage

## Settings
The framework settings module (located at `src/framework/Settings.luau`) has a few different options that developers can customize for their projects.

| Setting | Description |
| --- | --- |
| `Debug.CyclicAnalysis` | When `true`, tracks cyclic dependency chains across the project and prints an analysis after initialization completes. |
| `Debug.VerboseLoading` | When `true`, prints detailed information during initialization: discovered modules, the resolved load order, and when each module finishes. |
| `SilentMode` | When `true`, suppresses all regular output (version info, initialization notices, etc.). Warnings are never suppressed. Defaults to `false` in Studio and `true` in production. |
| `InitOrder` | `"Project"` runs each initializer across all tasks before moving to the next. `"Individual"` runs all initializers on each task before moving to the next task. Both modes respect priority values. |
| `InitFunctionConfig` | A table defining the initialization functions for the project and their options (name, async, protected, warn delay). |
| `PlaceTypes` | Maps Place IDs to named place type strings. Unrecognized places default to `"Generic"`. The active type is accessible at runtime via `shared.PlaceType`. |
| `CodeGroups` | Maps place type names to the set of code group root directories that should be active for that type. Enables selectively sharing modules across different server types (e.g. lobby vs. game server). |

## File structure

### Tasks
Tasks are modules that have code intended for immediate execution at runtime. Tasks should be placed in the `tasks` folder of the appropriate context.
:::info
    Any module that is placed inside the `tasks` folder will be loaded by default, even if no initialization function exists within it or if it isn't even a table. All other modules are loaded only as requested.
:::
#### Priorities
If you wish to give a task priority during the initialization phase, set a `Priority` key in the main module table to the priority level you would like (higher values load first, negative values load last). Setting a priority is optional - if you don't set one, the task will be set to priority 0 by default.
:::warning
    Tasks with priorities are still initialized asynchronously, so if the task yields during initialization there is no guarantee that it will finish before a lower priority task starts initializing. Tasks with the same priority are initialized in an arbitrary order.
:::
#### Initialization functions and synchronization
In the default configuration, tasks can place their code to execute into two initialization functions: `:Prep()` and `:Init()`. `:Prep()` comes first and is synchronous, and then `:Init()` comes after and is asynchronous. Tasks are not required to have either, and are allowed to define their own initialization functions if desired. These can be defined by placing a table called `InitConfigOverride` in the module table, following the same structure as is found for `InitFunctionConfig` in the `Settings.luau` file of the framework folder.

#### Example
```lua
local NewTask = {
    Priority = 5,
}

function NewTask:Prep()
    print("Task is prepped.")
end

function NewTask:Init()
	print("Task is running!")
end

return NewTask
```

### Everything else
All other modules can be placed in the provided `lib` folder, or any other custom folders that you create.

### File paths
There are five top-level directories by default:

- `character` - StarterPlayer.StarterCharacterScripts
- `client` - StarterPlayer.StarterPlayerScripts
- `first` - ReplicatedFirst
- `server` - ServerScriptService
- `shared` - ReplicatedStorage.Shared

:::note
    `first` and `character` are not scanned for task modules, as it is assumed that developers will simply use LocalScripts/Scripts instead. If you wish to add tasks there, you may add custom support at the end of the main framework module. For Rojo users, further file path customization can be configured in the `default.project.json` file.
:::

## Loading dependencies
Order makes use of the `shared` global variable to load dependencies. In code, this takes the place of the usual `require` keyword. This function can take either a string of the module's name, a string of a partial or complete path to the module, or a direct object reference to a ModuleScript.
Valid examples:
```lua
local GetRemote = shared("GetRemote")
```
```lua
local GetRemote = shared("lib/GetRemote")
```
```lua
local GetRemote = shared(game:GetService("ReplicatedStorage").Shared.core.lib.GetRemote)
```
:::warning
    When two or more modules exist with the same name or partial path, Order will warn you that it found multiple modules for your request, and will ask you to be more specific. You can use any level of the module paths it provides you with, as long as it is unique.
:::

The Order module itself can also be used instead of `shared` if you have other uses for that keyword, want to avoid globals like the plague, or are running in portable mode. For example:
```lua
local require = require(game:GetService("ReplicatedStorage").Order)
```

### Supporting modules from other frameworks
If you would like to import a module from another framework that uses `require` to load dependencies (such as Nevermore), simply redirect `require` to `shared`:
```lua
local require = shared
```
Or, alternatively, you can redirect their require call to the main Order module:
```lua
local require = require(game:GetService("ReplicatedStorage").Order)
```
Also be sure to update your initializer configuration to support the module's intended initialization procedure (or adapt it to Order's, if preferred.)
