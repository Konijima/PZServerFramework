-- Server Commands: servermsg
-- Requires OWNER access level
if isClient() or not isServer() then return end

require "ChatSystem/CommandAPI"

local Commands = ChatSystem.Commands
-- NOTE: We access ChatSystem.Commands.Server at runtime inside handlers
-- because it's not available at file load time (Server.lua merges it later)

-- ==========================================================
-- Server Message Command (Owner)
-- ==========================================================

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
        local Server = ChatSystem.Commands.Server
        local message = context.rawArgs
        if not message or message == "" then
            Server.ReplyError(context.player, "Usage: /servermsg <message>", context.channel)
            return
        end
        
        Server.Broadcast(message, ChatSystem.ChannelType.GLOBAL)
    end
})

print("[ChatSystem] Server commands loaded")
