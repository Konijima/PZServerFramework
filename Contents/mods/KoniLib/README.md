# KoniLib

Shared library for Project Zomboid mods, providing networking abstractions and utility functions.

## Features

### Multiplayer Abstraction (MP)

`KoniLib.MP` provides a unified interface for handling networking in Project Zomboid. It abstracts the differences between Singleplayer, Hosted Multiplayer, and Dedicated Servers.

#### Usage

Include `require "KoniLib/MP"` in your files (though it is loaded automatically if the mod is enabled).

**1. Registering a Command Handler**

Register a function to listen for a specific command. This works on both Client and Server.

```lua
-- server/MyLogic.lua OR client/MyUI.lua

-- @param player: In SP/Server->Client/Client->Server context, this is the player object related to the event.
-- @param args: Table containing the data sent.
KoniLib.MP.Register("MyModID", "MyCommandName", function(player, args)
    print("Received command from: " .. tostring(player and player:getUsername() or "Unknown"))
    print("Data: " .. tostring(args.someValue))
end)
```

**2. Sending a Command**

Send a command from Client to Server, Server to Client, or locally in Singleplayer.

```lua
-- client/MyClientKeybinds.lua

local args = { someValue = 123, status = "active" }

-- In Singleplayer: Executes the registered handler immediately.
-- In Multiplayer (Client): Sends 'sendClientCommand' to the server.
KoniLib.MP.Send(getPlayer(), "MyModID", "MyCommandName", args)
```

```lua
-- server/MyServerLogic.lua

local args = { message = "Hello from Server" }

-- Broadcast to ALL clients
KoniLib.MP.Send(nil, "MyModID", "ServerMessage", args)

-- Send to specific player
KoniLib.MP.Send(targetPlayerObj, "MyModID", "SecretMessage", args)
```

#### How it works

- **Singleplayer**: Bypasses the network stack entirely. `MP.Send` looks up the handler in `MP.Handlers` and executes it immediately.
- **Client**: Hooks into `Events.OnServerCommand` to receive data, and uses `sendClientCommand` to send data.
- **Server**: Hooks into `Events.OnClientCommand` to receive data, and uses `sendServerCommand` to send data.
