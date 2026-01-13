# Project Zomboid Server Startup Sequence Analysis

**Based on:** `server-console.txt`
**Date:** 2026-01-12
**Scope:** Multiplayer Dedicated Server Initialization

This document analyzes the initialization order of Project Zomboid systems during a server boot process. Understanding this sequence is critical for determining when to initialize mod logic to ensure dependencies (like ModData, Map Zones, or Networking) are ready.

## Initialization Timeline

The server boot process can be categorized into several distinct phases:

### 1. Core Asset & Definition Loading
*Early initialization of static game data.*

*   **Sprites & Textures**: Validates and loads textures (deduplicated).
*   **Tile Definitions**: `LoadTileDefinitions` ends.
*   **Animal Definitions**: `loadAnimalDefinitions`.

### 2. Game Systems Initialization
*Basic simulation systems come online.*

*   **GameTime & Weather**: `GameTime.init()` loads weather patterns.
*   **Radio System**: `ZomboidRadio.Init()` loads `RadioData.xml` and translation files.
    *   *Note:* Radio channels are loaded here.

### 3. Data Persistence & World State
*Loading saved data and synchronization structures.*

*   **Global Mod Data**: `GlobalModData.init()`
    *   *Implication:* Global ModData is available before the world geometry is fully loaded.
*   **Instance Tracker**: `InstanceTracker.load()`
*   **Erosion**: `ErosionGlobals.Boot()`
*   **World Dictionary**: `WorldDictionary.init()` checks and loads the object dictionary (`WorldDictionary.bin`).
    *   *Critical:* Ensures Item IDs match across saves/updates.
*   **Entities & Outfits**: `GameEntityManager.Init()`, `PersistentOutfits.init()`.

### 4. Map & Metagrid Loading
*The world geometry and zones are constructed.*

*   **IsoMetaGrid**: `IsoMetaGrid.Create`/`load`
    *   Reads `map_meta.bin`, `map_zone.bin`, `map_animals.bin`.
    *   *Event:* `triggerEvent OnLoadedMapZones` fires after this.
*   **Item Configuration**: `ItemConfigurator.Preprocess()`.
*   **Collision**: `MapCollisionData.init()`.

### 5. Population & Pathfinding
*AI Managers and Navigation Mesh.*

*   **Animals**: `AnimalPopulationManager.init()`.
*   **Zombies**: `ZombiePopulationManager.init()`.
*   **Pathfinding**: `Pathfind init()`.

### 6. World Streaming & Cell Loading
*Preparing the actual chunks for the spawn region.*

*   **World Streamer**: `WorldStreamer.create()`.
*   **Cell Loading**: `CellLoader.LoadCellBinaryChunk` loads specific chunks.
*   **Meta Tracker**: `MetaTracker.load()`.
*   **Spawn Points**: `SpawnPoints.initSpawnBuildings` validates spawn locations.

### 7. Networking & Server Start
*Opening the server to the outside world.*

*   **RakNet Init**: `Initialising RakNet...`
*   **Server Start Marker**: `*** SERVER STARTED ****`
    *   *Note:* The server considers itself "Started" at this point.
*   **RCON**: Starts listening on port 27015.

### 8. Lua Networking (LuaNet)
*High-level Lua networking bridge initialization.*

*   **Initialization**: `LuaNet: Initializing...`
    *   **Registry**: `LuaNet: Registering server listener...`
    *   **Completion**: `LuaNet: Initialization [DONE]`
    *   **Event**: Triggers `LuaNet.onInitAdd`.

> **Observation:** LuaNet initializes **AFTER** the `*** SERVER STARTED ***` message. This reinforces the need for safe wrappers (like `KoniLib.Events.OnNetworkAvailable`) to ensure mod networking is truly ready before sending packets.

## Player Connection Sequence

When a client connects (`admin` in the analyzed log):

1.  **RakNet Handshake**: `new-incoming-connection` -> `login` -> `client-connect`.
2.  **Connection Details**: Server sends `connection-details`.
3.  **Login Queue**: `login-queue-request` -> `login-queue-done`.
4.  **Action System**: Validates transition XMLs (Warnings about canceled transitions often appear here).
5.  **Player Instance**: `player-connect` -> `fully-connected`.
    *   *Log:* `[KoniLib.Socket] Player connected to chat: admin`
6.  **Chat/Commands**: Player begins sending packets (Global chat, Commands).

## Critical Takeaways for Modding

1.  **GlobalModData** initializes very early (Phase 3), before the Map or Zombies. Safe for static data reconfiguration.
2.  **Map Zones** are loaded in Phase 4. `OnLoadedMapZones` is the safe event to manipulate zones programmatically.
3.  **Networking is Layered**:
    *   RakNet starts at Phase 7.
    *   LuaNet (which Modders use via `sendServerCommand`) initializes in Phase 8.
    *   *Attempting to send network commands `OnGameStart` (Client) or immediately at Phase 7 (Server) might fail if LuaNet isn't hooked yet.*
