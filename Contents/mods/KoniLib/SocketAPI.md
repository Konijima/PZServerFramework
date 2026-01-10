# KoniLib Socket API Documentation

## Overview

`KoniLib.Socket` is a **Socket.io-inspired** networking abstraction built on top of Project Zomboid's native networking. It provides:

- **Namespaces** - Isolated communication channels
- **Rooms** - Group players together for targeted messaging
- **Middleware** - Authentication, validation, and hooks
- **Acknowledgments** - Request/response pattern with callbacks
- **Broadcasting** - Flexible emission patterns

---

## Quick Start

### Server Setup

```lua
-- server/MyMod/ChatServer.lua
local Socket = require("KoniLib/Socket")

-- Create a namespace
local chat = KoniLib.Socket.of("/chat")

-- Authentication middleware
chat:use("connection", function(player, auth, context, next, reject)
    -- Validate the connecting player
    if not auth.username then
        return reject("Username required")
    end
    
    -- Pass data to context (available in all handlers)
    next({ 
        username = auth.username,
        joinedAt = os.time()
    })
end)

-- Handle successful connections
chat:on("connect", function(player, context)
    -- Auto-join a default room
    chat:join(player, "global")
    
    -- Notify others
    chat:to("global"):emit("userJoined", {
        username = context.username
    })
end)

-- Handle messages
chat:on("message", function(player, data, context, ack)
    -- Broadcast to room
    chat:to(data.room):emit("message", {
        from = context.username,
        text = data.text,
        timestamp = os.time()
    })
    
    -- Acknowledge receipt
    if ack then
        ack({ delivered = true })
    end
end)
```

### Client Setup

```lua
-- client/MyMod/ChatClient.lua
local Socket = require("KoniLib/Socket")

-- Connect with auth data
local chat = KoniLib.Socket.of("/chat", {
    auth = { username = getPlayer():getUsername() }
})

-- Handle connection
chat:on("connect", function()
    print("Connected to chat!")
end)

-- Handle errors
chat:on("error", function(reason)
    print("Chat error: " .. reason)
end)

-- Listen for messages
chat:on("message", function(data)
    print("[" .. data.from .. "]: " .. data.text)
end)

-- Send a message with acknowledgment
chat:emit("message", { room = "global", text = "Hello!" }, function(response)
    if response.delivered then
        print("Message delivered!")
    end
end)
```

---

## API Reference

### Core Module

**File:** `shared/KoniLib/Socket.lua`

#### `KoniLib.Socket.of(namespace, options)`

Get or create a socket for a namespace.

**Parameters:**
- `namespace` (string): The namespace path (e.g., `"/chat"`, `"/trade"`)
- `options` (table, optional):
  - `auth` (table): Authentication data to send on connect
  - `autoConnect` (boolean): Auto-connect on creation (default: `true`)

**Returns:** `SocketClient` (client-side) or `SocketServer` (server-side)

```lua
-- Simple
local chat = KoniLib.Socket.of("/chat")

-- With auth
local chat = KoniLib.Socket.of("/chat", {
    auth = { token = "abc123", role = "admin" }
})
```

#### `KoniLib.Socket.get(namespace)`

Get an existing socket without creating one.

```lua
local chat = KoniLib.Socket.get("/chat")
if chat then
    chat:emit("ping", {})
end
```

#### `KoniLib.Socket.has(namespace)`

Check if a namespace exists.

```lua
if KoniLib.Socket.has("/chat") then
    print("Chat socket exists")
end
```

#### `KoniLib.Socket.destroy(namespace)`

Destroy a socket namespace and disconnect all clients.

```lua
KoniLib.Socket.destroy("/chat")
```

---

### Client API

**File:** `client/KoniLib/SocketClient.lua`

#### Connection

##### `socket:connect(auth)`

Connect to the server namespace.

```lua
local chat = KoniLib.Socket.of("/chat", { autoConnect = false })

-- Connect later with auth
chat:connect({ token = "secret123" })
```

##### `socket:disconnect()`

Disconnect from the namespace.

```lua
chat:disconnect()
```

##### `socket:isConnected()`

Check connection status.

```lua
if chat:isConnected() then
    chat:emit("ping", {})
end
```

#### Events

##### `socket:on(event, callback)`

Register an event handler.

```lua
chat:on("message", function(data)
    print(data.text)
end)
```

##### `socket:once(event, callback)`

Register a one-time event handler (removed after first call).

```lua
chat:once("welcome", function(data)
    print("Welcome message: " .. data.message)
end)
```

##### `socket:off(event, callback)`

Remove an event handler.

```lua
local handler = function(data) print(data) end
chat:on("message", handler)

-- Remove specific handler
chat:off("message", handler)

-- Remove all handlers for event
chat:off("message")
```

#### Emission

##### `socket:emit(event, data, ackCallback)`

Emit an event to the server.

```lua
-- Simple emit
chat:emit("message", { text = "Hello" })

-- With acknowledgment
chat:emit("save", { value = 100 }, function(response)
    if response.success then
        print("Saved with ID: " .. response.id)
    else
        print("Error: " .. response.error)
    end
end)
```

#### Rooms

##### `socket:joinRoom(room, ackCallback)`

Request to join a room.

```lua
chat:joinRoom("faction-survivors", function(response)
    if response.success then
        print("Joined room: " .. response.room)
    end
end)
```

##### `socket:leaveRoom(room)`

Leave a room.

```lua
chat:leaveRoom("faction-survivors")
```

##### `socket:getRooms()`

Get all rooms the client has joined.

```lua
local rooms = chat:getRooms()
for room, _ in pairs(rooms) do
    print("In room: " .. room)
end
```

##### `socket:inRoom(room)`

Check if in a specific room.

```lua
if chat:inRoom("global") then
    chat:emit("message", { room = "global", text = "Hi!" })
end
```

#### Built-in Events

| Event | Data | Description |
|-------|------|-------------|
| `connect` | - | Successfully connected and authenticated |
| `disconnect` | `reason` | Disconnected from namespace |
| `error` | `reason` | Connection or operation error |
| `joined` | `room` | Successfully joined a room |
| `left` | `room` | Left a room |
| `kicked` | `room`, `reason` | Kicked from a room |

---

### Server API

**File:** `server/KoniLib/SocketServer.lua`

#### Middleware

##### `socket:use(type, middleware)`

Add middleware for a specific hook point.

**Middleware Types:**

| Type | Signature | Purpose |
|------|-----------|---------|
| `connection` | `(player, auth, context, next, reject)` | Auth validation |
| `disconnect` | `(player, context, next)` | Cleanup hooks |
| `join` | `(player, room, context, next, reject)` | Room access control |
| `leave` | `(player, room, context, next)` | Leave hooks |
| `emit` | `(player, event, data, context, next, reject)` | Event validation |

**Examples:**

```lua
-- Authentication
chat:use("connection", function(player, auth, context, next, reject)
    if not validateToken(auth.token) then
        return reject("Invalid token")
    end
    next({ role = auth.role, verified = true })
end)

-- Room access control
chat:use("join", function(player, room, context, next, reject)
    if room:find("^admin-") and context.role ~= "admin" then
        return reject("Admin rooms require admin role")
    end
    next()
end)

-- Rate limiting
local lastMessage = {}
chat:use("emit", function(player, event, data, context, next, reject)
    if event == "message" then
        local username = player:getUsername()
        local now = os.time()
        if lastMessage[username] and now - lastMessage[username] < 1 then
            return reject("Rate limited")
        end
        lastMessage[username] = now
    end
    next()
end)
```

##### `socket:removeMiddleware(type, middleware)`

Remove a specific middleware.

```lua
chat:removeMiddleware("emit", rateLimitMiddleware)
```

#### Context Management

##### `socket:getContext(player)`

Get the context object for a connected player.

```lua
local ctx = chat:getContext(player)
print("Player role: " .. ctx.role)
```

##### `socket:setContext(player, key, value)` / `socket:setContext(player, table)`

Update player context.

```lua
-- Set single key
chat:setContext(player, "messageCount", 0)

-- Replace entire context
chat:setContext(player, { role = "moderator", verified = true })
```

#### Connection Management

##### `socket:getConnectedPlayers()`

Get all connected players with their contexts.

```lua
local players = chat:getConnectedPlayers()
for _, data in ipairs(players) do
    print(data.player:getUsername() .. " - Role: " .. data.context.role)
end
```

##### `socket:isConnected(player)`

Check if a player is connected to this namespace.

```lua
if chat:isConnected(player) then
    chat:emit("ping", {}, player)
end
```

##### `socket:disconnect(player, reason)`

Force disconnect a player.

```lua
chat:disconnect(player, "Banned for spam")
```

#### Room Management

##### `socket:join(player, room)`

Add a player to a room (server-initiated).

```lua
chat:join(player, "faction-" .. factionName)
```

##### `socket:leave(player, room)`

Remove a player from a room.

```lua
chat:leave(player, "faction-" .. oldFaction)
```

##### `socket:leaveAll(player)`

Remove a player from all rooms.

```lua
chat:leaveAll(player)
```

##### `socket:kick(player, room, reason)`

Kick a player from a room with a reason.

```lua
chat:kick(player, "admin-chat", "Inappropriate behavior")
```

##### `socket:getRooms(player)`

Get all rooms a player is in.

```lua
local rooms = chat:getRooms(player)
```

##### `socket:getPlayersInRoom(room)`

Get all players in a room.

```lua
local players = chat:getPlayersInRoom("global")
for _, p in ipairs(players) do
    print(p:getUsername())
end
```

##### `socket:getAllRooms()`

Get all active room names.

```lua
local rooms = chat:getAllRooms()
```

#### Events

##### `socket:on(event, callback)`

Register a server-side event handler.

**Callback Signature:** `function(player, data, context, ack)`

```lua
chat:on("message", function(player, data, context, ack)
    print(player:getUsername() .. " says: " .. data.text)
    
    -- Use context
    if context.isMuted then
        if ack then ack({ error = "You are muted" }) end
        return
    end
    
    -- Broadcast and acknowledge
    chat:to(data.room):emit("message", {
        from = player:getUsername(),
        text = data.text
    })
    
    if ack then
        ack({ success = true, messageId = generateId() })
    end
end)
```

##### `socket:once(event, callback)`

One-time event handler.

##### `socket:off(event, callback)`

Remove event handler(s).

#### Emission

##### `socket:emit(event, data, player)`

Emit to a specific player or all connected players.

```lua
-- To specific player
chat:emit("notification", { text = "Hello!" }, player)

-- To all connected (broadcast)
chat:emit("serverMessage", { text = "Server restarting in 5 minutes" })
```

##### `socket:to(room)`

Create an emitter targeting a specific room.

```lua
chat:to("global"):emit("message", { text = "Hello global!" })

-- Chain multiple rooms
chat:to("room1"):to("room2"):emit("alert", { text = "Alert!" })
```

##### `socket:in_(room)`

Alias for `socket:to(room)`.

##### `socket:broadcast(excludePlayer)`

Create an emitter that excludes a specific player.

```lua
-- Send to everyone except the sender
chat:broadcast(player):emit("userAction", {
    username = player:getUsername(),
    action = "jumped"
})
```

##### `socket:except(player)`

Alias for `socket:broadcast(player)`.

---

## Patterns & Examples

### 1. Authenticated Chat System

```lua
-- ============ SERVER ============
local chat = KoniLib.Socket.of("/chat")

-- Require faction membership
chat:use("connection", function(player, auth, context, next, reject)
    local faction = Faction.getPlayerFaction(player)
    if not faction then
        return reject("Must be in a faction to use chat")
    end
    next({
        faction = faction:getName(),
        isOwner = faction:isOwner(player:getUsername())
    })
end)

-- Auto-join rooms on connect
chat:on("connect", function(player, context)
    chat:join(player, "global")
    chat:join(player, "faction-" .. context.faction)
    
    if context.isOwner then
        chat:join(player, "faction-leaders")
    end
end)

-- Restrict leader chat
chat:use("join", function(player, room, context, next, reject)
    if room == "faction-leaders" and not context.isOwner then
        return reject("Leaders only")
    end
    next()
end)

-- Handle messages
chat:on("message", function(player, data, context, ack)
    chat:to(data.room):emit("message", {
        sender = player:getUsername(),
        faction = context.faction,
        text = data.text,
        isLeader = context.isOwner
    })
    if ack then ack({ sent = true }) end
end)

-- ============ CLIENT ============
local chat = KoniLib.Socket.of("/chat")

chat:on("connect", function()
    print("Connected to faction chat!")
end)

chat:on("error", function(reason)
    print("Chat error: " .. reason)
end)

chat:on("message", function(data)
    local prefix = data.isLeader and "★ " or ""
    print("[" .. data.faction .. "] " .. prefix .. data.sender .. ": " .. data.text)
end)

-- Send message
chat:emit("message", { room = "global", text = "Hello everyone!" })
```

### 2. Trading System with Acknowledgments

```lua
-- ============ SERVER ============
local trade = KoniLib.Socket.of("/trade")

trade:use("connection", function(player, auth, context, next, reject)
    next({ activeTrade = nil })
end)

trade:on("requestTrade", function(player, data, context, ack)
    local target = getPlayerByUsername(data.target)
    if not target then
        return ack({ error = "Player not found" })
    end
    
    local targetCtx = trade:getContext(target)
    if targetCtx and targetCtx.activeTrade then
        return ack({ error = "Player is busy" })
    end
    
    -- Send trade request to target
    trade:emit("tradeRequest", {
        from = player:getUsername()
    }, target)
    
    ack({ sent = true })
end)

trade:on("acceptTrade", function(player, data, context, ack)
    local requester = getPlayerByUsername(data.from)
    if not requester then
        return ack({ error = "Player left" })
    end
    
    -- Create trade room
    local roomId = "trade-" .. os.time()
    trade:join(player, roomId)
    trade:join(requester, roomId)
    
    -- Update contexts
    trade:setContext(player, "activeTrade", roomId)
    trade:setContext(requester, "activeTrade", roomId)
    
    -- Notify both
    trade:to(roomId):emit("tradeStarted", { room = roomId })
    
    ack({ success = true, room = roomId })
end)

-- ============ CLIENT ============
local trade = KoniLib.Socket.of("/trade")

trade:on("tradeRequest", function(data)
    -- Show UI to accept/decline
    showTradeRequestUI(data.from)
end)

trade:on("tradeStarted", function(data)
    openTradeWindow(data.room)
end)

-- Request a trade
function requestTrade(targetUsername)
    trade:emit("requestTrade", { target = targetUsername }, function(response)
        if response.error then
            print("Trade request failed: " .. response.error)
        else
            print("Trade request sent!")
        end
    end)
end
```

### 3. Admin Panel with Role-Based Access

```lua
-- ============ SERVER ============
local admin = KoniLib.Socket.of("/admin")

-- Strict authentication
admin:use("connection", function(player, auth, context, next, reject)
    local accessLevel = getAccessLevel(player:getUsername())
    if accessLevel == "none" then
        return reject("Admin access required")
    end
    next({
        accessLevel = accessLevel,
        permissions = getPermissionsForLevel(accessLevel)
    })
end)

-- Command authorization
admin:use("emit", function(player, event, data, context, next, reject)
    if event:find("^cmd:") then
        local cmd = event:gsub("^cmd:", "")
        if not context.permissions[cmd] then
            return reject("No permission for: " .. cmd)
        end
    end
    next()
end)

admin:on("cmd:kick", function(player, data, context, ack)
    local target = getPlayerByUsername(data.target)
    if target then
        kickPlayer(target, data.reason)
        
        -- Log to all admins
        admin:emit("log", {
            type = "kick",
            admin = player:getUsername(),
            target = data.target,
            reason = data.reason
        })
        
        ack({ success = true })
    else
        ack({ error = "Player not found" })
    end
end)

admin:on("cmd:broadcast", function(player, data, context, ack)
    -- Broadcast to all game players (using regular MP)
    KoniLib.MP.Send(nil, "GameNotification", "Announce", { 
        message = data.message 
    })
    ack({ success = true })
end)
```

### 4. Real-time Location Sharing

```lua
-- ============ SERVER ============
local location = KoniLib.Socket.of("/location")

location:on("connect", function(player, context)
    location:join(player, "tracking")
end)

location:on("updatePosition", function(player, data, context)
    -- Broadcast to everyone except sender
    location:broadcast(player):emit("playerMoved", {
        username = player:getUsername(),
        x = data.x,
        y = data.y,
        z = data.z
    })
end)

location:on("disconnect", function(player)
    location:broadcast(player):emit("playerLeft", {
        username = player:getUsername()
    })
end)

-- ============ CLIENT ============
local location = KoniLib.Socket.of("/location")

-- Track other players
local playerPositions = {}

location:on("playerMoved", function(data)
    playerPositions[data.username] = { x = data.x, y = data.y, z = data.z }
end)

location:on("playerLeft", function(data)
    playerPositions[data.username] = nil
end)

-- Send own position periodically
Events.OnTick.Add(function()
    local p = getPlayer()
    if p and location:isConnected() then
        location:emit("updatePosition", {
            x = p:getX(),
            y = p:getY(),
            z = p:getZ()
        })
    end
end)
```

---

## Singleplayer Support

The Socket system automatically handles singleplayer mode. When running in SP:

- Uses `SocketSP` class internally (loopback)
- Client emissions are immediately processed by server handlers
- No network packets are sent
- All functionality works identically

No code changes needed - just use `KoniLib.Socket.of()` normally.

---

## Best Practices

### 1. Always Handle Errors

```lua
chat:on("error", function(reason)
    print("Socket error: " .. reason)
    -- Show UI notification to user
end)
```

### 2. Use Acknowledgments for Important Actions

```lua
-- Don't just fire-and-forget important data
chat:emit("saveProgress", data, function(response)
    if response.error then
        -- Retry or notify user
    end
end)
```

### 3. Validate in Middleware, Not Handlers

```lua
-- Good: Middleware handles validation
chat:use("emit", function(player, event, data, context, next, reject)
    if event == "message" and #data.text > 500 then
        return reject("Message too long")
    end
    next()
end)

-- Handler can focus on logic
chat:on("message", function(player, data, context, ack)
    -- data.text is guaranteed to be <= 500 chars
    broadcast(data.text)
end)
```

### 4. Clean Up Contexts

```lua
chat:on("disconnect", function(player)
    -- Clean up any player-specific data
    cleanupPlayerData(player:getUsername())
end)
```

### 5. Use Rooms for Scoped Communication

```lua
-- Instead of checking manually
chat:on("factionMessage", function(player, data, context)
    -- Bad: Manual filtering
    for _, p in ipairs(getOnlinePlayers()) do
        if getFaction(p) == context.faction then
            chat:emit("message", data, p)
        end
    end
end)

-- Good: Use rooms
chat:on("connect", function(player, context)
    chat:join(player, "faction-" .. context.faction)
end)

chat:on("factionMessage", function(player, data, context)
    chat:to("faction-" .. context.faction):emit("message", data)
end)
```

---

## Troubleshooting

### "Namespace does not exist"
The server must create the namespace before clients can connect.

```lua
-- Server must run first
if isServer() then
    KoniLib.Socket.of("/chat")
end
```

### Middleware Not Running
Ensure middleware is registered before any connections.

```lua
local chat = KoniLib.Socket.of("/chat")
chat:use("connection", authMiddleware)  -- Register BEFORE players connect
```

### Events Not Firing
1. Check `isConnected()` before emitting
2. Verify event names match exactly (case-sensitive)
3. Check for errors in middleware that might reject

### Memory Leaks
Always clean up when destroying:

```lua
-- Remove event handlers when no longer needed
chat:off("message", myHandler)

-- Destroy namespace when done
KoniLib.Socket.destroy("/chat")
```
