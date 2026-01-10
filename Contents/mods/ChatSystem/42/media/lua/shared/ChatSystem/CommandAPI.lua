ChatSystem = ChatSystem or {}
ChatSystem.Commands = ChatSystem.Commands or {}

local Commands = ChatSystem.Commands

-- Command access levels
Commands.AccessLevel = {
    PLAYER = "player",      -- Any player can use
    MODERATOR = "moderator", -- Moderators and above
    ADMIN = "admin",        -- Admins only
    OWNER = "owner",        -- Server owner only
}

-- Command argument types for validation
Commands.ArgType = {
    STRING = "string",
    NUMBER = "number",
    INTEGER = "integer",
    BOOLEAN = "boolean",
    PLAYER = "player",      -- Online player name
    COORDINATE = "coordinate", -- x,y,z or x y z
}

-- Registry of all commands
Commands.registry = {}

---@class CommandDefinition
---@field name string Command name (without prefix)
---@field aliases string[]? Alternative command names
---@field description string Short description of the command
---@field usage string? Usage example (e.g., "<player> <reason>")
---@field accessLevel string Required access level
---@field category string? Category for grouping (e.g., "admin", "teleport", "items")
---@field args CommandArg[]? Argument definitions
---@field handler function Server-side handler function
---@field clientHandler function? Client-side handler (for client-only commands)

---@class CommandArg
---@field name string Argument name
---@field type string Argument type (from Commands.ArgType)
---@field required boolean? Whether the argument is required (default: true)
---@field default any? Default value if not required

--- Register a new command
---@param definition CommandDefinition
---@return boolean success
---@return string? error
function Commands.Register(definition)
    if not definition then
        return false, "No definition provided"
    end
    
    if not definition.name then
        return false, "Command name is required"
    end
    
    local name = definition.name:lower()
    
    -- Check if command already exists
    if Commands.registry[name] then
        return false, "Command '" .. name .. "' already registered"
    end
    
    -- Validate required fields
    if not definition.description then
        definition.description = "No description"
    end
    
    if not definition.accessLevel then
        definition.accessLevel = Commands.AccessLevel.PLAYER
    end
    
    if not definition.handler then
        return false, "Command handler is required"
    end
    
    -- Register the command
    Commands.registry[name] = {
        name = name,
        aliases = definition.aliases or {},
        description = definition.description,
        usage = definition.usage,
        accessLevel = definition.accessLevel,
        category = definition.category or "general",
        args = definition.args or {},
        handler = definition.handler,
        clientHandler = definition.clientHandler,
    }
    
    -- Register aliases
    if definition.aliases then
        for _, alias in ipairs(definition.aliases) do
            alias = alias:lower()
            if not Commands.registry[alias] then
                Commands.registry[alias] = Commands.registry[name]
            end
        end
    end
    
    print("[ChatSystem.Commands] Registered command: /" .. name)
    return true
end

--- Unregister a command
---@param name string
---@return boolean
function Commands.Unregister(name)
    name = name:lower()
    local cmd = Commands.registry[name]
    
    if not cmd then
        return false
    end
    
    -- Remove aliases first
    for _, alias in ipairs(cmd.aliases or {}) do
        alias = alias:lower()
        if Commands.registry[alias] == cmd then
            Commands.registry[alias] = nil
        end
    end
    
    -- Remove main command
    Commands.registry[name] = nil
    
    print("[ChatSystem.Commands] Unregistered command: /" .. name)
    return true
end

--- Get a command by name or alias
---@param name string
---@return table|nil
function Commands.Get(name)
    if not name then return nil end
    return Commands.registry[name:lower()]
end

--- Check if a string is a command (starts with /)
---@param text string
---@return boolean
function Commands.IsCommand(text)
    if not text or text == "" then return false end
    return text:sub(1, 1) == "/"
end

--- Parse command string into name and arguments
---@param text string
---@return string|nil name
---@return string[] args
---@return string rawArgs (everything after command name)
function Commands.Parse(text)
    if not Commands.IsCommand(text) then
        return nil, {}, ""
    end
    
    -- Remove leading /
    local cmdText = text:sub(2)
    
    -- Handle empty command
    if cmdText == "" or cmdText == " " then
        return nil, {}, ""
    end
    
    -- Split by spaces, respecting quotes
    local parts = Commands.SplitArgs(cmdText)
    
    if #parts == 0 then
        return nil, {}, ""
    end
    
    local name = parts[1]:lower()
    local args = {}
    
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    -- Get raw args (everything after command name)
    local rawArgs = ""
    local nameEnd = cmdText:find("%s")
    if nameEnd then
        rawArgs = cmdText:sub(nameEnd + 1)
    end
    
    return name, args, rawArgs
end

--- Split a string into arguments, respecting quoted strings
---@param text string
---@return string[]
function Commands.SplitArgs(text)
    local args = {}
    local current = ""
    local inQuotes = false
    local quoteChar = nil
    
    for i = 1, #text do
        local char = text:sub(i, i)
        
        if (char == '"' or char == "'") and not inQuotes then
            inQuotes = true
            quoteChar = char
        elseif char == quoteChar and inQuotes then
            inQuotes = false
            quoteChar = nil
        elseif char == " " and not inQuotes then
            if current ~= "" then
                table.insert(args, current)
                current = ""
            end
        else
            current = current .. char
        end
    end
    
    if current ~= "" then
        table.insert(args, current)
    end
    
    return args
end

--- Validate argument against expected type
---@param value string
---@param argType string
---@return boolean valid
---@return any convertedValue
function Commands.ValidateArg(value, argType)
    if argType == Commands.ArgType.STRING then
        return true, value
        
    elseif argType == Commands.ArgType.NUMBER then
        local num = tonumber(value)
        return num ~= nil, num
        
    elseif argType == Commands.ArgType.INTEGER then
        local num = tonumber(value)
        if num and math.floor(num) == num then
            return true, math.floor(num)
        end
        return false, nil
        
    elseif argType == Commands.ArgType.BOOLEAN then
        local lower = value:lower()
        if lower == "true" or lower == "1" or lower == "yes" or lower == "on" then
            return true, true
        elseif lower == "false" or lower == "0" or lower == "no" or lower == "off" then
            return true, false
        end
        return false, nil
        
    elseif argType == Commands.ArgType.PLAYER then
        -- Just return the string, actual player lookup is done server-side
        return value ~= "", value
        
    elseif argType == Commands.ArgType.COORDINATE then
        -- Accept "x,y,z" or just return as string for manual parsing
        local parts = {}
        for part in value:gmatch("[^,]+") do
            local num = tonumber(part)
            if num then
                table.insert(parts, num)
            else
                return false, nil
            end
        end
        if #parts >= 2 then
            return true, { x = parts[1], y = parts[2], z = parts[3] or 0 }
        end
        return false, nil
    end
    
    return true, value
end

--- Get all commands in a category
---@param category string
---@return table[]
function Commands.GetByCategory(category)
    local cmds = {}
    local seen = {}
    
    for name, cmd in pairs(Commands.registry) do
        if cmd.category == category and not seen[cmd.name] then
            seen[cmd.name] = true
            table.insert(cmds, cmd)
        end
    end
    
    -- Sort by name
    table.sort(cmds, function(a, b) return a.name < b.name end)
    
    return cmds
end

--- Get all unique commands (no aliases)
---@return table[]
function Commands.GetAll()
    local cmds = {}
    local seen = {}
    
    for name, cmd in pairs(Commands.registry) do
        if not seen[cmd.name] then
            seen[cmd.name] = true
            table.insert(cmds, cmd)
        end
    end
    
    -- Sort by name
    table.sort(cmds, function(a, b) return a.name < b.name end)
    
    return cmds
end

--- Get all command categories
---@return string[]
function Commands.GetCategories()
    local categories = {}
    local seen = {}
    
    for _, cmd in pairs(Commands.registry) do
        if not seen[cmd.category] then
            seen[cmd.category] = true
            table.insert(categories, cmd.category)
        end
    end
    
    table.sort(categories)
    return categories
end

--- Format usage string for a command
---@param cmd table
---@return string
function Commands.FormatUsage(cmd)
    local usage = "/" .. cmd.name
    
    if cmd.usage then
        usage = usage .. " " .. cmd.usage
    elseif cmd.args and #cmd.args > 0 then
        for _, arg in ipairs(cmd.args) do
            if arg.required ~= false then
                usage = usage .. " <" .. arg.name .. ">"
            else
                usage = usage .. " [" .. arg.name .. "]"
            end
        end
    end
    
    return usage
end

-- Events for command execution
if KoniLib and KoniLib.Event then
    Commands.Events = {
        OnCommandExecuted = KoniLib.Event.new("ChatSystem_OnCommandExecuted"),
        OnCommandFailed = KoniLib.Event.new("ChatSystem_OnCommandFailed"),
    }
end

print("[ChatSystem] CommandAPI Shared Loaded")
