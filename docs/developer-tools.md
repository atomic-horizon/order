---
sidebar_position: 4.5
title: Developer Tools
---

# Developer Tools

Order includes a [Cmdr](https://eryn.io/Cmdr/) console and a Branches pane for moving between the places in your experience. Who can use them is controlled by `PermissionService`.

## Opening the tools

| Tool | Permission | Ways to open |
| --- | --- | --- |
| Cmdr console | `cmdr` | <kbd>F2</kbd> for everyone, plus `/cmdr` or `/console` in chat and a top bar button |
| Branches pane | `branches` | `/branches` in chat and a top bar button |

The chat commands and top bar buttons only appear for players with the matching permission. Change how they appear in `DeveloperToolsConfig` (`src/client/core/lib/DeveloperTools`):

| Setting | Default | Effect |
| --- | --- | --- |
| `ChatCommands` | `true` | Adds the `/cmdr`, `/console` and `/branches` chat commands. On touch devices, chat is the only way to open the tools without the top bar buttons. |
| `TopbarButtons` | `true` | Adds top bar buttons for the tools. |
| `GroupTopbarButtons` | `true` | When a player can see more than one tool button, puts them in a single "Dev" group that expands when selected. |

Teleport requests from the Branches pane are checked on the server: only players with the `branches` permission are teleported, and only to places in the same experience.

## Cmdr

Cmdr's built-in commands are registered, including `ban` and `unban`, which accept a player in the server, an offline username, or `#UserId`. Players with the `mod` permission can run `kick`, `boot`, `ban` and `unban`. Every other command needs the `cmdr` permission.

Custom commands, types and hooks go in the `CustomCommands`, `CustomTypes` and `CustomHooks` folders under `src/server/core/tasks/CmdrHooks`. Order adds two types:

| Type | Accepts | Parses to |
| --- | --- | --- |
| `branch` | The name of a place in the experience | The place |
| `userIdOrPlayer` / `userIdsOrPlayers` | A player in the server (with autocomplete), a UserId, or `.` / `me` for yourself | A UserId |

## Permissions

Permissions are set in `PermissionsConfig` (`src/shared/core/lib`). A check takes the first rule that applies, in this order:

1. A runtime grant or revoke from `PermissionService:SetRuntimePermission()`
2. `UserDeniedPermissions`
3. `Admins`, then the test player and Studio settings
4. `UserPermissions`
5. `GroupPermissions`

```lua
GroupPermissions = {
    ["cmdr"] = {
        [123456] = { RoleIds = { 987654321 } },
    },
},
```

Group permissions match **role IDs**, which you can copy with the "Copy Role ID" button at the bottom of a role's settings page. Roblox no longer uses rank to order roles, so it recommends checking role IDs instead. A `MinimumRank` rule still works but logs a deprecation warning. Only public roles can be checked.

| Function | Use |
| --- | --- |
| `PermissionService:HasPermission(player, label)` | Checks a player in the server. Works on the client and the server. |
| `PermissionService:UserHasPermission(userId, label)` | Checks any user, including ones not in the server. |
| `PermissionService:SetRuntimePermission(label, userId, granted)` | Server only. Grants (`true`) or revokes (`false`) a permission until the server shuts down, or removes the override (`nil`). Players in the server see the change through an attribute. |
