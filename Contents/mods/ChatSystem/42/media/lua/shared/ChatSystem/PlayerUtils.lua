-- ChatSystem Player Utilities
-- Thin wrapper around KoniLib.Player with ChatSystem-specific roleplay mode
-- Use this module for consistent player name handling across ChatSystem

require "ChatSystem/Definitions"
require "KoniLib/Player"

ChatSystem.PlayerUtils = ChatSystem.PlayerUtils or {}
local Utils = ChatSystem.PlayerUtils
local Player = KoniLib.Player

-- ==========================================================
-- Roleplay Mode Check (ChatSystem-specific)
-- ==========================================================

--- Check if roleplay mode is enabled
--- Reads directly from SandboxVars to work on both client and server
---@return boolean
function Utils.IsRoleplayMode()
    return SandboxVars and SandboxVars.ChatSystem and SandboxVars.ChatSystem.RoleplayMode or false
end

-- ==========================================================
-- Wrappers that automatically apply roleplay mode
-- ==========================================================

--- Get display name for a player object
--- Returns character name if roleplay mode is enabled, otherwise username
---@param player IsoPlayer The player object
---@return string The display name
function Utils.GetDisplayName(player)
    return Player.GetDisplayName(player, Utils.IsRoleplayMode)
end

--- Get display name for a player by their username
---@param username string The player's username
---@return string The display name (falls back to username if player not found)
function Utils.GetDisplayNameByUsername(username)
    return Player.GetDisplayNameByUsername(username, Utils.IsRoleplayMode)
end

--- Get both username and display name for a player
---@param player IsoPlayer The player object
---@return string username The username
---@return string displayName The display name (may be same as username)
function Utils.GetBothNames(player)
    return Player.GetBothNames(player, Utils.IsRoleplayMode)
end

--- Get a formatted name with both display name and username if different
---@param player IsoPlayer The player object
---@return string Formatted name string
function Utils.GetFormattedName(player)
    return Player.GetFormattedName(player, Utils.IsRoleplayMode)
end

--- Get formatted name by username lookup
---@param username string The player's username
---@return string Formatted name string
function Utils.GetFormattedNameByUsername(username)
    return Player.GetFormattedNameByUsername(username, Utils.IsRoleplayMode)
end

-- ==========================================================
-- Direct pass-through to KoniLib.Player
-- ==========================================================

--- Get username for a player object
---@param player IsoPlayer The player object
---@return string The username
Utils.GetUsername = Player.GetUsername

--- Get character name from a SurvivorDesc
---@param descriptor SurvivorDesc
---@return string|nil Character full name or nil if not available
Utils.GetCharacterNameFromDescriptor = Player.GetCharacterName

--- Get a player by username
---@param username string
---@return IsoPlayer|nil
Utils.GetPlayerByUsername = Player.GetByUsername

--- Get all online players as a Lua table
---@return IsoPlayer[]
Utils.GetOnlinePlayers = Player.GetOnlinePlayers

--- Check if player is staff (mod/admin/etc)
---@param player IsoPlayer
---@return boolean
Utils.IsStaff = Player.IsStaff

--- Check if player is admin
---@param player IsoPlayer
---@return boolean
Utils.IsAdmin = Player.IsAdmin

return ChatSystem.PlayerUtils
