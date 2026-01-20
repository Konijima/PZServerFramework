--[[
    ChatTabs Component - Channel and PM tabs
    Built with ReactiveUI framework
    
    Uses ReactiveUI Components with self:bind() for reactive state subscriptions.
    Components automatically clean up bindings when destroyed.
]]

require "ISUI/ISContextMenu"
require "ReactiveUI/Client"
require "ChatSystem/UI/ChatState"
require "ChatSystem/UI/ChatPipes"

ChatUI = ChatUI or {}
ChatUI.Components = ChatUI.Components or {}

local Elements = ReactiveUI.Elements
local Pipe = ReactiveUI.Pipe

-- ==========================================================
-- Tab Button Component
-- Uses self:bind() for reactive updates to unread counts
-- ==========================================================

local TabButton = ReactiveUI.Component.define({
    name = "ChatTabButton",
    
    defaultProps = {
        x = 0,
        y = 0,
        width = 50,
        height = 20,
        baseText = "",       -- Base display text (channel name or username)
        channel = nil,
        username = nil,
        unreadKey = nil,     -- Key in unreadMessages state (e.g., "local" or "pm:username")
        isActive = false,
        color = { r = 1, g = 1, b = 1 },
        onClick = nil,
    },
    
    render = function(self, props, state)
        local color = props.color
        local bgColor, textColor
        
        if props.isActive then
            bgColor = { r = 0.3, g = 0.3, b = 0.35, a = 0.95 }
            textColor = { r = color.r, g = color.g, b = color.b, a = 1 }
        else
            bgColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.7 }
            textColor = { r = color.r * 0.6, g = color.g * 0.6, b = color.b * 0.6, a = 0.8 }
        end
        
        -- Elements.Button auto-initializes
        local btn = Elements.Button({
            x = props.x,
            y = props.y,
            width = props.width,
            height = props.height,
            text = props.baseText,
            font = UIFont.Small,
            backgroundColor = bgColor,
            textColor = textColor,
            backgroundColorMouseOver = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 },
            borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 },
            tooltip = props.tooltip,
            target = self,
            onClick = function(target)
                if props.onClick then
                    props.onClick(props.channel, props.username)
                end
                -- Schedule re-focus after tab click
                if ChatUI.State:get("focused") then
                    ChatUI.Components.ChatWindow._refocusNextFrame = true
                end
            end,
        })
        
        -- Store references for click handlers
        btn.channel = props.channel
        btn.username = props.username
        
        -- Use self:bind() to reactively update unread badge
        -- This binding is automatically cleaned up when component is destroyed
        if not props.isActive and props.unreadKey then
            -- Store unread count for flash effect
            local unreadCount = 0
            
            self:bind("unreadMessages", ChatUI.State)
                :pipe("default", {})
                :toCallback(function(unreadMessages)
                    unreadCount = unreadMessages[props.unreadKey] or 0
                    local badge = Pipe.create("unreadCount")(unreadCount)
                    btn:setTitle(props.baseText .. badge)
                end)
            
            -- Bind to flash state for visual effect
            self:bind("flashState", ChatUI.State)
                :toCallback(function(flashState)
                    if unreadCount > 0 then
                        if flashState then
                            -- Flash on: brighter background with channel color tint
                            btn.backgroundColor = { r = color.r * 0.4, g = color.g * 0.4, b = color.b * 0.4, a = 0.9 }
                            btn.textColor = { r = 1, g = 1, b = 1, a = 1 }
                        else
                            -- Flash off: normal inactive state
                            btn.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.7 }
                            btn.textColor = { r = color.r * 0.6, g = color.g * 0.6, b = color.b * 0.6, a = 0.8 }
                        end
                    else
                        -- No unread: normal inactive state
                        btn.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.7 }
                        btn.textColor = { r = color.r * 0.6, g = color.g * 0.6, b = color.b * 0.6, a = 0.8 }
                    end
                end)
        end
        
        return btn
    end,
})

-- ==========================================================
-- Close Button Component
-- ==========================================================

local CloseButton = ReactiveUI.Component.define({
    name = "ChatCloseButton",
    
    defaultProps = {
        x = 0,
        y = 0,
        width = 14,
        height = 20,
        username = nil,
        onClick = nil,
    },
    
    render = function(self, props, state)
        -- Elements.Button auto-initializes
        local btn = Elements.Button({
            x = props.x,
            y = props.y,
            width = props.width,
            height = props.height,
            text = "x",
            font = UIFont.Small,
            backgroundColor = { r = 0.2, g = 0.1, b = 0.1, a = 0.8 },
            textColor = { r = 1, g = 0.6, b = 0.6, a = 1 },
            backgroundColorMouseOver = { r = 0.4, g = 0.15, b = 0.15, a = 0.9 },
            borderColor = { r = 0.5, g = 0.3, b = 0.3, a = 0.8 },
            tooltip = "Close conversation",
            target = self,
            onClick = function(target)
                if props.onClick then
                    props.onClick(props.username)
                end
                -- Schedule re-focus after close button click
                if ChatUI.State:get("focused") then
                    ChatUI.Components.ChatWindow._refocusNextFrame = true
                end
            end,
        })
        btn.username = props.username
        return btn
    end,
})

-- ==========================================================
-- New PM Button Component
-- ==========================================================

-- Helper function for showing the player menu (defined outside component)
local function showPlayerMenu(props)
    local player = getPlayer()
    if player and player:isDead() then return end
    
    local parentWindow = props.parentWindow
    local x = parentWindow and (parentWindow:getAbsoluteX() + props.panelX) or 0
    local y = parentWindow and (parentWindow:getAbsoluteY() + props.panelY + props.panelHeight) or 0
    local myUsername = player and player:getUsername() or ""
    
    -- Refresh and show menu in callback to ensure player list is up to date
    ChatSystem.Client.RefreshPlayersWithCallback(function(onlinePlayers)
        local context = ISContextMenu.get(0, x, y)
        local hasPlayers = false
        
        if onlinePlayers then
            for _, p in ipairs(onlinePlayers) do
                if p.username and p.username ~= myUsername then
                    hasPlayers = true
                    context:addOption(p.username, nil, function()
                        ChatSystem.Client.OpenConversation(p.username)
                        ChatUI.Components.ChatTabs.refresh()
                        ChatUI.Messages.rebuild()
                    end)
                end
            end
        end
        
        if not hasPlayers then
            local option = context:addOption("No other players online", nil, nil)
            option.notAvailable = true
        end
        
        context:setVisible(true)
    end)
end

local NewPmButton = ReactiveUI.Component.define({
    name = "ChatNewPmButton",
    
    defaultProps = {
        x = 0,
        y = 0,
        width = 22,
        height = 20,
        parentWindow = nil,
        panelX = 0,
        panelY = 0,
        panelHeight = 20,
    },
    
    render = function(self, props, state)
        -- Elements.Button auto-initializes
        local btn = Elements.Button({
            x = props.x,
            y = props.y,
            width = props.width,
            height = props.height,
            text = "+",
            font = UIFont.Small,
            backgroundColor = { r = 0.1, g = 0.2, b = 0.1, a = 0.8 },
            textColor = { r = 0.5, g = 1, b = 0.5, a = 1 },
            backgroundColorMouseOver = { r = 0.2, g = 0.35, b = 0.2, a = 0.9 },
            borderColor = { r = 0.4, g = 0.6, b = 0.4, a = 0.8 },
            tooltip = "New conversation",
            target = self,
            onClick = function(target)
                showPlayerMenu(props)
            end,
        })
        return btn
    end,
})

-- ==========================================================
-- ChatTabs Module
-- ==========================================================

ChatUI.Components.ChatTabs = {}
local Tabs = ChatUI.Components.ChatTabs

-- Module state
local _parent = nil
local _panel = nil
local _tabComponents = {}

-- State subscription for channel changes (tabs structure)
local _stateSubscription = nil

function Tabs.create(window)
    _parent = window
    local th = window:titleBarHeight()
    local pad = ChatUI.Constants.PADDING
    
    -- Elements.Panel auto-initializes
    _panel = Elements.Panel({
        x = pad,
        y = th + pad,
        width = window.width - pad * 2 - 25,
        height = ChatUI.Constants.TAB_HEIGHT,
        background = false,
    })
    window:addChild(_panel)
    
    Tabs.refresh()
    
    -- Subscribe to state changes that affect tab structure
    -- Individual TabButtons handle their own unread count bindings via self:bind()
    _stateSubscription = ChatUI.State:subscribe({"currentChannel", "settingsVersion"}, function()
        Tabs.refresh()
    end)
    
    return _panel
end

function Tabs.refresh()
    if not _panel or not _parent then return end
    
    -- Destroy existing components to clean up their bindings
    for _, component in pairs(_tabComponents) do
        if component.destroy then
            component:destroy()
        end
    end
    
    -- Clear panel and component tracking
    _panel:clearChildren()
    _tabComponents = {}
    
    local channels = (ChatSystem.Client and ChatSystem.Client.GetAvailableChannels()) or { "local", "global" }
    local conversations = (ChatSystem.Client and ChatSystem.Client.GetConversations()) or {}
    local currentChannel = ChatUI.State:get("currentChannel")
    local activeConv = ChatSystem.Client and ChatSystem.Client.activeConversation
    
    local tabX = 0
    local tabW = 50
    local tabH = ChatUI.Constants.TAB_HEIGHT
    
    -- Channel tabs
    for _, channel in ipairs(channels) do
        local isActive = (channel == currentChannel and not activeConv)
        -- Use channelName pipe for base display name
        local tabName = Pipe.create("channelName")(channel)
        
        local color = (ChatSystem.ChannelColors and ChatSystem.ChannelColors[channel]) or { r = 1, g = 1, b = 1 }
        
        -- TabButton uses self:bind() to handle unread counts reactively
        local tabBtn = TabButton({
            x = tabX,
            y = 0,
            width = tabW,
            height = tabH,
            baseText = tabName,
            unreadKey = channel,  -- Key for unread lookup
            channel = channel,
            isActive = isActive,
            color = color,
            onClick = Tabs._onTabClick,
        })
        
        _panel:addChild(tabBtn:getElement())
        _tabComponents[channel] = tabBtn
        tabX = tabX + tabW + 2
    end
    
    -- PM tabs
    local pmColor = (ChatSystem.ChannelColors and ChatSystem.ChannelColors["private"]) or { r = 0.8, g = 0.5, b = 0.8 }
    for username, _ in pairs(conversations) do
        local pmKey = "pm:" .. username
        local isActive = (activeConv == username)
        -- Use usernameDisplay pipe for truncated name
        local displayName = Pipe.create("usernameDisplay")(username)
        
        -- PM tab button - uses self:bind() for reactive unread updates
        local pmTab = TabButton({
            x = tabX,
            y = 0,
            width = tabW,
            height = tabH,
            baseText = displayName,
            unreadKey = pmKey,  -- Key for unread lookup (e.g., "pm:username")
            channel = "private",
            username = username,
            isActive = isActive,
            color = pmColor,
            tooltip = username,
            onClick = Tabs._onPmTabClick,
        })
        
        _panel:addChild(pmTab:getElement())
        _tabComponents[pmKey] = pmTab
        tabX = tabX + tabW + 2
        
        -- Close button
        local closeBtn = CloseButton({
            x = tabX - 2,
            y = 0,
            width = 14,
            height = tabH,
            username = username,
            onClick = Tabs._onClosePmTab,
        })
        
        _panel:addChild(closeBtn:getElement())
        tabX = tabX + 16
    end
    
    -- New PM button
    if ChatSystem.Settings and ChatSystem.Settings.enablePrivateMessages then
        local newPmBtn = NewPmButton({
            x = tabX,
            y = 0,
            width = 22,
            height = tabH,
            parentWindow = _parent,
            panelX = _panel:getX(),
            panelY = _panel:getY(),
            panelHeight = _panel:getHeight(),
        })
        
        _panel:addChild(newPmBtn:getElement())
    end
end

function Tabs._onTabClick(channel, username)
    if not channel then return end
    
    ChatSystem.Client.DeactivateConversation()
    ChatSystem.Client.SetChannel(channel)
    
    -- Create new table to ensure state change is detected
    local oldUnread = ChatUI.State:get("unreadMessages") or {}
    local unread = {}
    for k, v in pairs(oldUnread) do unread[k] = v end
    unread[channel] = 0
    ChatUI.State:set("unreadMessages", unread)
    
    ChatUI.Messages.rebuild()
end

function Tabs._onPmTabClick(channel, username)
    if not username then return end
    
    ChatSystem.Client.OpenConversation(username)
    
    -- Create new table to ensure state change is detected
    local oldUnread = ChatUI.State:get("unreadMessages") or {}
    local unread = {}
    for k, v in pairs(oldUnread) do unread[k] = v end
    unread["pm:" .. username] = 0
    ChatUI.State:set("unreadMessages", unread)
    
    ChatUI.Messages.rebuild()
end

function Tabs._onClosePmTab(username)
    if not username then return end
    
    ChatSystem.Client.CloseConversation(username)
    Tabs.refresh()
    ChatUI.Messages.rebuild()
end

print("[ChatSystem] ChatTabs component loaded (ReactiveUI)")
