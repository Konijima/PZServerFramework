--[[
    ChatSystem ReactiveUI - Main Entry Point
    
    This is the new ChatUI built with ReactiveUI framework.
    It provides a modular, reactive chat interface using ReactiveUI components.
]]

-- ChatSystem UI is multiplayer only
if not isClient() then 
    print("[ChatSystem] ReactiveUI: Skipping - singleplayer mode")
    return 
end

require "ReactiveUI/Client"
require "ChatSystem/Definitions"
require "ChatSystem/Client"

-- Load UI components
require "ChatSystem/UI/ChatState"
require "ChatSystem/UI/Components/ChatWindow"
require "ChatSystem/UI/Components/ChatTabs"
require "ChatSystem/UI/Components/ChatMessages"
require "ChatSystem/UI/Components/ChatInput"
require "ChatSystem/UI/Components/ChatSettings"

---@class ChatUI
---@field instance ReactiveUI.ComponentInstance|nil
ChatUI = ChatUI or {}

-- ==========================================================
-- Event Handlers
-- ==========================================================

function ChatUI.OnToggleChat(key)
    if ChatUI.instance == nil then return end
    
    if getCore():isKey("Toggle chat", key) then
        ChatUI.State:set("focused", true)
    end
end

function ChatUI.OnMouseDown()
    if not ChatUI.instance then return end
    
    local mx, my = getMouseX(), getMouseY()
    local el = ChatUI.instance
    
    local isInside = mx >= el:getAbsoluteX() and mx <= el:getAbsoluteX() + el:getWidth() and
                     my >= el:getAbsoluteY() and my <= el:getAbsoluteY() + el:getHeight()
    
    if not isInside then
        -- Clicking outside - unfocus to return to game
        if ChatUI.State:get("focused") then
            ChatUI.State:set("focused", false)
        end
    end
end

function ChatUI.OnTick()
    -- Reserved for future use (fade timer, etc.)
end

function ChatUI.HideVanillaChat()
    if ISChat and ISChat.instance then
        ISChat.instance:setVisible(false)
        ISChat.instance:removeFromUIManager()
    end
end

function ChatUI.OnPlayerDeath(player)
    if ChatUI.instance and ChatUI.State:get("focused") then
        ChatUI.State:set("focused", false)
    end
end

function ChatUI.OnResolutionChange(oldw, oldh, neww, newh)
    if ChatUI.instance then
        if not ChatUI.instance:isVisible() then return end
        
        local x, y = ChatUI.instance:getX(), ChatUI.instance:getY()
        local newX = neww * (x / oldw)
        local newY = newh * (y / oldh)
        
        ChatUI.instance:setX(newX)
        ChatUI.instance:setY(newY)
        
        print("[ChatSystem] Resolution changed: " .. oldw .. "x" .. oldh .. " -> " .. neww .. "x" .. newh)
    end
end

-- ==========================================================
-- Create Chat UI
-- ==========================================================

function ChatUI.Create()
    if not isClient() and isServer() then return end
    
    -- Hide vanilla chat
    ChatUI.HideVanillaChat()
    
    -- Calculate position
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    
    local chatW = 450
    local chatH = 250
    local chatX = 15
    local chatY = screenH - chatH - 150
    
    -- Reset state
    ChatUI.State:reset()
    
    -- Create main chat window
    ChatUI.instance = ChatUI.Components.ChatWindow.create({
        x = chatX,
        y = chatY,
        width = chatW,
        height = chatH,
    })
    
    ChatUI.instance:addToUIManager()
    
    -- Register with ISLayoutManager for position/size persistence
    require "ISUI/ISLayoutManager"
    ISLayoutManager.RegisterWindow('customchat', ISCollapsableWindow, ChatUI.instance)
    
    -- Load any messages that were received before the UI was created
    if ChatSystem.Client and ChatSystem.Client.messages then
        for _, message in ipairs(ChatSystem.Client.messages) do
            ChatUI.Messages.add(message)
        end
    end
    
    -- Register vanilla events
    Events.OnKeyPressed.Add(ChatUI.OnToggleChat)
    Events.OnMouseDown.Add(ChatUI.OnMouseDown)
    Events.OnPlayerDeath.Add(ChatUI.OnPlayerDeath)
    Events.OnResolutionChange.Add(ChatUI.OnResolutionChange)
    Events.OnTick.Add(ChatUI.OnTick)
    
    -- Register ChatSystem events
    ChatSystem.Events.OnMessageReceived:Add(function(message)
        ChatUI.Messages.add(message)
    end)
    
    ChatSystem.Events.OnChannelChanged:Add(function(channel)
        ChatUI.State:set("currentChannel", channel)
    end)
    
    ChatSystem.Events.OnTypingChanged:Add(function(channel, users, target)
        local key = channel
        if channel == "private" and target then
            key = "pm:" .. target
        end
        local typingUsers = ChatUI.State:get("typingUsers") or {}
        typingUsers[key] = users
        ChatUI.State:set("typingUsers", typingUsers)
    end)
    
    ChatSystem.Events.OnSettingsChanged:Add(function(settings)
        print("[ChatSystem] ReactiveUI: Settings changed")
        -- Force refresh tabs
        if ChatUI.instance then
            ChatUI.State:set("settingsVersion", (ChatUI.State:get("settingsVersion") or 0) + 1)
        end
    end)
    
    print("[ChatSystem] ReactiveUI Chat Created")
end

-- ==========================================================
-- Initialize
-- ==========================================================

local function OnGameStart()
    local tickCount = 0
    local function delayedInit()
        tickCount = tickCount + 1
        if tickCount > 10 then
            Events.OnTick.Remove(delayedInit)
            ChatUI.Create()
        end
    end
    Events.OnTick.Add(delayedInit)
end

Events.OnGameStart.Add(OnGameStart)

print("[ChatSystem] ReactiveUI Loaded")
