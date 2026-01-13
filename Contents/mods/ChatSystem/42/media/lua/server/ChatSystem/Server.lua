-- ChatSystem Server is multiplayer only
if isClient() or not isServer() then 
    print("[ChatSystem] Server: Skipping - singleplayer mode")
    return
end

require "ChatSystem/Definitions"
local Socket = require("KoniLib/Socket")

-- Load sub-modules (they return tables with functions)
local Helpers = require("ChatSystem/ServerHelpers")
local MessageRouter = require("ChatSystem/ServerMessageRouter")
local TypingIndicators = require("ChatSystem/ServerTypingIndicators")
local Commands = require("ChatSystem/ServerCommands")

-- Initialize namespace
ChatSystem.Server = {}
local Server = ChatSystem.Server

-- Merge sub-module functions into Server
for k, v in pairs(Helpers) do Server[k] = v end
for k, v in pairs(MessageRouter) do Server[k] = v end
for k, v in pairs(TypingIndicators) do Server[k] = v end

-- Initialize Commands.Server namespace and merge command functions
ChatSystem.Commands.Server = {}
for k, v in pairs(Commands) do ChatSystem.Commands.Server[k] = v end

-- Server state
Server.playerData = {} -- { [username] = { faction, safehouse, isAdmin } }
Server.lastMessageTime = {} -- { [username] = timestamp }
Server.typingPlayers = {} -- { [channel] = { [username] = timestamp } }

-- Create the chat namespace
local chatSocket = Socket.of("/chat")
Server.chatSocket = chatSocket

-- ==========================================================
-- Socket Middleware
-- ==========================================================

--- Broadcast updated player list to all connected clients
local function broadcastPlayerList()
    local players = Server.BuildPlayerList()
    chatSocket:broadcast():emit("playerList", { players = players })
end

-- Connection middleware - store player data
chatSocket:use(Socket.MIDDLEWARE.CONNECTION, function(player, auth, context, next, reject)
    local username = player:getUsername()
    
    -- Store player data
    Server.playerData[username] = {
        faction = Server.GetPlayerFaction(player),
        safehouse = Server.GetPlayerSafehouse(player),
        safehouseId = Server.GetPlayerSafehouseId(player),
        isStaff = Server.IsPlayerStaff(player),
        isAdmin = Server.IsPlayerAdmin(player),
    }
    
    next({ username = username })
    
    -- Broadcast updated player list to all clients (after connection is established)
    broadcastPlayerList()
end)

-- Disconnect middleware - cleanup
chatSocket:use(Socket.MIDDLEWARE.DISCONNECT, function(player, context, next, reject)
    local username = player:getUsername()
    Server.playerData[username] = nil
    next()
    
    -- Broadcast updated player list to all clients (after disconnect is processed)
    broadcastPlayerList()
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
            if Server.playerData[username] then
                Server.playerData[username].faction = Server.GetPlayerFaction(player)
                Server.playerData[username].safehouse = Server.GetPlayerSafehouse(player)
                Server.playerData[username].isAdmin = Server.IsPlayerAdmin(player)
                Server.playerData[username].isStaff = Server.IsPlayerStaff(player)
            end
        end
        return
    end
    
    for i = 0, onlinePlayers:size() - 1 do
        local player = onlinePlayers:get(i)
        local username = player:getUsername()
        
        if Server.playerData[username] then
            Server.playerData[username].faction = Server.GetPlayerFaction(player)
            Server.playerData[username].safehouse = Server.GetPlayerSafehouse(player)
            Server.playerData[username].isAdmin = Server.IsPlayerAdmin(player)
            Server.playerData[username].isStaff = Server.IsPlayerStaff(player)
        end
    end
end

-- Periodic update
Events.EveryOneMinute.Add(updatePlayerData)
Events.EveryOneMinute.Add(Server.CleanupTypingIndicators)

-- ==========================================================
-- Socket Event Handlers
-- ==========================================================

-- Handle incoming messages from clients
chatSocket:onServer("message", function(player, data, context, ack)
    local username = player:getUsername()
    local channel = data.channel or ChatSystem.ChannelType.LOCAL
    local text = data.text
    local metadata = data.metadata or {}
    
    -- Add player's access level/role to metadata
    local accessLevel = player:getAccessLevel()
    if accessLevel and accessLevel ~= "" then
        metadata.role = accessLevel
    else
        metadata.role = "player"
    end
    
    print("[ChatSystem] Server: Received message from " .. username .. " - channel: " .. tostring(channel) .. ", text: " .. tostring(text))
    
    -- Check if this is a command (starts with /)
    if text and text:sub(1, 1) == "/" then
        -- Check if it's a channel prefix command (like /g, /l, etc.)
        local isChannelCommand = false
        for channelType, commands in pairs(ChatSystem.ChannelCommands) do
            for _, cmd in ipairs(commands) do
                if luautils.stringStarts(text:lower(), cmd:lower()) then
                    isChannelCommand = true
                    break
                end
            end
            if isChannelCommand then break end
        end
        
        -- If it's a custom command (not a channel command), handle it
        if not isChannelCommand then
            local Commands = ChatSystem.Commands
            if Commands and Commands.IsCommand and Commands.IsCommand(text) then
                local success, result = Commands.Server.Execute(player, text, { channel = channel })
                if not success then
                    Commands.Server.ReplyError(player, result or "Command failed")
                end
                if ack then
                    ack({ success = success, isCommand = true })
                end
                return
            end
        end
    end
    
    -- Validate message
    local valid, errorMsg = Server.ValidateIncomingMessage(player, data)
    if not valid then
        print("[ChatSystem] Server: Message validation failed - " .. tostring(errorMsg))
        if ack then
            ack({ success = false, error = errorMsg })
        end
        return
    end
    
    -- Build message object
    local message = ChatSystem.CreateMessage(channel, username, text, metadata)
    
    -- Route the message
    local skipDefaultAck = Server.RouteMessage(player, channel, message, metadata, ack)
    
    -- Send default ack if not handled by route function
    if not skipDefaultAck and ack then
        ack({ success = true, messageId = message.id })
    end
end)

-- Handle typing indicator events
chatSocket:onServer("typing", function(player, data, context, ack)
    if data.isTyping then
        Server.HandleTypingStart(player, data)
    else
        Server.HandleTypingStop(player, data)
    end
end)

-- Handle player list requests
chatSocket:onServer("getPlayers", function(player, data, context, ack)
    if ack then
        local players = Server.BuildPlayerList()
        ack({ players = players })
    end
end)

-- ==========================================================
-- System Messages
-- ==========================================================

--- Broadcast a system message to all connected players
---@param text string
---@param color table? Optional color override {r, g, b}
function Server.BroadcastSystemMessage(text, color)
    -- Only broadcast if socket is connected (SP) or has connections (MP)
    if not chatSocket.connected and Server.TableIsEmpty(chatSocket.connections or {}) then
        Socket.Log("Skipping broadcast (not connected): " .. text)
        return
    end
    
    local msg = ChatSystem.CreateSystemMessage(text, ChatSystem.ChannelType.GLOBAL)
    if color then
        msg.color = color
    end
    chatSocket:broadcast():emit("message", msg)
end

-- ==========================================================
-- Player Events (Quit, Death)
-- ==========================================================

-- Player quit/disconnected from server (detected by KoniLib polling)
local function OnPlayerQuit(username)
    -- Cleanup typing indicators
    Server.ClearPlayerTyping(username, nil)
    
    -- Cleanup player data
    Server.playerData[username] = nil
end

-- Player death handler - broadcast stop typing for all channels they were typing in
local function OnPlayerDeath(player)
    if not player then return end
    local username = player:getUsername()
    if not username then return end
    
    -- Clear typing indicators for this player
    Server.ClearPlayerTyping(username, player)
end

-- Use KoniLib events for cleanup
KoniLib.Events.OnPlayerQuit:Add(OnPlayerQuit)
Events.OnPlayerDeath.Add(OnPlayerDeath)

print("[ChatSystem] Server Loaded")
