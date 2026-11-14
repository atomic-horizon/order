---
sidebar_position: 2.5
title: Player Data
description: "Save and replicate Roblox player data in Order with ProfileStore and ReplicaService, and read it on the client with DataController."
keywords: [roblox player data, profilestore, replicaservice, datastore, luau]
---

# Player Data

Order saves each player's data with [ProfileStore](https://madstudioroblox.github.io/ProfileStore/) and replicates it to that player's client with [ReplicaService](https://madstudioroblox.github.io/ReplicaService/). The server reads and writes data through the `PlayerData` service. The client gets a read-only copy through `DataController`, which updates as the server changes it.

## The profile template

`ProfileTemplate` (`src/shared/core/lib/PlayerData/ProfileTemplate.luau`) is the shape and starting value of every player's data. Add the keys your game needs:

```lua
local ProfileTemplate = {
    AwardedBadges = {},
    PendingBadges = {},

    Coins = 0,
    Settings = {
        MusicVolume = 0.5,
    },
}
```

- New players start with a copy of the template.
- When a returning player loads, keys added to the template since they last played are filled in with their template values. Keys removed from the template stay in saved data until you clear them.
- The template is frozen, so code can't change it by accident.
- `AwardedBadges` and `PendingBadges` are used by `BadgeGiver`. Keep them.

Because the template is shared, the client can read it too. In Edit mode, where no server is running, `DataController` returns the template so UI previews have data to show.

## Loading

Data loads automatically when a player joins. Wait for it before using it:

```lua
local PlayerData = shared("PlayerData")

Players.PlayerAdded:Connect(function(player)
    if not PlayerData:WaitForData(player) then
        return -- The player left, or their data failed to load
    end

    print(PlayerData:GetValue(player, "Coins"))
end)
```

`WaitForData` returns `false` if the player leaves or their data can't load. In a live server, a player whose data can't load is kicked with a message to try again. Studio doesn't kick, so you can still test.

A profile can only be loaded in one server at a time. When a player rejoins the same server quickly, their new load waits up to 15 seconds for the previous session to finish saving.

## Reading and writing on the server

Every function that takes a key path accepts a single key, a dot-separated path, or an array of keys:

```lua
PlayerData:GetValue(player, "Coins")
PlayerData:GetValue(player, "Settings.MusicVolume")
PlayerData:GetValue(player, { "Settings", "MusicVolume" })
```

| Function | Use |
| --- | --- |
| `GetValue(player, keyPath)` | Returns the value at the path, or `nil` if the last key is missing. Every table before the last key must exist, or it errors. |
| `SetValue(player, keyPath, value)` | Sets the value and replicates it to the player. |
| `IncrementNumValue(player, keyPath, amount)` | Adds a non-zero amount to a number (a missing value counts as `0`) and returns the new value. Returns `nil` if the amount is `0` or the stored value isn't a number. |
| `Observe(player, keyPath, callback)` | Calls `callback(newValue, oldValue)` with the current value right away, then on every change. Returns a connection. |
| `SetValueCallback(player, keyPath, callback, runImmediately?)` | Like `Observe`, but only calls back for the current value when `runImmediately` is `true`. |
| `GetPlayerDataReplica(player)` | Returns the player's `Replica`. Yields until data loads, and returns `nil` if the player leaves or their data can't load. |

Each of these yields until the player's data loads. If the data can't load, they warn and return `nil` instead of acting. There's no warning if the player has already left.

:::caution
Never change tables from `GetValue` in place. The change isn't replicated, and the client's copy goes out of date. For a single value, use `SetValue`. For arrays, use the replica's methods, such as `ArrayInsert` and `ArrayRemove` (see the [Replica API](https://madstudioroblox.github.io/ReplicaService/api/#replica)):

```lua
local replica = PlayerData:GetPlayerDataReplica(player)
replica:ArrayInsert("OwnedItems", "Sword")
```
:::

## Reading on the client

`DataController` mirrors the reading half of the server API, without the `player` argument:

```lua
local DataController = shared("DataController")

local coinsConnection = DataController:Observe("Coins", function(coins)
    CoinsLabel.Text = `{coins}`
end)
```

| Function | Use |
| --- | --- |
| `GetValue(keyPath)` | Returns the value at the path, or `nil` if any part of the path is missing. Yields until data arrives. |
| `Observe(keyPath, callback)` | Calls back with the current value right away, then on every change. Returns a connection. |
| `SetValueCallback(keyPath, callback, runImmediately?)` | Like `Observe`, but only calls back for the current value when `runImmediately` is `true`. |
| `GetData()` | Returns the whole data table. Yields until data arrives. |
| `GetDataReplica()` | Returns the `Replica`. Yields until it arrives. |

Client data is read-only. To change data, send a request to the server with a remote and validate it there.

## Saving

ProfileStore saves each profile every few minutes and when the player leaves. To save sooner, for example after a purchase, call `RequestSave`:

```lua
PlayerData:IncrementNumValue(player, "Coins", 500)
PlayerData:RequestSave(player)
```

`RequestSave` returns right away. It retries up to 3 times in the background and warns if every attempt fails. It returns `false` when there's nothing to save, such as when the player has left or data is read-only.

### Profile holds

When a player leaves, their profile is saved and released. If you have async work that still needs to write to their data, such as a purchase being processed, hold the profile until it finishes:

```lua
local holdId = PlayerData:CreateProfileHold(player)

-- Async work that writes to the player's data

PlayerData:ReleaseProfileHold(holdId)
```

`CreateProfileHold` returns `nil` if the player's profile isn't loaded, so create the hold before the work starts. When the player leaves, the release waits up to about 10 seconds for holds to clear, then releases the profile anyway.

## Reading another player's data

`ViewProfileAsync(userId)` returns a copy of any user's saved data, including users who aren't in the server. It returns `nil` if they have nothing saved or the read fails. It doesn't lock the profile, so it won't disturb a session they have in another server. Changes to the copy aren't saved.

```lua
local savedData = PlayerData:ViewProfileAsync(userId)
if savedData then
    print(savedData.Coins)
end
```

## Data stores and testing

Production places save to the `PlayerData_Prod` store. Testing places and Studio share one testing store, so testing never touches real player data. See [Environments](usage#environments) to set a place's environment.

Two attributes on `workspace` change how data is handled while testing:

| Attribute | Effect |
| --- | --- |
| `UseMockData` | Uses an in-memory store that is discarded when the server closes. |
| `ReadOnlyData` | Loads each player's saved data without locking it, and never writes it back. Every session starts from the same saved state. A player with nothing saved starts from the template. |

:::caution
Both attributes are ignored in live servers of production places, and the server warns once if either is set. A place published with one left on still loads and saves real player data.
:::
