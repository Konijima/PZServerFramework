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

## Events

- `ChatSystem.Events.OnMessageReceived` - Fired when a message is received
- `ChatSystem.Events.OnChannelChanged` - Fired when the active channel changes

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
