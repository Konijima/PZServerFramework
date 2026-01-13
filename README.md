# PZServerFramework

A collection of Project Zomboid Mods and Frameworks designed for server management, custom chat, and shared library utilities.

## Documentation

Full API documentation is available in the [docs/](docs/) folder:
- [AreaSystem Documentation](docs/AreaSystem/README.md) - Area management and visualization
- [ChatSystem Documentation](docs/ChatSystem/README.md) - Chat replacement and command system
- [KoniLib Documentation](docs/KoniLib/README.md) - Core library and utilities
- [KoniLib API Reference](docs/KoniLib/API.md) - Main API reference
- [Socket API](docs/KoniLib/SocketAPI.md) - Socket.io-like networking system
- [Events API](docs/KoniLib/EventsAPI.md) - Custom lifecycle events

## Contents

### 1. KoniLib
A shared library mod serving as the foundation for other mods in this suite.

*   **Centralized Logging:** `KoniLib.Log` for per-module verbose logging with easy enable/disable.
*   **MP Abstraction:** Unified `KoniLib.MP` module for handling Client/Server communication transparently across Singleplayer, Hosted, and Dedicated Server environments.
*   **Socket.io-like Networking:** `KoniLib.Socket` provides namespaces, rooms, middleware, acknowledgments, and broadcasting patterns.
*   **Event System:** `KoniLib.Event` wrapper for creating and managing custom Lua events with type safety.
*   **Lifecycle Events:** Standardized events (`OnNetworkAvailable`, `OnPlayerInit`, `OnAccessLevelChanged`, etc.) that solve common MP/SP timing issues.

See [KoniLib Documentation](docs/KoniLib/README.md) for detailed usage.

### 2. ChatSystem
A custom chat implementation replacing vanilla chat with a modern, Socket.io-based system.

*   **Multiple Channels:** Local, Global, Faction, Safehouse, Private, Staff, Admin, and Radio.
*   **Command System:** Extensible command API with access levels and argument parsing.
*   **Proximity Chat:** Local chat respects distance between players.
*   **Live Settings:** Server sandbox options update in real-time.

See [ChatSystem Documentation](docs/ChatSystem/README.md) for detailed usage.

### 3. AreaSystem
An admin tool and system for creating, managing, and visualizing custom areas within the game world.

*   **UI Tools:** In-game editors for Areas and Shapes (Rectangles, etc.).
*   **Map Integration:** Visualizes created areas directly on the game map.
*   **Real-time Sync:** Changes sync instantly across all connected clients.
*   **Persistence:** Data survives server restarts.

See [AreaSystem Documentation](docs/AreaSystem/README.md) for usage guide.

## Installation

1.  Copy the `Contents/mods/` folders into your Project Zomboid `mods` directory (or Workshop content folder).
2.  Ensure `KoniLib` is enabled whenever using `ChatSystem`, `AreaSystem`, or other dependent mods.

## License

MIT
