-- ChatSystem is multiplayer only
if isServer() then return end
if not isClient() then 
    print("[ChatSystem] Client: Skipping - singleplayer mode")
    return 
end

require "ChatSystem/Definitions"
local Socket = require("KoniLib/Socket")

-- Load sub-modules (they return tables with functions)
local TypingIndicators = require("ChatSystem/ClientTypingIndicators")
local VanillaHook = require("ChatSystem/ClientVanillaHook")
local Conversations = require("ChatSystem/ClientConversations")
local ChannelManager = require("ChatSystem/ClientChannelManager")

ChatSystem.Client = {}
local Client = ChatSystem.Client

-- Merge sub-module functions into Client
for k, v in pairs(TypingIndicators) do Client[k] = v end
for k, v in pairs(VanillaHook) do Client[k] = v end
for k, v in pairs(Conversations) do Client[k] = v end
for k, v in pairs(ChannelManager) do Client[k] = v end

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

-- Channel tracking (to detect changes in available channels)
Client.lastAvailableChannels = nil

-- Faction/Safehouse state tracking (to detect joins/leaves)
Client.lastFactionName = nil
Client.lastSafehouseId = nil

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
    
    -- Teleport handler (for /tp, /bring and similar commands)
    -- Uses vanilla commands which are processed by Java server-side
    Client.socket:on("teleport", function(data)
        if not data then return end
        
        local player = getPlayer()
        if not player then return end
        
        if data.type == "bring" then
            -- Teleport another player TO the admin (this client)
            -- Uses vanilla /teleportplayer "target" "destination"
            local adminName = player:getDisplayName()
            SendCommandToServer("/teleportplayer \"" .. data.target .. "\" \"" .. adminName .. "\"")
            
        elseif data.type == "goto_player" then
            -- Teleport this client TO another player
            -- Uses vanilla /teleport "playername"
            SendCommandToServer("/teleport \"" .. data.target .. "\"")
            
        elseif data.type == "goto_coords" then
            -- Teleport this client to coordinates
            -- Uses vanilla /teleportto x,y,z
            SendCommandToServer("/teleportto " .. tostring(data.x) .. "," .. tostring(data.y) .. "," .. tostring(data.z))
            
        else
            -- Fallback: legacy coordinate-based teleport
            if data.x and data.y and data.z then
                SendCommandToServer("/teleportto " .. tostring(data.x) .. "," .. tostring(data.y) .. "," .. tostring(data.z))
            end
        end
    end)
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
    
    -- Clear any typing indicators for this player
    Client.ClearTypingIndicator(username)
    
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
    
    -- Clear any typing indicators for this player
    Client.ClearTypingIndicator(username)
    
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

-- ==========================================================
-- Initialization
-- ==========================================================

local function OnGameStart()
    Client.Connect()
    
    -- Initialize sub-modules
    TypingIndicators.Init()
    VanillaHook.Init()
    ChannelManager.Init()
    
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

print("[ChatSystem] Client Loaded (multiplayer)")
