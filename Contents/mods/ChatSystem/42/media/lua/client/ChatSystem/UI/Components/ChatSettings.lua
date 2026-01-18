--[[
    ChatSettings Component - Settings menu, typing indicator
    Built with ReactiveUI framework
    
    Uses direct state subscriptions for reactive updates.
]]

require "ISUI/ISContextMenu"
require "ReactiveUI/Client"
require "ChatSystem/UI/ChatState"
require "ChatSystem/UI/ChatPipes"

ChatUI = ChatUI or {}
ChatUI.Components = ChatUI.Components or {}
ChatUI.Components.TypingIndicator = {}
ChatUI.Settings = {}

local Elements = ReactiveUI.Elements
local Pipe = ReactiveUI.Pipe
local Typing = ChatUI.Components.TypingIndicator

-- Module-level label reference and state subscription
local _label = nil
local _stateSubscription = nil

function Typing.create(window)
    local pad = ChatUI.Constants.PADDING
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local typingH = ChatUI.Constants.TYPING_INDICATOR_HEIGHT
    local bottomPad = 8  -- Match the input's bottom padding
    
    -- Elements.Label auto-initializes
    _label = Elements.Label({
        x = pad,
        y = window.height - entryH - bottomPad - typingH,
        height = typingH,
        text = "",
        font = UIFont.Small,
        color = { r = 0.6, g = 0.6, b = 0.6, a = 0.8 },
        anchorTop = false,
        anchorBottom = true,
    })
    _label:setVisible(false)  -- Start hidden
    
    -- Subscribe to state changes that affect typing display
    _stateSubscription = ChatUI.State:subscribe({"typingUsers", "currentChannel"}, function()
        Typing._updateLabel()
    end)
    
    return _label
end

-- Internal update function called by subscription
function Typing._updateLabel()
    if not _label then return end
    
    local typingUsers = ChatUI.State:get("typingUsers") or {}
    local currentChannel = ChatUI.State:get("currentChannel")
    local activeConv = ChatSystem.Client and ChatSystem.Client.activeConversation
    
    local key = activeConv and ("pm:" .. activeConv) or currentChannel
    local users = typingUsers[key] or {}
    
    if #users == 0 then
        _label:setVisible(false)
        return
    end
    
    -- Use the typingUsers pipe for formatting
    local text = Pipe.create("typingUsers")(users)
    
    -- Get channel color for typing indicator
    local color
    if activeConv then
        color = (ChatSystem.ChannelColors and ChatSystem.ChannelColors["private"]) or { r = 0.8, g = 0.5, b = 0.8 }
    else
        color = (ChatSystem.ChannelColors and ChatSystem.ChannelColors[currentChannel]) or { r = 0.6, g = 0.6, b = 0.6 }
    end
    
    _label:setName(text)
    _label:setColor(color.r, color.g, color.b)
    _label:setVisible(true)
end

-- Legacy update function for compatibility
function Typing.update(label)
    Typing._updateLabel()
end

function Typing.updateLayout(label, window)
    label = label or _label
    if not label or not window then return end
    
    local pad = ChatUI.Constants.PADDING
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local typingH = ChatUI.Constants.TYPING_INDICATOR_HEIGHT
    local bottomPad = ChatUI.State:get("locked") and 5 or 8  -- Match input's bottom padding
    
    label:setX(pad)
    label:setY(window.height - entryH - bottomPad - typingH)
end

-- Settings menu
function ChatUI.Settings.showMenu(window)
    if not window then return end
    
    local x = window:getAbsoluteX() + window.width - 20
    local y = window:getAbsoluteY() + window:titleBarHeight() + 20
    
    local context = ISContextMenu.get(0, x, y)
    
    -- Timestamps
    local showTs = ChatUI.State:get("showTimestamp")
    context:addOption(showTs and "Hide Timestamps" or "Show Timestamps", nil, function()
        ChatUI.State:set("showTimestamp", not showTs)
        ChatUI.Messages.rebuild()
        ChatUI.SaveSettings()
    end)
    
    -- Fade toggle
    local fadeOn = ChatUI.State:get("fadeEnabled")
    context:addOption(fadeOn and "Disable Fade" or "Enable Fade", nil, function()
        ChatUI.State:set("fadeEnabled", not fadeOn)
        -- Reset to full opacity immediately when disabling fade
        if fadeOn then
            ChatUI.State:set("fadeTimer", 0)
            if window then
                window.backgroundColor.a = ChatUI.State:get("maxOpaque")
            end
        end
        ChatUI.SaveSettings()
    end)
    
    -- Fade opacity submenu (only show if fading is enabled)
    if fadeOn then
        local fadeOption = context:addOption("Fade Opacity")
        local fadeSub = context:getNew(context)
        context:addSubMenu(fadeOption, fadeSub)
        
        local opacities = { 0, 25, 50, 75 }
        local currentMin = math.floor(ChatUI.State:get("minOpaque") * 100)
        for _, pct in ipairs(opacities) do
            local opt = fadeSub:addOption(pct .. "%", nil, function()
                ChatUI.State:set("minOpaque", pct / 100)
                ChatUI.SaveSettings()
            end)
            if currentMin == pct then
                fadeSub:setOptionChecked(opt, true)
            end
        end
    end
    
    -- Font size submenu
    local fontOption = context:addOption("Font Size")
    local fontSub = context:getNew(context)
    context:addSubMenu(fontOption, fontSub)
    
    local currentFont = ChatUI.State:get("chatFont") or "medium"
    local fontNames = { "small", "medium", "large" }
    for _, name in ipairs(fontNames) do
        local displayName = name:sub(1,1):upper() .. name:sub(2)
        local opt = fontSub:addOption(displayName, nil, function()
            ChatUI.State:set("chatFont", name)
            ChatUI.Messages.rebuild()
            ChatUI.SaveSettings()
        end)
        if currentFont == name then
            fontSub:setOptionChecked(opt, true)
        end
    end
    
    -- Clear chat
    context:addOption("Clear Chat", nil, function()
        ChatUI.State:set("messages", {})
        if ChatSystem.Client and ChatSystem.Client.ClearMessages then
            ChatSystem.Client.ClearMessages()
        end
    end)
end

print("[ChatSystem] ChatSettings component loaded (ReactiveUI)")
