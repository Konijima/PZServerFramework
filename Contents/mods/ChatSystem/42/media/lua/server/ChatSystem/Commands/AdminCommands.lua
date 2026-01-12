-- Admin Commands: kick, announce, teleport, bring, god, invisible
-- Requires MODERATOR or ADMIN access level
if isClient() then return end
if not isServer() then return end

require "ChatSystem/CommandAPI"
require "ChatSystem/CommandServer"

local Commands = ChatSystem.Commands
local Server = Commands.Server

-- ==========================================================
-- Kick Command (Moderator+)
-- ==========================================================

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
        
        -- Announce kick to all players (GLOBAL)
        Server.Broadcast(targetName .. " was kicked: " .. reason, ChatSystem.ChannelType.GLOBAL)
        print("[ChatSystem.Commands] " .. context.username .. " kicked " .. targetName .. ": " .. reason)
    end
})

-- ==========================================================
-- Announce Command (Admin+)
-- ==========================================================

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

-- ==========================================================
-- Teleport Command (Admin+)
-- ==========================================================

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
        local chatSocket = KoniLib.Socket.of("/chat")
        
        -- Try coordinates first
        local x, y, z = targetStr:match("([%d.-]+)[,:%s]+([%d.-]+)[,:%s]*([%d.-]*)")
        if x and y then
            x, y = tonumber(x), tonumber(y)
            z = tonumber(z) or context.player:getZ()
            
            if x and y then
                -- Emit to admin's client for coordinate teleport
                -- Vanilla command will send its own confirmation
                chatSocket:to(context.player):emit("teleport", {
                    type = "goto_coords",
                    x = x,
                    y = y,
                    z = z
                })
                return
            end
        end
        
        -- Try player name
        local target, err = Server.FindPlayer(targetStr)
        if not target then
            Server.ReplyError(context.player, err, context.channel)
            return
        end
        
        -- Emit to admin's client for player teleport
        -- Vanilla command will send its own confirmation
        chatSocket:to(context.player):emit("teleport", {
            type = "goto_player",
            target = target:getDisplayName()  -- vanilla uses displayName, not username
        })
    end
})

-- ==========================================================
-- Bring Command (Admin+)
-- ==========================================================

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
        
        -- Emit to admin's client - they will use vanilla /teleportplayer command
        -- This works because vanilla commands are processed by Java server-side
        local chatSocket = KoniLib.Socket.of("/chat")
        chatSocket:to(context.player):emit("teleport", {
            type = "bring",
            target = target:getDisplayName()  -- vanilla uses displayName, not username
        })
        
        -- Vanilla command will send its own confirmation, so we only notify the target
        Server.Reply(target, "You have been teleported to " .. context.username, nil, context.channel)
    end
})

-- ==========================================================
-- God Mode Command (Admin+)
-- ==========================================================

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

-- ==========================================================
-- Invisible Command (Admin+)
-- ==========================================================

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

print("[ChatSystem] Admin commands loaded")
