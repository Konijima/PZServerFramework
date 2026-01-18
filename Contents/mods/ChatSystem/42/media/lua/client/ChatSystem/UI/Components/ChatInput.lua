--[[
    ChatInput Component - Text entry
    Built with ReactiveUI framework
]]

require "ReactiveUI/Client"
require "ChatSystem/UI/ChatState"

ChatUI = ChatUI or {}
ChatUI.Components = ChatUI.Components or {}
ChatUI.Components.ChatInput = {}

local Elements = ReactiveUI.Elements
local Input = ChatUI.Components.ChatInput

function Input.create(window)
    local pad = ChatUI.Constants.PADDING
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local bottomPad = 8  -- Reduced from BOTTOM_PADDING to bring input closer to bottom
    
    -- Elements.TextEntry auto-initializes and handles deferred props like editable
    local entry = Elements.TextEntry({
        x = pad,
        y = window.height - entryH - bottomPad,
        width = window.width - pad * 2,
        height = entryH,
        text = "",
        anchorLeft = true,
        anchorRight = true,
        anchorTop = false,
        anchorBottom = true,
        editable = false,  -- Auto-applied after init
    })
    
    -- Apply max message length from sandbox settings
    local maxLength = (ChatSystem.Settings and ChatSystem.Settings.maxMessageLength) or 500
    entry:setMaxTextLength(maxLength)
    
    Input._setupHandlers(entry)
    
    return entry
end

function Input._setupHandlers(entry)
    entry.onCommandEntered = function()
        Input._onSubmit(entry)
    end
    
    -- Override onKeyPress to intercept Up/Down for history navigation
    -- onOtherKey doesn't receive arrow keys as they're consumed by text entry cursor logic
    local origOnKeyPress = entry.onKeyPress
    entry.onKeyPress = function(self, key)
        if key == Keyboard.KEY_UP then
            Input._historyUp(entry)
            return true  -- Consume the key
        elseif key == Keyboard.KEY_DOWN then
            Input._historyDown(entry)
            return true  -- Consume the key
        elseif key == Keyboard.KEY_TAB then
            Input._cycleChannel()
            return true  -- Consume the key
        elseif key == Keyboard.KEY_ESCAPE then
            ChatUI.State:set("focused", false)
            return true  -- Consume the key
        end
        if origOnKeyPress then return origOnKeyPress(self, key) end
    end
    
    entry.onTextChange = function()
        if not ChatSystem.Client then return end
        local text = entry:getText() or ""
        -- Don't show typing indicator when typing a command or when text is empty
        if text == "" or text:sub(1, 1) == "/" then
            if ChatSystem.Client.StopTyping then
                ChatSystem.Client.StopTyping()
            end
        else
            if ChatSystem.Client.StartTyping then
                ChatSystem.Client.StartTyping()
            end
        end
    end
end

function Input._onSubmit(entry)
    local text = entry:getText()
    if not text or text == "" then
        ChatUI.State:set("focused", false)
        return
    end
    
    -- Add to command history (create new table for state change detection)
    local oldHistory = ChatUI.State:get("commandHistory") or {}
    local history = {}
    for i, h in ipairs(oldHistory) do
        history[i] = h
    end
    table.insert(history, text)
    if #history > 50 then table.remove(history, 1) end
    ChatUI.State:setMany({ commandHistory = history, historyIndex = 0 })
    
    -- Stop typing indicator
    if ChatSystem.Client and ChatSystem.Client.StopTyping then
        ChatSystem.Client.StopTyping()
    end
    
    local activeConv = ChatSystem.Client and ChatSystem.Client.activeConversation
    if activeConv then
        -- Send as PM (SendMessageDirect handles activeConversation automatically)
        ChatSystem.Client.SendMessageDirect(text)
    else
        -- Check if user typed a channel command (e.g., /l, /g)
        -- If so, switch channel and extract the message
        local detectedChannel, cleanText = ChatSystem.Client.DetectChannelPrefix(text)
        if detectedChannel then
            -- Switch to that channel
            ChatSystem.Client.SetChannel(detectedChannel)
            text = cleanText
        end
        
        -- Only send if there's actual message content
        if text and text ~= "" and text ~= " " then
            -- Send message using current channel (no prefix needed)
            ChatSystem.Client.SendMessageDirect(text)
        end
    end
    
    entry:setText("")
    
    -- Unfocus after sending message to return to game
    ChatUI.State:set("focused", false)
end

function Input._historyUp(entry)
    local history = ChatUI.State:get("commandHistory") or {}
    local idx = ChatUI.State:get("historyIndex") or 0
    
    if #history == 0 then return end
    
    idx = math.min(idx + 1, #history)
    ChatUI.State:set("historyIndex", idx)
    
    local historyText = history[#history - idx + 1]
    if historyText then entry:setText(historyText) end
end

function Input._historyDown(entry)
    local history = ChatUI.State:get("commandHistory") or {}
    local idx = ChatUI.State:get("historyIndex") or 0
    
    if idx <= 0 then return end
    
    idx = idx - 1
    ChatUI.State:set("historyIndex", idx)
    
    if idx == 0 then
        entry:setText("")
    else
        local historyText = history[#history - idx + 1]
        if historyText then entry:setText(historyText) end
    end
end

function Input._cycleChannel()
    ChatSystem.Client.DeactivateConversation()
    local channels = ChatSystem.Client.GetAvailableChannels()
    local current = ChatUI.State:get("currentChannel")
    
    local idx = 1
    for i, ch in ipairs(channels) do
        if ch == current then idx = i break end
    end
    
    local nextIdx = (idx % #channels) + 1
    ChatSystem.Client.SetChannel(channels[nextIdx])
    ChatUI.Messages.rebuild()
end

function Input.focus(entry, clearText)
    if not entry then return end
    -- Now set up for input
    entry:setVisible(true)
    entry:setEditable(true)
    entry:focus()
    entry:ignoreFirstInput()
    -- Only clear text if explicitly requested (e.g., opening chat with T)
    if clearText then
        entry:setText("")
    end
end

function Input.unfocus(entry)
    if not entry then return end
    entry:unfocus()
    entry:setText("")
    entry:setEditable(false)
    -- doKeyPress(false) is called by ChatWindow._unfocus
end

function Input.updateLayout(entry, window)
    if not entry or not window then return end
    
    local pad = ChatUI.Constants.PADDING
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local bottomPad = ChatUI.State:get("locked") and 5 or 8  -- Use consistent reduced padding
    
    entry:setX(pad)
    entry:setY(window.height - entryH - bottomPad)
    entry:setWidth(window.width - pad * 2)
end

print("[ChatSystem] ChatInput component loaded (ReactiveUI)")
