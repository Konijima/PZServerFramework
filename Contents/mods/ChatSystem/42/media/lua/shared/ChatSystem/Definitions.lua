ChatSystem = ChatSystem or {}

-- Chat Channel Types
ChatSystem.ChannelType = {
    LOCAL = "local",       -- Proximity-based chat
    GLOBAL = "global",     -- Server-wide chat
    FACTION = "faction",   -- Faction members only
    SAFEHOUSE = "safehouse", -- Safehouse members only
    PRIVATE = "private",   -- Direct messages
    ADMIN = "admin",       -- Admin chat
    RADIO = "radio",       -- Radio frequency chat
}

-- Message structure
---@class ChatMessage
---@field id string Unique message ID
---@field channel string Channel type
---@field author string Username of sender
---@field text string Message content
---@field timestamp number Server timestamp
---@field color table? Optional custom color {r, g, b}
---@field isSystem boolean? Is system message
---@field metadata table? Extra data (e.g., radio frequency, faction name)

--- Create a new chat message
---@param channel string
---@param author string
---@param text string
---@param metadata table?
---@return ChatMessage
function ChatSystem.CreateMessage(channel, author, text, metadata)
    return {
        id = tostring(getRandomUUID()),
        channel = channel or ChatSystem.ChannelType.LOCAL,
        author = author or "System",
        text = text or "",
        timestamp = getTimestampMs(),
        color = nil,
        isSystem = false,
        metadata = metadata or {}
    }
end

--- Create a system message
---@param text string
---@param channel string?
---@return ChatMessage
function ChatSystem.CreateSystemMessage(text, channel)
    local msg = ChatSystem.CreateMessage(channel or ChatSystem.ChannelType.GLOBAL, "System", text)
    msg.isSystem = true
    msg.color = { r = 1, g = 0.8, b = 0.2 } -- Yellow for system messages
    return msg
end

-- Default channel colors
ChatSystem.ChannelColors = {
    [ChatSystem.ChannelType.LOCAL] = { r = 1, g = 1, b = 1 },       -- White
    [ChatSystem.ChannelType.GLOBAL] = { r = 0.6, g = 0.9, b = 1 },  -- Light blue
    [ChatSystem.ChannelType.FACTION] = { r = 0.2, g = 1, b = 0.2 }, -- Green
    [ChatSystem.ChannelType.SAFEHOUSE] = { r = 1, g = 0.6, b = 0.2 }, -- Orange
    [ChatSystem.ChannelType.PRIVATE] = { r = 1, g = 0.5, b = 1 },   -- Pink
    [ChatSystem.ChannelType.ADMIN] = { r = 1, g = 0.2, b = 0.2 },   -- Red
    [ChatSystem.ChannelType.RADIO] = { r = 0.5, g = 1, b = 0.5 },   -- Light green
}

-- Channel display names
ChatSystem.ChannelNames = {
    [ChatSystem.ChannelType.LOCAL] = "Local",
    [ChatSystem.ChannelType.GLOBAL] = "Global",
    [ChatSystem.ChannelType.FACTION] = "Faction",
    [ChatSystem.ChannelType.SAFEHOUSE] = "Safehouse",
    [ChatSystem.ChannelType.PRIVATE] = "PM",
    [ChatSystem.ChannelType.ADMIN] = "Admin",
    [ChatSystem.ChannelType.RADIO] = "Radio",
}

-- Channel commands/shortcuts
ChatSystem.ChannelCommands = {
    [ChatSystem.ChannelType.LOCAL] = { "/local ", "/l ", "/say ", "/s " },
    [ChatSystem.ChannelType.GLOBAL] = { "/global ", "/g ", "/all " },
    [ChatSystem.ChannelType.FACTION] = { "/faction ", "/f " },
    [ChatSystem.ChannelType.SAFEHOUSE] = { "/safehouse ", "/sh " },
    [ChatSystem.ChannelType.PRIVATE] = { "/pm ", "/whisper ", "/w ", "/msg " },
    [ChatSystem.ChannelType.ADMIN] = { "/admin ", "/a " },
    [ChatSystem.ChannelType.RADIO] = { "/radio ", "/r " },
}

-- Events
ChatSystem.Events = {}
if KoniLib and KoniLib.Event then
    ChatSystem.Events.OnMessageReceived = KoniLib.Event.new("ChatSystem_OnMessageReceived")
    ChatSystem.Events.OnChannelChanged = KoniLib.Event.new("ChatSystem_OnChannelChanged")
    ChatSystem.Events.OnTypingChanged = KoniLib.Event.new("ChatSystem_OnTypingChanged")
else
    print("[ChatSystem] Error: KoniLib.Event not found!")
end

-- Settings
ChatSystem.Settings = {
    maxMessageLength = 500,
    maxMessagesStored = 200,
    localChatRange = 30, -- tiles
    yellRange = 60,      -- tiles for yelling
}

print("[ChatSystem] Shared Definitions Loaded")
