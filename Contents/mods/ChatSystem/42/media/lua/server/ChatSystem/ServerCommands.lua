-- ChatSystem Server Commands Module
-- Handles command parsing, execution, and responses
-- Returns a module table to be merged into ChatSystem.Commands.Server

require "ChatSystem/Definitions"
require "ChatSystem/CommandAPI"
require "KoniLib/Player"

-- Load command files
require "ChatSystem/Commands/GeneralCommands"
require "ChatSystem/Commands/AdminCommands"
require "ChatSystem/Commands/ServerCommands"

print("[ChatSystem] All commands loaded")

local Module = {}
local Commands = ChatSystem.Commands

-- ==========================================================
-- Access Level Checking
-- ==========================================================

-- Access level hierarchy (higher index = more permissions)
local accessHierarchy = {
    [Commands.AccessLevel.PLAYER] = 1,
    [Commands.AccessLevel.MODERATOR] = 2,
    [Commands.AccessLevel.ADMIN] = 3,
    [Commands.AccessLevel.OWNER] = 4,
}

--- Get player's access level (maps to ChatSystem command levels)
---@param player IsoPlayer
---@return string ChatSystem access level (PLAYER, MODERATOR, ADMIN, OWNER)
function Module.GetPlayerAccessLevel(player)
    if not player then
        return Commands.AccessLevel.PLAYER
    end
    
    -- In singleplayer, player is owner
    if not isClient() and not isServer() then
        return Commands.AccessLevel.OWNER
    end
    
    local accessLevel = KoniLib.Player.GetAccessLevel(player)
    if not accessLevel or accessLevel == "none" then
        return Commands.AccessLevel.PLAYER
    end
    
    -- Map PZ access levels to our command system
    local mapping = {
        ["admin"] = Commands.AccessLevel.OWNER,
        ["moderator"] = Commands.AccessLevel.MODERATOR,
        ["overseer"] = Commands.AccessLevel.MODERATOR,
        ["gm"] = Commands.AccessLevel.ADMIN,
        ["observer"] = Commands.AccessLevel.MODERATOR,
    }
    
    return mapping[accessLevel] or Commands.AccessLevel.PLAYER
end

--- Check if player has required access level
---@param player IsoPlayer
---@param requiredLevel string
---@return boolean
function Module.HasAccess(player, requiredLevel)
    local playerLevel = Module.GetPlayerAccessLevel(player)
    local playerRank = accessHierarchy[playerLevel] or 0
    local requiredRank = accessHierarchy[requiredLevel] or 0
    
    return playerRank >= requiredRank
end

-- ==========================================================
-- Command Execution
-- ==========================================================

--- Execute a command
---@param player IsoPlayer
---@param commandText string The full command string (including /)
---@param options table|nil Optional execution options { channel = string }
---@return boolean success
---@return string|nil error
function Module.Execute(player, commandText, options)
    if not player then
        return false, "No player"
    end
    
    local name, args, rawArgs = Commands.Parse(commandText)
    
    if not name then
        return false, "Invalid command"
    end
    
    local cmd = Commands.Get(name)
    
    if not cmd then
        return false, "Unknown command: /" .. name
    end
    
    -- Check access level
    if not Module.HasAccess(player, cmd.accessLevel) then
        return false, "You don't have permission to use this command"
    end
    
    -- Validate and convert arguments
    local validatedArgs = {}
    local argDefs = cmd.args or {}
    
    for i, argDef in ipairs(argDefs) do
        local value = args[i]
        
        if not value or value == "" then
            -- Check if required
            if argDef.required ~= false then
                local usage = Commands.FormatUsage(cmd)
                return false, "Missing required argument: " .. argDef.name .. "\nUsage: " .. usage
            else
                -- Use default value
                validatedArgs[argDef.name] = argDef.default
            end
        else
            -- Validate type
            local valid, converted = Commands.ValidateArg(value, argDef.type)
            if not valid then
                return false, "Invalid " .. argDef.type .. " for argument: " .. argDef.name
            end
            validatedArgs[argDef.name] = converted
        end
    end
    
    -- Build context
    local context = {
        player = player,
        username = player:getUsername(),
        accessLevel = Module.GetPlayerAccessLevel(player),
        args = validatedArgs,
        rawArgs = rawArgs,
        argList = args,
        command = cmd,
        channel = options and options.channel or ChatSystem.ChannelType.LOCAL,
    }
    
    -- Execute the handler
    local success, result = pcall(cmd.handler, context)
    
    if not success then
        print("[ChatSystem.Commands] Error executing /" .. name .. ": " .. tostring(result))
        return false, "Command error: " .. tostring(result)
    end
    
    -- Log command execution
    if result then
        print("[ChatSystem.Commands] " .. player:getUsername() .. " executed: " .. commandText .. " -> " .. tostring(result))
    else
        print("[ChatSystem.Commands] " .. player:getUsername() .. " executed: " .. commandText)
    end
    
    -- Trigger event
    if Commands.Events then
        Commands.Events.OnCommandExecuted:Trigger(player, cmd, context)
    end
    
    return true, result
end

-- ==========================================================
-- Response Helpers
-- ==========================================================

--- Send a response message to a player
---@param player IsoPlayer
---@param text string
---@param isError boolean?
---@param channel string?
function Module.Reply(player, text, isError, channel)
    local Server = ChatSystem.Server
    -- Use provided channel or default to LOCAL for command responses
    local ch = channel or ChatSystem.ChannelType.LOCAL
    local msg = ChatSystem.CreateSystemMessage(text, ch)
    if isError then
        msg.color = { r = 1, g = 0.3, b = 0.3 } -- Red for errors
    else
        msg.color = { r = 0.5, g = 1, b = 0.5 } -- Green for success
    end
    msg.metadata.isCommandResponse = true
    Server.chatSocket:to(player):emit("message", msg)
end

--- Send an error response
---@param player IsoPlayer
---@param text string
---@param channel string?
function Module.ReplyError(player, text, channel)
    Module.Reply(player, text, true, channel)
end

--- Send a success response
---@param player IsoPlayer
---@param text string
---@param channel string?
function Module.ReplySuccess(player, text, channel)
    Module.Reply(player, text, false, channel)
end

--- Broadcast a message based on channel type
---@param text string
---@param channel string?
---@param sourcePlayer IsoPlayer? Source player for LOCAL channel proximity
function Module.Broadcast(text, channel, sourcePlayer)
    local Server = ChatSystem.Server
    local ch = channel or ChatSystem.ChannelType.LOCAL
    local msg = ChatSystem.CreateSystemMessage(text, ch)
    
    local onlinePlayers = KoniLib.Player.GetOnlinePlayers()
    
    -- SP mode: send directly to player since broadcast excludes sender
    if #onlinePlayers == 0 then
        local player = getPlayer()
        if player then
            Server.chatSocket:to(player):emit("message", msg)
        end
        return
    end
    
    -- Handle different channel types
    if ch == ChatSystem.ChannelType.LOCAL and sourcePlayer then
        -- LOCAL: send to players in range
        local x, y, z = sourcePlayer:getX(), sourcePlayer:getY(), sourcePlayer:getZ()
        local range = ChatSystem.Settings.localChatRange or 30
        
        for _, player in ipairs(onlinePlayers) do
            local px, py, pz = player:getX(), player:getY(), player:getZ()
            
            -- Check Z level (same floor or adjacent)
            if math.abs(pz - z) <= 1 then
                local dist = math.sqrt((px - x)^2 + (py - y)^2)
                if dist <= range then
                    Server.chatSocket:to(player):emit("message", msg)
                end
            end
        end
    elseif ch == ChatSystem.ChannelType.GLOBAL then
        -- GLOBAL: broadcast to all
        Server.chatSocket:broadcast():emit("message", msg)
    else
        -- Default: broadcast to all (fallback for other channels)
        Server.chatSocket:broadcast():emit("message", msg)
    end
end

--- Send a message to all players with a specific access level
---@param text string
---@param minAccessLevel string
function Module.BroadcastToAccess(text, minAccessLevel)
    local onlinePlayers = KoniLib.Player.GetOnlinePlayers()
    
    -- SP mode: onlinePlayers is empty
    if #onlinePlayers == 0 then
        local player = getPlayer()
        if player and Module.HasAccess(player, minAccessLevel) then
            Module.Reply(player, text)
        end
        return
    end
    
    for _, player in ipairs(onlinePlayers) do
        if Module.HasAccess(player, minAccessLevel) then
            Module.Reply(player, text)
        end
    end
end

-- ==========================================================
-- Player Lookup Helper
-- ==========================================================

--- Find a player by name (partial match)
---@param name string
---@return IsoPlayer|nil player
---@return string|nil error
function Module.FindPlayer(name)
    if not name or name == "" then
        return nil, "No player name provided"
    end
    
    name = name:lower()
    
    local onlinePlayers = KoniLib.Player.GetOnlinePlayers()
    
    -- SP mode: onlinePlayers is empty
    if #onlinePlayers == 0 then
        local player = getPlayer()
        if player and KoniLib.Player.GetUsername(player):lower():find(name) then
            return player
        end
        return nil, "Player not found"
    end
    
    local exactMatch = nil
    local partialMatches = {}
    
    for _, player in ipairs(onlinePlayers) do
        local username = KoniLib.Player.GetUsername(player):lower()
        
        if username == name then
            exactMatch = player
            break
        elseif username:find(name) then
            table.insert(partialMatches, player)
        end
    end
    
    if exactMatch then
        return exactMatch
    end
    
    if #partialMatches == 1 then
        return partialMatches[1]
    elseif #partialMatches > 1 then
        local names = {}
        for _, p in ipairs(partialMatches) do
            table.insert(names, p:getUsername())
        end
        return nil, "Multiple matches: " .. table.concat(names, ", ")
    end
    
    return nil, "Player not found: " .. name
end

-- ==========================================================
-- Command Message Handler
-- ==========================================================

--- Check if a message is a command and handle it
---@param player IsoPlayer
---@param text string
---@param channel string|nil The source channel the command was sent from
---@return boolean wasCommand
function Module.HandleMessageAsCommand(player, text, channel)
    if not Commands.IsCommand(text) then
        return false
    end
    
    -- Check if this is a channel command (like /g, /l, etc.)
    for channelType, commands in pairs(ChatSystem.ChannelCommands) do
        for _, cmd in ipairs(commands) do
            if luautils.stringStarts(text:lower(), cmd:lower()) then
                -- This is a channel command, not a custom command
                return false
            end
        end
    end
    
    -- This is a custom command
    local success, result = Module.Execute(player, text, { channel = channel })
    
    if not success then
        Module.ReplyError(player, result or "Command failed", channel)
    end
    
    return true
end

return Module
