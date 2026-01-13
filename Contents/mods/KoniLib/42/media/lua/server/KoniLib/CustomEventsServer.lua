if isClient() then return end
if not KoniLib then KoniLib = {} end
local Log = require("KoniLib/Log")
local MP = require("KoniLib/MP")

print("[KoniLib] CustomEventsServer loading...")

-- Events are defined in shared/KoniLib/CustomEvents.lua and registered using KoniLib/Event.lua

-- Track players who have joined this session (for respawn detection)
local sessionPlayers = {}

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

-- Handle Player Join/Quit (Polling)
local onlinePlayers = {}
local playerCheckTicker = 0

local function checkPlayerChanges()
    playerCheckTicker = playerCheckTicker + 1
    if playerCheckTicker < 15 then return end -- Check every ~15 ticks
    playerCheckTicker = 0

    local currentOnline = {}
    local players = getOnlinePlayers()
    
    if players then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                local username = p:getUsername()
                currentOnline[username] = p
                
                -- Check if this is a new player (joined)
                if not onlinePlayers[username] then
                    local isRespawn = sessionPlayers[username] == true
                    sessionPlayers[username] = true
                    
                    Log.Print("Events", "Player " .. (isRespawn and "Respawn" or "Join") .. " detected: " .. tostring(username))
                    
                    -- Trigger Server-side Event
                    if KoniLib.Events and KoniLib.Events.OnPlayerInit then
                        KoniLib.Events.OnPlayerInit:Trigger(0, p, isRespawn)
                    else
                        triggerEvent("OnPlayerInit", 0, p, isRespawn)
                    end
                    
                    -- Broadcast to all clients
                    MP.Send(nil, "KoniLib", "PlayerInit", { username = username, isRespawn = isRespawn })
                end
            end
        end
    end

    -- Check for players who quit
    for username, _ in pairs(onlinePlayers) do
        if not currentOnline[username] then
            Log.Print("Events", "Player Quit detected: " .. tostring(username))
            
            -- Trigger Server-side Event
            if KoniLib.Events and KoniLib.Events.OnPlayerQuit then
                KoniLib.Events.OnPlayerQuit:Trigger(username)
            else
                triggerEvent("OnPlayerQuit", username)
            end
            
            -- Broadcast to all clients
            MP.Send(nil, "KoniLib", "PlayerQuit", { username = username })
        end
    end
    
    -- Update tracked players (store just true, not the player object)
    onlinePlayers = {}
    for username, _ in pairs(currentOnline) do
        onlinePlayers[username] = true
    end
end
Events.OnTick.Add(checkPlayerChanges)

print("[KoniLib] CustomEventsServer loaded - Player polling active")
