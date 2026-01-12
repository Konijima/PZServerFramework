-- ChatSystem Server Helpers
-- Utility functions for player lookups, permissions, and range calculations
if isClient() then return end
if not isServer() then return end

require "ChatSystem/Definitions"

ChatSystem.Server = ChatSystem.Server or {}
local Server = ChatSystem.Server

-- ==========================================================
-- Table Utilities
-- ==========================================================

--- Check if a table is empty (replacement for next() which isn't available in PZ)
---@param t table|nil
---@return boolean
function Server.TableIsEmpty(t)
    if not t then return true end
    for _ in pairs(t) do
        return false
    end
    return true
end

-- ==========================================================
-- Display Name
-- ==========================================================

--- Get the display name for a player based on roleplay mode setting
---@param player IsoPlayer
---@return string The display name (character name if roleplay mode, username otherwise)
function Server.GetPlayerDisplayName(player)
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
-- Player Lookups
-- ==========================================================

--- Get a player by username (works in both SP and MP)
---@param username string
---@return IsoPlayer|nil
function Server.GetPlayerByName(username)
    if not username then return nil end
    
    -- Try getPlayerByUsername first (MP)
    if getPlayerByUsername then
        local player = getPlayerByUsername(username)
        if player then return player end
    end
    
    -- Fallback: iterate through online players
    local onlinePlayers = getOnlinePlayers()
    if onlinePlayers and onlinePlayers:size() > 0 then
        for i = 0, onlinePlayers:size() - 1 do
            local p = onlinePlayers:get(i)
            if p and p:getUsername() == username then
                return p
            end
        end
    end
    
    -- SP fallback
    local player = getPlayer()
    if player and player:getUsername() == username then
        return player
    end
    
    return nil
end

--- Get players within range of a position
---@param x number
---@param y number
---@param z number
---@param range number
---@return table Array of players
function Server.GetPlayersInRange(x, y, z, range)
    local players = {}
    local onlinePlayers = getOnlinePlayers()
    
    -- In singleplayer, getOnlinePlayers() returns nil or empty
    if not onlinePlayers or (onlinePlayers.size and onlinePlayers:size() == 0) then
        local player = getPlayer()
        if player then
            -- In SP, always include the player (they're talking to themselves)
            table.insert(players, player)
        end
        return players
    end
    
    for i = 0, onlinePlayers:size() - 1 do
        local player = onlinePlayers:get(i)
        local px, py, pz = player:getX(), player:getY(), player:getZ()
        
        -- Check Z level (same floor or adjacent)
        if math.abs(pz - z) <= 1 then
            local dist = math.sqrt((px - x)^2 + (py - y)^2)
            if dist <= range then
                table.insert(players, player)
            end
        end
    end
    
    return players
end

-- ==========================================================
-- Faction & Safehouse
-- ==========================================================

--- Get player's faction name
---@param player IsoPlayer
---@return string|nil
function Server.GetPlayerFaction(player)
    local faction = Faction.getPlayerFaction(player)
    if faction then
        return faction:getName()
    end
    return nil
end

--- Get player's safehouse ID (unique identifier for comparison)
---@param player IsoPlayer
---@return string|nil Safehouse ID (x_y format) or nil
function Server.GetPlayerSafehouseId(player)
    local safehouse = SafeHouse.hasSafehouse(player)
    if safehouse then
        -- Use coordinates as unique ID
        return safehouse:getX() .. "_" .. safehouse:getY()
    end
    return nil
end

--- Get player's safehouse object
---@param player IsoPlayer
---@return SafeHouse|nil
function Server.GetPlayerSafehouse(player)
    return SafeHouse.hasSafehouse(player)
end

-- ==========================================================
-- Permissions
-- ==========================================================

--- Check if player is admin (actual "admin" access level only)
---@param player IsoPlayer
---@return boolean
function Server.IsPlayerAdmin(player)
    -- Only "admin" access level can access admin chat (not moderator, observer, etc.)
    local accessLevel = player:getAccessLevel()
    return accessLevel and string.lower(accessLevel) == "admin"
end

--- Check if player is staff (admin, moderator, overseer, or GM)
--- Uses capability check for SeePlayersConnected as indicator of staff role
---@param player IsoPlayer
---@return boolean
function Server.IsPlayerStaff(player)
    -- Admins are always staff
    if Server.IsPlayerAdmin(player) then
        return true
    end
    
    -- Check for staff capability (SeePlayersConnected is a good indicator)
    local role = player:getRole()
    if role and Capability then
        local success, hasStaffCap = pcall(function()
            return role:hasCapability(Capability.SeePlayersConnected) or
                   role:hasCapability(Capability.AnswerTickets)
        end)
        if success and hasStaffCap then
            return true
        end
    end
    
    -- Check access level - only specific staff roles (not observer)
    local accessLevel = player:getAccessLevel()
    if accessLevel then
        local level = string.lower(accessLevel)
        -- Staff roles: admin, moderator, overseer, gm (NOT observer)
        return level == "admin" or level == "moderator" or level == "overseer" or level == "gm"
    end
    return false
end

-- ==========================================================
-- Player List
-- ==========================================================

--- Build current player list for broadcasting
---@return table Array of player data
function Server.BuildPlayerList()
    local players = {}
    local onlinePlayers = getOnlinePlayers()
    
    if not onlinePlayers then
        local p = getPlayer()
        if p then
            table.insert(players, {
                username = p:getUsername(),
                isAdmin = Server.IsPlayerAdmin(p),
                isStaff = Server.IsPlayerStaff(p)
            })
        end
    else
        for i = 0, onlinePlayers:size() - 1 do
            local p = onlinePlayers:get(i)
            table.insert(players, {
                username = p:getUsername(),
                isAdmin = Server.IsPlayerAdmin(p),
                isStaff = Server.IsPlayerStaff(p)
            })
        end
    end
    
    return players
end

print("[ChatSystem] Server Helpers loaded")
