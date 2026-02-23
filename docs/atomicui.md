---
sidebar_position: 6
title: AtomicUI
---

# Working with AtomicUI

AtomicUI is the UI framework used throughout the project. It is built around four modules:

- **[AtomicPane](/api/AtomicPane)** — The base class for all UI components. Provides visibility animation, spring management, and automatic transparency interpolation.
- **[AtomicButton](/api/AtomicButton)** — Extends `AtomicPane` with interactive states (hover, press, selected, enabled) and corresponding events.
- **[ScreenGui](/api/ScreenGui)** — A small utility for creating `ScreenGui` instances with sensible defaults.
- **[UIStateManager](/api/UIStateManager)** — Manages which registered UI components are visible based on named application states.

GUI template instances are stored under `ReplicatedStorage.GuiTemplates`. The included `/amodule` snippet can be used to create new template asset modules.

---

## Creating a ScreenGui

Use `ScreenGui.new` to create a container for your UI. It automatically parents to `PlayerGui` at runtime and to `CoreGui` in story environments.

```lua
local ScreenGui = shared("ScreenGui") ---@module ScreenGui

local MyGui = ScreenGui.new("MyGui")
```

---

## Creating an AtomicPane

Subclass `AtomicPane` to build a custom UI component. Override `_draw` to update your elements each frame based on spring values.

```lua
local AtomicPane = shared("AtomicPane") ---@module AtomicPane

local MyPane = setmetatable({}, AtomicPane)
MyPane.__index = MyPane
MyPane.ClassName = "MyPane"

function MyPane:_draw()
    local alpha = self._springs.Alpha.Position
    self.Gui.Visible = alpha < 0.999
    self.Gui.GroupTransparency = alpha
end

function MyPane.new(parent: Instance)
    local self = setmetatable(AtomicPane.new("MyPaneTemplate", {
        TitleLabel = "Title",
    }), MyPane)

    self:SetVisible(false, true) -- start hidden, no animation

    self.Gui.Parent = parent

    return self
end

return MyPane
```

The string key passed to `AtomicPane.new` must match the name of a `GuiObject` in `ReplicatedStorage.GuiTemplates`. The second argument maps descendant instance names to keys on `self` for quick access.

### Automatic alpha mapping

Instead of manually interpolating transparencies in `_draw`, call `MapAlpha` on any element whose transparency properties should be driven by the `Alpha` spring automatically:

```lua
function MyPane.new(parent: Instance)
    local self = setmetatable(AtomicPane.new("MyPaneTemplate", {}), MyPane)

    self:MapAlpha(self.Gui) -- maps all descendants recursively

    self:SetVisible(false, true)
    self.Gui.Parent = parent

    return self
end
```

### Custom springs

Add extra springs for animations beyond visibility:

```lua
function MyPane.new(parent: Instance)
    local self = setmetatable(AtomicPane.new("MyPaneTemplate", {}), MyPane)

    self:AddSpring("Slide", { s = 35, d = 1, i = 0 })

    self:SetVisible(false, true)
    self.Gui.Parent = parent

    return self
end

function MyPane:_draw()
    local alpha = self._springs.Alpha.Position
    local slide = self._springs.Slide.Position

    self.Gui.Visible = alpha < 0.999
    self.Gui.Position = UDim2.new(slide * -0.5, 0, 0.5, 0)
end
```

---

## Creating an AtomicButton

Subclass `AtomicButton` the same way as `AtomicPane`. It adds `Hovered`, `Pressed`, `Selected`, and `Enabled` springs automatically, along with the corresponding signals and setter methods.

```lua
local AtomicButton = shared("AtomicButton") ---@module AtomicButton

local MyButton = setmetatable({}, AtomicButton)
MyButton.__index = MyButton
MyButton.ClassName = "MyButton"

function MyButton:_draw()
    local alpha   = self._springs.Alpha.Position
    local hovered = self._springs.Hovered.Position
    local pressed = self._springs.Pressed.Position

    self.Gui.Visible = alpha < 0.999

    -- Subtle scale feedback
    local scale = 1 - pressed * 0.04 + hovered * 0.02
    self.Gui.Size = UDim2.fromScale(scale, scale)
end

function MyButton.new(parent: Instance)
    local self = setmetatable(AtomicButton.new("MyButtonTemplate", {}), MyButton)

    self.Activated:Connect(function()
        print("Button clicked!")
    end)

    self:SetVisible(false, true)
    self.Gui.Parent = parent

    return self
end

return MyButton
```

:::note
`AtomicButton` automatically creates a transparent `TextButton` named `Sensor` as a child of `Gui` if one does not already exist. You do not need to add one manually.
:::

---

## Linking panes

Use `AtomicPane:Link` to tie the lifetime (and optionally visibility) of a child pane to a parent pane. When the parent is destroyed, the linked child is cleaned up automatically.

```lua
local childPane = MyChildPane.new()
childPane:Link(parentPane)

-- Also mirror visibility changes:
childPane:Link(parentPane, true)
```

---

## Using UIStateManager

`UIStateManager` allows you to define named application states that show and hide groups of registered UI components together.

### Registering a component

Call `RegisterComponent` with a unique name and the pane instance. The component must implement `:Show()` and `:Hide()`, which all `AtomicPane` subclasses provide.

```lua
local UIStateManager = shared("UIStateManager") ---@module UIStateManager

UIStateManager:RegisterComponent("HUD", myHudPane)
UIStateManager:RegisterComponent("PauseMenu", myPausePane)
```

### Registering states

Define states with `RegisterState`, specifying which components to show and hide:

```lua
UIStateManager:RegisterState("Gameplay", {
    Shows = { "HUD" },
    Hides = { "PauseMenu" },
    CoreGui = {
        Shows = { "*" },
        Hides = {},
    },
    GamepadCursorEnabled = false,
})

UIStateManager:RegisterState("Paused", {
    Shows = { "PauseMenu" },
    Hides = { "HUD" },
    GamepadCursorEnabled = true,
})
```

Use `"*"` in `Shows` or `Hides` to target all registered components at once.

### Switching states

```lua
UIStateManager:SetState("Paused")

-- Restore the previous state
UIStateManager:PreviousState()

-- Return to the default state
UIStateManager:SetDefault()
```

### Blocking transitions

Add a `Blocks` list to a state's properties to prevent certain transitions while that state is active:

```lua
UIStateManager:RegisterState("Cutscene", {
    Shows = {},
    Hides = { "*" },
    Blocks = { "*" }, -- prevent all state changes
})
```

Pass `true` as the second argument to `SetState` to force a transition regardless of blocks:

```lua
UIStateManager:SetState("Gameplay", true)
```

### Reacting to state changes

Use `RegisterEventHook` to run logic whenever the state changes:

```lua
UIStateManager:RegisterEventHook("StateChange", function(newState, oldState)
    print("Transitioned from", oldState, "to", newState)
end)
```

Available hooks: `StateChange`, `BeforeStateChange`, `AfterStateChange`, `CoreGuiChange`.
