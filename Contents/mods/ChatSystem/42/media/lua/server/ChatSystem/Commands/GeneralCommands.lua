-- General Commands: help, online, roll, me
-- Available to all players
if isClient() or not isServer() then return end

require "ChatSystem/CommandAPI"
require "ChatSystem/PlayerUtils"
require "KoniLib/Player"

local Commands = ChatSystem.Commands
local PlayerUtils = ChatSystem.PlayerUtils
local Player = KoniLib.Player
local ChannelType = ChatSystem.ChannelType
-- NOTE: We access ChatSystem.Commands.Server at runtime inside handlers
-- because it's not available at file load time (Server.lua merges it later)

--- Get the appropriate display name for a player based on channel
--- Staff and Admin channels always use username for accountability
---@param player IsoPlayer
---@param channel string
---@return string
local function getDisplayNameForChannel(player, channel)
    if channel == ChannelType.STAFF or channel == ChannelType.ADMIN then
        return Player.GetUsername(player)
    end
    return PlayerUtils.GetDisplayName(player)
end

-- ==========================================================
-- Help Command
-- ==========================================================

Commands.Register({
    name = "help",
    aliases = { "h", "commands", "?" },
    description = "Show available commands or help for a specific command",
    usage = "[command]",
    accessLevel = Commands.AccessLevel.PLAYER,
    category = "general",
    args = {
        { name = "command", type = Commands.ArgType.STRING, required = false }
    },
    handler = function(context)
        local cmdName = context.args.command
        
        local Server = ChatSystem.Commands.Server
        if cmdName then
            -- Show help for specific command
            local cmd = Commands.Get(cmdName)
            if not cmd then
                Server.ReplyError(context.player, "Unknown command: /" .. cmdName, context.channel)
                return
            end
            
            local help = Commands.FormatUsage(cmd) .. " - " .. cmd.description
            if cmd.aliases and #cmd.aliases > 0 then
                help = help .. " (Aliases: /" .. table.concat(cmd.aliases, ", /") .. ")"
            end
            Server.Reply(context.player, help, nil, context.channel)
        else
            -- Show all commands
            local categories = Commands.GetCategories()
            local output = "Available commands:"
            
            for _, category in ipairs(categories) do
                local cmds = Commands.GetByCategory(category)
                local names = {}
                
                for _, cmd in ipairs(cmds) do
                    -- Only show commands the player has access to
                    if Server.HasAccess(context.player, cmd.accessLevel) then
                        table.insert(names, "/" .. cmd.name)
                    end
                end
                
                if #names > 0 then
                    output = output .. "\n[" .. category:upper() .. "]: " .. table.concat(names, ", ")
                end
            end
            
            output = output .. "\n\nUse '/help [command]' <SPACE> for more info"
            Server.Reply(context.player, output, nil, context.channel)
        end
    end
})

-- ==========================================================
-- Online Command
-- ==========================================================

Commands.Register({
    name = "online",
    aliases = { "players", "who" },
    description = "Show online players",
    accessLevel = Commands.AccessLevel.PLAYER,
    category = "general",
    handler = function(context)
        local Server = ChatSystem.Commands.Server
        local onlinePlayers = Player.GetOnlinePlayers()
        
        if #onlinePlayers == 0 then
            -- SP mode
            Server.Reply(context.player, "Online: " .. context.username .. " (you)", nil, context.channel)
            return
        end
        
        -- Group players by access level
        local groups = {
            { level = Commands.AccessLevel.OWNER, label = "Owner", players = {} },
            { level = Commands.AccessLevel.ADMIN, label = "Admins", players = {} },
            { level = Commands.AccessLevel.MODERATOR, label = "Moderators", players = {} },
            { level = Commands.AccessLevel.PLAYER, label = "Players", players = {} }
        }
        
        local totalCount = #onlinePlayers
        
        for _, p in ipairs(onlinePlayers) do
            local name = Player.GetUsername(p)
            local accessLevel = Server.GetPlayerAccessLevel(p)
            
            -- Mark current player
            if name == context.username then
                name = name .. " (you)"
            end
            
            -- Add to appropriate group
            for _, group in ipairs(groups) do
                if accessLevel == group.level then
                    table.insert(group.players, name)
                    break
                end
            end
        end
        
        -- Build output
        local output = "=== Online Players (" .. totalCount .. ") ==="
        
        for _, group in ipairs(groups) do
            if #group.players > 0 then
                output = output .. "\n[" .. group.label .. "] " .. table.concat(group.players, ", ")
            end
        end
        
        Server.Reply(context.player, output, nil, context.channel)
    end
})

-- ==========================================================
-- Roll Command
-- ==========================================================

Commands.Register({
    name = "roll",
    aliases = { "dice" },
    description = "Roll dice (e.g., /roll 2d6)",
    usage = "[dice]",
    accessLevel = Commands.AccessLevel.PLAYER,
    category = "general",
    args = {
        { name = "dice", type = Commands.ArgType.STRING, required = false, default = "1d6" }
    },
    handler = function(context)
        local Server = ChatSystem.Commands.Server
        local diceStr = context.args.dice or "1d6"
        
        -- Parse dice notation (NdM)
        local count, sides = diceStr:match("(%d+)d(%d+)")
        if not count then
            -- Try just a number (dN)
            sides = diceStr:match("d(%d+)")
            count = 1
        end
        
        count = tonumber(count) or 1
        sides = tonumber(sides) or 6
        
        -- Limit dice
        count = math.min(count, 10)
        sides = math.min(sides, 100)
        
        local total = 0
        local rolls = {}
        
        for i = 1, count do
            local roll = ZombRand(1, sides + 1)
            total = total + roll
            table.insert(rolls, roll)
        end
        
        local displayName = getDisplayNameForChannel(context.player, context.channel)
        local result = displayName .. " rolled " .. count .. "d" .. sides .. ": "
        if count > 1 then
            result = result .. "[" .. table.concat(rolls, ", ") .. "] = " .. total
        else
            result = result .. total
        end
        
        -- Broadcast to the channel the command was sent from
        Server.Broadcast(result, context.channel, context.player)
        
        return result
    end
})

-- ==========================================================
-- Me (Emote) Command
-- ==========================================================

Commands.Register({
    name = "me",
    aliases = { "emote", "action" },
    description = "Perform a roleplay action",
    usage = "<action>",
    accessLevel = Commands.AccessLevel.PLAYER,
    category = "general",
    args = {
        { name = "action", type = Commands.ArgType.STRING, required = true }
    },
    handler = function(context)
        local Server = ChatSystem.Commands.Server
        local action = context.rawArgs
        if not action or action == "" then
            Server.ReplyError(context.player, "Usage: /me <action>", context.channel)
            return
        end
        
        local displayName = getDisplayNameForChannel(context.player, context.channel)
        local emoteText = "* " .. displayName .. " " .. action .. " *"
        
        -- Broadcast to the active channel as a styled message
        local msg = ChatSystem.CreateMessage(
            context.channel,
            displayName,
            emoteText
        )
        msg.metadata.isEmote = true
        msg.color = { r = 1, g = 0.8, b = 0.5 } -- Orange for emotes
        
        -- Use the same broadcast logic as regular messages
        local chatSocket = KoniLib.Socket.of("/chat")
        
        if context.channel == ChatSystem.ChannelType.LOCAL then
            -- LOCAL: Send to nearby players
            local x, y, z = context.player:getX(), context.player:getY(), context.player:getZ()
            local range = ChatSystem.Settings.localChatRange
            local onlinePlayers = Player.GetOnlinePlayers()
            
            if #onlinePlayers == 0 then
                chatSocket:to(context.player):emit("message", msg)
                return
            end
            
            for _, p in ipairs(onlinePlayers) do
                local px, py, pz = p:getX(), p:getY(), p:getZ()
                if math.abs(pz - z) <= 1 then
                    local dist = math.sqrt((px - x)^2 + (py - y)^2)
                    if dist <= range then
                        chatSocket:to(p):emit("message", msg)
                    end
                end
            end
        elseif context.channel == ChatSystem.ChannelType.GLOBAL then
            -- GLOBAL: Broadcast to all
            chatSocket:broadcast():emit("message", msg)
        else
            -- Other channels (faction, safehouse, admin, staff, etc): Use Server.Broadcast
            Server.Broadcast(emoteText, context.channel, context.player)
        end
    end
})

print("[ChatSystem] General commands loaded")
