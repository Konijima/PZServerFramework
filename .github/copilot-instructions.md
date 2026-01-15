# PZServerFramework - AI Coding Guidelines

## Project Overview

This is a **Project Zomboid Build 42** modding framework containing four mods:
- **KoniLib** - Core library providing MP abstraction, Socket.io-like networking, custom events
- **ChatSystem** - Custom chat implementation built on KoniLib's Socket API
- **AreaSystem** - Admin zone management tool
- **ReactiveUI** - Reactive UI framework for simplified UI creation

All mods (except KoniLib) require **KoniLib** as a dependency. Code is written in **Lua 5.1** for PZ's embedded Kahlua interpreter.

**📚 Full API Documentation:** [GitHub Wiki](https://github.com/Konijima/PZServerFramework/wiki)

## Project Zomboid References

**Target Build:** Build 42 (unstable)

**Game Source Code Locations:**
- **Java Classes:** `[Steam]/steamapps/common/ProjectZomboid/zombie/` (`.class` files - can be decompiled on demand)
- **Lua Source:** `[Steam]/steamapps/common/ProjectZomboid/media/lua/`
  - `shared/` - Core game logic, definitions, systems
  - `client/` - UI (ISUI classes), rendering, local player
  - `server/` - Server-side logic, admin commands, world management

**Key Game APIs to Reference:**
- **ISUI Classes:** `ISPanel`, `ISButton`, `ISTextEntryBox`, `ISRichTextPanel`, `ISScrollingListBox`, etc.
- **Player:** `IsoPlayer`, `IsoGameCharacter`, `SurvivorDesc`
- **World:** `IsoWorld`, `IsoCell`, `IsoGridSquare`, `IsoObject`
- **Multiplayer:** `sendClientCommand()`, `sendServerCommand()`, `OnClientCommand`, `OnServerCommand`
- **Events:** `LuaEventManager`, `Events` (check `shared/Definitions/LuaManager.lua` for event list)
- **ModData:** `ModData`, `getModData()`, `transmitModData()`

**Official Documentation:**
- Modding Guide: https://pzwiki.net/wiki/Modding
- Lua Events: https://pzwiki.net/wiki/Lua_Events
- Mod Structure: https://pzwiki.net/wiki/Mod_structure

## Directory Structure

```
Contents/mods/{ModName}/42/media/lua/
├── client/    # Client-only code (UI, local player logic)
├── server/    # Server-only code (authoritative handlers)
└── shared/    # Definitions, utilities loaded on both sides
```

**Mod Loading Order:**
1. **Dependencies first** - Mods listed in `require=` in `mod.info` load before dependent mods
2. **Shared files** - Loaded on both client and server, before client/server-specific files
3. **Client/Server files** - Loaded based on context (`isClient()` or `isServer()`)
4. **Alphabetical within folders** - Files load alphabetically within each directory

**File Loading Context:**
- **Client:** Loads `shared/` then `client/` directories
- **Server:** Loads `shared/` then `server/` directories
- **Both use:** `shared/` files, so they must be context-agnostic or use `isClient()`/`isServer()` guards

**Key Rules:**
- **Definitions files** (`shared/{Mod}/Definitions.lua`) define constants, types, and shared structures
- Use `isClient()` / `isServer()` guards for side-specific code in shared files
- Server files should start with `if isClient() then return end` guard
- Global namespace initialization must happen in shared files loaded first (typically `Definitions.lua`)
- **Build 42 Requirement:** In `mod.info`, dependencies must have backslash prefix: `require=\KoniLib` or `require=\KoniLib,\ReactiveUI`

## Core Patterns

### Global Namespace Pattern
Each mod initializes a global table, typically in `Definitions.lua`:
```lua
ModName = ModName or {}
```

**Modular Sub-System Pattern:**
To avoid load-order issues, sub-modules return tables that get merged into the main namespace:

```lua
-- shared/MyMod/SubModule.lua
local Module = {}

function Module.DoSomething()
    -- Implementation
end

return Module

-- client/MyMod/Client.lua
local SubModule = require("MyMod/SubModule")

MyMod.Client = {}
local Client = MyMod.Client

-- Option 1: Merge sub-module functions (flat namespace)
for k, v in pairs(SubModule) do 
    Client[k] = v 
end
-- Access: ChatSystem.Client.DoSomething()

-- Option 2: Nested sub-module (organized namespace)
Client.MyModule = SubModule
-- Access: ChatSystem.Client.MyModule.DoSomething()
```

**When to use each:**
- **Merge (Option 1):** For small utilities or when you want a flat API surface
- **Nested (Option 2):** For larger sub-systems to maintain clear organization (e.g., `ChatSystem.Client.TypingIndicators`)

This pattern allows:
- Independent file organization without global namespace conflicts
- Predictable initialization order
- Clear separation of concerns
- Safe code reuse across contexts

### KoniLib.MP - Simple Client/Server Communication
- **Use for:** Simple commands, request/response, broadcasting
- **Register:** `KoniLib.MP.Register(module, command, callback)`
- **Send:** `KoniLib.MP.Send(player, module, command, args)` - Pass `nil` for broadcast
- **Documentation:** [MP System Wiki](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-MP-System)

### KoniLib.Socket - Socket.io-style Networking
- **Use for:** Complex features needing rooms, middleware, acknowledgments
- **Create:** `KoniLib.Socket.of("/namespace")`
- **Server:** Middleware (`.use()`), events (`.on()`), rooms (`.join()`, `.to()`)
- **Client:** Connect (`.connect()`), emit with acks (`.emit(event, data, callback)`)
- **Documentation:** [Socket API Wiki](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Socket-API)

### Lifecycle Events (Critical for MP)
- **OnNetworkAvailable** - First safe moment to send network packets (use this, not `OnGameStart`)
- **OnPlayerInit** - Fires on join AND respawn; provides `isRespawn` flag to distinguish
- **OnRemotePlayer*** - Client notification when other players join/die/quit
- **Documentation:** [Events System Wiki](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Events-System)

### Custom Events
- **Define:** `MyMod.Events.OnSomething = KoniLib.Event.new("MyMod_OnSomething")`
- **Subscribe:** `.Add(function(data) end)`
- **Trigger:** `.Trigger(data)`

### ChatSystem Commands
- **Register:** `ChatSystem.Commands.Register({ name, handler, accessLevel, args, ... })`
- **Server-side only** in `server/ChatSystem/Commands/`
- **Access levels:** PLAYER, MODERATOR, ADMIN, OWNER
- **Documentation:** [Commands Wiki](https://github.com/Konijima/PZServerFramework/wiki/ChatSystem-Commands)

## Common Mistakes to Avoid

1. **Network Timing:** Use `OnNetworkAvailable` instead of `OnGameStart` for initial packets
2. **Random/Time Functions:** Use `getTimestampMs()` and `ZombRand(min, max)` instead of `os.time()` or `math.random()`
3. **IDs:** Always use `tostring(getRandomUUID())` for unique identifiers
4. **Side Checks:** Use `isClient()`/`isServer()` guards before network calls
5. **Shared State:** Don't modify `Definitions.lua` constants at runtime
6. **Respawn vs Join:** Always use `isRespawn` flag from `OnPlayerInit` to distinguish cases

## Code Style

- Use LuaDoc annotations: `---@class`, `---@param`, `---@return`
- Use `KoniLib.Log.Print(module, message)` for debug logging
- Prefix internal functions with module name (e.g., `MP.Resolve()`)
- Boolean settings default to `true` when enabling features
- Keep `Definitions.lua` files focused on constants and type definitions only

## Testing Strategy

Test in all three modes to ensure compatibility:
1. **Singleplayer** - Tests SP loopback logic
2. **Hosted Multiplayer** - Tests client/server from host perspective  
3. **Dedicated Server** - Tests true client/server separation

See `ChatSystem/TESTING_CHECKLIST.md` for manual testing procedures.

## Quick Reference Links

- **[Getting Started](https://github.com/Konijima/PZServerFramework/wiki/Getting-Started)** - Installation and setup
- **[KoniLib Overview](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Overview)** - Core library guide
- **[MP System](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-MP-System)** - Simple networking
- **[Socket API](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Socket-API)** - Advanced networking
- **[Events System](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Events-System)** - Lifecycle events
- **[ChatSystem Commands](https://github.com/Konijima/PZServerFramework/wiki/ChatSystem-Commands)** - Command system
- **[ReactiveUI](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Overview)** - UI framework
- **[Event Timing Analysis](https://github.com/Konijima/PZServerFramework/wiki/Technical-Event-Timing)** - Deep dive into PZ events
