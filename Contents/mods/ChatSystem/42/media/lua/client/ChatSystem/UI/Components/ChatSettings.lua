--[[
    ChatSettings Component - Settings menu, typing indicator
    Built with ReactiveUI framework
]]

require "ISUI/ISContextMenu"
require "ReactiveUI/Client"
require "ChatSystem/UI/ChatState"

ChatUI = ChatUI or {}
ChatUI.Components = ChatUI.Components or {}
ChatUI.Components.TypingIndicator = {}
ChatUI.Settings = {}

local Elements = ReactiveUI.Elements
local Typing = ChatUI.Components.TypingIndicator

function Typing.create(window)
    local pad = ChatUI.Constants.PADDING
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local typingH = ChatUI.Constants.TYPING_INDICATOR_HEIGHT
    local bottomPad = ChatUI.Constants.BOTTOM_PADDING
    
    -- Elements.Label auto-initializes
    local label = Elements.Label({
        x = pad + 5,
        y = window.height - entryH - bottomPad - typingH,
        height = typingH,
        text = "",
        font = UIFont.Small,
        color = { r = 0.6, g = 0.6, b = 0.6, a = 0.8 },
        anchorTop = false,
        anchorBottom = true,
    })
    
    -- Subscribe to state changes for automatic updates
    ChatUI.State:subscribe("typingUsers", function() Typing.update(label) end)
    
    return label
end

function Typing.update(label)
    if not label then return end
    
    local typingUsers = ChatUI.State:get("typingUsers") or {}
    local currentChannel = ChatUI.State:get("currentChannel")
    local activeConv = ChatSystem.Client and ChatSystem.Client.activeConversation
    
    local key = activeConv and ("pm:" .. activeConv) or currentChannel
    local users = typingUsers[key] or {}
    
    local text = ""
    if #users == 1 then
        text = users[1] .. " is typing..."
    elseif #users > 1 then
        text = table.concat(users, ", ") .. " are typing..."
    end
    
    label:setName(text)
end

function Typing.updateLayout(label, window)
    if not label or not window then return end
    
    local pad = ChatUI.Constants.PADDING
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local typingH = ChatUI.Constants.TYPING_INDICATOR_HEIGHT
    local bottomPad = ChatUI.State:get("locked") and 5 or ChatUI.Constants.BOTTOM_PADDING
    
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
    end)
    
    -- Fade
    local fadeOn = ChatUI.State:get("fadeEnabled")
    context:addOption(fadeOn and "Disable Fade" or "Enable Fade", nil, function()
        ChatUI.State:set("fadeEnabled", not fadeOn)
    end)
    
    -- Font size
    local fontSub = context:getNew(context)
    context:addSubMenu(context:addOption("Font Size"), fontSub)
    for name, _ in pairs(ChatUI.FontSizes) do
        fontSub:addOption(name:sub(1,1):upper() .. name:sub(2), nil, function()
            ChatUI.State:set("chatFont", name)
            ChatUI.Messages.rebuild()
        end)
    end
    
    -- Clear
    context:addOption("Clear Chat", nil, function()
        ChatUI.State:set("messages", {})
    end)
end

print("[ChatSystem] ChatSettings component loaded (ReactiveUI)")
