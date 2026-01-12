-- Command Loader
-- Loads all command files from the Commands directory
if isClient() then return end
if not isServer() then return end

-- Load command files
require "ChatSystem/Commands/GeneralCommands"
require "ChatSystem/Commands/AdminCommands"
require "ChatSystem/Commands/ServerCommands"

print("[ChatSystem] All commands loaded")
