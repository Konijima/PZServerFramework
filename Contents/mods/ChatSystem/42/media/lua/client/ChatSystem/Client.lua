-- ChatSystem is multiplayer only
if isServer() then return end
if not isClient() then 
    print("[ChatSystem] Client: Skipping - singleplayer mode")
    return 
end

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
        
        -- Show welcome message with keybinding
        local chatKey = Keyboard.getKeyName(getCore():getKey("Toggle chat"))
        local welcomeMsg = ChatSystem.CreateSystemMessage("Press '" .. chatKey .. "' to open chat. Use ALL CAPS or start with ! to yell. Type /help for commands.")
        Client.OnMessageReceived(welcomeMsg)
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
    
    -- Player list update handler
    Client.socket:on("playerList", function(data)
        if data and data.players then
            Client.onlinePlayers = data.players
            -- Trigger event for UI updates
            ChatSystem.Events.OnPlayersUpdated:Trigger(data.players)
        end
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
    
    -- For PM typing, use the username as the key (who is typing to us)
    local trackingKey = channel
    if channel == ChatSystem.ChannelType.PRIVATE then
        trackingKey = "pm:" .. username
    end
    
    if not Client.typingPlayers[trackingKey] then
        Client.typingPlayers[trackingKey] = {}
    end
    
    if isTyping then
        Client.typingPlayers[trackingKey][username] = true
    else
        Client.typingPlayers[trackingKey][username] = nil
    end
    
    -- Trigger event for UI update
    -- For PM, pass the username who is typing so UI can update the right conversation
    ChatSystem.Events.OnTypingChanged:Trigger(channel, Client.GetTypingUsers(trackingKey), username)
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
    
    local player = getPlayer()
    local myUsername = player and player:getUsername() or ""
    
    -- LOCAL channel messages from ourselves are handled via vanilla (processSay/processShout on ack)
    -- They will appear via OnVanillaMessage hook, so skip them here
    -- (We shouldn't even receive LOCAL messages via socket anymore, but just in case)
    if message.channel == ChatSystem.ChannelType.LOCAL and not message.isSystem then
        if message.author == myUsername then
            -- Skip - will be handled by vanilla OnVanillaMessage
            return
        end
        -- Messages from OTHER players in local chat shouldn't come via socket
        -- They come via vanilla OnAddMessage (from their processSay/processShout)
        -- But if we do receive them, add to chat
    end
    
    -- Handle private messages differently
    if message.channel == ChatSystem.ChannelType.PRIVATE then
        local otherUser = nil
        
        -- Determine who the conversation is with
        -- If we sent it (author is us), the other user is the recipient (to)
        -- If we received it (author is not us), the other user is the sender (from or author)
        if message.author == myUsername then
            -- We sent this message, conversation is with the recipient
            otherUser = message.metadata and message.metadata.to
        else
            -- We received this message, conversation is with the sender
            otherUser = (message.metadata and message.metadata.from) or message.author
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
        local hasYellPrefix = luautils.stringStarts(text, "!")
        local textToCheck = hasYellPrefix and text:sub(2) or text
        local isUppercase = textToCheck == textToCheck:upper() and #textToCheck > 0 and textToCheck:match("%a")
        
        if hasYellPrefix then
            metadata.isYell = true
            text = text:sub(2)  -- Always remove ! prefix
        end
        
        if isUppercase then
            metadata.isYell = true
        end
    end
    
    -- Send via socket
    print("[ChatSystem] Client: SendMessageDirect - channel: " .. tostring(channel) .. ", text: " .. tostring(text) .. ", isYell: " .. tostring(metadata.isYell))
    Client.socket:emit("message", {
        channel = channel,
        text = text,
        metadata = metadata
    }, function(response)
        print("[ChatSystem] Client: SendMessageDirect ack received - success: " .. tostring(response and response.success) .. ", isLocal: " .. tostring(response and response.isLocal) .. ", isYell: " .. tostring(response and response.isYell))
        -- For LOCAL chat, call vanilla processSay/processShout on successful ack
        if response and response.success and response.isLocal then
            local processedText = response.text or text
            if response.isYell then
                print("[ChatSystem] Client: Calling processShoutMessage with: " .. tostring(processedText))
                processShoutMessage(processedText)
                -- Play the shout animation
                local player = getPlayer()
                if player then
                    player:playEmote("shout")
                end
            else
                print("[ChatSystem] Client: Calling processSayMessage with: " .. tostring(processedText))
                processSayMessage(processedText)
            end
        end
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
        local hasYellPrefix = luautils.stringStarts(text, "!")
        local textToCheck = hasYellPrefix and text:sub(2) or text
        local isUppercase = textToCheck == textToCheck:upper() and #textToCheck > 0 and textToCheck:match("%a")
        
        if hasYellPrefix then
            metadata.isYell = true
            text = text:sub(2)  -- Always remove ! prefix
        end
        
        if isUppercase then
            metadata.isYell = true
        end
    end
    
    -- Send via socket
    print("[ChatSystem] Client: SendMessage - channel: " .. tostring(channel) .. ", text: " .. tostring(text) .. ", isYell: " .. tostring(metadata.isYell))
    Client.socket:emit("message", {
        channel = channel,
        text = text,
        metadata = metadata
    }, function(response)
        print("[ChatSystem] Client: SendMessage ack received - success: " .. tostring(response and response.success) .. ", isLocal: " .. tostring(response and response.isLocal) .. ", isYell: " .. tostring(response and response.isYell))
        -- For LOCAL chat, call vanilla processSay/processShout on successful ack
        if response and response.success and response.isLocal then
            local processedText = response.text or text
            if response.isYell then
                print("[ChatSystem] Client: Calling processShoutMessage with: " .. tostring(processedText))
                processShoutMessage(processedText)
                -- Play the shout animation
                local player = getPlayer()
                if player then
                    player:playEmote("shout")
                end
            else
                print("[ChatSystem] Client: Calling processSayMessage with: " .. tostring(processedText))
                processSayMessage(processedText)
            end
        end
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
        
        -- Check admin (only if admin chat is enabled and player is actual admin)
        if settings.enableAdminChat then
            local accessLevel = getAccessLevel and getAccessLevel()
            -- Only "admin" access level can see admin chat (not moderator, observer, etc.)
            if accessLevel and string.lower(accessLevel) == "admin" then
                table.insert(channels, ChatSystem.ChannelType.ADMIN)
            end
        end
        
        -- Check staff (only if staff chat is enabled and player is admin, mod, or GM)
        if settings.enableStaffChat then
            local isStaff = false
            
            -- Check role capabilities (SeePlayersConnected or AnswerTickets = staff)
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

-- List of vanilla server message patterns to filter out (not shown in custom chat)
local filteredVanillaPatterns = {
    "^Safety:", -- Safety restore messages
}

--- Check if a vanilla message should be filtered (not shown in chat)
---@param text string
---@return boolean
local function shouldFilterVanillaMessage(text)
    if not text then return true end
    for _, pattern in ipairs(filteredVanillaPatterns) do
        if text:match(pattern) then
            return true
        end
    end
    return false
end

--- Hook into vanilla chat messages (yells, server messages, etc.)
--- This captures messages that bypass our custom chat system
local function OnVanillaMessage(message, tabID)
    local author = message:getAuthor()
    local text = message:getText()
    local textWithPrefix = message:getTextWithPrefix()
    
    if not text or text == "" then return end
    
    -- Debug: print the message details
    print("[ChatSystem] Vanilla message - author: " .. tostring(author) .. ", text: " .. tostring(text) .. ", prefix: " .. tostring(textWithPrefix))
    
    -- Filter out unwanted server messages
    if author == "Server" and shouldFilterVanillaMessage(text) then
        print("[ChatSystem] Filtered vanilla message: " .. text)
        return
    end
    
    -- Determine channel based on message source
    local channel = ChatSystem.ChannelType.LOCAL
    local isSystem = false
    local isYell = false
    local color = nil
    
    if author == "Server" then
        -- Server system messages (sandbox changes, etc.)
        channel = ChatSystem.ChannelType.GLOBAL
        isSystem = true
        color = { r = 1, g = 0.9, b = 0.5 } -- Yellow-ish
    else
        -- Player messages (yells, says, etc.) - these are local chat
        channel = ChatSystem.ChannelType.LOCAL
        
        -- Check if this is a yell by looking at the prefix text
        -- Vanilla yell format usually contains [Shout] or similar, or text is uppercase
        if textWithPrefix then
            local lowerPrefix = textWithPrefix:lower()
            if lowerPrefix:find("%[shout%]") or lowerPrefix:find("%[yell%]") then
                isYell = true
            end
        end
        
        -- Also check if the text is all uppercase (common yell indicator)
        if not isYell and text == text:upper() and #text > 0 and text:match("%a") then
            isYell = true
        end
        
        if isYell then
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
    if isYell then
        msg.metadata.isYell = true
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
    Client.Connect()
    
    -- Hook vanilla chat messages to capture yells, server announcements, etc.
    Events.OnAddMessage.Add(OnVanillaMessage)
    
    -- Register for KoniLib remote player events (deferred to ensure KoniLib is loaded)
    if KoniLib and KoniLib.Events then
        if KoniLib.Events.OnRemotePlayerInit then
            KoniLib.Events.OnRemotePlayerInit:Add(OnRemotePlayerInit)
            print("[ChatSystem] Client: Registered OnRemotePlayerInit handler")
        end
        if KoniLib.Events.OnRemotePlayerQuit then
            KoniLib.Events.OnRemotePlayerQuit:Add(OnRemotePlayerQuit)
            print("[ChatSystem] Client: Registered OnRemotePlayerQuit handler")
        end
        if KoniLib.Events.OnRemotePlayerDeath then
            KoniLib.Events.OnRemotePlayerDeath:Add(OnRemotePlayerDeath)
            print("[ChatSystem] Client: Registered OnRemotePlayerDeath handler")
        end
    else
        print("[ChatSystem] Client: WARNING - KoniLib.Events not available!")
    end
end

Events.OnGameStart.Add(OnGameStart)

-- ==========================================================
-- Remote Player Events (via KoniLib)
-- ==========================================================

--- Handle remote player join/respawn
local function OnRemotePlayerInit(username, isRespawn)
    if not username then return end
    
    -- Don't show message for ourselves
    local myUsername = getPlayer() and getPlayer():getUsername() or ""
    if username == myUsername then return end
    
    local text
    if isRespawn then
        text = username .. " has respawned."
    else
        text = username .. " has joined the server."
    end
    
    local msg = ChatSystem.CreateSystemMessage(text, ChatSystem.ChannelType.GLOBAL)
    msg.color = { r = 0.5, g = 1, b = 0.5 } -- Light green
    
    -- Store message
    table.insert(Client.messages, msg)
    while #Client.messages > ChatSystem.Settings.maxMessagesStored do
        table.remove(Client.messages, 1)
    end
    
    -- Trigger event for UI update
    ChatSystem.Events.OnMessageReceived:Trigger(msg)
    
    -- Refresh online players list
    Client.RefreshPlayers()
end

--- Handle remote player quit
local function OnRemotePlayerQuit(username)
    if not username then return end
    
    local msg = ChatSystem.CreateSystemMessage(username .. " has left the server.", ChatSystem.ChannelType.GLOBAL)
    msg.color = { r = 0.6, g = 0.6, b = 0.6 } -- Gray
    
    -- Store message
    table.insert(Client.messages, msg)
    while #Client.messages > ChatSystem.Settings.maxMessagesStored do
        table.remove(Client.messages, 1)
    end
    
    -- Trigger event for UI update
    ChatSystem.Events.OnMessageReceived:Trigger(msg)
    
    -- Refresh online players list
    Client.RefreshPlayers()
end

--- Handle remote player death
local function OnRemotePlayerDeath(username, x, y, z)
    if not username then return end
    
    local msg = ChatSystem.CreateSystemMessage(username .. " has died.", ChatSystem.ChannelType.GLOBAL)
    msg.color = { r = 1, g = 0.3, b = 0.3 } -- Red
    
    -- Store message
    table.insert(Client.messages, msg)
    while #Client.messages > ChatSystem.Settings.maxMessagesStored do
        table.remove(Client.messages, 1)
    end
    
    -- Trigger event for UI update
    ChatSystem.Events.OnMessageReceived:Trigger(msg)
end

print("[ChatSystem] Client Loaded (multiplayer)")
