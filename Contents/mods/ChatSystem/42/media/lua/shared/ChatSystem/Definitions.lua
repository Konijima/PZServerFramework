ChatSystem = ChatSystem or {}

-- Chat Channel Types
ChatSystem.ChannelType = {
    LOCAL = "local",       -- Proximity-based chat
    GLOBAL = "global",     -- Server-wide chat
    FACTION = "faction",   -- Faction members only
    SAFEHOUSE = "safehouse", -- Safehouse members only
    PRIVATE = "private",   -- Direct messages
    STAFF = "staff",       -- Staff chat (mods, admins, etc.)
    ADMIN = "admin",       -- Admin-only chat
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
    [ChatSystem.ChannelType.PRIVATE] = { r = 1, g = 0.5, b = 1 },   -- Pink (for PM conversations)
    [ChatSystem.ChannelType.STAFF] = { r = 1, g = 0.8, b = 0.2 },   -- Gold/Yellow
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
    [ChatSystem.ChannelType.STAFF] = "Staff",
    [ChatSystem.ChannelType.ADMIN] = "Admin",
    [ChatSystem.ChannelType.RADIO] = "Radio",
}

-- Channel commands/shortcuts (PM removed - handled via conversation tabs)
ChatSystem.ChannelCommands = {
    [ChatSystem.ChannelType.LOCAL] = { "/local ", "/l ", "/say ", "/s " },
    [ChatSystem.ChannelType.GLOBAL] = { "/global ", "/g ", "/all " },
    [ChatSystem.ChannelType.FACTION] = { "/faction ", "/f " },
    [ChatSystem.ChannelType.SAFEHOUSE] = { "/safehouse ", "/sh " },
    [ChatSystem.ChannelType.STAFF] = { "/staff ", "/st " },
    [ChatSystem.ChannelType.ADMIN] = { "/admin ", "/a " },
    [ChatSystem.ChannelType.RADIO] = { "/radio ", "/r " },
}

-- Events
ChatSystem.Events = {}
if KoniLib and KoniLib.Event then
    ChatSystem.Events.OnMessageReceived = KoniLib.Event.new("ChatSystem_OnMessageReceived")
    ChatSystem.Events.OnChannelChanged = KoniLib.Event.new("ChatSystem_OnChannelChanged")
    ChatSystem.Events.OnTypingChanged = KoniLib.Event.new("ChatSystem_OnTypingChanged")
    ChatSystem.Events.OnSettingsChanged = KoniLib.Event.new("ChatSystem_OnSettingsChanged")
else
    print("[ChatSystem] Error: KoniLib.Event not found!")
end

-- Settings (defaults, will be overridden by sandbox options)
ChatSystem.Settings = {
    maxMessageLength = 500,
    maxMessagesStored = 200,
    localChatRange = 30, -- tiles
    yellRange = 60,      -- tiles for yelling
    
    -- Channel toggles
    enableGlobalChat = true,
    enableFactionChat = true,
    enableSafehouseChat = true,
    enableStaffChat = true,
    enableAdminChat = true,
    enablePrivateMessages = true,
    
    -- Moderation
    chatSlowMode = 0, -- seconds between messages (0 = disabled)
    
    -- Roleplay
    roleplayMode = false, -- Use character firstname lastname instead of username
}

-- Cache of last loaded sandbox values for change detection
ChatSystem._lastSandboxValues = nil

--- Deep copy a table for comparison
local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

--- Check if two values are equal (handles tables)
local function valuesEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not valuesEqual(v, b[k]) then return false end
    end
    for k, v in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- Load settings from sandbox options (call after game starts)
--- @param silent boolean? If true, don't print messages
--- @return boolean changed Whether settings actually changed
function ChatSystem.LoadSandboxSettings(silent)
    if not SandboxVars or not SandboxVars.ChatSystem then
        if not silent then
            print("[ChatSystem] SandboxVars.ChatSystem not available, using defaults")
        end
        return false
    end
    
    local sv = SandboxVars.ChatSystem
    
    -- Capture previous settings for comparison
    local prevSettings = deepCopy(ChatSystem.Settings)
    
    -- General
    if sv.MaxMessageLength then ChatSystem.Settings.maxMessageLength = sv.MaxMessageLength end
    if sv.MaxMessagesStored then ChatSystem.Settings.maxMessagesStored = sv.MaxMessagesStored end
    
    -- Range
    if sv.LocalChatRange then ChatSystem.Settings.localChatRange = sv.LocalChatRange end
    if sv.YellRange then ChatSystem.Settings.yellRange = sv.YellRange end
    
    -- Channel toggles
    if sv.EnableGlobalChat ~= nil then ChatSystem.Settings.enableGlobalChat = sv.EnableGlobalChat end
    if sv.EnableFactionChat ~= nil then ChatSystem.Settings.enableFactionChat = sv.EnableFactionChat end
    if sv.EnableSafehouseChat ~= nil then ChatSystem.Settings.enableSafehouseChat = sv.EnableSafehouseChat end
    if sv.EnableStaffChat ~= nil then ChatSystem.Settings.enableStaffChat = sv.EnableStaffChat end
    if sv.EnableAdminChat ~= nil then ChatSystem.Settings.enableAdminChat = sv.EnableAdminChat end
    if sv.EnablePrivateMessages ~= nil then ChatSystem.Settings.enablePrivateMessages = sv.EnablePrivateMessages end
    
    -- Moderation
    if sv.ChatSlowMode then ChatSystem.Settings.chatSlowMode = sv.ChatSlowMode end
    
    -- Roleplay
    if sv.RoleplayMode ~= nil then ChatSystem.Settings.roleplayMode = sv.RoleplayMode end
    
    -- Check if settings changed
    local changed = not valuesEqual(prevSettings, ChatSystem.Settings)
    
    if not silent then
        print("[ChatSystem] Sandbox settings loaded:")
        print("  - Max message length: " .. ChatSystem.Settings.maxMessageLength)
        print("  - Local chat range: " .. ChatSystem.Settings.localChatRange)
        print("  - Yell range: " .. ChatSystem.Settings.yellRange)
        print("  - Global chat: " .. tostring(ChatSystem.Settings.enableGlobalChat))
        print("  - Private messages: " .. tostring(ChatSystem.Settings.enablePrivateMessages))
    end
    
    -- Trigger event if settings changed
    if changed and ChatSystem.Events and ChatSystem.Events.OnSettingsChanged then
        print("[ChatSystem] Settings changed, triggering OnSettingsChanged event")
        ChatSystem.Events.OnSettingsChanged:Trigger(ChatSystem.Settings)
    end
    
    return changed
end

--- Apply settings received from server (client-side)
---@param settings table The settings table from server
function ChatSystem.ApplySettings(settings)
    if not settings then return end
    
    local prevSettings = deepCopy(ChatSystem.Settings)
    
    -- Apply all settings from server
    for key, value in pairs(settings) do
        ChatSystem.Settings[key] = value
    end
    
    -- Check if settings changed
    local changed = not valuesEqual(prevSettings, ChatSystem.Settings)
    
    if changed then
        print("[ChatSystem] Applied settings from server")
        if ChatSystem.Events and ChatSystem.Events.OnSettingsChanged then
            ChatSystem.Events.OnSettingsChanged:Trigger(ChatSystem.Settings)
        end
    end
end

-- Settings sync timer for live updates
local settingsCheckTimer = 0
local SETTINGS_CHECK_INTERVAL = 60 -- Check every ~1 second

-- Periodic check for sandbox settings changes (vanilla game syncs SandboxVars automatically)
local function OnTick()
    settingsCheckTimer = settingsCheckTimer + 1
    
    if settingsCheckTimer >= SETTINGS_CHECK_INTERVAL then
        settingsCheckTimer = 0
        
        -- Re-load sandbox settings (will return true if changed and trigger event)
        ChatSystem.LoadSandboxSettings(true) -- silent mode
    end
end

-- Load sandbox settings when the game starts
Events.OnGameStart.Add(function()
    ChatSystem.LoadSandboxSettings()
    -- Start periodic checking after initial load
    Events.OnTick.Add(OnTick)
end)

print("[ChatSystem] Shared Definitions Loaded")
