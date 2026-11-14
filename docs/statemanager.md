---
sidebar_position: 3.5
title: StateManager
description: "Track named gameplay states in Roblox with Order's StateManager, with rules for which states block, end or start others."
keywords: [roblox state machine, statemanager, luau, gameplay states]
---

# StateManager

`StateManager` tracks named states, such as `"Sprinting"` or `"InMenu"`, that can be on or off at the same time. Rules in a config decide which states block, end or start other states. Code can then ask "can the player sprint right now?" in one place instead of checking a list of flags.

It is separate from [UIStateManager](atomicui#using-uistatemanager), which switches between one UI state at a time and shows and hides panes. The two don't depend on each other.

## Defining states

States are defined in `GlobalConfig` (`src/shared/core/lib/StateManager/Configs/GlobalConfig.luau`). Each key is a state name, and every rule is optional:

```lua
return {
    Sprinting = {
        BlockedBy = { "Stunned" },
        Deactivates = { "Crouching" },
        Tags = { "Movement" },
    },
    Crouching = {
        BlockedBy = { "Stunned" },
        Deactivates = { "Sprinting" },
        Tags = { "Movement" },
    },
    Stunned = {
        Deactivates = { "Sprinting", "Crouching" },
    },
    InMenu = {
        Activates = { "MouseUnlocked" },
    },
    MouseUnlocked = {},
} :: StateConfig
```

| Rule | Effect when the state is activated |
| --- | --- |
| `BlockedBy` | Fails if any of these states is active. |
| `Deactivates` | Deactivates any of these states that are active. |
| `Activates` | Also activates these states, following their own rules. |
| `Tags` | Groups the state so it can be checked or changed with others. See [Tags](#tags). |

The config also has a `Requires` rule, but it doesn't work yet: a state with `Requires` set can never be activated.

`shared("StateManager")` returns one shared manager built from `GlobalConfig`. Every state the code refers to must be in the config. Activating a state that isn't there raises an error.

## Activating and deactivating

```lua
local StateManager = shared("StateManager")

local activated, blockingState = StateManager:ActivateState("Sprinting")
if not activated then
    print(`Can't sprint while {blockingState.Name} is active`)
end

StateManager:DeactivateState("Sprinting")
StateManager:ToggleState("Crouching")
```

`ActivateState` returns `true` and the state if it is now active (or already was). It returns `false` and the active state that blocked it otherwise. States listed in `Deactivates` never block, they're turned off instead.

| Function | Use |
| --- | --- |
| `ActivateState(name)` | Activates a state if its rules allow it. |
| `DeactivateState(name)` | Deactivates a state. |
| `ToggleState(name)` | Activates or deactivates a state, depending on whether it's active. |
| `IsStateActive(name)` | Whether a state is active. Pass a list to check that all of them are active. |
| `IsAnyStateActive(names)` | Whether any state in the list is active. |
| `IsStateActivatable(name)` | Whether `ActivateState` would succeed right now, and the name of the blocking state if not. |
| `GetState(name)` | Returns the `State` object. |
| `GetActiveStates()` / `GetAllStates()` | Returns the active states or all states, keyed by name. These are the manager's own tables, so don't change them. |

## Reacting to changes

The manager has `StateActivated` and `StateDeactivated` signals, which fire with the state's name:

```lua
StateManager.StateActivated:Connect(function(stateName)
    print(`{stateName} on`)
end)
```

To react to one state, use its own signals, or bind a handler that runs on both activation and deactivation:

```lua
StateManager:GetStateActivatedSignal("InMenu"):Connect(function()
    print("Menu opened")
end)

local sprinting = StateManager:GetState("Sprinting")
sprinting:BindHandler(function(state)
    humanoid.WalkSpeed = if state:IsActive() then 24 else 16
end, "SprintSpeed")
```

| `State` member | Use |
| --- | --- |
| `Name` | The state's name. |
| `IsActive()` | Whether the state is active. |
| `Activated` / `Deactivated` | Signals for this state. |
| `BindHandler(handler, handlerName?)` | Calls `handler(state)` on every activation and deactivation, in a new thread. Returns the handler's name, a generated one if you didn't pass one. |
| `UnbindHandler(handlerName)` / `ClearHandlers()` | Removes one handler or all of them. |
| `LastActivatedAt` / `LastDeactivatedAt` | `os.clock()` time of the last change. |

## Tags

Tags act on groups of states:

```lua
-- End all movement states except crouching
StateManager:DeactivateStatesWithTagExcept("Movement", "Crouching")

local activeMovementStates = StateManager:GetStatesActiveWithTag("Movement")
```

| Function | Use |
| --- | --- |
| `GetStatesActiveWithTag(tag)` | Returns the active states with the tag. |
| `ActivateStatesWithTag(tag)` | Tries to activate every state with the tag. Returns whether any failed, then the activated and failed states. |
| `ActivateStatesWithTagExcept(tag, names)` | The same, skipping one name or a list of names. Returns whether all succeeded, then the activated and failed states. |
| `DeactivateStatesWithTag(tag)` | Deactivates every state with the tag. |
| `DeactivateStatesWithTagExcept(tag, names)` | The same, skipping one name or a list of names. |

:::caution
The first value from `ActivateStatesWithTag` is `true` when something **failed**, but the first value from `ActivateStatesWithTagExcept` is `true` when everything **succeeded**.
:::

Using a tag that no state has warns and changes nothing.
