-- ChatSystem Typing Indicators Module
-- Handles typing indicator display, cleanup, and network communication
-- Returns a module table to be merged into ChatSystem.Client

require "ChatSystem/Definitions"

local Module = {}

-- ==========================================================
-- Configuration
-- ==========================================================

-- Typing indicator timeout (5 seconds) - indicators not refreshed within this time are cleared
local TYPING_INDICATOR_TIMEOUT = 5000

-- Throttle for typing indicator cleanup (check every ~1 second using tick count)
local typingCleanupTickCounter = 0
local TYPING_CLEANUP_INTERVAL = 60  -- Every 60 ticks (~1 second at 60 TPS)

-- ==========================================================
-- Typing Indicator Handlers
-- ==========================================================

--- Handle received typing indicator
---@param data table { username, channel, isTyping, target, displayName? }
function Module.OnTypingReceived(data)
    local Client = ChatSystem.Client
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local username = data.username
    local isTyping = data.isTyping
    local target = data.target  -- For PM typing
    local displayName = data.displayName or username  -- From server (character name if roleplay)
    
    -- For PM typing, use the username as the key (who is typing to us)
    local trackingKey = channel
    if channel == ChatSystem.ChannelType.PRIVATE then
        trackingKey = "pm:" .. username
    end
    
    if not Client.typingPlayers[trackingKey] then
        Client.typingPlayers[trackingKey] = {}
    end
    
    if isTyping then
        -- Store timestamp and displayName to allow timeout-based cleanup
        Client.typingPlayers[trackingKey][username] = { 
            timestamp = getTimestampMs(),
            displayName = displayName
        }
    else
        Client.typingPlayers[trackingKey][username] = nil
    end
    
    -- Trigger event for UI update
    -- For PM, pass the username who is typing so UI can update the right conversation
    ChatSystem.Events.OnTypingChanged:Trigger(channel, Module.GetTypingUsers(trackingKey), username)
end

--- Get list of users typing in a channel
---@param channel string
---@return table Array of display names
function Module.GetTypingUsers(channel)
    local Client = ChatSystem.Client
    local users = {}
    if Client.typingPlayers[channel] then
        for username, data in pairs(Client.typingPlayers[channel]) do
            -- Use displayName from server (character name if roleplay mode, username otherwise)
            local name = username
            if type(data) == "table" and data.displayName then
                name = data.displayName
            end
            table.insert(users, name)
        end
    end
    return users
end

--- Clear typing indicator for a specific player (used when player dies/quits/goes out of range)
---@param username string
function Module.ClearTypingIndicator(username)
    local Client = ChatSystem.Client
    if not username then return end
    
    for channel, players in pairs(Client.typingPlayers) do
        if players[username] then
            players[username] = nil
            -- Trigger UI update for this channel
            ChatSystem.Events.OnTypingChanged:Trigger(channel, Module.GetTypingUsers(channel), username)
        end
    end
end

--- Cleanup stale typing indicators (called periodically)
--- Removes typing indicators that haven't been refreshed within the timeout
function Module.CleanupTypingIndicators()
    local Client = ChatSystem.Client
    local now = getTimestampMs()
    
    for channel, players in pairs(Client.typingPlayers) do
        for username, data in pairs(players) do
            -- Get timestamp from data (new format: table with timestamp and characterName)
            local timestamp = type(data) == "table" and data.timestamp or data
            if type(timestamp) == "number" then
                if now - timestamp > TYPING_INDICATOR_TIMEOUT then
                    players[username] = nil
                    ChatSystem.Events.OnTypingChanged:Trigger(channel, Module.GetTypingUsers(channel), username)
                end
            elseif timestamp == true then
                -- Legacy format (boolean) - can't timeout, but will be cleaned up by quit/death events
            end
        end
    end
end

--- Send typing start indicator
---@param channel string|nil Channel to type in (defaults to current channel or active conversation)
---@param target string|nil Optional target for PM typing
function Module.StartTyping(channel, target)
    local Client = ChatSystem.Client
    if not Client.isConnected then return end
    
    -- Default to active conversation (PM) or current channel
    if not channel then
        if Client.activeConversation then
            channel = ChatSystem.ChannelType.PRIVATE
            target = Client.activeConversation
        else
            channel = Client.currentChannel
        end
    end
    
    local now = getTimestampMs()
    
    -- Only send if not already typing in this channel, or if it's been a while
    if not Client.isTyping or Client.typingChannel ~= channel or Client.typingTarget ~= target or (now - Client.lastTypingTime > 3000) then
        Client.isTyping = true
        Client.typingChannel = channel
        Client.typingTarget = target
        Client.lastTypingTime = now
        
        Client.socket:emit("typing", { channel = channel, target = target, isTyping = true })
    end
end

--- Send typing stop indicator
function Module.StopTyping()
    local Client = ChatSystem.Client
    if not Client.isConnected then return end
    
    if Client.isTyping and Client.typingChannel then
        Client.socket:emit("typing", { channel = Client.typingChannel, target = Client.typingTarget, isTyping = false })
        Client.isTyping = false
        Client.typingChannel = nil
        Client.typingTarget = nil
    end
end

-- ==========================================================
-- Initialization
-- ==========================================================

--- Initialize typing indicators module
function Module.Init()
    Events.OnTick.Add(function()
        typingCleanupTickCounter = typingCleanupTickCounter + 1
        if typingCleanupTickCounter >= TYPING_CLEANUP_INTERVAL then
            typingCleanupTickCounter = 0
            Module.CleanupTypingIndicators()
        end
    end)
    print("[ChatSystem] TypingIndicators module initialized")
end

print("[ChatSystem] TypingIndicators module loaded")

return Module
