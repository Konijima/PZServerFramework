if isClient() then return end
if not KoniLib then KoniLib = {} end
local Log = require("KoniLib/Log")
local MP = require("KoniLib/MP")

-- Events are defined in shared/KoniLib/CustomEvents.lua and registered using KoniLib/Event.lua

local initializedPlayers = {}

---Logic to trigger OnPlayerRespawn on Server
-- On Server, OnCreatePlayer passes (playerID, playerObj) or just playerObj depending on legacy.
-- Actually standard Event OnCreatePlayer usually passes (id, player).
local function onCreatePlayerServer(playerIndex, player)
    -- On Server we track by username because player index/ID might recycle or be less reliable across sessions, 
    -- but for the session lifetime 'player' object reference or username is safer.
    
    if not player then return end
    local username = player:getUsername()
    
    local isRespawn = false
    if not initializedPlayers[username] then
        -- First creation in this session (Join)
        initializedPlayers[username] = true
        isRespawn = false
        Log.Print("Events", "Initial player creation detected (Join) for " .. tostring(username))
    else
        -- Creating player again in same session -> Respawn
        isRespawn = true
        Log.Print("Events", "Respawn detected for " .. tostring(username))
    end

    if KoniLib.Events and KoniLib.Events.OnPlayerInit then
        KoniLib.Events.OnPlayerInit:Trigger(playerIndex, player, isRespawn)
    else
        triggerEvent("OnPlayerInit", playerIndex, player, isRespawn)
    end
    
    -- Notify all clients about this player initialization
    MP.Send(nil, "KoniLib", "PlayerInit", { username = username, isRespawn = isRespawn })
end

-- OnNetworkAvailable doesn't really apply to Server (it's the host), so we only handle Respawn.
Events.OnCreatePlayer.Add(onCreatePlayerServer)

-- Handle Player Death
local function onPlayerDeath(player)
    if player and instanceof(player, "IsoPlayer") then
        local username = player:getUsername()
        Log.Print("Events", "Player Death detected: " .. tostring(username))
        
        -- Broadcast to all clients
        MP.Send(nil, "KoniLib", "PlayerDeath", { 
            username = username,
            x = player:getX(),
            y = player:getY(),
            z = player:getZ()
        })
    end
end
Events.OnPlayerDeath.Add(onPlayerDeath)

-- Handle Player Quit (Polling)
local onlinePlayers = {}
local quitCheckTicker = 0

local function checkQuitters()
    quitCheckTicker = quitCheckTicker + 1
    if quitCheckTicker < 15 then return end -- Check every ~15 ticks (approx 0.25-0.5s ? depends on tick rate, usually 60TPS)
    quitCheckTicker = 0

    local currentOnline = {}
    local players = getOnlinePlayers()
    
    if players then
        for i=0, players:size()-1 do
             local p = players:get(i)
             if p then
                currentOnline[p:getUsername()] = true
                -- Ensure we track them if we missed the storage
                if not onlinePlayers[p:getUsername()] then
                    onlinePlayers[p:getUsername()] = true
                end
             end
        end
    end

    for username, _ in pairs(onlinePlayers) do
        if not currentOnline[username] then
            -- They are gone
            onlinePlayers[username] = nil
            
            -- Trigger Server-side Event
            if KoniLib.Events and KoniLib.Events.OnPlayerQuit then
                KoniLib.Events.OnPlayerQuit:Trigger(username)
            else
                triggerEvent("OnPlayerQuit", username)
            end
            
            Log.Print("Events", "Player Quit detected: " .. tostring(username))
            
            -- Broadcast to all clients
            MP.Send(nil, "KoniLib", "PlayerQuit", { username = username })
        end
    end
end
Events.OnTick.Add(checkQuitters)
