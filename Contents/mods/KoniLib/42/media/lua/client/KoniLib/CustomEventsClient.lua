if isServer() then return end
if not KoniLib then KoniLib = {} end
local MP = require("KoniLib/MP")

-- Events are defined in shared/KoniLib/CustomEvents.lua and registered using KoniLib/Event.lua

local hasNetworkFired = false
local initializedPlayers = {}

---Logic to trigger OnNetworkAvailable
local function onTickCheck()
    if hasNetworkFired then return end
    
    local player = getSpecificPlayer(0)
    if player then
        hasNetworkFired = true
        if KoniLib.Events and KoniLib.Events.OnNetworkAvailable then
             KoniLib.Events.OnNetworkAvailable:Trigger(0)
             MP.Log("Triggered OnNetworkAvailable")
        else
            -- Fallback if something went wrong with loading
            triggerEvent("OnNetworkAvailable", 0)
            MP.Log("Triggered OnNetworkAvailable (Fallback)")
        end

        -- Stop checking
        Events.OnTick.Remove(onTickCheck)
    end
end

---Logic to trigger OnPlayerRespawn
local function onCreatePlayer(playerIndex, player)
    -- OnCreatePlayer key-point:
    -- On Client: fires for each player created (local and remote potentially, but usually local are prioritized).
    -- Ensure we process local players for respawn logic.
    if player and not player:isLocalPlayer() then return end
    
    -- OnCreatePlayer fires on initial login AND subsequent respawns.
    local isRespawn = false
    if not initializedPlayers[playerIndex] then
        -- First time we see this player index -> This is the initial Join
        initializedPlayers[playerIndex] = true
        isRespawn = false
        
        local name = player and player:getUsername() or "Unknown"
        MP.Log("Initial player creation detected (Join) for Player " .. tostring(playerIndex) .. " ("..name..")")
    else
        -- We have seen this index before -> This must be a respawn
        isRespawn = true
        MP.Log("Respawn detected for Player " .. tostring(playerIndex))
    end

    if KoniLib.Events and KoniLib.Events.OnPlayerInit then
        KoniLib.Events.OnPlayerInit:Trigger(playerIndex, player, isRespawn)
    else
        triggerEvent("OnPlayerInit", playerIndex, player, isRespawn)
    end
end

Events.OnTick.Add(onTickCheck)
Events.OnCreatePlayer.Add(onCreatePlayer)

-- Handle Remote Player Init (Broadcasted by Server)
MP.Register("KoniLib", "PlayerInit", function(player, args)
    local username = args.username
    local isRespawn = args.isRespawn
    
    if username then
        if KoniLib.Events and KoniLib.Events.OnRemotePlayerInit then
            KoniLib.Events.OnRemotePlayerInit:Trigger(username, isRespawn)
        else
            triggerEvent("OnRemotePlayerInit", username, isRespawn)
        end
        MP.Log("Remote player init: " .. username .. (isRespawn and " (Respawn)" or " (Join)"))
    end
end)

-- Handle Remote Player Death
MP.Register("KoniLib", "PlayerDeath", function(player, args)
    local username = args.username
    local x = args.x
    local y = args.y
    local z = args.z
    
    if KoniLib.Events and KoniLib.Events.OnRemotePlayerDeath then
        KoniLib.Events.OnRemotePlayerDeath:Trigger(username, x, y, z)
    else
        triggerEvent("OnRemotePlayerDeath", username, x, y, z)
    end
    MP.Log("Remote player death: " .. tostring(username))
end)

-- Handle Remote Player Quit
MP.Register("KoniLib", "PlayerQuit", function(player, args)
    local username = args.username
    
    if KoniLib.Events and KoniLib.Events.OnRemotePlayerQuit then
        KoniLib.Events.OnRemotePlayerQuit:Trigger(username)
    else
        triggerEvent("OnRemotePlayerQuit", username)
    end
    MP.Log("Remote player quit: " .. tostring(username))
end)
