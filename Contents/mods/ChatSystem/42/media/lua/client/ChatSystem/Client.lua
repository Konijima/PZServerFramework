if isServer() then return end
require "ChatSystem/Definitions"
local Socket = require("KoniLib/Socket")

ChatSystem.Client = {}
local Client = ChatSystem.Client

-- Client state
Client.socket = nil
Client.messages = {}       -- All messages
Client.currentChannel = ChatSystem.ChannelType.LOCAL
Client.onlinePlayers = {}
Client.isConnected = false
Client.typingPlayers = {}  -- { [channel] = { [username] = true } }
Client.isTyping = false
Client.typingChannel = nil
Client.typingTarget = nil  -- Target for PM typing
Client.lastTypingTime = 0

-- Private conversation state
Client.conversations = {}  -- { [username] = { messages = {}, unread = 0 } }
Client.activeConversation = nil  -- Username of active PM conversation (nil = normal channel)

-- ==========================================================
-- Socket Connection
-- ==========================================================

function Client.Connect()
    if Client.isConnected then return end
    
    Client.socket = Socket.of("/chat")
    
    -- Check if already connected (can happen in SP if server code loaded first)
    if Client.socket.connected or Client.socket:isConnected() then
        Client.isConnected = true
        print("[ChatSystem] Client: Already connected to chat server")
    end
    
    -- Connection events
    Client.socket:on("connect", function()
        Client.isConnected = true
        print("[ChatSystem] Client: Connected to chat server")
        
        -- Request online players list
        Client.socket:emit("getPlayers", {}, function(response)
            if response and response.players then
                Client.onlinePlayers = response.players
            end
        end)
    end)
    
    Client.socket:on("disconnect", function()
        Client.isConnected = false
        print("[ChatSystem] Client: Disconnected from chat server")
    end)
    
    Client.socket:on("error", function(error)
        print("[ChatSystem] Client: Error - " .. tostring(error))
    end)
    
    -- Message handler
    Client.socket:on("message", function(message)
        Client.OnMessageReceived(message)
    end)
    
    -- Typing indicator handler
    Client.socket:on("typing", function(data)
        Client.OnTypingReceived(data)
    end)
end

-- ==========================================================
-- Typing Indicators
-- ==========================================================

--- Handle received typing indicator
---@param data table { username, channel, isTyping, target }
function Client.OnTypingReceived(data)
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local username = data.username
    local isTyping = data.isTyping
    local target = data.target  -- For PM typing
    
    if not Client.typingPlayers[channel] then
        Client.typingPlayers[channel] = {}
    end
    
    if isTyping then
        Client.typingPlayers[channel][username] = true
    else
        Client.typingPlayers[channel][username] = nil
    end
    
    -- Trigger event for UI update with target info
    ChatSystem.Events.OnTypingChanged:Trigger(channel, Client.GetTypingUsers(channel), target)
end

--- Get list of users typing in a channel
---@param channel string
---@return table Array of usernames
function Client.GetTypingUsers(channel)
    local users = {}
    if Client.typingPlayers[channel] then
        for username, _ in pairs(Client.typingPlayers[channel]) do
            table.insert(users, username)
        end
    end
    return users
end

--- Send typing start indicator
---@param channel string
---@param target string|nil Optional target for PM typing
function Client.StartTyping(channel, target)
    if not Client.isConnected then return end
    
    local now = getTimestampMs()
    
    -- Only send if not already typing in this channel, or if it's been a while
    if not Client.isTyping or Client.typingChannel ~= channel or Client.typingTarget ~= target or (now - Client.lastTypingTime > 3000) then
        Client.isTyping = true
        Client.typingChannel = channel
        Client.typingTarget = target
        Client.lastTypingTime = now
        
        Client.socket:emit("typingStart", { channel = channel, target = target })
    end
end

--- Send typing stop indicator
function Client.StopTyping()
    if not Client.isConnected then return end
    
    if Client.isTyping and Client.typingChannel then
        Client.socket:emit("typingStop", { channel = Client.typingChannel, target = Client.typingTarget })
        Client.isTyping = false
        Client.typingChannel = nil
        Client.typingTarget = nil
    end
end

-- ==========================================================
-- Message Handling
-- ==========================================================

---@param message ChatMessage
function Client.OnMessageReceived(message)
    print("[ChatSystem] Client: Received message from " .. tostring(message.author) .. " - " .. tostring(message.text))
    
    -- Handle private messages differently
    if message.channel == ChatSystem.ChannelType.PRIVATE then
        local otherUser = nil
        local myUsername = getPlayer() and getPlayer():getUsername() or ""
        
        -- Determine who the conversation is with
        if message.metadata and message.metadata.from then
            otherUser = message.metadata.from
        elseif message.metadata and message.metadata.to then
            otherUser = message.metadata.to
        elseif message.author ~= myUsername then
            otherUser = message.author
        end
        
        if otherUser then
            -- Create conversation if it doesn't exist
            if not Client.conversations[otherUser] then
                Client.conversations[otherUser] = { messages = {}, unread = 0 }
            end
            
            -- Add message to conversation
            table.insert(Client.conversations[otherUser].messages, message)
            
            -- Trim old messages
            while #Client.conversations[otherUser].messages > ChatSystem.Settings.maxMessagesStored do
                table.remove(Client.conversations[otherUser].messages, 1)
            end
            
            -- Increment unread if not the active conversation
            if Client.activeConversation ~= otherUser then
                Client.conversations[otherUser].unread = (Client.conversations[otherUser].unread or 0) + 1
            end
            
            -- Play sound for PM
            getSoundManager():PlaySound("UISelectSmall", false, 0.5)
        end
    else
        -- Regular channel message - add to message history
        table.insert(Client.messages, message)
        
        -- Trim old messages
        while #Client.messages > ChatSystem.Settings.maxMessagesStored do
            table.remove(Client.messages, 1)
        end
    end
    
    -- Trigger event for UI update
    ChatSystem.Events.OnMessageReceived:Trigger(message)
    
    -- Show overhead text for local chat
    if message.channel == ChatSystem.ChannelType.LOCAL and not message.isSystem then
        local player = getPlayer()
        if player and message.author == player:getUsername() then
            -- Show text above the player's head
            if message.metadata and message.metadata.isYell then
                -- Use Yell for red overhead text
                player:Yell(message.text)
            else
                -- Use Say for normal overhead text
                player:Say(message.text)
            end
        end
    end
end

-- ==========================================================
-- Sending Messages
-- ==========================================================

--- Parse input text for commands and extract channel/target
---@param inputText string
---@return string channel
---@return string text
---@return table metadata
function Client.ParseInput(inputText)
    local channel = Client.currentChannel
    local text = inputText
    local metadata = {}
    
    -- Check for command prefixes
    for channelType, commands in pairs(ChatSystem.ChannelCommands) do
        for _, cmd in ipairs(commands) do
            if luautils.stringStarts(inputText:lower(), cmd:lower()) then
                channel = channelType
                text = inputText:sub(#cmd + 1)
                break
            end
        end
    end
    
    return channel, text, metadata
end

--- Detect if input starts with a channel prefix and return the channel + remaining text
---@param inputText string
---@return string|nil channel (nil if no prefix found)
---@return string text (remaining text after prefix)
function Client.DetectChannelPrefix(inputText)
    for channelType, commands in pairs(ChatSystem.ChannelCommands) do
        for _, cmd in ipairs(commands) do
            if luautils.stringStarts(inputText:lower(), cmd:lower()) then
                local text = inputText:sub(#cmd + 1)
                -- Trim leading space
                if text:sub(1, 1) == " " then
                    text = text:sub(2)
                end
                return channelType, text
            end
        end
    end
    return nil, inputText
end

--- Send a message directly using the current channel (no prefix parsing)
---@param text string The message text (already cleaned)
function Client.SendMessageDirect(text)
    if not Client.isConnected then
        print("[ChatSystem] Client: Not connected to chat server")
        return
    end
    
    if not text or text == "" then return end
    
    local channel = Client.currentChannel
    local metadata = {}
    
    -- Handle private message conversation
    if Client.activeConversation then
        channel = ChatSystem.ChannelType.PRIVATE
        metadata.target = Client.activeConversation
    end
    
    -- Check for yell (uppercase or ! prefix)
    if channel == ChatSystem.ChannelType.LOCAL then
        if text == text:upper() and #text > 3 then
            metadata.isYell = true
        elseif luautils.stringStarts(text, "!") then
            metadata.isYell = true
            text = text:sub(2)
        end
    end
    
    -- Send via socket
    print("[ChatSystem] Client: Sending message - channel: " .. tostring(channel) .. ", text: " .. tostring(text))
    Client.socket:emit("message", {
        channel = channel,
        text = text,
        metadata = metadata
    }, function(response)
        print("[ChatSystem] Client: Message response: " .. tostring(response and response.success))
    end)
end

--- Send a chat message
---@param inputText string
function Client.SendMessage(inputText)
    if not Client.isConnected then
        print("[ChatSystem] Client: Not connected to chat server")
        return
    end
    
    if not inputText or inputText == "" then return end
    
    local channel, text, metadata = Client.ParseInput(inputText)
    
    -- Don't send empty messages
    if not text or text == "" or text == " " then return end
    
    -- Handle active PM conversation
    if Client.activeConversation then
        channel = ChatSystem.ChannelType.PRIVATE
        metadata.target = Client.activeConversation
    end
    
    -- Check for yell (uppercase or ! prefix)
    if channel == ChatSystem.ChannelType.LOCAL then
        if text == text:upper() and #text > 3 then
            metadata.isYell = true
        elseif luautils.stringStarts(text, "!") then
            metadata.isYell = true
            text = text:sub(2)
        end
    end
    
    -- Send via socket
    print("[ChatSystem] Client: Sending message - channel: " .. tostring(channel) .. ", text: " .. tostring(text))
    Client.socket:emit("message", {
        channel = channel,
        text = text,
        metadata = metadata
    }, function(response)
        print("[ChatSystem] Client: Message response: " .. tostring(response and response.success))
    end)
end

-- ==========================================================
-- Channel Management
-- ==========================================================

--- Check if a channel is currently available
---@param channel string
---@return boolean
function Client.IsChannelAvailable(channel)
    local available = Client.GetAvailableChannels()
    for _, ch in ipairs(available) do
        if ch == channel then
            return true
        end
    end
    return false
end

--- Set the current default channel
---@param channel string
function Client.SetChannel(channel)
    -- Only allow setting to available channels
    if ChatSystem.ChannelColors[channel] and Client.IsChannelAvailable(channel) then
        Client.currentChannel = channel
        ChatSystem.Events.OnChannelChanged:Trigger(channel)
    end
end

--- Get available channels for the current player
---@return table Array of channel types
function Client.GetAvailableChannels()
    local channels = {}
    local settings = ChatSystem.Settings
    
    -- In singleplayer, only local chat makes sense
    if not isClient() and not isServer() then
        table.insert(channels, ChatSystem.ChannelType.LOCAL)
        return channels
    end
    
    -- Add global chat if enabled
    if settings.enableGlobalChat then
        table.insert(channels, ChatSystem.ChannelType.GLOBAL)
    end
    
    -- Local chat is always available
    table.insert(channels, ChatSystem.ChannelType.LOCAL)
    
    local player = getPlayer()
    if player then
        -- Check faction (only if faction chat is enabled and player is in a faction)
        if settings.enableFactionChat and Faction and Faction.getPlayerFaction and Faction.getPlayerFaction(player) then
            table.insert(channels, ChatSystem.ChannelType.FACTION)
        end
        
        -- Check safehouse (only if safehouse chat is enabled and player has a safehouse)
        if settings.enableSafehouseChat and SafeHouse and SafeHouse.hasSafehouse and SafeHouse.hasSafehouse(player) then
            table.insert(channels, ChatSystem.ChannelType.SAFEHOUSE)
        end
        
        -- Check admin (only if admin chat is enabled and player has admin power)
        if settings.enableAdminChat then
            local isAdmin = false
            
            -- Check role hasAdminPower() in multiplayer
            if isClient() then
                local role = player:getRole()
                if role then
                    local success, hasAdmin = pcall(function()
                        return role:hasAdminPower()
                    end)
                    if success and hasAdmin then
                        isAdmin = true
                    end
                end
            end
            
            -- Fallback: check access level for "admin"
            if not isAdmin then
                local accessLevel = getAccessLevel and getAccessLevel()
                if accessLevel and string.lower(accessLevel) == "admin" then
                    isAdmin = true
                end
            end
            
            if isAdmin then
                table.insert(channels, ChatSystem.ChannelType.ADMIN)
            end
        end
        
        -- Check staff (only if staff chat is enabled and player is admin, mod, or GM)
        if settings.enableStaffChat then
            local isStaff = false
            
            -- Check role capabilities in multiplayer (SeePlayersConnected or AnswerTickets = staff)
            if isClient() then
                local role = player:getRole()
                if role and Capability then
                    -- Admin power means staff
                    local success, hasAdmin = pcall(function()
                        return role:hasAdminPower()
                    end)
                    if success and hasAdmin then
                        isStaff = true
                    end
                    
                    -- Staff capabilities
                    if not isStaff then
                        local success2, hasStaffCap = pcall(function()
                            return role:hasCapability(Capability.SeePlayersConnected) or
                                   role:hasCapability(Capability.AnswerTickets)
                        end)
                        if success2 and hasStaffCap then
                            isStaff = true
                        end
                    end
                end
            end
            
            -- Fallback: check specific staff roles (not observer)
            if not isStaff then
                local accessLevel = getAccessLevel and getAccessLevel()
                if accessLevel then
                    local level = string.lower(accessLevel)
                    -- Staff roles: admin, moderator, overseer, gm (NOT observer)
                    isStaff = level == "admin" or level == "moderator" or level == "overseer" or level == "gm"
                end
            end
            
            if isStaff then
                table.insert(channels, ChatSystem.ChannelType.STAFF)
            end
        end
    end
    
    -- Radio if player has one
    -- TODO: Check for radio item
    -- table.insert(channels, ChatSystem.ChannelType.RADIO)
    
    return channels
end

--- Get the command prefix for a channel
---@param channel string
---@return string
function Client.GetChannelCommand(channel)
    local commands = ChatSystem.ChannelCommands[channel]
    if commands and commands[1] then
        return commands[1]
    end
    return ""
end

-- ==========================================================
-- Player List
-- ==========================================================

--- Get online players
---@return table
function Client.GetOnlinePlayers()
    return Client.onlinePlayers
end

--- Refresh online players list
function Client.RefreshPlayers()
    if not Client.isConnected then return end
    
    Client.socket:emit("getPlayers", {}, function(response)
        if response and response.players then
            Client.onlinePlayers = response.players
        end
    end)
end

-- ==========================================================
-- Private Conversations
-- ==========================================================

--- Start or open a conversation with a player
---@param username string
function Client.OpenConversation(username)
    if not username or username == "" then return end
    
    -- Create conversation if it doesn't exist
    if not Client.conversations[username] then
        Client.conversations[username] = { messages = {}, unread = 0 }
    end
    
    -- Set as active conversation
    Client.activeConversation = username
    Client.conversations[username].unread = 0
    
    -- Trigger event
    ChatSystem.Events.OnChannelChanged:Trigger("pm:" .. username)
end

--- Close a conversation
---@param username string
function Client.CloseConversation(username)
    if not username then return end
    
    -- If closing the active conversation, switch to local
    if Client.activeConversation == username then
        Client.activeConversation = nil
        Client.currentChannel = ChatSystem.ChannelType.LOCAL
        ChatSystem.Events.OnChannelChanged:Trigger(ChatSystem.ChannelType.LOCAL)
    end
    
    -- Remove conversation data
    Client.conversations[username] = nil
end

--- Get messages for a conversation
---@param username string
---@return table
function Client.GetConversationMessages(username)
    if Client.conversations[username] then
        return Client.conversations[username].messages
    end
    return {}
end

--- Get all open conversations
---@return table { username = { messages, unread } }
function Client.GetConversations()
    return Client.conversations
end

--- Deactivate conversation (switch back to normal channel)
function Client.DeactivateConversation()
    Client.activeConversation = nil
end

-- ==========================================================
-- Message Filtering
-- ==========================================================

--- Get messages for a specific channel (or all)
---@param channel string|nil
---@return table
function Client.GetMessages(channel)
    if not channel then
        return Client.messages
    end
    
    local filtered = {}
    for _, msg in ipairs(Client.messages) do
        if msg.channel == channel then
            table.insert(filtered, msg)
        end
    end
    return filtered
end

--- Clear message history
function Client.ClearMessages()
    Client.messages = {}
end

-- ==========================================================
-- Initialization
-- ==========================================================

--- Hook into vanilla chat messages (yells, server messages, etc.)
--- This captures messages that bypass our custom chat system
local function OnVanillaMessage(message, tabID)
    local author = message:getAuthor()
    local text = message:getText()
    
    if not text or text == "" then return end
    
    -- Determine channel based on message source
    local channel = ChatSystem.ChannelType.LOCAL
    local isSystem = false
    local color = nil
    
    if author == "Server" then
        -- Server system messages (sandbox changes, etc.)
        channel = ChatSystem.ChannelType.GLOBAL
        isSystem = true
        color = { r = 1, g = 0.9, b = 0.5 } -- Yellow-ish
    else
        -- Player messages (yells, says, etc.) - these are local chat
        channel = ChatSystem.ChannelType.LOCAL
        
        -- Check if this is a yell (usually in uppercase or has specific formatting)
        local textWithPrefix = message:getTextWithPrefix()
        if textWithPrefix and textWithPrefix:find("%[Yell%]") then
            color = { r = 1, g = 0.3, b = 0.3 } -- Red for yells
        end
    end
    
    -- Create message for our custom chat
    local msg
    if isSystem then
        msg = ChatSystem.CreateSystemMessage(text, channel)
    else
        msg = ChatSystem.CreateMessage(channel, author or "Unknown", text)
    end
    
    if color then
        msg.color = color
    end
    msg.metadata.isVanilla = true
    
    -- Add to message history
    table.insert(Client.messages, msg)
    
    -- Trim old messages
    while #Client.messages > ChatSystem.Settings.maxMessagesStored do
        table.remove(Client.messages, 1)
    end
    
    -- Trigger event for UI update
    ChatSystem.Events.OnMessageReceived:Trigger(msg)
    
    print("[ChatSystem] Client: Captured vanilla message from " .. tostring(author) .. ": " .. text)
end

local function OnGameStart()
    if isClient() or not isServer() then
        Client.Connect()
        
        -- Hook vanilla chat messages to capture yells, server announcements, etc.
        Events.OnAddMessage.Add(OnVanillaMessage)
    end
end

Events.OnGameStart.Add(OnGameStart)

print("[ChatSystem] Client Loaded")
