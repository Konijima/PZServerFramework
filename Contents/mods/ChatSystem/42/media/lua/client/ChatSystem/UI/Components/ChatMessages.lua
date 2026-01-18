--[[
    ChatMessages Component - Message display
    Built with ReactiveUI framework
    
    This module creates and manages the chat message display panel.
    Uses direct state subscriptions for reactive updates.
]]

require "ReactiveUI/Client"
require "ChatSystem/UI/ChatState"
require "ChatSystem/UI/ChatPipes"

ChatUI = ChatUI or {}
ChatUI.Components = ChatUI.Components or {}
ChatUI.Components.ChatMessages = {}
ChatUI.Messages = {}

local Elements = ReactiveUI.Elements
local Pipe = ReactiveUI.Pipe
local Messages = ChatUI.Components.ChatMessages

-- Module-level panel reference and state subscription
local _panel = nil
local _stateSubscription = nil

function Messages.create(window)
    local th = window:titleBarHeight()
    local pad = ChatUI.Constants.PADDING
    local tabH = ChatUI.Constants.TAB_HEIGHT
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local typingH = ChatUI.Constants.TYPING_INDICATOR_HEIGHT
    local bottomPad = 8  -- Match the input's bottom padding
    
    local y = th + pad + tabH + pad
    local h = window.height - y - entryH - bottomPad - pad - typingH
    
    -- Elements.RichText auto-initializes
    _panel = Elements.RichText({
        x = pad,
        y = y,
        width = window.width - pad * 2,
        height = h,
        anchorLeft = true,
        anchorRight = true,
        anchorTop = true,
        anchorBottom = true,
        backgroundColor = { r = 0, g = 0, b = 0, a = 0 },
        borderColor = { r = 0, g = 0, b = 0, a = 0 },
    })
    _panel.autosetheight = false
    _panel.background = false
    _panel.clip = true
    _panel.marginTop = 5
    _panel.marginBottom = 5
    _panel._needsScrollToBottom = false
    
    -- Hook prerender to scroll to bottom after pagination is computed
    local origPrerender = _panel.prerender
    _panel.prerender = function(self)
        if origPrerender then origPrerender(self) end
        if self._needsScrollToBottom and self.vscroll then
            self.vscroll:setCurrentValue(self.vscroll.maxValue or 0)
            self._needsScrollToBottom = false
        end
    end
    
    -- When clicking on messages panel, schedule input re-focus
    local origMouseDown = _panel.onMouseDown
    _panel.onMouseDown = function(self, x, y)
        if ChatUI.State:get("focused") then
            ChatUI.Components.ChatWindow._refocusNextFrame = true
        end
        if origMouseDown then origMouseDown(self, x, y) end
    end
    
    -- Subscribe to state changes that affect message display
    _stateSubscription = ChatUI.State:subscribe({"messages", "showTimestamp", "chatFont"}, function()
        Messages.rebuild()
    end)
    
    return _panel
end

function Messages.rebuild(panel)
    panel = panel or _panel
    if not panel then return end
    
    local messages = ChatUI.State:get("messages") or {}
    local currentChannel = ChatUI.State:get("currentChannel")
    local activeConv = ChatSystem.Client and ChatSystem.Client.activeConversation
    local showTimestamp = ChatUI.State:get("showTimestamp")
    local fontName = ChatUI.State:get("chatFont") or "medium"
    local font = ChatUI.FontSizes[fontName] or UIFont.Medium
    
    panel:setText("")
    -- Must set both font and defaultFont for ISRichTextPanel to work properly
    panel.font = font
    panel.defaultFont = font
    
    local text = ""
    
    if activeConv then
        -- Show PM conversation messages using the conversation system
        local conversationMessages = ChatSystem.Client and ChatSystem.Client.GetConversationMessages and ChatSystem.Client.GetConversationMessages(activeConv) or {}
        for _, msg in ipairs(conversationMessages) do
            text = text .. Messages.formatMessage(msg, showTimestamp) .. " <LINE> "
        end
    else
        -- Filter messages by current channel (but always show global system messages)
        for _, msg in ipairs(messages) do
            local showMessage = msg.channel == currentChannel
            -- Always show system messages from global channel (announcements, etc.)
            if msg.isSystem and msg.channel == "global" then
                showMessage = true
            end
            -- Don't show PMs in regular channel tabs
            if msg.channel == "private" then
                showMessage = false
            end
            if showMessage then
                text = text .. Messages.formatMessage(msg, showTimestamp) .. " <LINE> "
            end
        end
    end
    
    panel:setText(text)
    panel:paginate()
    
    -- Schedule scroll to bottom for next prerender (after pagination is computed)
    panel._needsScrollToBottom = true
end

function Messages.formatMessage(msg, showTimestamp)
    local result = ""
    
    -- Timestamp [HH:MM] - gray - using chatTimestamp pipe
    if showTimestamp and msg.timestamp then
        local formattedTime = Pipe.create("chatTimestamp")(msg.timestamp)
        result = result .. " <RGB:0.5,0.5,0.5> " .. formattedTime
    end
    
    -- Handle special message types (emotes and system messages)
    if msg.metadata and msg.metadata.isEmote then
        -- Emote format: just the text (already formatted as "* Name action *")
        local emoteColor = Messages.getRoleColor(msg.metadata and msg.metadata.role)
        result = result .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", emoteColor.r, emoteColor.g, emoteColor.b) .. "> " .. (msg.text or "")
        return result
    elseif msg.isSystem then
        -- System message: yellow color, no author prefix
        result = result .. " <SPACE> <RGB:1,0.8,0.2> " .. (msg.text or "")
        return result
    end
    
    -- Regular message: Author name colored by role (using roleColor pipe)
    local msgAuthor = type(msg.author) == "string" and msg.author or tostring(msg.author or "???")
    local roleColor = Pipe.create("roleColor")(msg.metadata and msg.metadata.role)
    result = result .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", roleColor.r, roleColor.g, roleColor.b) .. "> " .. msgAuthor .. ":"
    
    -- Message text in white
    local msgText = msg.text or msg.message or ""
    result = result .. " <SPACE> <RGB:1,1,1> " .. msgText
    
    -- Yell indicator
    if msg.metadata and msg.metadata.isYell then
        result = result .. " <SPACE> <RGB:1,0.5,0.5> (!)"
    end
    
    return result
end

-- Get color based on player role/access level
function Messages.getRoleColor(role)
    local roleColors = {
        owner = { r = 1, g = 0.2, b = 0.2 },       -- Red for owner
        admin = { r = 1, g = 0.4, b = 0.4 },       -- Light red for admin
        moderator = { r = 0.2, g = 0.8, b = 1 },   -- Cyan for moderator
        player = { r = 1, g = 1, b = 1 },          -- White for regular player
    }
    
    if role and roleColors[role:lower()] then
        return roleColors[role:lower()]
    end
    
    -- Default white for unknown/no role
    return { r = 1, g = 1, b = 1 }
end

function Messages.updateLayout(panel, window)
    if not panel or not window then return end
    
    local th = window:titleBarHeight()
    local pad = ChatUI.Constants.PADDING
    local tabH = ChatUI.Constants.TAB_HEIGHT
    local entryH = ChatUI.Constants.ENTRY_HEIGHT
    local typingH = ChatUI.Constants.TYPING_INDICATOR_HEIGHT
    local bottomPad = ChatUI.State:get("locked") and 5 or 8  -- Match input's bottom padding
    
    local y = th + pad + tabH + pad
    local h = window.height - y - entryH - bottomPad - pad - typingH
    
    panel:setY(y)
    panel:setHeight(h)
    panel:setWidth(window.width - pad * 2)
end

-- Static helpers for ChatUI.Messages
function ChatUI.Messages.add(message)
    local oldMessages = ChatUI.State:get("messages") or {}
    -- Create a new table to ensure state change is detected
    local messages = {}
    for i, msg in ipairs(oldMessages) do
        messages[i] = msg
    end
    table.insert(messages, message)
    
    while #messages > ChatUI.Constants.MAX_MESSAGES do
        table.remove(messages, 1)
    end
    
    ChatUI.State:set("messages", messages)
    
    -- Update unread
    local currentChannel = ChatUI.State:get("currentChannel")
    local activeConv = ChatSystem.Client and ChatSystem.Client.activeConversation
    
    if message.channel == "private" then
        -- For PM messages, check if this is the active conversation
        local myUsername = getPlayer() and getPlayer():getUsername() or ""
        local otherPerson = message.author
        if message.metadata and message.metadata.to and message.author == myUsername then
            otherPerson = message.metadata.to
        end
        
        if activeConv ~= otherPerson then
            -- Not viewing this conversation, mark as unread
            local pmKey = "pm:" .. otherPerson
            -- Create new table to ensure state change is detected
            local oldUnread = ChatUI.State:get("unreadMessages") or {}
            local unread = {}
            for k, v in pairs(oldUnread) do unread[k] = v end
            unread[pmKey] = (unread[pmKey] or 0) + 1
            ChatUI.State:set("unreadMessages", unread)
        end
    elseif message.channel ~= currentChannel or activeConv then
        -- Not on this channel tab (or we're in a PM conversation)
        -- Create new table to ensure state change is detected
        local oldUnread = ChatUI.State:get("unreadMessages") or {}
        local unread = {}
        for k, v in pairs(oldUnread) do unread[k] = v end
        unread[message.channel] = (unread[message.channel] or 0) + 1
        ChatUI.State:set("unreadMessages", unread)
    end
    
    -- Reset fade
    ChatUI.State:set("fadeTimer", 0)
    if ChatUI.instance then
        ChatUI.instance.backgroundColor.a = ChatUI.State:get("maxOpaque")
    end
end

function ChatUI.Messages.rebuild()
    Messages.rebuild()
end

print("[ChatSystem] ChatMessages component loaded (ReactiveUI)")
