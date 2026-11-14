---
sidebar_position: 4.8
title: Utilities
---

# Utilities

Order ships a set of general purpose modules in `src/shared/core/lib` and `src/shared/core/tasks`. All of them load with `shared()` on both the server and the client. Modules with an API reference page are linked from their heading.

| Module | Use |
| --- | --- |
| [Maid](#maid) | Cleans up connections, instances and functions together. |
| [Observe](#observe) | Runs a callback with a property, attribute or children list now and on every change. |
| [PlayerUtils](#playerutils) | Join callbacks, a maid per player, and cached user info. |
| [CharacterUtils](#characterutils) | Spawn callbacks, a maid per character, and animation playback. |
| [CacheService](#cacheservice) | Named caches with an entry limit and an age limit. |
| [ProcessQueue](#processqueue) | Processes items one at a time, with an optional delay. |
| [rcall](#rcall) | Retries a function that can fail, such as a web call. |
| [Get](#get) | Waits for a path of children in one call. |
| [GetBranches](#getbranches) | Lists the places in the experience. |
| [Environment](#environment) | Tells you whether the server is production or testing. |
| [FormatNumber](#formatnumber) | Adds commas or shortens numbers with suffixes. |
| [TimerUtils](#timerutils) | Formats a countdown and tells you when it next needs redrawing. |
| [Sounds](#sounds) | Plays `AudioPlayer` sounds from `SoundService`. |
| [DebugRaycast and DebugPart](#debugraycast-and-debugpart) | Draws casts and parts for debugging. |
| [Small helpers](#small-helpers) | `DeepCopy`, `lerp`, `SpecialCharacters` and `Icons`. |

## Maid

A `Maid` holds things that need cleaning up and cleans them all at once. Use one per object or session so nothing outlives it.

```lua
local Maid = shared("Maid")

local maid = Maid.new()

maid:GiveTask(workspace.ChildAdded:Connect(print))
maid:GiveTask(someInstance)
maid:GiveTask(function()
    print("Cleaned up")
end)

-- Later
maid:DoCleaning()
```

When cleaned, a maid disconnects connections, destroys instances, calls functions, cancels threads, and calls `Destroy` (or `Disconnect`) on tables that have one.

| Method | Use |
| --- | --- |
| `GiveTask(task)` | Adds a task and returns its numeric ID. |
| `GiveTasks(tasks)` | Adds every task in a list. |
| `Add(task)` | Adds a task and returns the task itself, so you can create and track in one line. |
| `GivePromise(promise)` | Tracks a pending promise and removes it once it settles. |
| `DoCleaning()` / `Destroy()` | Cleans every task. Connections are disconnected first. |

You can also give a task a name. Setting a new task under the same name cleans the old one, and setting it to `nil` cleans it without adding anything:

```lua
maid.Highlight = Instance.new("Highlight")
maid.Highlight = nil -- Destroys the highlight
```

Names that match a `Maid` method, such as `maid.Destroy`, raise an error.

`PlayerUtils` and `CharacterUtils` give you ready-made maids that clean up when a player leaves or a character is removed. See below.

## Observe

[API reference](/api/Observe)

Each function calls the callback right away with the current value, then again on every change, and returns a connection. Pair them with a maid:

```lua
local Observe = shared("Observe")

maid:GiveTask(Observe.Attribute(workspace, "RoundState", function(roundState)
    StatusLabel.Text = `{roundState}`
end))
```

| Function | Calls back with |
| --- | --- |
| `Observe.Attribute(instance, attribute, callback)` | The attribute's value. |
| `Observe.Property(instance, property, callback)` | The property's value. |
| `Observe.Children(instance, callback)` | The full list of children, whenever one is added or removed. Returns a table with `Disconnect()` and `Connected` rather than a real connection. |

## PlayerUtils

[API reference](/api/PlayerUtils)

```lua
local PlayerUtils = shared("PlayerUtils")

PlayerUtils:OnPlayerAdded(function(player, playerMaid)
    playerMaid:GiveTask(player.Chatted:Connect(function(message)
        print(player, message)
    end))
end, "LogChat")
```

| Function | Use |
| --- | --- |
| `OnPlayerAdded(callback, callbackName?)` | Calls `callback(player, playerMaid)` for every player in the server and every player who joins. |
| `RemoveJoinCallback(callbackName)` | Removes a named join callback. |
| `GetPlayerMaid(player)` | Returns a maid that is cleaned when the player leaves. |
| `FetchUserInfo(userId)` | Returns the user's info from `UserService`, or `nil`. Yields. Results are cached, and failed lookups are not retried for a while. |

## CharacterUtils

[API reference](/api/CharacterUtils)

```lua
local CharacterUtils = shared("CharacterUtils")

CharacterUtils:OnAnyCharacterSpawned(function(character, characterMaid, player)
    local humanoid = character:WaitForChild("Humanoid")
    characterMaid:GiveTask(humanoid.Died:Connect(function()
        print(`{player} died`)
    end))
end, "DeathLogger")
```

The character maid is cleaned when the character is removed, so anything tied to one life goes in it.

| Function | Use |
| --- | --- |
| `GetCharacter(player, shouldYield?)` | Returns the player's character, optionally waiting for it. |
| `GetAllCharacters()` / `GetAllNonLocalCharacters()` | Returns the characters in the server. |
| `OnCharacterSpawned(player, callback, callbackName?, priority?)` | Calls `callback(character, characterMaid, player)` on every spawn, and right away if the player has a character. Lower priorities run first. |
| `OnAnyCharacterSpawned(callback, callbackName?, priority?)` | The same, for every player now and later. |
| `OnLocalCharacterSpawned(callback, callbackName?, priority?)` | The same, for the local player. Client only. |
| `RemoveOnSpawnedCallback(player, callbackName)`, `RemoveOnAnySpawnedCallback(callbackName)`, `RemoveLocalOnSpawnedCallback(callbackName)` | Removes a named callback. |
| `GetCharacterMaid(player)` / `GetLocalCharacterMaid()` | Returns the maid for the current character. |
| `GetChildFromCharacter(player, childName, shouldYield?)` | Returns a child of the character, such as `"Humanoid"`. |
| `PlayAnimationOnCharacter(character, animationId, options?, shouldYield?)` | Loads and plays an animation. Tracks are cached per character unless `options.shouldNotCache` is set. `options` also takes `fadeTime`, `weight` and `speed`. |

## CacheService

[API reference](/api/CacheService)

Stores values by key in named caches. Entries expire after an age limit, one hour by default. Every 30 seconds expired entries are removed, and a cache that holds more than its entry limit (1000 by default) is cleared completely.

```lua
local CacheService = shared("CacheService")

local thumbnailCache = CacheService:CreateCache("Thumbnails", 200, 600)

local thumbnail = thumbnailCache:GetOrAdd(userId, function()
    return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
```

`GetOrAdd` runs the callback only once per key at a time. Other callers asking for the same key wait for that result. The callback can return a cleanup function as a second value, which runs when the entry is removed, replaced or expires. `Set(key, value, cleanup?)`, `Get(key)` and `Remove(key)` work as you would expect, and `CacheService` has the same functions with the cache name as the first argument.

## ProcessQueue

[API reference](/api/ProcessQueue)

Calls a function on each item in order, one at a time, with an optional delay in seconds between items:

```lua
local ProcessQueue = shared("ProcessQueue")

local announcementQueue = ProcessQueue.new(function(message)
    showAnnouncement(message)
end, 3)

announcementQueue:Add("Round starting")
```

Errors are caught and warned. Set `RetryFailures = true` to add failed items back to the end of the queue. `Remove(item)`, `Clear()`, `IsProcessing()` and `Destroy()` are also available.

:::note
The first `Add` on an idle queue processes the queue on the calling thread, so it yields until the queue is empty. Wrap it in `task.spawn` if the caller shouldn't wait.
:::

## rcall

Calls a function and retries it if it errors. Returns the function's results, or `nil` if every attempt fails:

```lua
local rcall = shared("rcall")

local userInfos = rcall({ retryLimit = 3, retryDelay = 5 }, function()
    return UserService:GetUserInfosByUserIdsAsync({ userId })
end)
```

| Option | Default | Effect |
| --- | --- | --- |
| `retryLimit` | No limit | How many attempts to make in total. Without a limit, it keeps trying until it succeeds. |
| `retryDelay` | `2` | Seconds between attempts. |
| `backoff` | `false` | Doubles the delay after each failure, up to 60 seconds. |
| `jitter` | `false` | Randomizes each delay to between half and all of itself. |
| `requireResult` | `false` | Treats a `nil` result as a failure. |
| `async` | `false` | Runs in a new thread and returns `nil` right away. |
| `silent` | `false` | Doesn't warn on failure. |
| `traceback` | `false` | Includes a stack trace in the warning. |
| `failWarning` | None | Extra text for the warning. |

Arguments after the function are passed to it.

## Get

[API reference](/api/Get)

Waits for each child in a path and returns the last one. If the last argument is a list, returns each child in it:

```lua
local Get = shared("Get")

local keystone = Get(workspace, "Arch", "Keystone")
local keystone, door = Get(workspace, "Arch", { "Keystone", "Door" })
```

## GetBranches

[API reference](/api/GetBranches)

Returns every place in the experience as `{ Name, DisplayName, PlaceId }`. `DisplayName` is the place's name and `Name` is the same with everything but letters and numbers removed. The result is fetched once and cached. The Branches pane in the [Developer Tools](developer-tools) uses it.

```lua
local GetBranches = shared("GetBranches")

for _, branch in GetBranches() do
    print(branch.DisplayName, branch.PlaceId)
end
```

## Environment

[API reference](/api/Environment)

Tells you whether the current server is a live production server, and whether the testing data attributes are on. See [Environments](usage#environments).

## FormatNumber

```lua
local FormatNumber = shared("FormatNumber")

FormatNumber.AddCommas(1234567) -- "1,234,567"
FormatNumber.Shorten(1530000) -- "1.5M"
```

`Shorten` keeps one decimal place and uses suffixes from `K`, `M`, `B` and `T` upward.

## TimerUtils

```lua
local TimerUtils = shared("TimerUtils")

TimerUtils:GetStringForTimeRemaining(3725) -- "1H 2M"
TimerUtils:TimeToNextSignificantUpdate(3725) -- 125
```

`GetStringForTimeRemaining` shows days (`2D`), hours and minutes (`1H 2M`), minutes and seconds (`4M 5S`), or seconds (`9S`), depending on how much time is left. `TimeToNextSignificantUpdate` returns how many seconds until that string next changes, so a countdown can wait instead of redrawing every frame.

## Sounds

Plays the `AudioPlayer` instances you place under `SoundService`, found by name:

```lua
local Sounds = shared("Sounds")

Sounds:PlaySound("ButtonClick")
Sounds:PlaySound("Explosion", true, explosionPosition, 0.1)
```

`PlaySound(soundName, shouldClone?, position?, varyPitch?, duration?, emitterType?)`:

- `shouldClone` plays a copy, so the same sound can overlap itself. Copies are destroyed when they end.
- `position` (a `Vector3` or a part) plays a copy from that point through an `AudioEmitter`. `emitterType` names an emitter template under `SoundService.Audio.Emitters` to copy.
- `varyPitch` randomizes the playback speed by up to that amount.
- `duration` sets the playback speed so the sound lasts that many seconds.

`GetSound(soundName)` returns the original sound, and `PlayExistingSound(sound, varyPitch?, duration?)` restarts a sound you already have. Copies played without a position are wired to `SoundService.Audio.Effects.Master_Fader` unless the original has its own `Wire`.

## DebugRaycast and DebugPart

`DebugRaycast` runs a cast and draws it, green on a hit and red on a miss. It returns the cast's result:

```lua
local DebugRaycast = shared("DebugRaycast")

local result = DebugRaycast:Raycast(origin, direction, raycastParams, nil, nil, 0.2, 0.5, 3)
```

| Function | Arguments after the cast's own |
| --- | --- |
| `Raycast(origin, direction, params?, ...)` | `hitColor?`, `missColor?`, `thickness?`, `transparency?`, `duration?` |
| `Spherecast(position, radius, direction, params?, ...)` | `hitColor?`, `missColor?`, `transparency?`, `duration?` |
| `Blockcast(cframe, size, direction, params?, ...)` | `hitColor?`, `missColor?`, `transparency?`, `duration?` |

Drawings go in a `DebugRaycast` folder in `workspace`, and are removed after `duration` seconds if you pass one. Pass a `thickness` for `Raycast`, since it has no default.

`DebugPart.new(properties)` creates an anchored, half transparent red part. `properties` takes `Size`, `Position`, `CFrame`, `Orientation`, `Color`, `Transparency`, `CanCollide`, `Name`, `Parent` and `Lifetime` (seconds before it is removed).

## Small helpers

| Module | Use |
| --- | --- |
| `DeepCopy(table)` | Returns a copy of a table and every table inside it. |
| `lerp(a, b, t)` | Returns the number `t` of the way from `a` to `b`. |
| `SpecialCharacters` | Roblox's private-use glyphs for text: `Verified`, `Premium`, `Robux` and `Plus`. |
| `Icons` | Asset IDs for shared icons, currently `Success` and `Failure`. |

```lua
local SpecialCharacters = shared("SpecialCharacters")

PriceLabel.Text = `{SpecialCharacters.Robux} 100`
```
