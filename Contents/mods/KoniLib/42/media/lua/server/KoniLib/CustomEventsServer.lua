if isClient() then return end
if not KoniLib then KoniLib = {} end
local Log = require("KoniLib/Log")
local MP = require("KoniLib/MP")
local Player = require("KoniLib/Player")

print("[KoniLib] CustomEventsServer loading...")

-- Events are defined in shared/KoniLib/CustomEvents.lua and registered using KoniLib/Event.lua

-- Track players who have joined this session (for respawn detection)
-- This persists across deaths/respawns - only cleared on server restart
local sessionPlayers = {}

-- Cache display names so we can use them after player disconnects
-- { [username] = displayName }
local displayNameCache = {}

-- Track recent deaths to suppress "quit" message during respawn grace period
-- { [username] = timestamp }
local recentDeaths = {}
local RESPAWN_GRACE_PERIOD = 30000 -- 30 seconds grace period after death

--- Get display name, updating cache if player is available
---@param player IsoPlayer|nil The player object (if available)
---@param username string The player's username
---@return string The display name (character name or username)
local function getDisplayName(player, username)
    if player then
        -- Update cache with current display name (character name)
        local displayName = Player.GetCharacterNameFromPlayer(player) or username
        displayNameCache[username] = displayName
        return displayName
    end
    -- Return cached name or fall back to username
    return displayNameCache[username] or username
end

-- Handle Player Death
local function onPlayerDeath(player)
    if player and instanceof(player, "IsoPlayer") then
        local username = player:getUsername()
        local displayName = getDisplayName(player, username)
        Log.Print("Events", "Player Death detected: " .. tostring(username))
        
        -- Mark this player as recently died (for respawn grace period)
        recentDeaths[username] = getTimestampMs()
        
        -- Broadcast to all clients (include displayName for client-side display)
        MP.Send(nil, "KoniLib", "PlayerDeath", { 
            username = username,
            displayName = displayName,
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
    local now = getTimestampMs()
    
    if players then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                local username = p:getUsername()
                currentOnline[username] = p
                
                -- Check if this is a new player (joined)
                if not onlinePlayers[username] then
                    -- Clear from recent deaths since they're back
                    recentDeaths[username] = nil
                    
                    local isRespawn = sessionPlayers[username] == true
                    sessionPlayers[username] = true
                    
                    -- Get and cache display name
                    local displayName = getDisplayName(p, username)
                    
                    Log.Print("Events", "Player " .. (isRespawn and "Respawn" or "Join") .. " detected: " .. tostring(username))
                    
                    -- Trigger Server-side Event
                    if KoniLib.Events and KoniLib.Events.OnPlayerInit then
                        KoniLib.Events.OnPlayerInit:Trigger(0, p, isRespawn)
                    else
                        triggerEvent("OnPlayerInit", 0, p, isRespawn)
                    end
                    
                    -- Broadcast to all clients (include displayName)
                    MP.Send(nil, "KoniLib", "PlayerInit", { username = username, displayName = displayName, isRespawn = isRespawn })
                end
            end
        end
    end

    -- Check for players who quit
    for username, _ in pairs(onlinePlayers) do
        if not currentOnline[username] then
            -- Check if this player recently died (respawn grace period)
            local deathTime = recentDeaths[username]
            if deathTime and (now - deathTime) < RESPAWN_GRACE_PERIOD then
                -- Player recently died, they're probably respawning - don't trigger quit
                Log.Print("Events", "Player " .. tostring(username) .. " disconnected during respawn grace period - suppressing quit event")
            else
                -- Get cached display name before we forget about this player
                local displayName = getDisplayName(nil, username)
                
                -- Clear recent death tracking
                recentDeaths[username] = nil
                
                Log.Print("Events", "Player Quit detected: " .. tostring(username))
                
                -- NOTE: Don't clear sessionPlayers here - we want to track who has played
                -- this session so rejoining after quit is still considered a "rejoin" not first join
                -- sessionPlayers persists until server restart
                
                -- Trigger Server-side Event
                if KoniLib.Events and KoniLib.Events.OnPlayerQuit then
                    KoniLib.Events.OnPlayerQuit:Trigger(username)
                else
                    triggerEvent("OnPlayerQuit", username)
                end
                
                -- Broadcast to all clients (include cached displayName)
                MP.Send(nil, "KoniLib", "PlayerQuit", { username = username, displayName = displayName })
            end
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
