if isClient() then return end

require "ChatSystem/CommandAPI"
require "ChatSystem/CommandServer"

-- ==========================================================
-- Built-in Commands
-- ==========================================================

local Commands = ChatSystem.Commands
local Server = Commands.Server

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

-- ==========================================================
-- General Commands (All Players)
-- ==========================================================

-- Help command
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

-- Online players command
Commands.Register({
    name = "online",
    aliases = { "players", "who" },
    description = "Show online players",
    accessLevel = Commands.AccessLevel.PLAYER,
    category = "general",
    handler = function(context)
        local onlinePlayers = getOnlinePlayers()
        
        if not onlinePlayers or onlinePlayers:size() == 0 then
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
        
        local totalCount = onlinePlayers:size()
        
        for i = 0, totalCount - 1 do
            local p = onlinePlayers:get(i)
            local name = p:getUsername()
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

-- Roll dice command
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
        
        local displayName = getPlayerDisplayName(context.player)
        local result = displayName .. " rolled " .. count .. "d" .. sides .. ": "
        if count > 1 then
            result = result .. "[" .. table.concat(rolls, ", ") .. "] = " .. total
        else
            result = result .. total
        end
        
        -- Broadcast to the channel the command was sent from
        Server.Broadcast(result, context.channel, context.player)
    end
})

-- Me action command
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
        local action = context.rawArgs
        if not action or action == "" then
            Server.ReplyError(context.player, "Usage: /me <action>", context.channel)
            return
        end
        
        local displayName = getPlayerDisplayName(context.player)
        local msg = ChatSystem.CreateMessage(
            ChatSystem.ChannelType.LOCAL,
            displayName,
            "* " .. displayName .. " " .. action .. " *"
        )
        msg.metadata.isEmote = true
        msg.color = { r = 1, g = 0.8, b = 0.5 } -- Orange for emotes
        
        -- Send to nearby players using broadcast (works in both SP and MP)
        local chatSocket = KoniLib.Socket.of("/chat")
        local x, y, z = context.player:getX(), context.player:getY(), context.player:getZ()
        local range = ChatSystem.Settings.localChatRange
        
        local onlinePlayers = getOnlinePlayers()
        
        -- SP mode: onlinePlayers is empty userdata or nil
        if not onlinePlayers or onlinePlayers:size() == 0 then
            chatSocket:to(context.player):emit("message", msg)
            return
        end
        
        -- MP mode: Send to players in range
        for i = 0, onlinePlayers:size() - 1 do
            local p = onlinePlayers:get(i)
            local px, py, pz = p:getX(), p:getY(), p:getZ()
            
            if math.abs(pz - z) <= 1 then
                local dist = math.sqrt((px - x)^2 + (py - y)^2)
                if dist <= range then
                    chatSocket:to(p):emit("message", msg)
                end
            end
        end
    end
})

-- ==========================================================
-- Admin Commands
-- ==========================================================

-- Kick command
Commands.Register({
    name = "kick",
    description = "Kick a player from the server",
    usage = "<player> [reason]",
    accessLevel = Commands.AccessLevel.MODERATOR,
    category = "admin",
    args = {
        { name = "player", type = Commands.ArgType.PLAYER, required = true },
        { name = "reason", type = Commands.ArgType.STRING, required = false, default = "Kicked by admin" }
    },
    handler = function(context)
        local target, err = Server.FindPlayer(context.argList[1])
        if not target then
            Server.ReplyError(context.player, err, context.channel)
            return
        end
        
        local reason = context.rawArgs:match("^%S+%s+(.+)$") or context.args.reason
        local targetName = target:getUsername()
        
        -- Can't kick yourself
        if targetName == context.username then
            Server.ReplyError(context.player, "You can't kick yourself", context.channel)
            return
        end
        
        -- Can't kick higher ranked staff
        local targetAccess = Server.GetPlayerAccessLevel(target)
        if Server.HasAccess(target, context.accessLevel) and targetAccess ~= Commands.AccessLevel.PLAYER then
            Server.ReplyError(context.player, "You can't kick staff members", context.channel)
            return
        end
        
        -- Execute kick
        target:getNetworkCharacter():kick(reason)
        
        Server.Broadcast(targetName .. " was kicked: " .. reason)
        print("[ChatSystem.Commands] " .. context.username .. " kicked " .. targetName .. ": " .. reason)
    end
})

-- Announce command
Commands.Register({
    name = "announce",
    aliases = { "broadcast", "bc" },
    description = "Send a server-wide announcement",
    usage = "<message>",
    accessLevel = Commands.AccessLevel.ADMIN,
    category = "admin",
    args = {
        { name = "message", type = Commands.ArgType.STRING, required = true }
    },
    handler = function(context)
        local message = context.rawArgs
        if not message or message == "" then
            Server.ReplyError(context.player, "Usage: /announce <message>", context.channel)
            return
        end
        
        local msg = ChatSystem.CreateSystemMessage("[ANNOUNCEMENT] " .. message, ChatSystem.ChannelType.GLOBAL)
        msg.color = { r = 1, g = 0.8, b = 0.2 } -- Gold
        
        local chatSocket = KoniLib.Socket.of("/chat")
        chatSocket:broadcast():emit("message", msg)
        
        print("[ChatSystem.Commands] Announcement by " .. context.username .. ": " .. message)
    end
})

-- Teleport command
Commands.Register({
    name = "tp",
    aliases = { "teleport", "goto" },
    description = "Teleport to a player or coordinates",
    usage = "<player|x,y,z>",
    accessLevel = Commands.AccessLevel.ADMIN,
    category = "admin",
    args = {
        { name = "target", type = Commands.ArgType.STRING, required = true }
    },
    handler = function(context)
        local targetStr = context.args.target
        
        -- Try coordinates first
        local x, y, z = targetStr:match("([%d.-]+)[,:%s]+([%d.-]+)[,:%s]*([%d.-]*)")
        if x and y then
            x, y = tonumber(x), tonumber(y)
            z = tonumber(z) or context.player:getZ()
            
            if x and y then
                context.player:setX(x)
                context.player:setY(y)
                context.player:setZ(z)
                Server.ReplySuccess(context.player, "Teleported to " .. x .. ", " .. y .. ", " .. z, context.channel)
                return
            end
        end
        
        -- Try player name
        local target, err = Server.FindPlayer(targetStr)
        if not target then
            Server.ReplyError(context.player, err, context.channel)
            return
        end
        
        context.player:setX(target:getX())
        context.player:setY(target:getY())
        context.player:setZ(target:getZ())
        
        Server.ReplySuccess(context.player, "Teleported to " .. target:getUsername(), context.channel)
    end
})

-- Bring command
Commands.Register({
    name = "bring",
    aliases = { "summon", "tphere" },
    description = "Teleport a player to you",
    usage = "<player>",
    accessLevel = Commands.AccessLevel.ADMIN,
    category = "admin",
    args = {
        { name = "player", type = Commands.ArgType.PLAYER, required = true }
    },
    handler = function(context)
        local target, err = Server.FindPlayer(context.args.player)
        if not target then
            Server.ReplyError(context.player, err, context.channel)
            return
        end
        
        local targetName = target:getUsername()
        
        if targetName == context.username then
            Server.ReplyError(context.player, "You can't teleport yourself to yourself", context.channel)
            return
        end
        
        target:setX(context.player:getX())
        target:setY(context.player:getY())
        target:setZ(context.player:getZ())
        
        Server.ReplySuccess(context.player, "Teleported " .. targetName .. " to you", context.channel)
        Server.Reply(target, "You have been teleported to " .. context.username, nil, context.channel)
    end
})

-- God mode command
Commands.Register({
    name = "god",
    aliases = { "godmode" },
    description = "Toggle god mode",
    accessLevel = Commands.AccessLevel.ADMIN,
    category = "admin",
    handler = function(context)
        local player = context.player
        local isGod = player:isGodMod()
        player:setGodMod(not isGod)
        
        Server.ReplySuccess(context.player, "God mode: " .. (not isGod and "ENABLED" or "DISABLED"), context.channel)
    end
})

-- Invisible command
Commands.Register({
    name = "invisible",
    aliases = { "invis", "vanish" },
    description = "Toggle invisibility",
    accessLevel = Commands.AccessLevel.ADMIN,
    category = "admin",
    handler = function(context)
        local player = context.player
        local isInvis = player:isInvisible()
        player:setInvisible(not isInvis)
        
        Server.ReplySuccess(context.player, "Invisibility: " .. (not isInvis and "ENABLED" or "DISABLED"), context.channel)
    end
})

-- ==========================================================
-- Server Commands (Owner)
-- ==========================================================

-- Server message command
Commands.Register({
    name = "servermsg",
    aliases = { "sm" },
    description = "Send a server message (appears as system)",
    usage = "<message>",
    accessLevel = Commands.AccessLevel.OWNER,
    category = "server",
    args = {
        { name = "message", type = Commands.ArgType.STRING, required = true }
    },
    handler = function(context)
        local message = context.rawArgs
        if not message or message == "" then
            Server.ReplyError(context.player, "Usage: /servermsg <message>", context.channel)
            return
        end
        
        Server.Broadcast(message, ChatSystem.ChannelType.GLOBAL)
    end
})

-- Save command (MP only)
-- Note: Full world save is not exposed to Lua API. Use RCON or server console instead.
Commands.Register({
    name = "save",
    aliases = { "saveworld" },
    description = "Trigger ModData save (full world save requires RCON/console)",
    accessLevel = Commands.AccessLevel.OWNER,
    category = "server",
    handler = function(context)
        if isServer() then
            -- Full world save is not available via Lua API
            -- We can only trigger ModData saves for mods
            ModData.save()
            Server.ReplySuccess(context.player, "ModData saved. For full world save, use RCON command 'save' or server console.", context.channel)
            print("[ChatSystem.Commands] ModData saved by " .. context.username)
        else
            Server.ReplyError(context.player, "This command is only available on multiplayer servers", context.channel)
        end
    end
})

print("[ChatSystem] Default Commands Loaded")
