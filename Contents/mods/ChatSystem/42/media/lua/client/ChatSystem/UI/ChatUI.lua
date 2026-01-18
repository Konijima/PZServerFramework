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
require "ChatSystem/UI/ChatPipes"
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
    
    -- Load saved settings first
    ChatUI.LoadSettings()
    
    -- Calculate default position
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    
    -- Use saved position/size or defaults
    local chatW = ChatUI.State:get("windowW") or 450
    local chatH = ChatUI.State:get("windowH") or 250
    local chatX = ChatUI.State:get("windowX") or 15
    local chatY = ChatUI.State:get("windowY") or (screenH - chatH - 150)
    
    -- Create main chat window (don't reset state - we just loaded settings!)
    ChatUI.instance = ChatUI.Components.ChatWindow.create({
        x = chatX,
        y = chatY,
        width = chatW,
        height = chatH,
    })
    
    ChatUI.instance:addToUIManager()
    
    -- Ensure window is within screen bounds (in case saved position is invalid for current resolution)
    ChatUI.Components.ChatWindow.ensureOnScreen(ChatUI.instance)
    
    -- Apply locked state to the window after creation
    local isLocked = ChatUI.State:get("locked")
    if isLocked then
        ChatUI.instance:setResizable(false)
    end
    
    -- Track window position/size changes for saving
    local origOnResize = ChatUI.instance.onResize
    ChatUI.instance.onResize = function(self)
        if origOnResize then origOnResize(self) end
        -- Save window dimensions
        ChatUI.State:set("windowW", self:getWidth())
        ChatUI.State:set("windowH", self:getHeight())
        ChatUI.SaveSettings()
    end
    
    -- Track window movement
    local origOnMouseUp = ChatUI.instance.onMouseUp
    ChatUI.instance.onMouseUp = function(self, x, y)
        if origOnMouseUp then origOnMouseUp(self, x, y) end
        -- Save window position after drag
        ChatUI.State:set("windowX", self:getX())
        ChatUI.State:set("windowY", self:getY())
        ChatUI.SaveSettings()
    end
    
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
        -- Create a new table to ensure state change is detected (shallow comparison)
        local oldTypingUsers = ChatUI.State:get("typingUsers") or {}
        local typingUsers = {}
        for k, v in pairs(oldTypingUsers) do
            typingUsers[k] = v
        end
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
    
    ChatSystem.Events.OnConversationsChanged:Add(function()
        print("[ChatSystem] ReactiveUI: Conversations changed")
        -- Refresh tabs to show new/removed PM conversations
        if ChatUI.Components and ChatUI.Components.ChatTabs then
            ChatUI.Components.ChatTabs.refresh()
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
