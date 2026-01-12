KoniLib = KoniLib or {}
KoniLib.MP = {}

local MP = KoniLib.MP
local Log = require("KoniLib/Log")

MP.Handlers = {}

-- Call to register a handler for a command
-- callback signature: function(player, args)
function MP.Register(module, command, callback)
    if not MP.Handlers[module] then
        MP.Handlers[module] = {}
    end
    MP.Handlers[module][command] = callback
    Log.Print("MP", "Registered handler: " .. module .. "." .. command)
end

-- Call to send a command
-- If Singleplayer: Executes immediately
-- If Client: Sends to Server
-- If Server: Sends to Client(s)
-- @param player: The player object. 
--          - On Client sending to Server: This is the local player (sender).
--          - On Server sending to Client: This is the target player (nil for broadcast).
--          - On SP: This is the player context passed to the handler.
function MP.Send(player, module, command, args)
    if not args then args = {} end
    
    if isClient() then
        -- Client -> Server
        local p = player or getPlayer()
        -- MP.Log("Client -> Server: " .. module .. "." .. command)
        sendClientCommand(p, module, command, args)
        
    elseif isServer() then
        -- Server -> Client
        if player then
            -- MP.Log("Server -> Client(" .. tostring(player:getUsername()) .. "): " .. module .. "." .. command)
            sendServerCommand(player, module, command, args)
        else
            -- MP.Log("Server -> All: " .. module .. "." .. command)
            sendServerCommand(module, command, args)
        end
        
    else
        -- Singleplayer
        -- MP.Log("SP Loopback: " .. module .. "." .. command)
        local p = player or getPlayer()
        MP.Resolve(p, module, command, args)
    end
end

-- Internal function to find and execute a handler
function MP.Resolve(player, module, command, args)
    if MP.Handlers[module] and MP.Handlers[module][command] then
        -- MP.Log("Resolving: " .. module .. "." .. command)
        MP.Handlers[module][command](player, args)
    else
        -- Only log valid handlers to avoid spamming if other mods use the same event? 
        -- Actually we filter by module first, so safe to warn.
        -- But remember this hears ALL commands on the bus if using the generic event?
        -- Wait, Events.OnServerCommand fires for specific module? No, it fires for all.
        -- We must check if it's OUR module before logging warning.
        if MP.Handlers[module] then 
             Log.Print("MP", "Warning: Handler defined for module '"..module.."' but command '"..command.."' is missing.")
        end
    end
end

-- ==========================================================
-- Event Integration
-- ==========================================================

-- Client receiving from Server
local function OnServerCommand(module, command, args)
    if MP.Handlers[module] then
        MP.Resolve(getPlayer(), module, command, args)
    end
end

-- Server receiving from Client
local function OnClientCommand(module, command, player, args)
    if MP.Handlers[module] then
        MP.Resolve(player, module, command, args)
    end
end

if isClient() then
    Events.OnServerCommand.Add(OnServerCommand)
elseif isServer() then
    Events.OnClientCommand.Add(OnClientCommand)
end

return KoniLib.MP
