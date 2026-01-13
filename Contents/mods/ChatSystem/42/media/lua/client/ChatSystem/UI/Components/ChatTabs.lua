--[[
    ChatTabs Component - Channel and PM tabs
    Built with ReactiveUI framework
]]

require "ISUI/ISContextMenu"
require "ReactiveUI/Client"
require "ChatSystem/UI/ChatState"

ChatUI = ChatUI or {}
ChatUI.Components = ChatUI.Components or {}

local Elements = ReactiveUI.Elements

-- ==========================================================
-- Tab Button Component
-- ==========================================================

local TabButton = ReactiveUI.Component.define({
    name = "ChatTabButton",
    
    defaultProps = {
        x = 0,
        y = 0,
        width = 50,
        height = 20,
        text = "",
        channel = nil,
        username = nil,
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
            text = props.text,
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
    
    ChatSystem.Client.RefreshPlayers()
    
    local parentWindow = props.parentWindow
    local x = parentWindow and (parentWindow:getAbsoluteX() + props.panelX) or 0
    local y = parentWindow and (parentWindow:getAbsoluteY() + props.panelY + props.panelHeight) or 0
    
    local context = ISContextMenu.get(0, x, y)
    local myUsername = player and player:getUsername() or ""
    
    local onlinePlayers = ChatSystem.Client.GetOnlinePlayers()
    if onlinePlayers then
        for _, p in ipairs(onlinePlayers) do
            if p.username and p.username ~= myUsername then
                context:addOption(p.username, nil, function()
                    ChatSystem.Client.OpenConversation(p.username)
                    ChatUI.Components.ChatTabs.refresh()
                    ChatUI.Messages.rebuild()
                end)
            end
        end
    end
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
    
    -- Subscribe to state changes
    ChatUI.State:subscribe("currentChannel", function() Tabs.refresh() end)
    ChatUI.State:subscribe("unreadMessages", function() Tabs.refresh() end)
    ChatUI.State:subscribe("settingsVersion", function() Tabs.refresh() end)
    
    return _panel
end

function Tabs.refresh()
    if not _panel or not _parent then return end
    
    -- Clear existing components
    _panel:clearChildren()
    _tabComponents = {}
    
    local channels = (ChatSystem.Client and ChatSystem.Client.GetAvailableChannels()) or { "local", "global" }
    local conversations = (ChatSystem.Client and ChatSystem.Client.GetConversations()) or {}
    local currentChannel = ChatUI.State:get("currentChannel")
    local activeConv = ChatSystem.Client and ChatSystem.Client.activeConversation
    local unread = ChatUI.State:get("unreadMessages") or {}
    
    local tabX = 0
    local tabW = 50
    local tabH = ChatUI.Constants.TAB_HEIGHT
    
    -- Channel tabs
    for _, channel in ipairs(channels) do
        local isActive = (channel == currentChannel and not activeConv)
        local tabName = ChatUI.ChannelShortNames[channel] or channel:sub(1, 5)
        local unreadCount = unread[channel] or 0
        
        if unreadCount > 0 and not isActive then
            tabName = tabName .. "(" .. (unreadCount > 9 and "9+" or unreadCount) .. ")"
        end
        
        local color = (ChatSystem.ChannelColors and ChatSystem.ChannelColors[channel]) or { r = 1, g = 1, b = 1 }
        
        local tabBtn = TabButton({
            x = tabX,
            y = 0,
            width = tabW,
            height = tabH,
            text = tabName,
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
        local displayName = #username > 5 and username:sub(1, 5) .. ".." or username
        local unreadCount = unread[pmKey] or 0
        
        if unreadCount > 0 and not isActive then
            displayName = displayName .. "(" .. (unreadCount > 9 and "9+" or unreadCount) .. ")"
        end
        
        -- PM tab button
        local pmTab = TabButton({
            x = tabX,
            y = 0,
            width = tabW,
            height = tabH,
            text = displayName,
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
    
    local unread = ChatUI.State:get("unreadMessages") or {}
    unread[channel] = 0
    ChatUI.State:set("unreadMessages", unread)
    
    ChatUI.Messages.rebuild()
end

function Tabs._onPmTabClick(channel, username)
    if not username then return end
    
    ChatSystem.Client.OpenConversation(username)
    
    local unread = ChatUI.State:get("unreadMessages") or {}
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
