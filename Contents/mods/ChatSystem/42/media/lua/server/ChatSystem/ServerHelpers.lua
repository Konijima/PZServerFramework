-- ChatSystem Server Helpers Module
-- Utility functions for player lookups, permissions, and range calculations
-- Returns a module table to be merged into ChatSystem.Server

require "ChatSystem/Definitions"
require "ChatSystem/PlayerUtils"
require "KoniLib/Player"

local Module = {}

-- ==========================================================
-- Table Utilities
-- ==========================================================

--- Check if a table is empty (replacement for next() which isn't available in PZ)
---@param t table|nil
---@return boolean
function Module.TableIsEmpty(t)
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
--- @deprecated Use ChatSystem.PlayerUtils.GetDisplayName(player) instead
---@param player IsoPlayer
---@return string The display name (character name if roleplay mode, username otherwise)
function Module.GetPlayerDisplayName(player)
    -- Delegate to centralized PlayerUtils
    return ChatSystem.PlayerUtils.GetDisplayName(player)
end

-- ==========================================================
-- Player Lookups
-- ==========================================================

--- Get a player by username (works in both SP and MP)
--- @deprecated Use KoniLib.Player.GetByUsername(username) instead
---@param username string
---@return IsoPlayer|nil
function Module.GetPlayerByName(username)
    -- Delegate to KoniLib, with SP fallback
    local player = KoniLib.Player.GetByUsername(username)
    if player then return player end
    
    -- SP fallback
    local localPlayer = getPlayer()
    if localPlayer and localPlayer:getUsername() == username then
        return localPlayer
    end
    
    return nil
end

--- Get players within range of a position
---@param x number
---@param y number
---@param z number
---@param range number
---@return table Array of players
function Module.GetPlayersInRange(x, y, z, range)
    local players = {}
    local onlinePlayers = KoniLib.Player.GetOnlinePlayers()
    
    -- In singleplayer, onlinePlayers is empty
    if #onlinePlayers == 0 then
        local player = getPlayer()
        if player then
            -- In SP, always include the player (they're talking to themselves)
            table.insert(players, player)
        end
        return players
    end
    
    for _, player in ipairs(onlinePlayers) do
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
function Module.GetPlayerFaction(player)
    local faction = Faction.getPlayerFaction(player)
    if faction then
        return faction:getName()
    end
    return nil
end

--- Get player's safehouse ID (unique identifier for comparison)
---@param player IsoPlayer
---@return string|nil Safehouse ID (x_y format) or nil
function Module.GetPlayerSafehouseId(player)
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
function Module.GetPlayerSafehouse(player)
    return SafeHouse.hasSafehouse(player)
end

-- ==========================================================
-- Permissions
-- ==========================================================

--- Check if player is admin (actual "admin" access level only)
--- @deprecated Use KoniLib.Player.IsAdmin(player) instead
---@param player IsoPlayer
---@return boolean
function Module.IsPlayerAdmin(player)
    return KoniLib.Player.IsAdmin(player)
end

--- Check if player is staff (admin, moderator, overseer, or GM)
--- @deprecated Use KoniLib.Player.IsStaff(player) instead
---@param player IsoPlayer
---@return boolean
function Module.IsPlayerStaff(player)
    return KoniLib.Player.IsStaff(player)
end

-- ==========================================================
-- Player List
-- ==========================================================

--- Build current player list for broadcasting
---@return table Array of player data
function Module.BuildPlayerList()
    local players = {}
    local onlinePlayers = KoniLib.Player.GetOnlinePlayers()
    
    if #onlinePlayers == 0 then
        -- SP mode fallback
        local p = getPlayer()
        if p then
            table.insert(players, {
                username = KoniLib.Player.GetUsername(p),
                isAdmin = KoniLib.Player.IsAdmin(p),
                isStaff = KoniLib.Player.IsStaff(p)
            })
        end
    else
        for _, p in ipairs(onlinePlayers) do
            table.insert(players, {
                username = KoniLib.Player.GetUsername(p),
                isAdmin = KoniLib.Player.IsAdmin(p),
                isStaff = KoniLib.Player.IsStaff(p)
            })
        end
    end
    
    return players
end

return Module
