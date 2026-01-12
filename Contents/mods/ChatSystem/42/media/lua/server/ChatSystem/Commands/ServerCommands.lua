-- Server Commands: servermsg
-- Requires OWNER access level
if isClient() then return end
if not isServer() then return end

require "ChatSystem/CommandAPI"
require "ChatSystem/CommandServer"

local Commands = ChatSystem.Commands
local Server = Commands.Server

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
        local message = context.rawArgs
        if not message or message == "" then
            Server.ReplyError(context.player, "Usage: /servermsg <message>", context.channel)
            return
        end
        
        Server.Broadcast(message, ChatSystem.ChannelType.GLOBAL)
    end
})

print("[ChatSystem] Server commands loaded")
