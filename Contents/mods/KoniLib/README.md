# KoniLib

**KoniLib** is a shared library mod designed to provide common utilities and abstractions for Project Zomboid mods in this suite. It serves as a strict dependency for mods like **AreaSystem**.

## Features

### 1. Multiplayer (MP) Abstraction
The `KoniLib.MP` module unifies networking logic, allowing developers to write code that works seamlessly across:
- **Singleplayer** (Local Loopback)
- **Hosted Multiplayer** (Listen/Host)
- **Dedicated Servers** (Client/Server)

It removes the need to manually check `isClient()` or `isServer()` for every action.

### 2. Event System Abstraction
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
