if isServer() then return end
if not KoniLib then KoniLib = {} end
local Log = require("KoniLib/Log")
local MP = require("KoniLib/MP")

-- Events are defined in shared/KoniLib/CustomEvents.lua and registered using KoniLib/Event.lua

local hasNetworkFired = false

-- Forward declaration for reset function
local onTickCheck

---Logic to trigger OnNetworkAvailable
onTickCheck = function()
    if hasNetworkFired then return end
    
    local player = getSpecificPlayer(0)
    if player then
        hasNetworkFired = true
        if KoniLib.Events and KoniLib.Events.OnNetworkAvailable then
             KoniLib.Events.OnNetworkAvailable:Trigger(0)
             Log.Print("Events", "Triggered OnNetworkAvailable")
        else
            -- Fallback if something went wrong with loading
            triggerEvent("OnNetworkAvailable", 0)
            Log.Print("Events", "Triggered OnNetworkAvailable (Fallback)")
        end

        -- Stop checking
        Events.OnTick.Remove(onTickCheck)
    end
end

---Reset client state when returning to main menu or disconnecting
local function resetClientState()
    hasNetworkFired = false
    Log.Print("Events", "Client state reset (disconnect/menu)")
    -- Re-add the tick check for next game session
    Events.OnTick.Add(onTickCheck)
end

---Logic to trigger OnPlayerInit (always as join, isRespawn kept for API compatibility)
local function onCreatePlayer(playerIndex, player)
    if player and not player:isLocalPlayer() then return end
    
    local username = player and player:getUsername() or "Unknown"
    local isRespawn = false  -- Always false - we treat all player creations as joins
    
    Log.Print("Events", "Player joined: " .. tostring(playerIndex) .. " ("..username..")")

    if KoniLib.Events and KoniLib.Events.OnPlayerInit then
        KoniLib.Events.OnPlayerInit:Trigger(playerIndex, player, isRespawn)
    else
        triggerEvent("OnPlayerInit", playerIndex, player, isRespawn)
    end
end

Events.OnTick.Add(onTickCheck)
Events.OnCreatePlayer.Add(onCreatePlayer)

-- Reset state when player returns to main menu (quit game) or disconnects
Events.OnMainMenuEnter.Add(resetClientState)
Events.OnDisconnect.Add(resetClientState)

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
        Log.Print("Events", "Remote player init: " .. username .. (isRespawn and " (Respawn)" or " (Join)"))
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
    Log.Print("Events", "Remote player death: " .. tostring(username))
end)

-- Handle Remote Player Quit
MP.Register("KoniLib", "PlayerQuit", function(player, args)
    local username = args.username
    
    if KoniLib.Events and KoniLib.Events.OnRemotePlayerQuit then
        KoniLib.Events.OnRemotePlayerQuit:Trigger(username)
    else
        triggerEvent("OnRemotePlayerQuit", username)
    end
    Log.Print("Events", "Remote player quit: " .. tostring(username))
end)

-- ==========================================================
-- Access Level Change Detection
-- ==========================================================

local lastAccessLevel = nil
local accessCheckTicker = 0
local accessCheckInitialized = false

local function checkAccessLevelChange()
    -- Only check every ~60 ticks (about 1 second)
    accessCheckTicker = accessCheckTicker + 1
    if accessCheckTicker < 60 then return end
    accessCheckTicker = 0
    
    -- Get current access level - try multiple methods
    local currentAccessLevel = nil
    
    -- Method 1: Global getAccessLevel() function
    if getAccessLevel then
        currentAccessLevel = getAccessLevel()
    end
    
    -- Method 2: Player object's getAccessLevel method (may be more up-to-date)
    local player = getPlayer()
    local playerAccessLevel = nil
    if player and player.getAccessLevel then
        playerAccessLevel = player:getAccessLevel()
    end
    
    -- Use player method if available and different (it might be more current)
    if playerAccessLevel and playerAccessLevel ~= "" then
        currentAccessLevel = playerAccessLevel
    end
    
    -- Initialize on first check
    if not accessCheckInitialized then
        lastAccessLevel = currentAccessLevel
        accessCheckInitialized = true
        return
    end
    
    -- Check if access level changed
    if currentAccessLevel ~= lastAccessLevel then
        local oldLevel = lastAccessLevel
        lastAccessLevel = currentAccessLevel
        
        -- Trigger event
        if KoniLib.Events and KoniLib.Events.OnAccessLevelChanged then
            KoniLib.Events.OnAccessLevelChanged:Trigger(currentAccessLevel, oldLevel)
        else
            triggerEvent("OnAccessLevelChanged", currentAccessLevel, oldLevel)
        end
    end
end

Events.OnTick.Add(checkAccessLevelChange)
