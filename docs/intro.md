---
sidebar_position: 1
title: Getting Started
---

import Tabs from "@theme/Tabs";
import TabItem from "@theme/TabItem";
import Link from "@docusaurus/Link";

# Getting Started
To get started working with Order, you can use any of the options detailed below. Be sure to check out [the API](/order/api) for details on how everything works!

---

## Installation

<Tabs groupId="installation-kind">
<TabItem value="rojo" label="Rojo" default>

### 1) Download VS Code and Rojo
1. Download and install VS Code from [here](https://code.visualstudio.com/)
2. From VS Code, install the extension Rojo from the Extensions tab on the left sidebar or through [this link.](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo)
3. In Roblox Studio, search for and add the plugin for Rojo through the toolbox, or use [this link.](https://create.roblox.com/store/asset/13916111004/Rojo)

### 2) Create a new repository based on this template
1. At the top of this page, click the green "Use this template" button and select "Create a new repository"
2. Select the proper owner, add a name, choose your desired visiblity options, and click "Create repository from template"
3. Using the software of your choice (I typically use VS Code's Source Control menu), clone your new repository to your computer

### 3) Initialize Wally
1. If you don't yet have Wally, you can install it [from here.](https://github.com/UpliftGames/wally)
2. Open a terminal in your new project's directory and run the command `wally install` to get the included packages.

### 4) Project configuration
1. Open the new repository in VS Code and then open the `default.project.json` file
2. At the top, you'll see a string that reads "New Order Project", replace this with the name of your new project and save the file

### 5) Sync code into Roblox Studio
1. In VS Code, click the Rojo button on the bottom right (if you don't see this icon, verify the Rojo extension is installed and restart VS Code)
2. In the context menu that appears, click on `default.project.json` at the bottom
3. In Roblox Studio, create or open a place file that will host your new experience
4. Switch to the Plugins tab, and select Rojo
5. In the Rojo window that appears, click "Connect"

You are now up and running with Order! Any code you write in VS Code will be synced into your new game whenever you save the file.

</TabItem>
<TabItem value="roblox" label="Roblox Package">

I highly recommend the professional environment that Rojo offers, but if you'd like, you can also get Order directly from the Roblox catalog [here](https://www.roblox.com/library/11152308855/). Installation instructions are included with the package. Note that this package follows a different setup structure and has to be updated manually, so updates come a lot slower to this version and it may often be out of date.

</TabItem>
</Tabs>
---
## Creating your first task

Tasks are the primary way to run code at runtime in Order. Any module placed inside a `tasks` folder will be automatically discovered and initialized by the framework.

### 1) Create the task file
Inside the appropriate context folder (`client`, `server`, or `shared`), create a `tasks` subfolder if one doesn't already exist, then add a new `.luau` file inside it. For example, to create a server-side task:

```
src/
  server/
    core/
      tasks/
        MyTask.luau   ← your new task
```

### 2) Write the task module

A task is a regular Lua table returned by the module. Add `:Prep()` for synchronous setup that runs before everything else, and `:Init()` for your main async logic that runs after all prep work is done. Both are optional.

```lua
local PlayerUtils = shared("PlayerUtils")

local MyTask = {
    Priority = 0, -- optional, higher values initialize first
}

function MyTask:Prep()
    -- Synchronous setup — runs before :Init() on any task.
    -- Safe to set up state here, but avoid yielding.
    self.Players = {}
end

function MyTask:Init()
    -- Async runtime logic — runs after all :Prep() calls finish.
    PlayerUtils:PlayerAdded(function(player)
		...
	end)
    print("MyTask initialized!")
end

return MyTask
```

### 3) Load other modules from your task

Call `shared()` at the top of the file, before defining the task table, to load dependencies by name, partial path, or direct reference:

```lua
local PlayerData = shared("PlayerData")
local GetRemote   = shared("GetRemote")

local MyTask = {}

function MyTask:Init()
    GetRemote("Counter"):OnEvent(function(player)
        PlayerData:IncrementNumValue(player, "Counter", 1)
    end)
end

return MyTask
```

For modules involved in a **cyclic dependency**, you can still call `shared()` at the top level — but any code that actually *uses* the returned value must be inside a function:

```lua
local CyclicModule = shared("CyclicModule") -- fine at the top level

local MyTask = {}

function MyTask:Init()
    CyclicModule:DoThing() -- safe: accessed inside a function, not bare code
end

return MyTask
```

:::warning
Bare top-level code that directly calls or indexes a cyclic dependency will not work. Order detects this and will skip initialization on that module with a warning.
:::

Once the framework initializes, your task will be picked up automatically — no registration or additional wiring needed.

