# ChatSystem

**ChatSystem** is a custom chat implementation for Project Zomboid that replaces the vanilla chat with a modern, Socket.io-based system.

## Features

- **Custom UI**: Clean, modern chat interface that replaces the vanilla chat
- **Multiple Channels**: Local, Global, Faction, Safehouse, Private Messages, Admin, and Radio
- **Socket-based Networking**: Built on KoniLib's Socket.io-like API
- **Proximity Chat**: Local chat respects distance between players
- **Channel Colors**: Each channel has a distinct color for easy identification
- **Command Shortcuts**: Use familiar commands like `/g`, `/l`, `/pm`, etc.
- **Message History**: Use Up/Down arrows to cycle through previous messages
- **Yell Support**: Type in ALL CAPS or prefix with `!` to yell (increased range)

## Requirements

- **KoniLib** - Core networking library

## Installation

1. Ensure `KoniLib` is installed
2. Add `ChatSystem` to your server's mod list
3. Make sure `mod.info` has `require=\KoniLib`

## Channel Types

| Channel | Command | Description |
|---------|---------|-------------|
| Local | `/l`, `/s`, `/say` | Proximity-based chat (30 tiles) |
| Global | `/g`, `/all` | Server-wide messages |
| Faction | `/f`, `/faction` | Faction members only |
| Safehouse | `/sh`, `/safehouse` | Safehouse members only |
| Private | `/pm`, `/w`, `/msg` | Direct message to player |
| Admin | `/a`, `/admin` | Admin-only channel |
| Radio | `/r`, `/radio` | Radio frequency chat |

## Usage

### Sending Messages

```
/g Hello everyone!          -- Global message
/l Hey neighbor             -- Local message
/pm Username Hello there    -- Private message to Username
/f Faction meeting at base  -- Faction message
!HELP ME!                   -- Yell (increased range)
```

### Keyboard Shortcuts

- **Enter**: Open chat / Send message
- **Escape**: Close chat
- **Tab**: Cycle through channels
- **Up/Down**: Browse message history

### UI Controls

- **Channel Button**: Click to select a channel
- **Gear Button**: Access settings (timestamps, font size, clear chat)

## Configuration

Edit `ChatSystem/Definitions.lua` to customize:

```lua
ChatSystem.Settings = {
    maxMessageLength = 500,  -- Max characters per message
    maxMessagesStored = 200, -- Messages kept in history
    localChatRange = 30,     -- Local chat range in tiles
    yellRange = 60,          -- Yell range in tiles
}
```

## API Usage

### Client-side

```lua
-- Send a message
ChatSystem.Client.SendMessage("/g Hello World!")

-- Change channel
ChatSystem.Client.SetChannel(ChatSystem.ChannelType.GLOBAL)

-- Listen for messages
ChatSystem.Events.OnMessageReceived:Add(function(message)
    print("New message from: " .. message.author)
end)
```

### Server-side

```lua
-- The server uses KoniLib.Socket
local chatSocket = KoniLib.Socket.of("/chat")

-- Send system message to a player
local sysMsg = ChatSystem.CreateSystemMessage("Welcome!")
chatSocket:to(player):emit("message", sysMsg)

-- Broadcast to all
chatSocket:broadcast():emit("message", msg)
```

## Command API

ChatSystem includes a powerful Command API for creating custom chat commands.

### Registering Commands

```lua
-- Register a simple player command
ChatSystem.Commands.Register({
    name = "ping",
    description = "Check server latency",
    accessLevel = ChatSystem.Commands.AccessLevel.PLAYER,
    category = "general",
    handler = function(context)
        ChatSystem.Commands.Server.ReplySuccess(context.player, "Pong!")
    end
})

-- Register an admin command with arguments
ChatSystem.Commands.Register({
    name = "settime",
    aliases = { "time" },
    description = "Set the game time",
    usage = "<hour>",
    accessLevel = ChatSystem.Commands.AccessLevel.ADMIN,
    category = "admin",
    args = {
        { name = "hour", type = ChatSystem.Commands.ArgType.INTEGER, required = true }
    },
    handler = function(context)
        local hour = context.args.hour
        -- Set time logic here
        ChatSystem.Commands.Server.ReplySuccess(context.player, "Time set to " .. hour .. ":00")
    end
})
```

### Access Levels

| Level | Description |
|-------|-------------|
| `PLAYER` | Any player can use |
| `MODERATOR` | Moderators and above |
| `ADMIN` | Server admins |
| `OWNER` | Server owner only |

### Argument Types

| Type | Description |
|------|-------------|
| `STRING` | Any text |
| `NUMBER` | Decimal number |
| `INTEGER` | Whole number |
| `BOOLEAN` | true/false, yes/no, 1/0 |
| `PLAYER` | Online player name |
| `COORDINATE` | x,y,z coordinates |

### Command Context

The handler receives a context object with:

```lua
context = {
    player = IsoPlayer,      -- The player who executed the command
    username = string,       -- Player's username
    accessLevel = string,    -- Player's access level
    args = table,            -- Validated arguments by name
    rawArgs = string,        -- Raw argument string
    argList = table,         -- Arguments as array
    command = table,         -- The command definition
}
```

### Response Helpers

```lua
-- Send success message (green)
ChatSystem.Commands.Server.ReplySuccess(player, "Done!")

-- Send error message (red)
ChatSystem.Commands.Server.ReplyError(player, "Something went wrong")

-- Send neutral message
ChatSystem.Commands.Server.Reply(player, "Info message")

-- Broadcast to all players
ChatSystem.Commands.Server.Broadcast("Server message")

-- Find player by name (partial match supported)
local target, err = ChatSystem.Commands.Server.FindPlayer("john")
```

### Built-in Commands

| Command | Access | Description |
|---------|--------|-------------|
| `/help [cmd]` | Player | Show commands or command help |
| `/online` | Player | List online players |
| `/roll [dice]` | Player | Roll dice (e.g., /roll 2d6) |
| `/me <action>` | Player | Roleplay action |
| `/kick <player> [reason]` | Moderator | Kick a player |
| `/announce <msg>` | Admin | Server announcement |
| `/tp <player\|x,y,z>` | Admin | Teleport |
| `/bring <player>` | Admin | Teleport player to you |
| `/god` | Admin | Toggle god mode |
| `/invisible` | Admin | Toggle invisibility |
| `/servermsg <msg>` | Owner | System message |
| `/save` | Owner | Save the world |

## Events

- `ChatSystem.Events.OnMessageReceived` - Fired when a message is received
- `ChatSystem.Events.OnChannelChanged` - Fired when the active channel changes
- `ChatSystem.Commands.Events.OnCommandExecuted` - Fired when a command is executed
- `ChatSystem.Commands.Events.OnCommandFailed` - Fired when a command fails

## Customization

### Adding Custom Channels

1. Add to `ChatSystem.ChannelType` in `Definitions.lua`
2. Add color to `ChatSystem.ChannelColors`
3. Add display name to `ChatSystem.ChannelNames`
4. Add commands to `ChatSystem.ChannelCommands`
5. Handle the channel in `Server.lua`

### Custom Message Colors

```lua
local msg = ChatSystem.CreateMessage(channel, author, text)
msg.color = { r = 1, g = 0.5, b = 0 } -- Orange
```

## License

MIT License - Feel free to use and modify.
