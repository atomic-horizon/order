# Project Rules

## Framework & Architecture

- This is a Roblox Luau project using a custom module framework (`src/framework/`). Documentation can be found at https://order.atomichorizon.net/
- **Module loading**: Use `shared("ModuleName")` for all dependencies — never use `require()` directly except within the framework itself.
- **Remotes**: Use `GetRemote("RemoteName")` to access remote events/functions. Never create RemoteEvent/RemoteFunction instances directly.
- **Roblox services**: Access via `game:GetService()`.

## Module Structure

All task and service modules follow a strict section ordering with comment headers:

```lua
-- Services
-- Dependencies
-- Types
-- Module Declaration
-- Constants
-- Global Variables
-- Objects
-- Private Functions
-- Public Functions
-- Task Initialization
```

Only include sections that have content, but preserve the ordering. Every section is introduced by a single-line comment header (e.g., `-- Services`). Leave a blank line between the header and its contents.

## File Headers

Every file must start with a file info block. Use this format:

```lua
--[[ File Info

    Author(s): AuthorName
    Module: ModuleName.luau
    Version: X.Y.Z

    A brief module description that explains the purpose of the module and any important details. This should be 1-3 sentences.

]]
```

## Module Patterns

### Singleton Tasks (Controllers / Services)

The most common pattern. Client modules are "Controllers", server modules are "Services":

```lua
local MyController = {}

function MyController:Prep()
    -- Synchronous setup (optional). Runs before Init across all tasks.
end

function MyController:Init()
    -- Async initialization. Can yield. Runs after all Prep phases complete.
end

return MyController
```

- `Prep` is synchronous and blocking — use for registering callbacks and basic state setup.
- `Init` is asynchronous — use for data loading, starting loops, connecting to events.
- Both are optional. Most modules only define `Init`.
- Modules may define `Priority = <number>` to control initialization order (higher = earlier).

### OOP Classes

Classes use metatables with `__index` and a `.new()` constructor:

```lua
local MyClass = {}
MyClass.__index = MyClass

function MyClass.new(...)
    local self = setmetatable({}, MyClass)
    -- Initialize fields
    return self
end

return MyClass
```

- UI pane classes inherit from `AtomicPane` via `setmetatable({}, AtomicPane)` and set `ClassName`.
- Always define `__index` on the class table itself.
- Private members and methods use `_` prefix and lowerCamelCase (e.g., `self._timer`, `self._queue`, `function MyClass:_processQueue()`).
- Public members and methods use PascalCase (e.g., `self.Timer`, `function MyClass:Start()`).

## Code Style

### Naming Conventions

- **Modules/Classes**: PascalCase (`DeploymentController`, `GameMode`, `CrackedTimerPane`)
- **Functions (public)**: PascalCase (`function MyModule:SetStage()`)
- **Functions (private)**: _camelCase (`function MyClass:_processQueue()`)
- **Constants**: UPPER_SNAKE_CASE (`local SECONDS_TO_AFK = 300`)
- **Local variables (any variable in a non-global scope, or function parameter)**: camelCase (`local currentStage`, `local matchmakingRemote`)
- **Global variables**: PascalCase (`local MyVariable`)
- **Module-level variables that act as singletons**: PascalCase (`local LocalPlayer = Players.LocalPlayer`)
- **Type names**: PascalCase (`type State`, `type GameMode`, `export type Cache`)
- **All names must be verbose and self-descriptive.** Prefer `matchmakingRequestRemote` over `mmRemote`, `deathTriggerRemote` over `dtRemote`, `shakeIntensity` over `si`. A reader should understand a variable's purpose without needing surrounding context. Single-letter names are only acceptable for trivial loop iterators (`_`, `i`).

### Typing

- Use Luau type annotations on function signatures: parameters and return types.
- Define `export type` for public types that other modules consume.
- Private members in type definitions use `_` prefix.

### Error Handling

- Use `warn()` for recoverable issues (bad input, missing state). Do not throw errors for expected edge cases.
- Use `error()` only for truly invalid states that indicate programmer mistakes.
- Server-side remote handlers should validate all client input before processing.
- Use early returns for guard clauses rather than deeply nested conditionals.

### Comments

- Use `--` single-line comments for brief explanations.
- Use `--[[ ]]` block comments only for file headers and API documentation blocks.
- Moonwave-style `--[=[ @class ]=]` doc comments are used on some shared libraries but are not required.
- Do not add comments for self-explanatory code.

## Project Structure

```
src/
  framework/       -- Module loader, settings, initialization
  client/          -- Client-side code
    core/
      tasks/       -- Core client controllers
      lib/         -- Client libraries and utilities
      external/    -- Third-party open source modules
  server/          -- Server-side code (mirrors client structure)
    core/
      tasks/       -- Core server services
      lib/         -- Server libraries and utilities
      external/    -- Third-party open source modules
  shared/          -- Shared between client and server
    core/
      tasks/       -- Core shared tasks
      lib/         -- Shared libraries and utilities
      external/    -- Third-party open source modules
```

- **Code groups**: Controlled by `Settings.luau`. Each PlaceType loads specific code groups (e.g., "Tutorial" loads core + game + arena + tutorial).
- **tasks/ folders** are automatically discovered and initialized by the framework.
- **All other folders and modules** are loaded on-demand via `shared()`.

## Client-Server Communication

- All remotes go through `GetRemote()`. Common patterns:
  - **Events**: `remote:Fire(...)` / `remote:OnEvent(callback)`
  - **Invocations**: `remote:Invoke(...)` / `remote:OnInvoke(callback)`
  - **Client-specific**: `remote:FireAllClients(...)` / `remote:OnClientEvent(callback)`
- Always validate input in server-side remote handlers.
- Remote names should be relevant to the functionality (e.g., `MatchmakingRequestRemote`, `DeathTriggerRemote`)

## Conventions

- Prefer `task.spawn()`, `task.delay()`, `task.wait()` over legacy coroutine/wait APIs.
- Use `AnimNation` for all UI and visual animations (tweens, springs, impulses).
- Use string interpolation with backticks for dynamic strings: `` `Hello {name}` ``.
- Use generalized iteration (`for key, value in table do`) — do not use `pairs()` or `ipairs()` in new code.
- `workspace:SetAttribute()` / `player:GetAttribute()` is the standard way to share lightweight state.
- Use `Maid` for cleanup of connections and instances.
- Use `Observe.Attribute()` for reactive attribute watching.
