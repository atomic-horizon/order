---
sidebar_position: 4
title: Networking
---

# Networking with GetRemote

All server-client communication is handled through the `GetRemote` module. It returns a [`Remote`](/api/Remote) object — a unified wrapper around `RemoteEvent`, `UnreliableRemoteEvent`, and `RemoteFunction` that automatically creates the underlying instances on demand and routes calls by context.

You never need to manually create or locate remote instances in `ReplicatedStorage`. Just call `GetRemote` with a name from either side and use it.

```lua
local GetRemote = shared("GetRemote") ---@module GetRemote

local MyRemote = GetRemote("MyRemote")
```

The same name resolves to the same `Remote` object throughout the session, so repeated calls with the same name are safe and return the same instance.

---

## Firing events

### Server → Client

```lua
-- Fire to one player
MyRemote:FireClient(player, "Hello!")

-- Fire to a list of players
MyRemote:FireClientList({ player1, player2 }, "Hello!")

-- Fire to all players
MyRemote:FireAllClients("Hello, everyone!")

-- Fire to all players except one
MyRemote:FireAllExcept(player, "Everyone but you!")
```

### Client → Server

```lua
MyRemote:FireServer("Hello, server!")
```

### Context-agnostic firing

`:Fire()` routes automatically — it calls `:FireServer()` from the client or `:FireAllClients()` from the server:

```lua
MyRemote:Fire("Hello!")
```

---

## Listening for events

`:OnEvent()` also routes automatically — it connects to `OnServerEvent` on the server and `OnClientEvent` on the client. The server callback receives the firing player as the first argument.

```lua
-- Server
MyRemote:OnEvent(function(player, message)
    print(player.Name, "says:", message)
end)

-- Client
MyRemote:OnEvent(function(message)
    print("Server says:", message)
end)
```

`OnServerEvent` and `OnClientEvent` are aliases for `:OnEvent()` and can be used for clarity.

### Rate limiting

Pass a `rateLimitInterval` (in seconds) as the second argument to avoid processing bursts of events. Only the latest arguments received within the interval will be processed:

```lua
MyRemote:OnEvent(function(player, value)
    -- processes at most once per 0.1 seconds per callback
    updateHealthBar(value)
end, 0.1)
```

:::caution
Rate limiting drops intermediate events — only the most recent arguments within the interval are kept. Avoid this for events where every individual fire must be processed.
:::

---

## Unreliable events

For high-frequency data where occasional packet loss is acceptable (e.g. position updates, visual effects), use the unreliable variants. These use `UnreliableRemoteEvent` under the hood and have lower overhead.

```lua
-- Server → Client
MyRemote:FireClientUnreliable(player, position)
MyRemote:FireAllClientsUnreliable(position)

-- Client → Server
MyRemote:FireServerUnreliable(position)

-- Context-agnostic
MyRemote:FireUnreliable(position)

-- Listening
MyRemote:OnUnreliableEvent(function(player, position)
    updateMarker(player, position)
end)
```

`FireClientFast`, `FireServerFast`, `FireFast`, and `OnServerUnreliableEvent`/`OnClientUnreliableEvent` are all aliases for their unreliable counterparts.

---

## Remote functions (invoke/callback)

Use `OnInvoke` to register a handler and `:Invoke()` or `:InvokeServer()` / `:InvokeClient()` to call it and wait for a return value.

### Client invokes the server

```lua
-- Server — register the handler
MyRemote:OnInvoke(function(player, request)
    if request == "getData" then
        return { score = 100 }
    end
end)

-- Client — invoke and await result
local data = MyRemote:InvokeServer("getData")
print(data.score) --> 100
```

### Server invokes a client

```lua
-- Client — register the handler
MyRemote:OnInvoke(function(request)
    return UserInputService:GetLastInputType().Name
end)

-- Server — invoke a specific player and await result
local inputType = MyRemote:InvokeClient(player, "getInput")
```

### Context-agnostic invoke

`:Invoke()` routes automatically. When called from the client it invokes the server; when called from the server the first argument must be the target `Player`:

```lua
-- From client
local result = MyRemote:Invoke("getData")

-- From server
local result = MyRemote:Invoke(player, "getData")
```

:::caution
Invoking a client from the server can hang indefinitely if the client disconnects or never responds. Prefer firing events with a follow-up callback pattern for server-initiated requests where possible.
:::

---

## Recommended patterns

### Dedicated remote per feature

Create one remote per logical feature rather than multiplexing many actions over a single remote. This keeps handlers focused and makes debugging easier.

```lua
-- inventory.server.luau
local InventoryRemote = GetRemote("Inventory")

InventoryRemote:OnEvent(function(player, action, itemId)
    if action == "equip" then
        equipItem(player, itemId)
    elseif action == "drop" then
        dropItem(player, itemId)
    end
end)
```

### Validating client input on the server

Never trust data sent from the client. Always validate before acting on it:

```lua
InventoryRemote:OnEvent(function(player, action, itemId)
    if typeof(itemId) ~= "number" then return end
    if not playerOwnsItem(player, itemId) then return end

    equipItem(player, itemId)
end)
```

### Sharing the remote reference

Since `GetRemote` returns the same object for a given name everywhere, you can safely call it in both a server script and a client script using the same name string — no shared module or passing of references is needed.

```lua
-- myFeature.server.luau
local MyRemote = GetRemote("MyFeature")

-- myFeature.client.luau
local MyRemote = GetRemote("MyFeature") -- same underlying remote
```
