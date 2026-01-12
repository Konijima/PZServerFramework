# KoniLib

**KoniLib** is a shared library mod designed to provide common utilities and abstractions for Project Zomboid mods in this suite. It serves as a strict dependency for mods like **AreaSystem** and **ChatSystem**.

> **📚 Full Documentation:** See [docs/API.md](../../../docs/API.md) for complete API reference.

## Features

### 1. Centralized Logging
The `KoniLib.Log` module provides per-module verbose logging with easy enable/disable:
```lua
KoniLib.Log.Print("MyMod", "Player joined")  -- [KoniLib.MyMod] Player joined
KoniLib.Log.SetVerbose("MyMod", false)       -- Disable logging for MyMod
```

### 2. Multiplayer (MP) Abstraction
The `KoniLib.MP` module unifies networking logic, allowing developers to write code that works seamlessly across:
- **Singleplayer** (Local Loopback)
- **Hosted Multiplayer** (Listen/Host)
- **Dedicated Servers** (Client/Server)

It removes the need to manually check `isClient()` or `isServer()` for every action.

### 3. Socket.io-like Networking
The `KoniLib.Socket` module provides a **Socket.io-inspired** networking abstraction with:
- **Namespaces** - Isolated communication channels (e.g., `/chat`, `/trade`)
- **Rooms** - Group players for targeted messaging
- **Middleware** - Authentication, validation, and hooks
- **Acknowledgments** - Request/response pattern with callbacks
- **Broadcasting** - Flexible emission patterns (`to`, `broadcast`, `except`)

See [SocketAPI.md](../../../docs/SocketAPI.md) for full documentation.

### 4. Event System Abstraction
The `KoniLib.Event` module provides an object-oriented wrapper around Project Zomboid's native event system. It simplifies the registration, subscription, and triggering of custom events.

**Key benefits:**
- **Automatic Registration**: Checks existence and registers the event with `LuaEventManager` automatically.
- **Unified Interface**: Add, Remove, and Trigger methods are all encapsulated in the event object.
- **Type Safety**: Reduces string typos by defining the event object once.

## Developer Usage

Ensure your `mod.info` requires this mod:
```ini
require=KoniLib
```

### Registering Listeners
Listen for commands sent from the other side (or from yourself in SP).

```lua
-- Runs on both Client and Server
KoniLib.MP.Register("MyModName", "MyCommand", function(player, args)
    print("Received command from " .. (player and player:getUsername() or "Unknown"))
    -- Do something with args...
end)
```

### Sending Commands
Send data. The library automatically routes it:
- **Client -> Server**: Uses `sendClientCommand`.
- **Server -> Client**: Uses `sendServerCommand` (Broadcast or Targeted).
- **Singleplayer**: Executes the handler immediately.

```lua
local args = { value = 15, text = "Hello" }
KoniLib.MP.Send(getPlayer(), "MyModName", "MyCommand", args)
```

### Event System

#### Defining an Event
Create a new event instance. It's best practice to define this in a shared file.

```lua
-- shared/MyModEvents.lua
MyModEvents = {}
MyModEvents.OnCustomAction = KoniLib.Event.new("MyMod_OnCustomAction")
```

#### Listening for Events (Add)
Subscribe to the event using the `.Add()` method.

```lua
-- client/MyModClient.lua
MyModEvents.OnCustomAction:Add(function(data)
    print("Action received: " .. tostring(data))
end)
```

#### Triggering Events
Fire the event using the `:Trigger()` method.

```lua
-- server/MyModServer.lua
MyModEvents.OnCustomAction:Trigger("Some Data")
```

### Socket.io-like Networking

#### Quick Example

```lua
-- ============ SERVER ============
local chat = KoniLib.Socket.of("/chat")

-- Authentication middleware
chat:use("connection", function(player, auth, context, next, reject)
    if not auth.token then
        return reject("Token required")
    end
    next({ verified = true })
end)

-- Handle messages
chat:on("message", function(player, data, context, ack)
    chat:to("global"):emit("message", {
        from = player:getUsername(),
        text = data.text
    })
    if ack then ack({ sent = true }) end
end)

-- ============ CLIENT ============
local chat = KoniLib.Socket.of("/chat", { auth = { token = "secret" } })

chat:on("connect", function()
    chat:joinRoom("global")
end)

chat:on("message", function(data)
    print("[" .. data.from .. "]: " .. data.text)
end)

chat:emit("message", { text = "Hello!" }, function(response)
    print("Delivered: " .. tostring(response.sent))
end)
```

### 5. Custom Lifecycle Events
KoniLib introduces a set of standardized events to handle player lifecycle and networking reliably, fixing common issues where vanilla events fire too early or inconsistently across MP/SP.

See [EventsAPI.md](../../../docs/EventsAPI.md) for full documentation with flow diagrams and examples.

#### Client-Side Events
| Event | Arguments | Description |
| :--- | :--- | :--- |
| `KoniLib.Events.OnNetworkAvailable` | `playerIndex` | **Critical for Setup.** Fires on the first tick where the local player exists and the network is confirmed ready. Use this to send your initial "RequestSync" packets. |
| `KoniLib.Events.OnRemotePlayerInit` | `username`, `isRespawn` | Fires when **another** player joins or respawns on the server. Useful for chat messages or UI updates. |
| `KoniLib.Events.OnRemotePlayerDeath` | `username`, `x`, `y`, `z` | Fires when **another** player dies. |
| `KoniLib.Events.OnRemotePlayerQuit` | `username` | Fires when **another** player disconnects. |
| `KoniLib.Events.OnAccessLevelChanged` | `newLevel`, `oldLevel` | Fires when local player's access level changes (promoted/demoted). |

#### Shared Events (Client & Server)
| Event | Arguments | Description |
| :--- | :--- | :--- |
| `KoniLib.Events.OnPlayerInit` | `playerIndex`, `player`, `isRespawn` | **The Main Entry Point.** <br> **Client**: Fires when YOU (the local player) are fully initialized (Join or Respawn). <br> **Server**: Fires when ANY player is fully initialized. |

#### Server-Side Events
| Event | Arguments | Description |
| :--- | :--- | :--- |
| `KoniLib.Events.OnPlayerQuit` | `username` | Fires when the server detects a player has dropped from the online list. |

#### Example Usage
Basic setup pattern for any mod using KoniLib:

```lua
local Events = KoniLib.Events

-- 1. Send initial data request when network is ready
Events.OnNetworkAvailable:Add(function(playerIndex)
    local player = getSpecificPlayer(playerIndex)
    KoniLib.MP.Send(player, "MyMod", "RequestData", {})
end)

-- 2. Handle player creation (both initial join and respawn after death)
Events.OnPlayerInit:Add(function(playerIndex, player, isRespawn)
    if isRespawn then
        print("Player respawned! Resetting local stats...")
    else
        print("Player joined the session!")
    end
end)

-- 3. Notify when others join
Events.OnRemotePlayerInit:Add(function(username, isRespawn)
    print("Remote player " .. username .. " is here.")
end)
```
