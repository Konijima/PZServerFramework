-- ChatSystem Conversations Module
-- Handles sending messages and private conversations
-- Returns a module table to be merged into ChatSystem.Client

require "ChatSystem/Definitions"
require "KoniLib/Player"

local Module = {}

-- ==========================================================
-- Sending Messages
-- ==========================================================

--- Parse input text for commands and extract channel/target
---@param inputText string
---@return string channel
---@return string text
---@return table metadata
function Module.ParseInput(inputText)
    local Client = ChatSystem.Client
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
function Module.DetectChannelPrefix(inputText)
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
---@return boolean success Whether the message was sent (false if rate limited)
function Module.SendMessageDirect(text)
    local Client = ChatSystem.Client
    if not Client.isConnected then
        print("[ChatSystem] Client: Not connected to chat server")
        return false
    end
    
    if not text or text == "" then return false end
    
    local channel = Client.currentChannel
    
    -- Check slow mode rate limiting (global channel only, exclude staff/admin)
    local slowMode = ChatSystem.Settings and ChatSystem.Settings.chatSlowMode or 0
    if slowMode > 0 and channel == ChatSystem.ChannelType.GLOBAL then
        -- Check if player is staff or admin (exempt from slow mode)
        local player = getPlayer()
        local isExempt = player and KoniLib.Player.IsStaff(player)
        
        if not isExempt then
            local now = getTimestampMs()
            local timeSinceLastMessage = (now - Client.lastMessageSentTime) / 1000  -- Convert to seconds
            if timeSinceLastMessage < slowMode then
                local waitTime = math.ceil(slowMode - timeSinceLastMessage)
                -- Add local system message to notify user (client-only, not broadcast)
                -- Use current channel so it appears in the channel they're viewing
                if ChatUI and ChatUI.Messages and ChatUI.Messages.add then
                    local currentChannel = Client.currentChannel or ChatSystem.ChannelType.GLOBAL
                    local msg = ChatSystem.CreateSystemMessage("Slow mode: Please wait " .. waitTime .. " second(s) before sending another message.", currentChannel)
                    ChatUI.Messages.add(msg)
                end
                return false
            end
            Client.lastMessageSentTime = now
        end
    end
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
function Module.SendMessage(inputText)
    local Client = ChatSystem.Client
    if not Client.isConnected then
        print("[ChatSystem] Client: Not connected to chat server")
        return
    end
    
    if not inputText or inputText == "" then return end
    
    local channel, text, metadata = Module.ParseInput(inputText)
    
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
-- Private Conversations
-- ==========================================================

--- Start or open a conversation with a player
---@param username string
function Module.OpenConversation(username)
    local Client = ChatSystem.Client
    if not username or username == "" then return end
    
    -- Handle typing state transition if we were typing in a different context
    if Client.isTyping then
        -- Stop typing in previous channel/conversation
        Client.socket:emit("typing", { channel = Client.typingChannel, target = Client.typingTarget, isTyping = false })
        -- Start typing in new PM conversation
        Client.typingChannel = ChatSystem.ChannelType.PRIVATE
        Client.typingTarget = username
        Client.lastTypingTime = getTimestampMs()
        Client.socket:emit("typing", { channel = ChatSystem.ChannelType.PRIVATE, target = username, isTyping = true })
    end
    
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
function Module.CloseConversation(username)
    local Client = ChatSystem.Client
    if not username then return end
    
    -- If closing the active conversation, switch to local
    if Client.activeConversation == username then
        -- Handle typing state transition if we were typing in this PM
        if Client.isTyping and Client.typingChannel == ChatSystem.ChannelType.PRIVATE and Client.typingTarget == username then
            -- Stop typing in PM
            Client.socket:emit("typing", { channel = Client.typingChannel, target = Client.typingTarget, isTyping = false })
            -- Start typing in local channel
            Client.typingChannel = ChatSystem.ChannelType.LOCAL
            Client.typingTarget = nil
            Client.lastTypingTime = getTimestampMs()
            Client.socket:emit("typing", { channel = ChatSystem.ChannelType.LOCAL, target = nil, isTyping = true })
        end
        
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
function Module.GetConversationMessages(username)
    local Client = ChatSystem.Client
    if Client.conversations[username] then
        return Client.conversations[username].messages
    end
    return {}
end

--- Get all open conversations
---@return table { username = { messages, unread } }
function Module.GetConversations()
    return ChatSystem.Client.conversations
end

--- Deactivate conversation (switch back to normal channel)
function Module.DeactivateConversation()
    local Client = ChatSystem.Client
    
    -- Handle typing state transition if we were typing in a PM
    if Client.isTyping and Client.typingChannel == ChatSystem.ChannelType.PRIVATE then
        -- Stop typing in PM
        Client.socket:emit("typing", { channel = Client.typingChannel, target = Client.typingTarget, isTyping = false })
        -- Start typing in current channel
        Client.typingChannel = Client.currentChannel
        Client.typingTarget = nil
        Client.lastTypingTime = getTimestampMs()
        Client.socket:emit("typing", { channel = Client.currentChannel, target = nil, isTyping = true })
    end
    
    Client.activeConversation = nil
end

print("[ChatSystem] Conversations module loaded")

return Module
