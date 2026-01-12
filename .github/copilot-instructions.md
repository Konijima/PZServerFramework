# PZServerFramework - AI Coding Guidelines

## Project Overview

This is a **Project Zomboid modding framework** containing three mods:
- **KoniLib** - Core library providing MP abstraction, Socket.io-like networking, custom events
- **ChatSystem** - Custom chat implementation built on KoniLib's Socket API
- **AreaSystem** - Admin zone management tool

All mods require **KoniLib** as a dependency. Code is written in **Lua 5.1** for PZ's embedded Kahlua interpreter.

## Directory Structure

```
Contents/mods/{ModName}/42/media/lua/
├── client/    # Client-only code (UI, local player logic)
├── server/    # Server-only code (authoritative handlers)
└── shared/    # Definitions, utilities loaded on both sides
```

- **Definitions files** (`shared/{Mod}/Definitions.lua`) define constants, types, and shared structures
- Use `isClient()` / `isServer()` guards for side-specific code in shared files
- Server files should start with `if isClient() then return end` guard

## Key Patterns

### Global Namespace Pattern
All mods use a global table initialized at file start:
```lua
ModName = ModName or {}
ModName.SubModule = {}
```

### KoniLib.MP - Simple Client/Server Communication
```lua
-- Register handler (runs on receiving side)
KoniLib.MP.Register("MyMod", "MyCommand", function(player, args) end)

-- Send (automatic routing: client→server, server→client, SP loopback)
KoniLib.MP.Send(player, "MyMod", "MyCommand", { data = "value" })
KoniLib.MP.Send(nil, "MyMod", "Broadcast", args)  -- nil = broadcast to all
```

### KoniLib.Socket - Socket.io-style Networking
Use for complex features needing rooms, middleware, or acknowledgments:
```lua
local socket = KoniLib.Socket.of("/namespace")

-- Server: middleware, rooms, events
socket:use("connection", function(player, auth, ctx, next, reject) end)
socket:on("event", function(player, data, ctx, ack) end)
socket:to("room"):emit("event", data)

-- Client: connect, emit with ack
socket:on("connect", function() end)
socket:emit("event", data, function(response) end)
```

### KoniLib.Event - Custom Events
```lua
-- Define in shared (e.g., Definitions.lua)
MyMod.Events.OnSomething = KoniLib.Event.new("MyMod_OnSomething")

-- Subscribe
MyMod.Events.OnSomething:Add(function(data) end)

-- Trigger
MyMod.Events.OnSomething:Trigger(data)
```

### Lifecycle Events (Critical for MP)
Use `OnNetworkAvailable` for initial sync - vanilla events fire before network is ready:
```lua
KoniLib.Events.OnNetworkAvailable:Add(function(playerIndex)
    -- Safe to send initial packets here
end)

KoniLib.Events.OnPlayerInit:Add(function(playerIndex, player, isRespawn)
    -- isRespawn distinguishes join vs death-respawn
end)
```

## ChatSystem Command Registration

Commands are server-side only. Define in `server/ChatSystem/`:
```lua
ChatSystem.Commands.Register({
    name = "mycommand",
    aliases = { "mc" },
    description = "Does something",
    accessLevel = ChatSystem.Commands.AccessLevel.PLAYER,  -- or MODERATOR, ADMIN, OWNER
    category = "general",
    args = {
        { name = "target", type = ChatSystem.Commands.ArgType.PLAYER, required = true }
    },
    handler = function(context)
        -- context.player, context.args.target, context.channel
        ChatSystem.Commands.Server.ReplySuccess(context.player, "Done!")
    end
})
```

## Common Mistakes to Avoid

1. **Don't send packets in `OnGameStart`** - Use `OnNetworkAvailable` instead
2. **Don't use `os.time()` or `math.random()`** - Use `getTimestampMs()` and `ZombRand(min, max)`
3. **Always use UUID for IDs** - `tostring(getRandomUUID())`
4. **Check side before network calls** - Use `isClient()`/`isServer()` guards
5. **Don't modify `Definitions.lua` constants at runtime** - They're shared state

## Code Style

- Use `---@class`, `---@param`, `---@return` LuaDoc annotations
- Prefix internal functions with module name: `Socket.Log()`, `MP.Resolve()`
- Boolean settings default to `true` when enabling features

## Testing

No automated tests. Test in-game via:
- Singleplayer (tests SP loopback)
- Hosted multiplayer (tests client/server from host perspective)
- Dedicated server with separate client (tests true MP)

See `ChatSystem/TESTING_CHECKLIST.md` for manual testing procedures.
