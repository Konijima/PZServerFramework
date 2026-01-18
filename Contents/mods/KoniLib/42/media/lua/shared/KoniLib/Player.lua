-- KoniLib Player Utilities
-- Centralized player name/display utilities that work on both client and server
-- Provides consistent player name handling across all mods

if not KoniLib then KoniLib = {} end

KoniLib.Player = KoniLib.Player or {}
local Player = KoniLib.Player

-- ==========================================================
-- Player Lookup
-- ==========================================================

--- Get a player by username (works in both SP and MP)
---@param username string
---@return IsoPlayer|nil
function Player.GetByUsername(username)
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
    
    return nil
end

--- Get all online players as a Lua table
---@return IsoPlayer[]
function Player.GetOnlinePlayers()
    local players = {}
    local onlinePlayers = getOnlinePlayers()
    if onlinePlayers then
        for i = 0, onlinePlayers:size() - 1 do
            local p = onlinePlayers:get(i)
            if p then
                table.insert(players, p)
            end
        end
    end
    return players
end

--- Get count of online players
---@return number
function Player.GetOnlineCount()
    local onlinePlayers = getOnlinePlayers()
    return onlinePlayers and onlinePlayers:size() or 0
end

-- ==========================================================
-- Character Name from Descriptor
-- ==========================================================

--- Get character name from a SurvivorDesc
---@param descriptor SurvivorDesc
---@return string|nil Character full name or nil if not available
function Player.GetCharacterName(descriptor)
    if not descriptor then return nil end
    
    local forename = descriptor:getForename() or ""
    local surname = descriptor:getSurname() or ""
    
    local fullName = forename
    if surname ~= "" then
        fullName = fullName .. " " .. surname
    end
    
    if fullName ~= "" then
        return fullName
    end
    
    return nil
end

--- Get character name from a player object
---@param player IsoPlayer
---@return string|nil Character full name or nil if not available
function Player.GetCharacterNameFromPlayer(player)
    if not player then return nil end
    return Player.GetCharacterName(player:getDescriptor())
end

-- ==========================================================
-- Username
-- ==========================================================

--- Get username for a player object
---@param player IsoPlayer The player object
---@return string The username
function Player.GetUsername(player)
    if not player then return "Unknown" end
    return player:getUsername() or "Unknown"
end

-- ==========================================================
-- Display Name (with optional roleplay support)
-- ==========================================================

--- Get display name for a player object using a custom roleplay mode check
---@param player IsoPlayer The player object
---@param useCharacterName boolean|function If true, use character name. If function, calls it to check.
---@return string The display name
function Player.GetDisplayName(player, useCharacterName)
    if not player then return "Unknown" end
    
    local username = player:getUsername() or "Unknown"
    
    -- Determine if we should use character name
    local shouldUseCharName = false
    if type(useCharacterName) == "function" then
        shouldUseCharName = useCharacterName()
    elseif useCharacterName then
        shouldUseCharName = true
    end
    
    if shouldUseCharName then
        local charName = Player.GetCharacterNameFromPlayer(player)
        if charName then
            return charName
        end
    end
    
    return username
end

--- Get display name by username lookup
---@param username string The player's username
---@param useCharacterName boolean|function If true, use character name. If function, calls it to check.
---@return string The display name (falls back to username if player not found)
function Player.GetDisplayNameByUsername(username, useCharacterName)
    if not username then return "Unknown" end
    
    -- Determine if we should use character name
    local shouldUseCharName = false
    if type(useCharacterName) == "function" then
        shouldUseCharName = useCharacterName()
    elseif useCharacterName then
        shouldUseCharName = true
    end
    
    -- If not using character names, just return username
    if not shouldUseCharName then
        return username
    end
    
    -- Try to find the player online
    local player = Player.GetByUsername(username)
    if player then
        return Player.GetDisplayName(player, true)
    end
    
    -- Fallback to username if player not found
    return username
end

--- Get both username and display name for a player
---@param player IsoPlayer The player object
---@param useCharacterName boolean|function If true, use character name. If function, calls it to check.
---@return string username The username
---@return string displayName The display name (may be same as username)
function Player.GetBothNames(player, useCharacterName)
    if not player then return "Unknown", "Unknown" end
    
    local username = player:getUsername() or "Unknown"
    local displayName = Player.GetDisplayName(player, useCharacterName)
    
    return username, displayName
end

-- ==========================================================
-- Formatted Name Strings
-- ==========================================================

--- Get a formatted name with both display name and username if different
--- Example: "John Smith (username123)" or just "username123" if same
---@param player IsoPlayer The player object
---@param useCharacterName boolean|function If true, use character name. If function, calls it to check.
---@return string Formatted name string
function Player.GetFormattedName(player, useCharacterName)
    local username, displayName = Player.GetBothNames(player, useCharacterName)
    
    if displayName ~= username then
        return displayName .. " (" .. username .. ")"
    end
    
    return username
end

--- Get formatted name by username lookup
---@param username string The player's username
---@param useCharacterName boolean|function If true, use character name. If function, calls it to check.
---@return string Formatted name string
function Player.GetFormattedNameByUsername(username, useCharacterName)
    if not username then return "Unknown" end
    
    local displayName = Player.GetDisplayNameByUsername(username, useCharacterName)
    
    if displayName ~= username then
        return displayName .. " (" .. username .. ")"
    end
    
    return username
end

-- ==========================================================
-- Access Level / Permissions
-- ==========================================================

--- Get player's access level
---@param player IsoPlayer
---@return string Access level (admin, moderator, overseer, gm, observer, or none)
function Player.GetAccessLevel(player)
    if not player then return "none" end
    local level = player:getAccessLevel()
    if level and level ~= "" then
        return level:lower()
    end
    return "none"
end

--- Check if player has staff capabilities using role/capability system
--- More robust than just checking access level string
---@param player IsoPlayer
---@return boolean
local function hasStaffCapabilities(player)
    if not player then return false end
    
    local role = player:getRole()
    if not role then return false end
    
    -- Check admin power (most reliable)
    local success, hasAdmin = pcall(function()
        return role:hasAdminPower()
    end)
    if success and hasAdmin then
        return true
    end
    
    -- Check staff capabilities
    if Capability then
        local success2, hasStaffCap = pcall(function()
            return role:hasCapability(Capability.SeePlayersConnected) or
                   role:hasCapability(Capability.AnswerTickets)
        end)
        if success2 and hasStaffCap then
            return true
        end
    end
    
    return false
end

--- Check if player is staff (admin, moderator, overseer, or gm)
--- Uses both access level string and capability checks for robustness
---@param player IsoPlayer
---@return boolean
function Player.IsStaff(player)
    -- First check capabilities (more robust)
    if hasStaffCapabilities(player) then
        return true
    end
    
    -- Fall back to access level check
    local level = Player.GetAccessLevel(player)
    return level == "admin" or level == "moderator" or level == "overseer" or level == "gm"
end

--- Check if player is admin (only "admin" access level, not moderator etc)
---@param player IsoPlayer
---@return boolean
function Player.IsAdmin(player)
    local level = Player.GetAccessLevel(player)
    return level == "admin"
end

return KoniLib.Player
