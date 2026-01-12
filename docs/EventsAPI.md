# KoniLib Custom Events Documentation

## Overview

KoniLib provides a set of **standardized lifecycle events** that solve common problems with Project Zomboid's vanilla events:

| Problem | KoniLib Solution |
|---------|------------------|
| `OnGameStart` fires before network is ready | `OnNetworkAvailable` fires when safe to send packets |
| No way to distinguish join vs respawn | `OnPlayerInit` provides `isRespawn` flag |
| No client notification when others join/die/quit | `OnRemotePlayer*` events |
| `OnPlayerDeath` inconsistent across MP/SP | Unified wrapper that works everywhere |
| No event when access level changes | `OnAccessLevelChanged` detects promotions/demotions |

---

## Event Reference

### OnNetworkAvailable

**Context:** Client Only  
**When:** First game tick where the local player exists and network is confirmed ready  

#### Why Use This?

In multiplayer, `OnGameStart` and `OnCreatePlayer` often fire **before** the network connection is fully established. If you try to send packets in those events, they may be silently dropped.

`OnNetworkAvailable` guarantees the network is ready, making it the **only safe place** to send your initial sync/handshake packets.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `playerIndex` | number | The index of the local player (usually 0) |

#### Example

```lua
-- ✅ CORRECT: Safe to send packets
KoniLib.Events.OnNetworkAvailable:Add(function(playerIndex)
    local player = getSpecificPlayer(playerIndex)
    KoniLib.MP.Send(player, "MyMod", "RequestSync", {})
end)

-- ❌ WRONG: Network may not be ready
Events.OnGameStart.Add(function()
    KoniLib.MP.Send(getPlayer(), "MyMod", "RequestSync", {})  -- May fail!
end)
```

#### Use Cases

- Request initial data sync from server
- Send "player joined" notification
- Initialize mod state that requires server data

---

### OnPlayerInit

**Context:** Shared (Client & Server)  
**When:** A player entity is fully initialized (via `OnCreatePlayer`)

#### Why Use This?

Project Zomboid's `OnCreatePlayer` fires both when a player first joins AND when they respawn after death. There's no built-in way to tell the difference.

`OnPlayerInit` provides an `isRespawn` flag so you can handle these cases differently.

#### Behavior by Context

| Context | Fires For | Notes |
|---------|-----------|-------|
| Client | Local player only | Use for UI setup, local state |
| Server | All players | Use for server-side data, broadcasting |

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `playerIndex` | number | The player index (0-3 for local, varies for server) |
| `player` | IsoPlayer | The player object |
| `isRespawn` | boolean | `false` = first join, `true` = respawn after death |

#### Example

```lua
KoniLib.Events.OnPlayerInit:Add(function(playerIndex, player, isRespawn)
    local username = player:getUsername()
    
    if isRespawn then
        -- Player died and respawned
        print(username .. " respawned!")
        
        -- Reset UI elements
        resetDeathScreen()
        
        -- Clear temporary buffs
        clearTemporaryEffects(player)
    else
        -- Player just joined the game
        print(username .. " joined the game!")
        
        -- Show welcome message
        showWelcomeUI()
        
        -- Load saved data
        loadPlayerData(player)
    end
end)
```

#### Use Cases

- **Join:** Load player data, show welcome UI, initialize stats
- **Respawn:** Reset UI, clear death-related state, respawn penalties

---

### OnRemotePlayerInit

**Context:** Client Only  
**When:** Server broadcasts that another player has joined or respawned

#### Why Use This?

Clients have no built-in way to know when other players join or respawn. This event lets you react to other players' lifecycle.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `username` | string | The username of the remote player |
| `isRespawn` | boolean | `false` = joined, `true` = respawned |

#### Example

```lua
KoniLib.Events.OnRemotePlayerInit:Add(function(username, isRespawn)
    if isRespawn then
        showNotification(username .. " has respawned")
    else
        showNotification(username .. " joined the server")
        playSound("player_join")
    end
end)
```

#### Use Cases

- Chat notifications ("Player X joined")
- Update player list UI
- Faction/team notifications
- Party system updates

---

### OnPlayerDeath

**Context:** Shared (wraps vanilla event)  
**When:** A player dies

#### Why Use This?

This is a wrapper around vanilla's `OnPlayerDeath` for consistency with the KoniLib event system. Use it the same way, but with KoniLib's `Event` API.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `player` | IsoPlayer | The player who died |

#### Example

```lua
KoniLib.Events.OnPlayerDeath:Add(function(player)
    local username = player:getUsername()
    print(username .. " has died at " .. player:getX() .. ", " .. player:getY())
    
    -- Server: Broadcast death to clients
    if isServer() then
        KoniLib.MP.Send(nil, "MyMod", "PlayerDied", {
            username = username,
            x = player:getX(),
            y = player:getY()
        })
    end
end)
```

---

### OnRemotePlayerDeath

**Context:** Client Only  
**When:** Server broadcasts that another player has died

#### Why Use This?

Clients don't receive vanilla death events for other players. This event notifies clients when any player dies, with location info.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `username` | string | The username of the player who died |
| `x` | number | X coordinate of death |
| `y` | number | Y coordinate of death |
| `z` | number | Z coordinate (floor level) of death |

#### Example

```lua
KoniLib.Events.OnRemotePlayerDeath:Add(function(username, x, y, z)
    -- Show death notification
    showNotification(username .. " has died!")
    
    -- Add death marker to map
    addMapMarker(x, y, "skull", username .. "'s death")
    
    -- Update party UI if they were in our party
    if isInMyParty(username) then
        updatePartyUI()
    end
end)
```

#### Use Cases

- Death notifications in chat
- Death markers on map
- Party/faction death alerts
- PvP kill tracking

---

### OnPlayerQuit

**Context:** Server Only  
**When:** Server detects a player has disconnected

#### Why Use This?

There's no reliable vanilla event for player disconnection. This event polls `getOnlinePlayers()` and detects when someone leaves.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `username` | string | The username of the player who quit |

#### Example

```lua
-- Server-side only
KoniLib.Events.OnPlayerQuit:Add(function(username)
    print(username .. " has disconnected")
    
    -- Save player data
    savePlayerData(username)
    
    -- Clean up server-side state
    removeFromActiveTrades(username)
    removeFromParties(username)
    
    -- Broadcast to clients
    KoniLib.MP.Send(nil, "MyMod", "PlayerQuit", { username = username })
end)
```

#### Use Cases

- Save player data on disconnect
- Clean up server-side state (trades, parties, etc.)
- Broadcast quit notification to clients
- Log player sessions

---

### OnRemotePlayerQuit

**Context:** Client Only  
**When:** Server broadcasts that another player has disconnected

#### Why Use This?

Clients need to know when other players leave to update UI, clean up references, etc.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `username` | string | The username of the player who quit |

#### Example

```lua
KoniLib.Events.OnRemotePlayerQuit:Add(function(username)
    -- Show quit notification
    showNotification(username .. " left the server")
    
    -- Remove from local player list
    removeFromPlayerList(username)
    
    -- Clean up any UI references
    closeTradeWindowWith(username)
    removePartyMember(username)
end)
```

#### Use Cases

- Quit notifications in chat
- Update player list UI
- Clean up trade/party UI
- Remove map markers for that player

---

### OnAccessLevelChanged

**Context:** Client Only  
**When:** The local player's access level changes (e.g., promoted to admin, demoted)

#### Why Use This?

When server admins promote or demote a player, there's no vanilla event to detect this change. This event polls the player's access level and fires when it changes.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| `newAccessLevel` | string | The new access level (e.g., "admin", "moderator", "") |
| `oldAccessLevel` | string\|nil | The previous access level |

#### Example

```lua
KoniLib.Events.OnAccessLevelChanged:Add(function(newLevel, oldLevel)
    if newLevel == "admin" then
        showNotification("You have been promoted to Admin!")
        enableAdminUI()
    elseif newLevel == "moderator" then
        showNotification("You have been promoted to Moderator!")
        enableModeratorUI()
    elseif newLevel == "" or newLevel == "None" then
        if oldLevel and oldLevel ~= "" then
            showNotification("Your access level has been revoked")
            disableStaffUI()
        end
    end
end)
```

#### Use Cases

- Show/hide admin UI panels when promoted
- Display promotion/demotion notifications
- Update available commands in chat
- Enable/disable staff-only features

---

## Event Flow Diagrams

### Player Join Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     PLAYER JOINS                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CLIENT (Joining Player)          SERVER                    │
│         │                            │                      │
│         │  ◄─── Connection ────►     │                      │
│         │                            │                      │
│   OnCreatePlayer                OnCreatePlayer              │
│         │                            │                      │
│   OnNetworkAvailable                 │                      │
│         │                            │                      │
│   OnPlayerInit ◄─────────────► OnPlayerInit                │
│   (isRespawn=false)              (isRespawn=false)          │
│         │                            │                      │
│         │                     Broadcasts to                 │
│         │                     other clients                 │
│         │                            │                      │
│                                      ▼                      │
│  OTHER CLIENTS                                              │
│         │                                                   │
│   OnRemotePlayerInit                                        │
│   (isRespawn=false)                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Player Death & Respawn Flow

```
┌─────────────────────────────────────────────────────────────┐
│                 PLAYER DIES & RESPAWNS                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CLIENT (Dying Player)            SERVER                    │
│         │                            │                      │
│   OnPlayerDeath ◄────────────► OnPlayerDeath               │
│         │                            │                      │
│         │                     Broadcasts death              │
│         │                            │                      │
│                                      ▼                      │
│  OTHER CLIENTS: OnRemotePlayerDeath                         │
│         │                                                   │
│         │        ... Player clicks respawn ...              │
│         │                            │                      │
│   OnCreatePlayer                OnCreatePlayer              │
│         │                            │                      │
│   OnPlayerInit ◄─────────────► OnPlayerInit                │
│   (isRespawn=true)               (isRespawn=true)           │
│         │                            │                      │
│         │                     Broadcasts to                 │
│         │                     other clients                 │
│         │                            │                      │
│                                      ▼                      │
│  OTHER CLIENTS: OnRemotePlayerInit (isRespawn=true)         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Player Quit Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     PLAYER QUITS                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CLIENT (Quitting)                SERVER                    │
│         │                            │                      │
│   Disconnects ──────────────────►    │                      │
│         │                            │                      │
│         X                      Detects disconnect           │
│                                      │                      │
│                                OnPlayerQuit                 │
│                                      │                      │
│                                Broadcasts to                │
│                                all clients                  │
│                                      │                      │
│                                      ▼                      │
│  OTHER CLIENTS                                              │
│         │                                                   │
│   OnRemotePlayerQuit                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Use OnNetworkAvailable for Initial Sync

```lua
-- ✅ Good
KoniLib.Events.OnNetworkAvailable:Add(function(playerIndex)
    requestDataFromServer()
end)

-- ❌ Bad - Network may not be ready
Events.OnGameStart.Add(function()
    requestDataFromServer()
end)
```

### 2. Handle Both Join and Respawn

```lua
KoniLib.Events.OnPlayerInit:Add(function(playerIndex, player, isRespawn)
    if isRespawn then
        -- Lighter initialization for respawn
        resetUI()
    else
        -- Full initialization for new join
        loadAllData()
        showWelcome()
    end
end)
```

### 3. Clean Up on Quit Events

```lua
-- Server
KoniLib.Events.OnPlayerQuit:Add(function(username)
    saveData(username)
    cleanupServerState(username)
end)

-- Client
KoniLib.Events.OnRemotePlayerQuit:Add(function(username)
    cleanupUIReferences(username)
end)
```

### 4. Use Remote Events for UI Updates

```lua
-- Update player count when others join/quit
KoniLib.Events.OnRemotePlayerInit:Add(function(username, isRespawn)
    if not isRespawn then
        incrementPlayerCount()
    end
end)

KoniLib.Events.OnRemotePlayerQuit:Add(function(username)
    decrementPlayerCount()
end)
```

---

## Comparison with Vanilla Events

| Scenario | Vanilla Approach | KoniLib Approach |
|----------|------------------|------------------|
| Initial sync | `OnGameStart` (unreliable) | `OnNetworkAvailable` ✓ |
| Detect respawn | Manual tracking with flags | `OnPlayerInit.isRespawn` ✓ |
| Other player joined | Not available | `OnRemotePlayerInit` ✓ |
| Other player died | Not available | `OnRemotePlayerDeath` ✓ |
| Player disconnected (server) | Poll manually | `OnPlayerQuit` ✓ |
| Other player quit (client) | Not available | `OnRemotePlayerQuit` ✓ |
