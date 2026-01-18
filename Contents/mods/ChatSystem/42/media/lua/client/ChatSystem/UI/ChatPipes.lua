--[[
    ChatSystem Custom Pipes
    
    Registers chat-specific pipes for formatting messages, timestamps, 
    typing indicators, and other UI elements.
    
    These pipes integrate with ReactiveUI's Pipe system for clean, 
    reusable formatting throughout the chat UI.
]]

require "ReactiveUI/Pipe"

local Pipe = ReactiveUI.Pipe

--[[
    Chat Timestamp Pipe
    
    Formats a millisecond timestamp to [HH:MM] format.
    
    Args:
        format (string): "short" for [HH:MM], "full" for [HH:MM:SS]. Default: "short"
    
    Usage:
        binding:pipe("chatTimestamp")
        binding:pipe("chatTimestamp", { format = "full" })
    
    Example:
        1705248000000 -> "[14:30]"
]]
Pipe.register("chatTimestamp", function(value, args)
    if not value then return "" end
    
    local format = args.format or "short"
    local timestamp = tonumber(value) or 0
    local seconds = math.floor(timestamp / 1000)
    
    if format == "full" then
        return "[" .. os.date("%H:%M:%S", seconds) .. "]"
    else
        return "[" .. os.date("%H:%M", seconds) .. "]"
    end
end)

function Pipe.chatTimestamp(args)
    return Pipe.create("chatTimestamp", args)
end

--[[
    Typing Users Pipe
    
    Formats a list of usernames into a typing indicator string.
    
    Args:
        maxShow (number): Max users to show by name. Default: 2
    
    Usage:
        binding:pipe("typingUsers")
    
    Examples:
        {"John"} -> "John is typing..."
        {"John", "Jane"} -> "John and Jane are typing..."
        {"John", "Jane", "Bob"} -> "John, Jane and 1 more are typing..."
]]
Pipe.register("typingUsers", function(value, args)
    if not value or type(value) ~= "table" or #value == 0 then
        return ""
    end
    
    local users = value
    local maxShow = args.maxShow or 2
    
    if #users == 1 then
        return users[1] .. " is typing..."
    elseif #users == 2 then
        return users[1] .. " and " .. users[2] .. " are typing..."
    else
        local shown = {}
        for i = 1, math.min(maxShow, #users) do
            table.insert(shown, users[i])
        end
        local remaining = #users - maxShow
        if remaining > 0 then
            return table.concat(shown, ", ") .. " and " .. remaining .. " more are typing..."
        else
            return table.concat(shown, ", ") .. " are typing..."
        end
    end
end)

function Pipe.typingUsers(args)
    return Pipe.create("typingUsers", args)
end

--[[
    Unread Count Pipe
    
    Formats an unread message count for display in tabs.
    
    Args:
        max (number): Maximum number to show before using "+". Default: 9
    
    Usage:
        binding:pipe("unreadCount")
    
    Examples:
        0 -> ""
        5 -> "(5)"
        15 -> "(9+)"
]]
Pipe.register("unreadCount", function(value, args)
    local count = tonumber(value) or 0
    if count <= 0 then return "" end
    
    local max = args.max or 9
    if count > max then
        return "(" .. max .. "+)"
    else
        return "(" .. count .. ")"
    end
end)

function Pipe.unreadCount(args)
    return Pipe.create("unreadCount", args)
end

--[[
    Username Display Pipe
    
    Formats a username for display in tabs (truncate with ellipsis).
    
    Args:
        maxLength (number): Maximum characters to show. Default: 5
    
    Usage:
        binding:pipe("usernameDisplay")
        binding:pipe("usernameDisplay", { maxLength = 8 })
    
    Examples:
        "John" -> "John"
        "VeryLongUsername" -> "VeryL.."
]]
Pipe.register("usernameDisplay", function(value, args)
    if not value then return "" end
    
    local str = tostring(value)
    local maxLength = args.maxLength or 5
    
    if #str > maxLength then
        return str:sub(1, maxLength) .. ".."
    end
    return str
end)

function Pipe.usernameDisplay(args)
    return Pipe.create("usernameDisplay", args)
end

--[[
    RGB Color Pipe
    
    Formats a color table for ISRichTextPanel RGB tags.
    
    Usage:
        binding:pipe("rgbTag")
    
    Example:
        { r = 1, g = 0.5, b = 0.2 } -> "<RGB:1.0,0.5,0.2>"
]]
Pipe.register("rgbTag", function(value, args)
    if not value or type(value) ~= "table" then
        return "<RGB:1,1,1>"
    end
    
    local r = value.r or 1
    local g = value.g or 1
    local b = value.b or 1
    
    return string.format("<RGB:%.1f,%.1f,%.1f>", r, g, b)
end)

function Pipe.rgbTag(args)
    return Pipe.create("rgbTag", args)
end

--[[
    Channel Display Name Pipe
    
    Converts channel ID to display name.
    
    Usage:
        binding:pipe("channelName")
    
    Examples:
        "local" -> "Local"
        "global" -> "Global"
        "unknown" -> "Unkno" (truncated)
]]
Pipe.register("channelName", function(value, args)
    if not value then return "" end
    
    local names = {
        ["local"] = "Local",
        ["global"] = "Global",
        ["faction"] = "Fac",
        ["safehouse"] = "Safe",
        ["staff"] = "Staff",
        ["admin"] = "Admin",
        ["radio"] = "Radio",
        ["private"] = "PM",
    }
    
    return names[value] or value:sub(1, 5)
end)

function Pipe.channelName(args)
    return Pipe.create("channelName", args)
end

--[[
    Player Role Color Pipe
    
    Returns color based on player role/access level.
    
    Usage:
        binding:pipe("roleColor")
    
    Examples:
        "admin" -> { r = 1, g = 0.4, b = 0.4 }
        "moderator" -> { r = 0.2, g = 0.8, b = 1 }
        nil -> { r = 1, g = 1, b = 1 }
]]
Pipe.register("roleColor", function(value, args)
    local roleColors = {
        owner = { r = 1, g = 0.2, b = 0.2 },       -- Red for owner
        admin = { r = 1, g = 0.4, b = 0.4 },       -- Light red for admin
        moderator = { r = 0.2, g = 0.8, b = 1 },   -- Cyan for moderator
        player = { r = 1, g = 1, b = 1 },          -- White for regular player
    }
    
    if value and roleColors[value:lower()] then
        return roleColors[value:lower()]
    end
    
    return { r = 1, g = 1, b = 1 }
end)

function Pipe.roleColor(args)
    return Pipe.create("roleColor", args)
end

print("[ChatSystem] ChatPipes registered (ReactiveUI)")
