-- ChatSystem Server is multiplayer only
if isClient() then return end
if not isServer() then 
    print("[ChatSystem] Server: Skipping - singleplayer mode")
    return 
end

require "ChatSystem/Definitions"
local Socket = require("KoniLib/Socket")

-- Helper function to check if a table is empty (replacement for next() which isn't available in PZ)
local function tableIsEmpty(t)
    if not t then return true end
    for _ in pairs(t) do
        return false
    end
    return true
end

ChatSystem.Server = {}
local Server = ChatSystem.Server

-- Create the chat namespace
local chatSocket = Socket.of("/chat")

-- Store connected players' data
local playerData = {} -- { [username] = { faction, safehouse, isAdmin } }

-- ==========================================================
-- Helper Functions
-- ==========================================================

--- Get the display name for a player based on roleplay mode setting
---@param player IsoPlayer
---@return string The display name (character name if roleplay mode, username otherwise)
local function getPlayerDisplayName(player)
    if not player then return "Unknown" end
    
    -- If roleplay mode is enabled, use character name
    if ChatSystem.Settings.roleplayMode then
        local descriptor = player:getDescriptor()
        if descriptor then
            local forename = descriptor:getForename() or ""
            local surname = descriptor:getSurname() or ""
            local fullName = forename
            if surname ~= "" then
                fullName = fullName .. " " .. surname
            end
            if fullName ~= "" then
                return fullName
            end
        end
    end
    
    -- Default to username
    return player:getUsername() or "Unknown"
end

--- Get a player by username (works in both SP and MP)
---@param username string
---@return IsoPlayer|nil
local function getPlayerByName(username)
    if not username then return nil end
    
    -- Try getPlayerByUsername first (MP)
    if getPlayerByUsername then
        local player = getPlayerByUsername(username)
        if player then return player end
    end
    
    -- Fallback: iterate through online players
    local onlinePlayers = getOnlinePlayers()
    if onlinePlayers and onlinePlayers:size() > 0 then
        for i = 0, onlinePlayers:size() - 1 do
            local p = onlinePlayers:get(i)
            if p and p:getUsername() == username then
                return p
            end
        end
    end
    
    -- SP fallback
    local player = getPlayer()
    if player and player:getUsername() == username then
        return player
    end
    
    return nil
end

--- Get players within range of a position
---@param x number
---@param y number
---@param z number
---@param range number
---@return table Array of players
local function getPlayersInRange(x, y, z, range)
    local players = {}
    local onlinePlayers = getOnlinePlayers()
    
    print("[ChatSystem] getPlayersInRange: onlinePlayers = " .. tostring(onlinePlayers) .. ", type = " .. type(onlinePlayers))
    
    -- In singleplayer, getOnlinePlayers() returns nil or empty
    if not onlinePlayers or (onlinePlayers.size and onlinePlayers:size() == 0) then
        local player = getPlayer()
        print("[ChatSystem] SP mode: getPlayer() = " .. tostring(player))
        if player then
            -- In SP, always include the player (they're talking to themselves)
            table.insert(players, player)
        end
        return players
    end
    
    for i = 0, onlinePlayers:size() - 1 do
        local player = onlinePlayers:get(i)
        local px, py, pz = player:getX(), player:getY(), player:getZ()
        
        -- Check Z level (same floor or adjacent)
        if math.abs(pz - z) <= 1 then
            local dist = math.sqrt((px - x)^2 + (py - y)^2)
            if dist <= range then
                table.insert(players, player)
            end
        end
    end
    
    return players
end

--- Get player's faction name
---@param player IsoPlayer
---@return string|nil
local function getPlayerFaction(player)
    local faction = Faction.getPlayerFaction(player)
    if faction then
        return faction:getName()
    end
    return nil
end

--- Get player's safehouse ID (unique identifier for comparison)
---@param player IsoPlayer
---@return string|nil Safehouse ID (x_y format) or nil
local function getPlayerSafehouseId(player)
    local safehouse = SafeHouse.hasSafehouse(player)
    if safehouse then
        -- Use coordinates as unique ID
        return safehouse:getX() .. "_" .. safehouse:getY()
    end
    return nil
end

--- Get player's safehouse object
---@param player IsoPlayer
---@return SafeHouse|nil
local function getPlayerSafehouse(player)
    return SafeHouse.hasSafehouse(player)
end

--- Check if player is admin (actual "admin" access level only)
---@param player IsoPlayer
---@return boolean
local function isPlayerAdmin(player)
    -- Only "admin" access level can access admin chat (not moderator, observer, etc.)
    local accessLevel = player:getAccessLevel()
    return accessLevel and string.lower(accessLevel) == "admin"
end

--- Check if player is staff (admin, moderator, overseer, or GM)
--- Uses capability check for SeePlayersConnected as indicator of staff role
---@param player IsoPlayer
---@return boolean
local function isPlayerStaff(player)
    -- Admins are always staff
    if isPlayerAdmin(player) then
        return true
    end
    
    -- Check for staff capability (SeePlayersConnected is a good indicator)
    local role = player:getRole()
    if role and Capability then
        local success, hasStaffCap = pcall(function()
            return role:hasCapability(Capability.SeePlayersConnected) or
                   role:hasCapability(Capability.AnswerTickets)
        end)
        if success and hasStaffCap then
            return true
        end
    end
    
    -- Check access level - only specific staff roles (not observer)
    local accessLevel = player:getAccessLevel()
    if accessLevel then
        local level = string.lower(accessLevel)
        -- Staff roles: admin, moderator, overseer, gm (NOT observer)
        return level == "admin" or level == "moderator" or level == "overseer" or level == "gm"
    end
    return false
end

-- ==========================================================
-- Socket Middleware
-- ==========================================================

-- Connection middleware - store player data
chatSocket:use(Socket.MIDDLEWARE.CONNECTION, function(player, auth, context, next, reject)
    local username = player:getUsername()
    
    -- Store player data
    playerData[username] = {
        faction = getPlayerFaction(player),
        safehouse = getPlayerSafehouse(player),
        safehouseId = getPlayerSafehouseId(player),
        isStaff = isPlayerStaff(player),
        isAdmin = isPlayerAdmin(player),
    }
    
    Socket.Log("Player connected to chat: " .. username)
    next({ username = username })
end)

-- Disconnect middleware - cleanup
chatSocket:use(Socket.MIDDLEWARE.DISCONNECT, function(player, context, next, reject)
    local username = player:getUsername()
    playerData[username] = nil
    Socket.Log("Player disconnected from chat: " .. username)
    next()
end)

-- Track last message time for slow mode
local lastMessageTime = {} -- { [username] = timestamp }

-- ==========================================================
-- Event Handlers
-- ==========================================================

--- Validate incoming message from player
---@param player IsoPlayer
---@param data table Message data
---@return boolean valid, string? errorMessage
local function validateIncomingMessage(player, data)
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local pData = playerData[username]
    
    if not pData then
        return false, "Not connected to chat"
    end
    
    -- Validate message length
    if data.text and #data.text > ChatSystem.Settings.maxMessageLength then
        return false, "Message too long"
    end
    
    -- Check if channel is enabled
    if channel == ChatSystem.ChannelType.GLOBAL and not ChatSystem.Settings.enableGlobalChat then
        return false, "Global chat is disabled"
    end
    
    if channel == ChatSystem.ChannelType.FACTION and not ChatSystem.Settings.enableFactionChat then
        return false, "Faction chat is disabled"
    end
    
    if channel == ChatSystem.ChannelType.SAFEHOUSE and not ChatSystem.Settings.enableSafehouseChat then
        return false, "Safehouse chat is disabled"
    end
    
    if channel == ChatSystem.ChannelType.STAFF and not ChatSystem.Settings.enableStaffChat then
        return false, "Staff chat is disabled"
    end
    
    if channel == ChatSystem.ChannelType.ADMIN and not ChatSystem.Settings.enableAdminChat then
        return false, "Admin chat is disabled"
    end
    
    if channel == ChatSystem.ChannelType.PRIVATE and not ChatSystem.Settings.enablePrivateMessages then
        return false, "Private messages are disabled"
    end
    
    -- Validate channel access (membership/permissions)
    -- Use real-time permission checks for staff/admin (not cached values)
    if channel == ChatSystem.ChannelType.STAFF then
        if not isPlayerStaff(player) then
            return false, "No access to staff chat"
        end
    end
    
    if channel == ChatSystem.ChannelType.ADMIN then
        if not isPlayerAdmin(player) then
            return false, "No access to admin chat"
        end
    end
    
    if channel == ChatSystem.ChannelType.FACTION and not pData.faction then
        return false, "You are not in a faction"
    end
    
    if channel == ChatSystem.ChannelType.SAFEHOUSE and not pData.safehouseId then
        return false, "You don't have a safehouse"
    end
    
    -- Check slow mode (skip for admins)
    if ChatSystem.Settings.chatSlowMode > 0 and not pData.isAdmin then
        local now = getTimestampMs()
        local lastTime = lastMessageTime[username] or 0
        local cooldownMs = ChatSystem.Settings.chatSlowMode * 1000
        
        if now - lastTime < cooldownMs then
            local remaining = math.ceil((cooldownMs - (now - lastTime)) / 1000)
            return false, "Slow mode: wait " .. remaining .. " second(s)"
        end
        
        -- Update last message time
        lastMessageTime[username] = now
    end
    
    return true, nil
end

-- Handle incoming chat messages
chatSocket:onServer("message", function(player, data, context, ack)
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local text = data.text or ""
    local metadata = data.metadata or {}
    
    print("[ChatSystem] Server: Received message from " .. tostring(username) .. " - channel: " .. tostring(channel) .. ", text: " .. tostring(text))
    
    -- Validate the message first
    local valid, errorMsg = validateIncomingMessage(player, data)
    if not valid then
        print("[ChatSystem] Server: Message rejected - " .. tostring(errorMsg))
        -- Send error back to player
        local errorMessage = ChatSystem.CreateSystemMessage(errorMsg)
        chatSocket:to(player):emit("message", errorMessage)
        if ack then
            ack({ success = false, error = errorMsg })
        end
        return
    end
    
    -- Check if this is a command (and not a channel command like /g, /l)
    if ChatSystem.Commands and ChatSystem.Commands.Server and ChatSystem.Commands.Server.HandleMessageAsCommand then
        if ChatSystem.Commands.Server.HandleMessageAsCommand(player, text, channel) then
            -- Was a command, don't process as chat
            if ack then
                ack({ success = true, wasCommand = true })
            end
            return
        end
    end
    
    -- Get display name (character name if roleplay mode, username otherwise)
    local displayName = getPlayerDisplayName(player)
    
    -- Handle yelling - convert to uppercase and set red color
    if metadata.isYell then
        text = string.upper(text)
    end
    
    -- Create the message
    local message = ChatSystem.CreateMessage(channel, displayName, text, metadata)
    
    -- Store original username in metadata for lookups (PMs, etc.)
    message.metadata.originalUsername = username
    
    -- Set red color for yelling
    if metadata.isYell then
        message.color = { r = 1, g = 0.3, b = 0.3 } -- Red for yells
    end
    
    -- Determine recipients based on channel
    if channel == ChatSystem.ChannelType.LOCAL then
        -- For LOCAL chat, don't emit anything back
        -- The client will call processSayMessage/processShoutMessage on ack
        -- which handles overhead text and vanilla broadcasts to nearby players
        -- Other players will receive it via vanilla OnAddMessage hook
        
        -- Just acknowledge with the processed text (uppercase for yells, display name)
        print("[ChatSystem] Server: LOCAL ack - isYell: " .. tostring(metadata.isYell) .. ", text: " .. tostring(text))
        if ack then
            ack({ 
                success = true, 
                messageId = message.id,
                isLocal = true,
                text = text,  -- Processed text (uppercased if yell)
                isYell = metadata.isYell or false
            })
        end
        return  -- Don't emit, don't fall through to bottom ack
        
    elseif channel == ChatSystem.ChannelType.GLOBAL then
        -- Broadcast to all connected players
        chatSocket:broadcast():emit("message", message)
        
    elseif channel == ChatSystem.ChannelType.FACTION then
        -- Send to faction members
        local faction = playerData[username].faction
        if faction then
            message.metadata.factionName = faction
            
            -- Find all players in the same faction
            for otherUsername, otherData in pairs(playerData) do
                if otherData.faction == faction then
                    local otherPlayer = getPlayerByName(otherUsername)
                    if otherPlayer then
                        chatSocket:to(otherPlayer):emit("message", message)
                    end
                end
            end
        end
        
    elseif channel == ChatSystem.ChannelType.SAFEHOUSE then
        -- Send to safehouse members
        local safehouseId = playerData[username].safehouseId
        local safehouse = playerData[username].safehouse
        if safehouseId and safehouse then
            message.metadata.safehouseName = safehouse:getTitle() or "Safehouse"
            
            -- Find all players in the same safehouse (compare by ID, not object reference)
            for otherUsername, otherData in pairs(playerData) do
                if otherData.safehouseId == safehouseId then
                    local otherPlayer = getPlayerByName(otherUsername)
                    if otherPlayer then
                        chatSocket:to(otherPlayer):emit("message", message)
                    end
                end
            end
        end
        
    elseif channel == ChatSystem.ChannelType.PRIVATE then
        -- Send to specific player
        local targetUsername = metadata.target
        if targetUsername then
            local targetPlayer = getPlayerByName(targetUsername)
            if targetPlayer then
                message.metadata.from = username
                message.metadata.to = targetUsername
                
                -- Send to target
                chatSocket:to(targetPlayer):emit("message", message)
                
                -- Send copy back to sender
                chatSocket:to(player):emit("message", message)
            else
                -- Player not found
                local errorMsg = ChatSystem.CreateSystemMessage("Player '" .. targetUsername .. "' not found.")
                chatSocket:to(player):emit("message", errorMsg)
            end
        end
        
    elseif channel == ChatSystem.ChannelType.ADMIN then
        -- Send to all admins (verify permission in real-time)
        for otherUsername, _ in pairs(playerData) do
            local otherPlayer = getPlayerByName(otherUsername)
            if otherPlayer and isPlayerAdmin(otherPlayer) then
                chatSocket:to(otherPlayer):emit("message", message)
            end
        end
        
    elseif channel == ChatSystem.ChannelType.STAFF then
        -- Send to all staff members (verify permission in real-time)
        for otherUsername, _ in pairs(playerData) do
            local otherPlayer = getPlayerByName(otherUsername)
            if otherPlayer and isPlayerStaff(otherPlayer) then
                chatSocket:to(otherPlayer):emit("message", message)
            end
        end
        
    elseif channel == ChatSystem.ChannelType.RADIO then
        -- Send to players on same frequency
        local frequency = metadata.frequency or 100.0
        message.metadata.frequency = frequency
        
        -- TODO: Implement radio frequency logic
        -- For now, broadcast to all
        chatSocket:broadcast():emit("message", message)
    end
    
    -- Acknowledge receipt
    if ack then
        ack({ success = true, messageId = message.id })
    end
end)

-- Handle player list request
chatSocket:onServer("getPlayers", function(player, data, context, ack)
    local players = {}
    local onlinePlayers = getOnlinePlayers()
    
    -- In singleplayer, getOnlinePlayers() returns nil
    if not onlinePlayers then
        local p = getPlayer()
        if p then
            table.insert(players, {
                username = p:getUsername(),
                isAdmin = isPlayerAdmin(p),
                isStaff = isPlayerStaff(p)
            })
        end
    else
        for i = 0, onlinePlayers:size() - 1 do
            local p = onlinePlayers:get(i)
            table.insert(players, {
                username = p:getUsername(),
                isAdmin = isPlayerAdmin(p),
                isStaff = isPlayerStaff(p)
            })
        end
    end
    
    if ack then
        ack({ players = players })
    end
end)

-- ==========================================================
-- Server Events
-- ==========================================================

-- Update player data when faction/safehouse changes
local function updatePlayerData()
    local onlinePlayers = getOnlinePlayers()
    
    -- In singleplayer, getOnlinePlayers() returns nil
    if not onlinePlayers then
        local player = getPlayer()
        if player then
            local username = player:getUsername()
            if playerData[username] then
                playerData[username].faction = getPlayerFaction(player)
                playerData[username].safehouse = getPlayerSafehouse(player)
                playerData[username].isAdmin = isPlayerAdmin(player)
                playerData[username].isStaff = isPlayerStaff(player)
            end
        end
        return
    end
    
    for i = 0, onlinePlayers:size() - 1 do
        local player = onlinePlayers:get(i)
        local username = player:getUsername()
        
        if playerData[username] then
            playerData[username].faction = getPlayerFaction(player)
            playerData[username].safehouse = getPlayerSafehouse(player)
            playerData[username].isAdmin = isPlayerAdmin(player)
            playerData[username].isStaff = isPlayerStaff(player)
        end
    end
end

-- Periodic update
Events.EveryOneMinute.Add(updatePlayerData)

-- ==========================================================
-- Typing Indicators
-- ==========================================================

-- Store who is typing in which channel
local typingPlayers = {} -- { [channel] = { [username] = timestamp } }

-- Handle typing start
chatSocket:onServer("typingStart", function(player, data, context, ack)
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local target = data.target  -- For PM typing
    
    if not typingPlayers[channel] then
        typingPlayers[channel] = {}
    end
    typingPlayers[channel][username] = getTimestampMs()
    
    -- Broadcast typing indicator based on channel
    Server.BroadcastTypingIndicator(player, channel, true, target)
end)

-- Handle typing stop
chatSocket:onServer("typingStop", function(player, data, context, ack)
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local target = data.target  -- For PM typing
    
    if typingPlayers[channel] then
        typingPlayers[channel][username] = nil
    end
    
    -- Broadcast typing indicator based on channel
    Server.BroadcastTypingIndicator(player, channel, false, target)
end)

--- Broadcast typing indicator to appropriate players
---@param player IsoPlayer
---@param channel string
---@param isTyping boolean
---@param target string|nil Optional target for PM typing
function Server.BroadcastTypingIndicator(player, channel, isTyping, target)
    local username = player:getUsername()
    local data = { username = username, channel = channel, isTyping = isTyping, target = target }
    
    if channel == ChatSystem.ChannelType.PRIVATE and target then
        -- PM typing: only send to the specific target
        local targetPlayer = getPlayerByName(target)
        if targetPlayer then
            chatSocket:to(targetPlayer):emit("typing", data)
        end
        
    elseif channel == ChatSystem.ChannelType.LOCAL then
        -- Send to nearby players
        local x, y, z = player:getX(), player:getY(), player:getZ()
        local recipients = getPlayersInRange(x, y, z, ChatSystem.Settings.localChatRange)
        for _, recipient in ipairs(recipients) do
            if recipient:getUsername() ~= username then
                chatSocket:to(recipient):emit("typing", data)
            end
        end
        
    elseif channel == ChatSystem.ChannelType.GLOBAL then
        -- broadcast(player) excludes that player
        chatSocket:broadcast(player):emit("typing", data)
        
    elseif channel == ChatSystem.ChannelType.FACTION then
        local faction = playerData[username] and playerData[username].faction
        if faction then
            for otherUsername, otherData in pairs(playerData) do
                if otherData.faction == faction and otherUsername ~= username then
                    local otherPlayer = getPlayerByName(otherUsername)
                    if otherPlayer then
                        chatSocket:to(otherPlayer):emit("typing", data)
                    end
                end
            end
        end
        
    elseif channel == ChatSystem.ChannelType.SAFEHOUSE then
        local safehouse = playerData[username] and playerData[username].safehouse
        if safehouse then
            for otherUsername, otherData in pairs(playerData) do
                if otherData.safehouse == safehouse and otherUsername ~= username then
                    local otherPlayer = getPlayerByName(otherUsername)
                    if otherPlayer then
                        chatSocket:to(otherPlayer):emit("typing", data)
                    end
                end
            end
        end
        
    elseif channel == ChatSystem.ChannelType.ADMIN then
        for otherUsername, otherData in pairs(playerData) do
            if otherData.isAdmin and otherUsername ~= username then
                local otherPlayer = getPlayerByName(otherUsername)
                if otherPlayer then
                    chatSocket:to(otherPlayer):emit("typing", data)
                end
            end
        end
        
    elseif channel == ChatSystem.ChannelType.STAFF then
        for otherUsername, otherData in pairs(playerData) do
            if otherData.isStaff and otherUsername ~= username then
                local otherPlayer = getPlayerByName(otherUsername)
                if otherPlayer then
                    chatSocket:to(otherPlayer):emit("typing", data)
                end
            end
        end
    end
end

-- Cleanup old typing indicators (timeout after 5 seconds)
local function cleanupTypingIndicators()
    local now = getTimestampMs()
    local timeout = 5000 -- 5 seconds
    
    for channel, players in pairs(typingPlayers) do
        for username, timestamp in pairs(players) do
            if now - timestamp > timeout then
                players[username] = nil
                -- Broadcast stop typing
                local player = getPlayerByName(username)
                if player then
                    Server.BroadcastTypingIndicator(player, channel, false)
                end
            end
        end
    end
end

Events.EveryOneMinute.Add(cleanupTypingIndicators)

-- ==========================================================
-- Player Events (Login, Logout, Death)
-- ==========================================================

--- Broadcast a system message to all connected players
---@param text string
---@param color table? Optional color override {r, g, b}
function Server.BroadcastSystemMessage(text, color)
    -- Only broadcast if socket is connected (SP) or has connections (MP)
    if not chatSocket.connected and tableIsEmpty(chatSocket.connections or {}) then
        Socket.Log("Skipping broadcast (not connected): " .. text)
        return
    end
    
    local msg = ChatSystem.CreateSystemMessage(text, ChatSystem.ChannelType.GLOBAL)
    if color then
        msg.color = color
    end
    chatSocket:broadcast():emit("message", msg)
end

-- Player connected/initialized on server
local function OnPlayerInit(playerIndex, player, isRespawn)
    if not player then return end
    
    local username = player:getUsername()
    
    -- Delay the broadcast slightly to allow socket connection to establish
    -- Use a simple timer approach
    local ticksToWait = 30 -- About 0.5 seconds
    local tickCount = 0
    
    local function delayedBroadcast()
        tickCount = tickCount + 1
        if tickCount >= ticksToWait then
            Events.OnTick.Remove(delayedBroadcast)
            if isRespawn then
                Server.BroadcastSystemMessage(username .. " has respawned.", { r = 0.5, g = 1, b = 0.5 }) -- Light green
            else
                Server.BroadcastSystemMessage(username .. " has joined the server.", { r = 0.5, g = 1, b = 0.5 }) -- Light green
            end
        end
    end
    
    Events.OnTick.Add(delayedBroadcast)
end

-- Player quit/disconnected from server (detected by KoniLib polling)
local function OnPlayerQuit(username)
    -- Cleanup typing indicators
    for channel, players in pairs(typingPlayers) do
        if players[username] then
            players[username] = nil
        end
    end
    
    -- Cleanup player data
    playerData[username] = nil
    
    Server.BroadcastSystemMessage(username .. " has left the server.", { r = 0.6, g = 0.6, b = 0.6 }) -- Gray
end

-- Player died
local function OnPlayerDeath(player)
    if not player then return end
    local username = player:getUsername()
    Server.BroadcastSystemMessage(username .. " has died.", { r = 1, g = 0.3, b = 0.3 }) -- Red
end

-- Use KoniLib events for reliable detection
KoniLib.Events.OnPlayerInit:Add(OnPlayerInit)
KoniLib.Events.OnPlayerQuit:Add(OnPlayerQuit)
KoniLib.Events.OnPlayerDeath:Add(OnPlayerDeath)

print("[ChatSystem] Server Loaded")
