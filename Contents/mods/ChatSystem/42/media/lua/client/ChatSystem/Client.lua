-- ChatSystem is multiplayer only
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
Client.currentChannel = ChatSystem.ChannelType.GLOBAL  -- Default to global if enabled
Client.onlinePlayers = {}
Client.isConnected = false
Client.typingPlayers = {}  -- { [channel] = { [username] = true } }
Client.isTyping = false
Client.typingChannel = nil
Client.typingTarget = nil  -- Target for PM typing
Client.lastTypingTime = 0
Client.lastMessageSentTime = 0  -- For slow mode rate limiting

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
        
        -- Show welcome message with keybinding (only on first connect, not reconnect)
        if not Client._hasShownWelcome then
            Client._hasShownWelcome = true
            local chatKey = Keyboard.getKeyName(getCore():getKey("Toggle chat"))
            local currentChannel = Client.currentChannel or ChatSystem.ChannelType.GLOBAL
            local welcomeMsg = ChatSystem.CreateSystemMessage("Press '" .. chatKey .. "' to open chat. Use ALL CAPS or start with ! to yell. Type /help for commands.", currentChannel)
            Client.OnMessageReceived(welcomeMsg)
        end
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

--- Force reconnect to the chat server (for respawn scenarios)
function Client.Reconnect()
    print("[ChatSystem] Client: Forcing reconnect after respawn...")
    
    -- Reset connection state
    Client.isConnected = false
    
    -- Clear typing state
    Client.isTyping = false
    Client.typingChannel = nil
    Client.typingTarget = nil
    Client.lastTypingTime = 0
    
    -- Force socket reconnect
    if Client.socket and Client.socket.reconnect then
        Client.socket:reconnect()
    elseif Client.socket then
        -- Fallback: reset socket state and reconnect
        Client.socket.connected = false
        Client.socket:connect()
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
            -- Check if this is a new conversation (need to refresh tabs)
            local isNewConversation = not Client.conversations[otherUser]
            
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
            
            -- If this is a new conversation, trigger event to refresh tabs
            if isNewConversation then
                ChatSystem.Events.OnConversationsChanged:Trigger()
            end
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

--- Refresh online players list with callback
---@param callback function Called with the player list when received
function Client.RefreshPlayersWithCallback(callback)
    if not Client.isConnected then
        if callback then callback(nil) end
        return
    end
    
    Client.socket:emit("getPlayers", {}, function(response)
        if response and response.players then
            Client.onlinePlayers = response.players
            if callback then callback(response.players) end
        else
            if callback then callback(nil) end
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
---@param username string The player's username
---@param isRespawn boolean Whether this is a respawn (true) or fresh join (false)
---@param displayName string|nil The player's display name (character name), provided by server
local function OnRemotePlayerInit(username, isRespawn, displayName)
    if not username then return end
    
    -- Only show messages if chat is fully connected
    if not Client.isConnected then return end
    
    -- Don't show message for ourselves
    local myUsername = getPlayer() and getPlayer():getUsername() or ""
    if username == myUsername then return end
    
    -- Use displayName only if roleplay mode is enabled, otherwise use username
    local nameToShow = username
    if ChatSystem.PlayerUtils.IsRoleplayMode() and displayName then
        nameToShow = displayName
    end
    
    local text
    if isRespawn then
        text = nameToShow .. " has respawned."
    else
        text = nameToShow .. " has joined the server."
    end
    
    -- Use current channel so message only appears in player's active channel view
    local currentChannel = Client.currentChannel or ChatSystem.ChannelType.GLOBAL
    local msg = ChatSystem.CreateSystemMessage(text, currentChannel)
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
---@param username string The player's username
---@param displayName string|nil The player's display name (character name), provided by server
local function OnRemotePlayerQuit(username, displayName)
    if not username then return end
    
    -- Only show messages if chat is fully connected
    if not Client.isConnected then return end
    
    -- Use displayName only if roleplay mode is enabled, otherwise use username
    local nameToShow = username
    if ChatSystem.PlayerUtils.IsRoleplayMode() and displayName then
        nameToShow = displayName
    end
    
    -- Clear any typing indicators for this player
    Client.ClearTypingIndicator(username)
    
    -- Use current channel so message only appears in player's active channel view
    local currentChannel = Client.currentChannel or ChatSystem.ChannelType.GLOBAL
    local msg = ChatSystem.CreateSystemMessage(nameToShow .. " has left the server.", currentChannel)
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
    
    -- If we have a conversation with this player, add a notification message
    if Client.conversations[username] then
        local pmNotification = ChatSystem.CreateSystemMessage(nameToShow .. " is no longer available.", ChatSystem.ChannelType.PRIVATE)
        pmNotification.color = { r = 1, g = 0.6, b = 0.3 } -- Orange
        pmNotification.metadata = { from = username, to = getPlayer():getUsername() }
        
        -- Add to conversation
        table.insert(Client.conversations[username].messages, pmNotification)
        
        -- Trim old messages
        while #Client.conversations[username].messages > ChatSystem.Settings.maxMessagesStored do
            table.remove(Client.conversations[username].messages, 1)
        end
        
        -- Trigger UI rebuild if viewing this conversation
        if Client.activeConversation == username then
            ChatSystem.Events.OnMessageReceived:Trigger(pmNotification)
        end
    end
end

--- Handle remote player death
---@param username string The player's username
---@param x number Player's X coordinate at death
---@param y number Player's Y coordinate at death
---@param z number Player's Z coordinate at death
---@param displayName string|nil The player's display name (character name), provided by server
local function OnRemotePlayerDeath(username, x, y, z, displayName)
    if not username then return end
    
    -- Only show messages if chat is fully connected
    if not Client.isConnected then return end
    
    -- Use displayName only if roleplay mode is enabled, otherwise use username
    local nameToShow = username
    if ChatSystem.PlayerUtils.IsRoleplayMode() and displayName then
        nameToShow = displayName
    end
    
    -- Clear any typing indicators for this player
    Client.ClearTypingIndicator(username)
    
    -- Use current channel so message only appears in player's active channel view
    local currentChannel = Client.currentChannel or ChatSystem.ChannelType.GLOBAL
    local msg = ChatSystem.CreateSystemMessage(nameToShow .. " has died.", currentChannel)
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

--- Handle local player init (join/respawn)
--- Called on both initial join and respawn, but we use _hasInitialized flag to detect respawn
---@param playerIndex number
---@param player IsoPlayer The local player
---@param isRespawn boolean Whether this is a respawn (from server, not reliable on client)
local function OnPlayerInit(playerIndex, player, isRespawn)
    -- On client, isRespawn is always false (see CustomEventsClient.lua)
    -- Instead, detect respawn by checking if we already initialized
    if not Client._hasInitialized then
        -- First join - Connect() will be called by OnGameStart
        Client._hasInitialized = true
        return
    end
    
    -- This is a respawn (player was already initialized before)
    -- Delay reconnect slightly to ensure player object is fully ready
    print("[ChatSystem] Client: Player respawned, scheduling reconnect...")
    
    local tickCount = 0
    local function delayedReconnect()
        tickCount = tickCount + 1
        if tickCount > 5 then  -- Wait ~5 ticks
            Events.OnTick.Remove(delayedReconnect)
            print("[ChatSystem] Client: Reconnecting to chat server after respawn...")
            Client.Reconnect()
        end
    end
    Events.OnTick.Add(delayedReconnect)
end

local function OnGameStart()
    Client._hasInitialized = true  -- Mark as initialized
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
        
        -- Register for local player init (for respawn handling)
        if KoniLib.Events.OnPlayerInit then
            KoniLib.Events.OnPlayerInit:Add(OnPlayerInit)
            print("[ChatSystem] Client: Registered OnPlayerInit handler for respawn")
        end
    else
        print("[ChatSystem] Client: WARNING - KoniLib.Events not available!")
    end
end

Events.OnGameStart.Add(OnGameStart)

print("[ChatSystem] Client Loaded (multiplayer)")
