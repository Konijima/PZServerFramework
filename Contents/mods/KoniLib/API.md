# KoniLib API Documentation

## Overview

KoniLib is a core utility library for Project Zomboid modding, designed to abstract away the complexities of:
1.  **Multiplayer Networking**: Handling Client/Server communication and Singleplayer compatibility transparently.
2.  **Custom Events**: Creating, managing, and firing custom Lua events with type safety.
3.  **Lifecycle Management**: Solving common initialization order problems (e.g., handling player creation, respawns, and initial network sync).

---

## 1. Multiplayer (MP) System
**Module:** `KoniLib.MP`  
**File:** `shared/KoniLib/MP.lua`

The MP system allows you to write one set of networking code that works in Singleplayer (SP), Hosted Multiplayer, and Dedicated Servers.

### `MP.Register(module, command, callback)`
Registers a function to handle a specific network command.

**Parameters:**
*   `module` (string): A namespace for your mod (e.g., "MyModID").
*   `command` (string): The specific action name (e.g., "UpdateScore").
*   `callback` (function): The function to execute when this command is received.
    *   **Signature:** `function(player, args)`
    *   `player` (IsoPlayer): The player object associated with the context (Sender on Server, Local Player on Client).
    *   `args` (table): The data table sent with the command.

**Example:**
```lua
KoniLib.MP.Register("StatsMod", "UpdateXp", function(player, args)
    local amount = args.amount
    player:getXp():AddXP(Perks.Strength, amount)
    print("Added " .. amount .. " XP to " .. player:getUsername())
end)
```

### `MP.Send(player, module, command, args)`
Sends a command across the network (or locally in SP).

**Parameters:**
*   `player` (IsoPlayer | nil): Context-dependent target.
    *   **Client -> Server**: Pass the local player (sender).
    *   **Server -> Client (Targeted)**: Pass the specific player object to send to.
    *   **Server -> Client (Broadcast)**: Pass `nil` to send to ALL connected clients.
    *   **Singleplayer**: Pass the local player.
*   `module` (string): Targeted namespace.
*   `command` (string): Targeted command.
*   `args` (table): Optional data table.

**Use Cases:**

**Case A: Client requesting data from Server**
```lua
-- on Client side
local player = getPlayer()
KoniLib.MP.Send(player, "StatsMod", "RequestData", { type = "full" })
```

**Case B: Server updating a specific player**
```lua
-- on Server side
KoniLib.MP.Send(targetPlayer, "StatsMod", "UpdateData", { result = 100 })
```

**Case C: Server announcing an event to everyone**
```lua
-- on Server side
KoniLib.MP.Send(nil, "StatsMod", "GlobalAnnouncement", { message = "Server Restarting!" })
```

---

## 2. Event System
**Module:** `KoniLib.Event`  
**File:** `shared/KoniLib/Event.lua`

Wraps the vanilla `LuaEventManager` to allow easy creation and usage of custom events.

### `Event.new(name)`
Creates a new event wrapper. If the event doesn't exist in Java/Vanilla Lua, it registers it.

**Returns:** An `Event` object.

**Example:**
```lua
local MyEvent = KoniLib.Event.new("OnZombieDance")
```

### `Event:Add(func)`
Subscribes a function to the event.

**Example:**
```lua
MyEvent:Add(function(dancerName)
    print(dancerName .. " is dancing!")
end)
```

### `Event:Trigger(...)`
Fires the event with any number of arguments.

**Example:**
```lua
MyEvent:Trigger("Bob")
```

---

## 3. Lifecycle & Lifecycle Events
**Module:** `KoniLib.Events`  
**Files:** `shared/KoniLib/CustomEvents.lua`, `client/KoniLib/CustomEventsClient.lua`, `server/KoniLib/CustomEventsServer.lua`

KoniLib standardizes player lifecycle events to fix common bugs regarding "When is it safe to send packets?" or "How do I distinguish a respawn from a login?".

### `KoniLib.Events.OnNetworkAvailable`
**Context**: Client Only  
**Trigger**: Fires on the **First Valid Tick** where the local player object exists.  
**Use Case**: This is the **only safe place** to send your initial "Hello Server / Request Sync" packets. Doing this in `OnGameStart` often fails because the connection isn't fully established.

**Parameters:**
*   `playerIndex` (number): The index of the local player (usually 0).

**Example:**
```lua
KoniLib.Events.OnNetworkAvailable:Add(function(playerIndex)
    local player = getSpecificPlayer(playerIndex)
    KoniLib.MP.Send(player, "MyMod", "Handshake", {})
end)
```

### `KoniLib.Events.OnPlayerInit`
**Context**: Shared (Client & Server)  
**Trigger**: Fires when a player entity is fully initialized via `OnCreatePlayer`.  
**Logic**: 
*   **Client**: Fires for the **Local Player** only.
*   **Server**: Fires for **Every Player** that connects/respawns.

**Parameters:**
*   `playerIndex` (number): The player index (0-3).
*   `player` (IsoPlayer): The player object.
*   `isRespawn` (boolean): `false` if this is the first login of the session. `true` if this is a respawn after death.

**Example:**
```lua
KoniLib.Events.OnPlayerInit:Add(function(playerIndex, player, isRespawn)
    if isRespawn then
        print(player:getUsername() .. " has respawned. Resetting UI...")
    else
        print(player:getUsername() .. " joined the game.")
    end
end)
```

### `KoniLib.Events.OnRemotePlayerInit`
**Context**: Client Only  
**Trigger**: Fires when the server informs clients that another player has joined or respawned.  

**Parameters:**
*   `username` (string): Name of the player.
*   `isRespawn` (boolean): Join vs Respawn.

**Example:**
```lua
KoniLib.Events.OnRemotePlayerInit:Add(function(username, isRespawn)
    if not isRespawn then
        HaloTextHelper.addText(username .. " connected!") 
    end
end)
```

### `KoniLib.Events.OnRemotePlayerDeath`
**Context**: Client Only  
**Trigger**: Fires when the server broadcasts that a player has died.

**Parameters:**
*   `username` (string)
*   `x`, `y`, `z` (floats): Location of death.

### `KoniLib.Events.OnPlayerQuit` (Server) / `OnRemotePlayerQuit` (Client)
**Trigger**: Fires when the system detects a player is no longer in the online list.
*   **Server**: Used to clean up server-side data for that user.
*   **Client**: Used to clean up UI elements representing that user.

**Parameters:**
*   `username` (string)

---

## 4. Full Workflow Example

Here is how you would setup a mod that syncs a "Mana" stat.

**1. Register Events & Handlers (Shared File)**
```lua
-- media/lua/shared/MyMod/Core.lua
require 'KoniLib'

-- Listen for Mana Updates
KoniLib.MP.Register("MyMod", "UpdateMana", function(player, args)
    local mana = args.val
    -- In SP/Client: Update UI
    -- In Server: Update Database
    print("Mana updated to: " .. mana)
end)

-- Listen for Sync Requests (Server Side Logic usually)
if isServer() then
    KoniLib.MP.Register("MyMod", "RequestSync", function(player, args)
        -- Send back current mana
        KoniLib.MP.Send(player, "MyMod", "UpdateMana", { val = 100 }) 
    end)
end
```

**2. Initialize on Client (Client File)**
```lua
-- media/lua/client/MyMod/Client.lua
require 'KoniLib'

-- Request data ONLY when we are sure network is ready
KoniLib.Events.OnNetworkAvailable:Add(function(playerIndex)
    local p = getSpecificPlayer(playerIndex)
    KoniLib.MP.Send(p, "MyMod", "RequestSync", {})
end)
```

