if isServer() then return end
require "ChatSystem/Definitions"
require "ChatSystem/CommandAPI"
local Socket = require("KoniLib/Socket")

ChatSystem.Commands.Client = {}
local Client = ChatSystem.Commands.Client
local Commands = ChatSystem.Commands

-- Client state
Client.socket = nil
Client.commandHistory = {}
Client.historyIndex = 0
Client.maxHistory = 50

-- ==========================================================
-- Command Detection
-- ==========================================================

--- Check if input text is a custom command (not a channel command)
---@param text string
---@return boolean
function Client.IsCustomCommand(text)
    if not Commands.IsCommand(text) then
        return false
    end
    
    -- Check if this is a channel command
    for channelType, commands in pairs(ChatSystem.ChannelCommands) do
        for _, cmd in ipairs(commands) do
            if luautils.stringStarts(text:lower(), cmd:lower()) then
                return false
            end
        end
    end
    
    return true
end

--- Get command suggestions based on partial input
---@param partial string
---@return table[] Array of matching commands
function Client.GetSuggestions(partial)
    if not partial or partial == "" then
        return {}
    end
    
    -- Remove leading /
    if partial:sub(1, 1) == "/" then
        partial = partial:sub(2)
    end
    
    partial = partial:lower()
    local suggestions = {}
    local seen = {}
    
    for name, cmd in pairs(Commands.registry) do
        if not seen[cmd.name] and name:find(partial, 1, true) == 1 then
            seen[cmd.name] = true
            table.insert(suggestions, cmd)
        end
    end
    
    -- Sort by relevance (exact prefix match first)
    table.sort(suggestions, function(a, b)
        local aExact = a.name:find(partial, 1, true) == 1
        local bExact = b.name:find(partial, 1, true) == 1
        if aExact ~= bExact then
            return aExact
        end
        return a.name < b.name
    end)
    
    return suggestions
end

-- ==========================================================
-- Command Execution
-- ==========================================================

--- Send a command to the server for execution
---@param commandText string
---@param callback function?
function Client.Execute(commandText, callback)
    if not ChatSystem.Client.isConnected then
        print("[ChatSystem.Commands] Not connected")
        return
    end
    
    if not Commands.IsCommand(commandText) then
        print("[ChatSystem.Commands] Not a command: " .. commandText)
        return
    end
    
    -- Add to history
    Client.AddToHistory(commandText)
    
    -- Check for client-only commands first
    local name, args, rawArgs = Commands.Parse(commandText)
    local cmd = Commands.Get(name)
    
    if cmd and cmd.clientHandler then
        -- Execute client-side handler
        local context = {
            args = args,
            rawArgs = rawArgs,
            argList = args,
            command = cmd,
        }
        
        local success, result = pcall(cmd.clientHandler, context)
        if callback then
            callback({ success = success, result = result, clientOnly = true })
        end
        return
    end
    
    -- Send to server (include current channel for context)
    ChatSystem.Client.socket:emit("command", { 
        command = commandText, 
        channel = ChatSystem.Client.currentChannel 
    }, function(response)
        if callback then
            callback(response)
        end
    end)
end

-- ==========================================================
-- Command History
-- ==========================================================

--- Add a command to history
---@param command string
function Client.AddToHistory(command)
    -- Don't add duplicates consecutively
    if #Client.commandHistory > 0 and Client.commandHistory[#Client.commandHistory] == command then
        return
    end
    
    table.insert(Client.commandHistory, command)
    
    -- Trim history
    while #Client.commandHistory > Client.maxHistory do
        table.remove(Client.commandHistory, 1)
    end
    
    -- Reset index
    Client.historyIndex = #Client.commandHistory + 1
end

--- Get previous command from history
---@return string|nil
function Client.GetPreviousCommand()
    if #Client.commandHistory == 0 then
        return nil
    end
    
    Client.historyIndex = Client.historyIndex - 1
    if Client.historyIndex < 1 then
        Client.historyIndex = 1
    end
    
    return Client.commandHistory[Client.historyIndex]
end

--- Get next command from history
---@return string|nil
function Client.GetNextCommand()
    if #Client.commandHistory == 0 then
        return nil
    end
    
    Client.historyIndex = Client.historyIndex + 1
    if Client.historyIndex > #Client.commandHistory then
        Client.historyIndex = #Client.commandHistory + 1
        return ""
    end
    
    return Client.commandHistory[Client.historyIndex]
end

--- Reset history navigation
function Client.ResetHistoryIndex()
    Client.historyIndex = #Client.commandHistory + 1
end

-- ==========================================================
-- Help System
-- ==========================================================

--- Get help text for a command
---@param name string
---@return string|nil
function Client.GetHelp(name)
    local cmd = Commands.Get(name)
    if not cmd then
        return nil
    end
    
    local help = Commands.FormatUsage(cmd) .. "\n"
    help = help .. cmd.description
    
    if cmd.aliases and #cmd.aliases > 0 then
        help = help .. "\nAliases: /" .. table.concat(cmd.aliases, ", /")
    end
    
    return help
end

--- Get list of all commands formatted for display
---@param accessLevel string? Filter by maximum access level
---@return string
function Client.GetCommandList(accessLevel)
    local categories = Commands.GetCategories()
    local output = ""
    
    for _, category in ipairs(categories) do
        local cmds = Commands.GetByCategory(category)
        local catCmds = {}
        
        for _, cmd in ipairs(cmds) do
            -- Filter by access level if specified
            if not accessLevel or cmd.accessLevel == accessLevel then
                table.insert(catCmds, "/" .. cmd.name)
            end
        end
        
        if #catCmds > 0 then
            output = output .. "\n[" .. category:upper() .. "]: " .. table.concat(catCmds, ", ")
        end
    end
    
    return output ~= "" and output or "No commands available"
end

print("[ChatSystem] CommandAPI Client Loaded")
