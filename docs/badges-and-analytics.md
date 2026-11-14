---
sidebar_position: 4.6
title: Badges and Analytics
---

# Badges and Analytics

## Badges

`BadgeGiver` awards badges from the server. It queues awards so they stay inside BadgeService's request limits, and records each award in [player data](player-data) so a badge that fails is tried again later.

```lua
local BadgeGiver = shared("BadgeGiver")

BadgeGiver:GiveBadge(player, 123456789)
```

`GiveBadge(player, badgeId, spreadSeconds?)` returns once the badge is queued, not once it is awarded. It yields until the player's data loads. It does nothing if the player's data shows they already have the badge, or if the player has left.

When many players earn a badge at the same moment, such as at the end of a round, pass `spreadSeconds` to delay each award by a random time up to that many seconds. Their requests then reach BadgeService over time rather than all at once:

```lua
for _, player in winners do
    BadgeGiver:GiveBadge(player, ROUND_WINNER_BADGE_ID, 10)
end
```

:::note
In Studio, `GiveBadge` does nothing, since badges can't be awarded there.
:::

### How awards are processed

1. `GiveBadge` adds the badge to the player's `PendingBadges`, then queues it. Queuing the same badge twice for one player does nothing.
2. A worker takes awards from the queue. It first checks `UserHasBadgeAsync`, and only calls `AwardBadgeAsync` if the player doesn't have the badge.
3. On success, the badge moves from `PendingBadges` to `AwardedBadges`. If BadgeService says the badge can't be awarded, for example because it's disabled, the server warns and the badge is removed from `PendingBadges` without being retried.
4. If a request errors, the award is retried with a delay that doubles from 2 seconds up to 60, with jitter. After 5 failed attempts it stops for the session.
5. When a player joins, every badge left in their `PendingBadges` is queued again. This covers awards that failed, and awards cut short by the player leaving.

Badge IDs are saved as string keys, so `AwardedBadges` and `PendingBadges` look like `{ ["123456789"] = true }`. Keep both keys in the [profile template](player-data#the-profile-template).

### Request limits

BadgeService allows 50 + 35 × players requests per minute across the server. The queue uses at most 80% of that, which leaves room for other scripts. When the budget for the last minute is spent, awards wait.

If 5 requests fail in a row, the queue pauses for 60 seconds and warns. This stops it from adding load while BadgeService is having trouble.

## Analytics

Order sets up the [Gamebeast](https://docs.gamebeast.gg/sdk/roblox) SDK on the server and the client. It's installed as the `GamebeastSDK` package.

### Enabling Gamebeast

The server reads its Gamebeast key from an experience secret named `Gamebeast`, using `HttpService:GetSecret("Gamebeast")`. Add the secret in your experience's settings on the Creator Hub, with your Gamebeast project's SDK key as its value.

- **With the secret**, `AnalyticsServer` sets up the SDK when the server starts.
- **Without it**, the server prints that Gamebeast analytics is disabled, and doesn't set up the SDK.

Either way, the server sets the `GamebeastEnabled` attribute on `workspace` to `true` or `false`. `AnalyticsClient` waits for that attribute, and only sets up the client SDK when it's `true`, since the client SDK waits for remotes that the server only creates during setup.

### Sending events

Order doesn't wrap the SDK, so use it directly through `shared("GamebeastSDK")`. For example, to send a marker from the server:

```lua
local GamebeastSDK = shared("GamebeastSDK")

GamebeastSDK:GetService("Markers"):SendMarker("ItemPurchased", {
    ItemId = itemId,
    Price = price,
})
```

See the [Gamebeast Roblox SDK reference](https://docs.gamebeast.gg/sdk/roblox) for the SDK's services, including markers, configs and experiments. If your game sells developer products, Gamebeast recommends tracking them with [`SendNewPurchaseGrantedMarker`](https://docs.gamebeast.gg/sdk/roblox/api/markers#sendnewpurchasegrantedmarkerreceiptinfo-position). On the client, check that `workspace:GetAttribute("GamebeastEnabled")` is `true` before using the SDK, because it won't be set up otherwise.
