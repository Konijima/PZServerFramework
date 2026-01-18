-- ChatSystem Typing Indicators Module (Server)
-- Handles typing indicator events and broadcasts
-- Returns a module table to be merged into ChatSystem.Server

require "ChatSystem/Definitions"
require "ChatSystem/PlayerUtils"

local Module = {}

-- ==========================================================
-- Typing Indicator Broadcasting
-- ==========================================================

--- Broadcast typing indicator to appropriate players
---@param player IsoPlayer
---@param channel string
---@param isTyping boolean
---@param target string|nil Optional target for PM typing
function Module.BroadcastTypingIndicator(player, channel, isTyping, target)
    local Server = ChatSystem.Server
    local username = player:getUsername()
    
    -- Use character name for roleplay mode, except for STAFF/ADMIN channels
    local displayName = username
    local useCharName = channel ~= ChatSystem.ChannelType.STAFF and channel ~= ChatSystem.ChannelType.ADMIN
    if useCharName then
        displayName = ChatSystem.PlayerUtils.GetDisplayName(player)
    end
    
    local data = { 
        username = username, 
        channel = channel, 
        isTyping = isTyping, 
        target = target,
        displayName = displayName
    }

    if channel == ChatSystem.ChannelType.PRIVATE and target then
        -- PM typing: only send to the specific target
        local targetPlayer = Server.GetPlayerByName(target)
        if targetPlayer then
            Server.chatSocket:to(targetPlayer):emit("typing", data)
        end

    elseif channel == ChatSystem.ChannelType.LOCAL then
        -- Send to nearby players
        local x, y, z = player:getX(), player:getY(), player:getZ()
        local recipients = Server.GetPlayersInRange(x, y, z, ChatSystem.Settings.localChatRange)
        for _, recipient in ipairs(recipients) do
            if recipient:getUsername() ~= username then
                Server.chatSocket:to(recipient):emit("typing", data)
            end
        end

    elseif channel == ChatSystem.ChannelType.GLOBAL then
        -- broadcast(player) excludes that player
        Server.chatSocket:broadcast(player):emit("typing", data)

    elseif channel == ChatSystem.ChannelType.FACTION then
        local faction = Server.playerData[username] and Server.playerData[username].faction
        if faction then
            for otherUsername, otherData in pairs(Server.playerData) do
                if otherData.faction == faction and otherUsername ~= username then
                    local otherPlayer = Server.GetPlayerByName(otherUsername)
                    if otherPlayer then
                        Server.chatSocket:to(otherPlayer):emit("typing", data)
                    end
                end
            end
        end

    elseif channel == ChatSystem.ChannelType.SAFEHOUSE then
        local safehouse = Server.playerData[username] and Server.playerData[username].safehouse
        if safehouse then
            for otherUsername, otherData in pairs(Server.playerData) do
                if otherData.safehouse == safehouse and otherUsername ~= username then
                    local otherPlayer = Server.GetPlayerByName(otherUsername)
                    if otherPlayer then
                        Server.chatSocket:to(otherPlayer):emit("typing", data)
                    end
                end
            end
        end

    elseif channel == ChatSystem.ChannelType.ADMIN then
        for otherUsername, otherData in pairs(Server.playerData) do
            if otherData.isAdmin and otherUsername ~= username then
                local otherPlayer = Server.GetPlayerByName(otherUsername)
                if otherPlayer then
                    Server.chatSocket:to(otherPlayer):emit("typing", data)
                end
            end
        end

    elseif channel == ChatSystem.ChannelType.STAFF then
        for otherUsername, otherData in pairs(Server.playerData) do
            if otherData.isStaff and otherUsername ~= username then
                local otherPlayer = Server.GetPlayerByName(otherUsername)
                if otherPlayer then
                    Server.chatSocket:to(otherPlayer):emit("typing", data)
                end
            end
        end
    end
end

-- ==========================================================
-- Event Handlers
-- ==========================================================

--- Handle typing start event
---@param player IsoPlayer
---@param data table
function Module.HandleTypingStart(player, data)
    local Server = ChatSystem.Server
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local target = data.target  -- For PM typing

    if not Server.typingPlayers[channel] then
        Server.typingPlayers[channel] = {}
    end
    Server.typingPlayers[channel][username] = getTimestampMs()

    -- Broadcast typing indicator based on channel
    Module.BroadcastTypingIndicator(player, channel, true, target)
end

--- Handle typing stop event
---@param player IsoPlayer
---@param data table
function Module.HandleTypingStop(player, data)
    local Server = ChatSystem.Server
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local target = data.target  -- For PM typing

    if Server.typingPlayers[channel] then
        Server.typingPlayers[channel][username] = nil
    end

    -- Broadcast typing indicator based on channel
    Module.BroadcastTypingIndicator(player, channel, false, target)
end

-- ==========================================================
-- Cleanup
-- ==========================================================

--- Cleanup old typing indicators (timeout after 5 seconds)
function Module.CleanupTypingIndicators()
    local Server = ChatSystem.Server
    local now = getTimestampMs()
    local timeout = 5000 -- 5 seconds

    for channel, players in pairs(Server.typingPlayers) do
        for username, timestamp in pairs(players) do
            if now - timestamp > timeout then
                players[username] = nil
                -- Broadcast stop typing
                local player = Server.GetPlayerByName(username)
                if player then
                    Module.BroadcastTypingIndicator(player, channel, false)
                end
            end
        end
    end
end

--- Clear typing indicators for a player (on quit/death)
---@param username string
---@param player IsoPlayer|nil Optional player object for broadcasting
function Module.ClearPlayerTyping(username, player)
    local Server = ChatSystem.Server
    for channel, players in pairs(Server.typingPlayers) do
        if players[username] then
            players[username] = nil
            -- Broadcast stop typing if we have the player object
            if player then
                Module.BroadcastTypingIndicator(player, channel, false)
            end
        end
    end
end

return Module
