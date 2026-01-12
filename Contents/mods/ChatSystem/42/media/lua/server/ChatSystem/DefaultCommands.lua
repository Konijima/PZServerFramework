-- ChatSystem Default Commands Loader
-- This file loads all built-in commands from the Commands directory
if isClient() then return end
if not isServer() then return end

-- Load all commands
require "ChatSystem/Commands/init"

