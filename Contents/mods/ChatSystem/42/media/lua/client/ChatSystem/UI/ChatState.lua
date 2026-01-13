--[[
    ChatUI State Management
    
    Central reactive state store for the chat UI using ReactiveUI.State.
    All UI components subscribe to relevant state changes for automatic updates.
]]

require "ReactiveUI/State"

ChatUI = ChatUI or {}

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
    
    -- Input state
    timerTextEntry = 0,
    
    -- Channel state
    currentChannel = "local",
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
        timerTextEntry = 0,
        currentChannel = "local",
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
