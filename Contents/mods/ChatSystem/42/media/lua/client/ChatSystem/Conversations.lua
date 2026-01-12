-- ChatSystem Conversations Module
-- Handles sending messages and private conversations
-- Must be loaded after Client.lua initializes ChatSystem.Client

if isServer() then return end
if not isClient() then return end

local Client = ChatSystem.Client

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

print("[ChatSystem] Conversations module loaded")
