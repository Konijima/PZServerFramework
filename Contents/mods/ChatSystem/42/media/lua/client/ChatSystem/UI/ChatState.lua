--[[
    ChatUI State Management
    
    Central reactive state store for the chat UI using ReactiveUI.State.
    All UI components subscribe to relevant state changes for automatic updates.
]]

require "ReactiveUI/State"

ChatUI = ChatUI or {}

-- Settings file path
local SETTINGS_FILE = "ChatSystemSettings.lua"

-- Create the global chat state store using ReactiveUI
ChatUI.State = ReactiveUI.State.create({
    -- Focus state
    focused = false,
    
    -- Window state
    locked = false,
    
    -- Display settings
    showTimestamp = true,
    fadeEnabled = true,
    minOpaque = 0.3,
    maxOpaque = 0.9,
    fadeTime = 5,
    fadeTimer = 0,
    chatFont = "medium",
    
    -- Window position/size
    windowX = nil,
    windowY = nil,
    windowW = 450,
    windowH = 250,
    
    -- Input state
    timerTextEntry = 0,
    
    -- Channel state
    currentChannel = "global",  -- Default to global if available
    activeConversation = nil,  -- Username for PM conversations
    
    -- Tab state
    unreadMessages = {},   -- { [channel or "pm:username"] = count }
    flashingTabs = {},     -- { [channel or "pm:username"] = true }
    flashTimer = 0,
    flashState = false,
    
    -- Typing indicators
    typingUsers = {},  -- { [channel or "pm:username"] = { username1, username2, ... } }
    
    -- Messages
    messages = {},     -- All received messages
    
    -- Command history
    commandHistory = {},
    historyIndex = 0,
    
    -- Settings version for forcing refreshes
    settingsVersion = 0,
})

-- ==========================================================
-- Settings Persistence
-- ==========================================================

--- Save settings to file
function ChatUI.SaveSettings()
    local fileWriter = getFileWriter(SETTINGS_FILE, true, false)
    if not fileWriter then
        print("[ChatSystem] Failed to open settings file for writing")
        return false
    end
    
    local settings = {
        showTimestamp = ChatUI.State:get("showTimestamp"),
        locked = ChatUI.State:get("locked"),
        fadeEnabled = ChatUI.State:get("fadeEnabled"),
        minOpaque = ChatUI.State:get("minOpaque"),
        chatFont = ChatUI.State:get("chatFont"),
        windowX = ChatUI.State:get("windowX"),
        windowY = ChatUI.State:get("windowY"),
        windowW = ChatUI.State:get("windowW"),
        windowH = ChatUI.State:get("windowH"),
    }
    
    fileWriter:write("return {\n")
    for key, value in pairs(settings) do
        if type(value) == "string" then
            fileWriter:write("    " .. key .. " = \"" .. tostring(value) .. "\",\n")
        elseif type(value) == "boolean" then
            fileWriter:write("    " .. key .. " = " .. tostring(value) .. ",\n")
        elseif type(value) == "number" then
            fileWriter:write("    " .. key .. " = " .. tostring(value) .. ",\n")
        end
    end
    fileWriter:write("}\n")
    fileWriter:close()
    
    print("[ChatSystem] Settings saved")
    return true
end

--- Load settings from file
function ChatUI.LoadSettings()
    local fileReader = getFileReader(SETTINGS_FILE, true)
    if not fileReader then
        print("[ChatSystem] No settings file found, using defaults")
        return false
    end
    
    local content = ""
    local line = fileReader:readLine()
    while line do
        content = content .. line .. "\n"
        line = fileReader:readLine()
    end
    fileReader:close()
    
    -- Parse the Lua table
    local chunk, err = loadstring(content)
    if not chunk then
        print("[ChatSystem] Failed to parse settings file: " .. tostring(err))
        return false
    end
    
    local success, settings = pcall(chunk)
    if not success or type(settings) ~= "table" then
        print("[ChatSystem] Failed to load settings: " .. tostring(settings))
        return false
    end
    
    -- Apply loaded settings
    if settings.showTimestamp ~= nil then
        ChatUI.State:set("showTimestamp", settings.showTimestamp)
    end
    if settings.locked ~= nil then
        ChatUI.State:set("locked", settings.locked)
    end
    if settings.fadeEnabled ~= nil then
        ChatUI.State:set("fadeEnabled", settings.fadeEnabled)
    end
    if settings.minOpaque ~= nil then
        ChatUI.State:set("minOpaque", settings.minOpaque)
    end
    if settings.chatFont ~= nil then
        ChatUI.State:set("chatFont", settings.chatFont)
    end
    if settings.windowX ~= nil then
        ChatUI.State:set("windowX", settings.windowX)
    end
    if settings.windowY ~= nil then
        ChatUI.State:set("windowY", settings.windowY)
    end
    if settings.windowW ~= nil then
        ChatUI.State:set("windowW", settings.windowW)
    end
    if settings.windowH ~= nil then
        ChatUI.State:set("windowH", settings.windowH)
    end
    
    print("[ChatSystem] Settings loaded")
    return true
end

-- Add reset function to state
function ChatUI.State:reset()
    self:setMany({
        focused = false,
        locked = false,
        showTimestamp = true,
        fadeEnabled = true,
        minOpaque = 0.3,
        maxOpaque = 0.9,
        fadeTime = 5,
        fadeTimer = 0,
        chatFont = "medium",
        windowX = nil,
        windowY = nil,
        windowW = 450,
        windowH = 250,
        timerTextEntry = 0,
        currentChannel = "global",  -- Default to global if available
        activeConversation = nil,
        unreadMessages = {},
        flashingTabs = {},
        flashTimer = 0,
        flashState = false,
        typingUsers = {},
        messages = {},
        commandHistory = {},
        historyIndex = 0,
        settingsVersion = 0,
    })
end

-- ==========================================================
-- Constants
-- ==========================================================

ChatUI.Constants = {
    MAX_MESSAGES = 200,
    TAB_HEIGHT = 20,
    PADDING = 5,
    ENTRY_HEIGHT = 25,
    BOTTOM_PADDING = 15,
    TYPING_INDICATOR_HEIGHT = 16,
    MIN_WIDTH = 300,
    MIN_HEIGHT = 180,
    FLASH_INTERVAL = 0.5,
}

-- Short channel names for tabs
ChatUI.ChannelShortNames = {
    ["local"] = "Local",
    ["global"] = "Global",
    ["faction"] = "Fac",
    ["safehouse"] = "Safe",
    ["staff"] = "Staff",
    ["admin"] = "Admin",
    ["radio"] = "Radio",
}

-- Font size mapping
ChatUI.FontSizes = {
    small = UIFont.Small,
    medium = UIFont.Medium,
    large = UIFont.Large,
}

print("[ChatSystem] ChatState loaded")
