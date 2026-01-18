# KoniLib

**KoniLib** is a shared library mod that provides common utilities and abstractions for Project Zomboid mods.

## 📚 [Full Documentation](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Overview)

Visit the **[KoniLib Wiki](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Overview)** for complete documentation.

## Features

- **[MP System](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-MP-System)** - Unified client/server networking
- **[Socket API](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Socket-API)** - Socket.io-like networking with rooms and middleware
- **[Events System](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Events-System)** - Standardized lifecycle events
- **[Logging](https://github.com/Konijima/PZServerFramework/wiki/KoniLib-Logging)** - Per-module debug logging
- **Player Utilities** - Player lookup, name handling, access level checks

## Quick Start

```lua
-- Simple networking
KoniLib.MP.Register("MyMod", "Command", function(player, args)
    print("Received: " .. args.data)
end)

KoniLib.MP.Send(player, "MyMod", "Command", { data = "Hello" })

-- Safe initialization
KoniLib.Events.OnNetworkAvailable:Add(function(playerIndex)
    local player = getSpecificPlayer(playerIndex)
    KoniLib.MP.Send(player, "MyMod", "RequestSync", {})
end)
```

## Installation

Required by: ChatSystem, AreaSystem, ReactiveUI

Add to your `mod.info`:
```ini
require=KoniLib
```
