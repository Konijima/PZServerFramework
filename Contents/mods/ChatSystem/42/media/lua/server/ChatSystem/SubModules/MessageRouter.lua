-- ChatSystem Message Router
-- Handles message validation and routing to appropriate recipients
if isClient() then return end
if not isServer() then return end

require "ChatSystem/Definitions"
require "ChatSystem/SubModules/Helpers"

local Server = ChatSystem.Server

-- ==========================================================
-- State (shared with main Server.lua)
-- ==========================================================

-- These will be set by Server.lua
Server.playerData = Server.playerData or {}
Server.lastMessageTime = Server.lastMessageTime or {}
Server.chatSocket = nil  -- Set by Server.lua

-- ==========================================================
-- Message Validation
-- ==========================================================

--- Validate incoming message from player
---@param player IsoPlayer
---@param data table Message data
---@return boolean valid, string? errorMessage
function Server.ValidateIncomingMessage(player, data)
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local pData = Server.playerData[username]
    
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
        if not Server.IsPlayerStaff(player) then
            return false, "No access to staff chat"
        end
    end
    
    if channel == ChatSystem.ChannelType.ADMIN then
        if not Server.IsPlayerAdmin(player) then
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
        local lastTime = Server.lastMessageTime[username] or 0
        local cooldownMs = ChatSystem.Settings.chatSlowMode * 1000
        
        if now - lastTime < cooldownMs then
            local remaining = math.ceil((cooldownMs - (now - lastTime)) / 1000)
            return false, "Slow mode: wait " .. remaining .. " second(s)"
        end
        
        -- Update last message time
        Server.lastMessageTime[username] = now
    end
    
    return true, nil
end

-- ==========================================================
-- Message Routing
-- ==========================================================

--- Route message to LOCAL channel recipients
---@param player IsoPlayer
---@param message table
---@param metadata table
---@param ack function|nil
function Server.RouteLocalMessage(player, message, metadata, ack)
    -- For LOCAL chat, don't emit anything back
    -- The client will call processSayMessage/processShoutMessage on ack
    -- which handles overhead text and vanilla broadcasts to nearby players
    -- Other players will receive it via vanilla OnAddMessage hook
    
    if ack then
        ack({ 
            success = true, 
            messageId = message.id,
            isLocal = true,
            text = message.text,
            isYell = metadata.isYell or false
        })
    end
end

--- Route message to GLOBAL channel recipients
---@param player IsoPlayer
---@param message table
function Server.RouteGlobalMessage(player, message)
    Server.chatSocket:broadcast():emit("message", message)
end

--- Route message to FACTION channel recipients
---@param player IsoPlayer
---@param message table
---@param username string
function Server.RouteFactionMessage(player, message, username)
    local faction = Server.playerData[username].faction
    if faction then
        message.metadata.factionName = faction
        
        -- Find all players in the same faction
        for otherUsername, otherData in pairs(Server.playerData) do
            if otherData.faction == faction then
                local otherPlayer = Server.GetPlayerByName(otherUsername)
                if otherPlayer then
                    Server.chatSocket:to(otherPlayer):emit("message", message)
                end
            end
        end
    end
end

--- Route message to SAFEHOUSE channel recipients
---@param player IsoPlayer
---@param message table
---@param username string
function Server.RouteSafehouseMessage(player, message, username)
    local safehouseId = Server.playerData[username].safehouseId
    local safehouse = Server.playerData[username].safehouse
    if safehouseId and safehouse then
        message.metadata.safehouseName = safehouse:getTitle() or "Safehouse"
        
        -- Find all players in the same safehouse (compare by ID, not object reference)
        for otherUsername, otherData in pairs(Server.playerData) do
            if otherData.safehouseId == safehouseId then
                local otherPlayer = Server.GetPlayerByName(otherUsername)
                if otherPlayer then
                    Server.chatSocket:to(otherPlayer):emit("message", message)
                end
            end
        end
    end
end

--- Route message to PRIVATE channel recipients
---@param player IsoPlayer
---@param message table
---@param username string
---@param metadata table
function Server.RoutePrivateMessage(player, message, username, metadata)
    local targetUsername = metadata.target
    if targetUsername then
        local targetPlayer = Server.GetPlayerByName(targetUsername)
        if targetPlayer then
            message.metadata.from = username
            message.metadata.to = targetUsername
            
            -- Send to target
            Server.chatSocket:to(targetPlayer):emit("message", message)
            
            -- Send copy back to sender
            Server.chatSocket:to(player):emit("message", message)
        else
            -- Player not found
            local errorMsg = ChatSystem.CreateSystemMessage("Player '" .. targetUsername .. "' not found.")
            Server.chatSocket:to(player):emit("message", errorMsg)
        end
    end
end

--- Route message to ADMIN channel recipients
---@param player IsoPlayer
---@param message table
function Server.RouteAdminMessage(player, message)
    -- Send to all admins (verify permission in real-time)
    for otherUsername, _ in pairs(Server.playerData) do
        local otherPlayer = Server.GetPlayerByName(otherUsername)
        if otherPlayer and Server.IsPlayerAdmin(otherPlayer) then
            Server.chatSocket:to(otherPlayer):emit("message", message)
        end
    end
end

--- Route message to STAFF channel recipients
---@param player IsoPlayer
---@param message table
function Server.RouteStaffMessage(player, message)
    -- Send to all staff members (verify permission in real-time)
    for otherUsername, _ in pairs(Server.playerData) do
        local otherPlayer = Server.GetPlayerByName(otherUsername)
        if otherPlayer and Server.IsPlayerStaff(otherPlayer) then
            Server.chatSocket:to(otherPlayer):emit("message", message)
        end
    end
end

--- Route message to RADIO channel recipients
---@param player IsoPlayer
---@param message table
---@param metadata table
function Server.RouteRadioMessage(player, message, metadata)
    local frequency = metadata.frequency or 100.0
    message.metadata.frequency = frequency
    
    -- TODO: Implement radio frequency logic
    -- For now, broadcast to all
    Server.chatSocket:broadcast():emit("message", message)
end

--- Route a message to appropriate recipients based on channel
---@param player IsoPlayer
---@param channel string
---@param message table
---@param metadata table
---@param ack function|nil
function Server.RouteMessage(player, channel, message, metadata, ack)
    local username = player:getUsername()
    
    if channel == ChatSystem.ChannelType.LOCAL then
        Server.RouteLocalMessage(player, message, metadata, ack)
        return true  -- Don't send default ack
        
    elseif channel == ChatSystem.ChannelType.GLOBAL then
        Server.RouteGlobalMessage(player, message)
        
    elseif channel == ChatSystem.ChannelType.FACTION then
        Server.RouteFactionMessage(player, message, username)
        
    elseif channel == ChatSystem.ChannelType.SAFEHOUSE then
        Server.RouteSafehouseMessage(player, message, username)
        
    elseif channel == ChatSystem.ChannelType.PRIVATE then
        Server.RoutePrivateMessage(player, message, username, metadata)
        
    elseif channel == ChatSystem.ChannelType.ADMIN then
        Server.RouteAdminMessage(player, message)
        
    elseif channel == ChatSystem.ChannelType.STAFF then
        Server.RouteStaffMessage(player, message)
        
    elseif channel == ChatSystem.ChannelType.RADIO then
        Server.RouteRadioMessage(player, message, metadata)
    end
    
    return false  -- Send default ack
end

print("[ChatSystem] Message Router loaded")
