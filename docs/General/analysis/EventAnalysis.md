# Event System Analysis & Findings

## Player Initialization & Event Timing
Experiments were conducted to determine the correct event for initializing client-side logic that requires the `Player` object (especially for `MP` usage).

### Key Findings (Local Host / Singleplayer)
1.  **`Events.OnInitWorld`**: Fired **TOO EARLY**. `getPlayer()` returns `nil`. Usage here causes errors or requires unsafe workarounds.
2.  **`Events.OnGameStart`**: `getPlayer()` returns a valid player object (e.g., "BrentHardison").
3.  **`Events.OnCreatePlayer`**:
    *   Fires during initial load (sometimes with a placeholder name like "Bob" before `OnGameStart`, or with the correct name).
    *   **CRITICAL**: Fires again during **Respawn** (when the player dies and creates a new character).
    *   `OnGameBoot` and other init events do **not** fire on respawn.

### Recommended Pattern
To handle both initial connection and respawns safely, utilize `Events.OnCreatePlayer`.

```lua
local function Init(playerIndex)
    local player = getSpecificPlayer(playerIndex)
    if player then
        -- Safe to access player object
        -- Safe to send Network commands (e.g. RequestSync)
    end
end
Events.OnCreatePlayer.Add(Init)
```

### Alternatives
*   **First Tick Check**: Hooking `Events.OnTick`, checking `if getPlayer()`, then unhooking works for the initial load but **fails on respawn** because the Lua script is not reloaded, so the hook is lost after the first execution.

## Network Availability

Tests were conducted to determine when `sendClientCommand` works reliably on multiplayer connections.

### Findings

#### 1. `Events.OnGameStart` (Too Early)
*   **Status**: ❌ **Failed**
*   **Explanation**: This event fires before the connection to the server is fully established. It's like trying to speak into a phone while it's still dialing; the other side can't hear you yet.
*   **Technical Details**:
    *   The client tried to send a "Ping" command at timestamp `...414`.
    *   The server logs show the connection handshake (`player-connect`) starting at `...416` and finishing (`fully-connected`) at `...610`.
    *   Since the command was sent **before** the connection was finished, the packet was dropped and never reached the server.

#### 2. `Events.OnTick` (First Update)
*   **Status**: ✅ **Success**
*   **Explanation**: Waiting for the game's first update loop (tick) ensures everything is loaded. If the player character exists, the connection is active and ready to carry messages.
*   **Technical Details**:
    *   The client checked for a valid player object during `OnTick`.
    *   It sent a "Ping" command which the server successfully received at `...376`.
    *   The server replied with a "Pong", confirming a full round-trip connection.

### Recommendation
For initial network requests (like data sync), waiting for the first valid `OnTick` (where player exists) is safer than `OnGameStart`.

## Custom Initialization Events (Implemented in KoniLib)

Based on these findings, KoniLib now provides two custom events to simplify lifecycle management:

### 1. `Events.OnNetworkAvailable`
*   **Trigger**: Fires on the first `OnTick` where the local player exists.
*   **Usage**: Use this for sending initial network commands (like requesting server configuration, sync data, etc.).
*   **Arguments**: `playerIndex` (number)
*   **Example**:
    ```lua
    Events.OnNetworkAvailable.Add(function(playerIndex)
        local player = getSpecificPlayer(playerIndex)
        -- Send initial packet
        sendClientCommand(player, "MyMod", "RequestSync", {})
    end)
    ```

### 2. `Events.OnPlayerRespawn`
*   **Trigger**: Fires when a player character is created *after* the initial join (i.e., upon respawning after death).
*   **Usage**: Re-initialization of character-specific data that is lost on death, without re-triggering "Join" logic.
*   **Arguments**: `playerIndex` (number), `player` (IsoPlayer)
*   **Example**:
    ```lua
    Events.OnPlayerRespawn.Add(function(playerIndex, player)
        print("Player respawned! resetting stats...")
    end)
    ```
