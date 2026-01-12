# PZServerFramework

A collection of Project Zomboid Mods and Frameworks designed for server management, custom chat, and shared library utilities.

## Documentation

Full API documentation is available in the [docs/](docs/) folder:
- [API.md](docs/API.md) - Main API reference
- [SocketAPI.md](docs/SocketAPI.md) - Socket.io-like networking system
- [EventsAPI.md](docs/EventsAPI.md) - Custom lifecycle events

## Contents

### 1. KoniLib
A shared library mod serving as the foundation for other mods in this suite.

*   **Centralized Logging:** `KoniLib.Log` for per-module verbose logging with easy enable/disable.
*   **MP Abstraction:** Unified `KoniLib.MP` module for handling Client/Server communication transparently across Singleplayer, Hosted, and Dedicated Server environments.
*   **Socket.io-like Networking:** `KoniLib.Socket` provides namespaces, rooms, middleware, acknowledgments, and broadcasting patterns.
*   **Event System:** `KoniLib.Event` wrapper for creating and managing custom Lua events with type safety.
*   **Lifecycle Events:** Standardized events (`OnNetworkAvailable`, `OnPlayerInit`, `OnAccessLevelChanged`, etc.) that solve common MP/SP timing issues.

See [KoniLib README](Contents/mods/KoniLib/README.md) for detailed usage.

### 2. ChatSystem
A custom chat implementation replacing vanilla chat with a modern, Socket.io-based system.

*   **Multiple Channels:** Local, Global, Faction, Safehouse, Private, Staff, Admin, and Radio.
*   **Command System:** Extensible command API with access levels and argument parsing.
*   **Proximity Chat:** Local chat respects distance between players.
*   **Live Settings:** Server sandbox options update in real-time.

See [ChatSystem README](Contents/mods/ChatSystem/README.md) for detailed usage.

### 3. AreaSystem
An admin tool and system for creating, managing, and visualizing custom areas within the game world.

*   **UI Tools:** In-game editors for Areas and Shapes (Rectangles, etc.).
*   **Map Integration:** Visualizes created areas directly on the game map.
*   **Real-time Sync:** Changes sync instantly across all connected clients.
*   **Persistence:** Data survives server restarts.

See [AreaSystem README](Contents/mods/AreaSystem/README.md) for usage guide.

## Installation

1.  Copy the `Contents/mods/` folders into your Project Zomboid `mods` directory (or Workshop content folder).
2.  Ensure `KoniLib` is enabled whenever using `ChatSystem`, `AreaSystem`, or other dependent mods.

## For Developers

KoniLib provides powerful abstractions for mod development:

```lua
-- Centralized logging
KoniLib.Log.Print("MyMod", "Player joined: " .. username)
KoniLib.Log.SetVerbose("MyMod", false)  -- Disable logging

-- Simple MP communication
KoniLib.MP.Register("MyMod", "DoSomething", function(player, args)
    print("Received from " .. player:getUsername())
end)
KoniLib.MP.Send(player, "MyMod", "DoSomething", { data = "value" })

-- Socket.io-like patterns
local socket = KoniLib.Socket.of("/chat")
socket:use("connection", function(player, auth, ctx, next, reject)
    if not auth.token then return reject("Auth required") end
    next({ verified = true })
end)
socket:on("message", function(player, data, ctx, ack)
    socket:to("global"):emit("message", data)
    if ack then ack({ sent = true }) end
end)

-- Reliable lifecycle events
KoniLib.Events.OnNetworkAvailable:Add(function(playerIndex)
    -- Safe to send initial sync packets here
end)
```

## License

MIT
