# KoniLib

**KoniLib** is a shared library mod designed to provide common utilities and abstractions for Project Zomboid mods in this suite. It serves as a strict dependency for mods like **AreaSystem**.

## Features

### 1. Multiplayer (MP) Abstraction
The `KoniLib.MP` module unifies networking logic, allowing developers to write code that works seamlessly across:
- **Singleplayer** (Local Loopback)
- **Hosted Multiplayer** (Listen/Host)
- **Dedicated Servers** (Client/Server)

It removes the need to manually check `isClient()` or `isServer()` for every action.

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
