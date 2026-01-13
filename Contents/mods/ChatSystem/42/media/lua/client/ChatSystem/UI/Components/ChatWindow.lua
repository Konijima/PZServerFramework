--[[
    ChatWindow Component - Main chat window
    Built with ReactiveUI framework
]]

require "ISUI/ISCollapsableWindow"
require "ReactiveUI/Client"
require "ChatSystem/UI/ChatState"

ChatUI = ChatUI or {}
ChatUI.Components = ChatUI.Components or {}
ChatUI.Components.ChatWindow = {}

local Elements = ReactiveUI.Elements
local ChatWindow = ChatUI.Components.ChatWindow

-- Module-level references
local _window = nil
local _lockBtn = nil
local _gearBtn = nil
local _tabs = nil
local _messages = nil
local _input = nil
local _typing = nil

function ChatWindow.create(props)
    props = props or {}
    local x = props.x or 15
    local y = props.y or 100
    local width = props.width or 450
    local height = props.height or 250
    
    -- Use ReactiveUI Elements.Window (auto-initializes)
    _window = Elements.Window({
        x = x,
        y = y,
        width = width,
        height = height,
        title = "Chat",
        resizable = true,
        backgroundColor = { r = 0, g = 0, b = 0, a = ChatUI.State:get("maxOpaque") },
    })
    _window.pin = true
    _window.minimumWidth = ChatUI.Constants.MIN_WIDTH
    _window.minimumHeight = ChatUI.Constants.MIN_HEIGHT
    
    ChatWindow._createChildren(_window)
    ChatWindow._setupBehaviors(_window)
    
    -- Subscribe to state
    ChatUI.State:subscribe("focused", function(focused)
        if focused then ChatWindow._focus() else ChatWindow._unfocus() end
    end)
    
    ChatUI.State:subscribe("locked", function(locked)
        ChatWindow._updateLockState(locked)
    end)
    
    -- Reset opacity when fade is disabled
    ChatUI.State:subscribe("fadeEnabled", function(enabled)
        if not enabled and _window then
            _window.backgroundColor.a = ChatUI.State:get("maxOpaque")
            ChatUI.State:set("fadeTimer", 0)
        end
    end)
    
    return _window
end

function ChatWindow.getWindow()
    return _window
end

function ChatWindow.getMessages()
    return _messages
end

function ChatWindow.getInput()
    return _input
end

function ChatWindow._createChildren(window)
    local th = window:titleBarHeight()
    local pad = ChatUI.Constants.PADDING
    
    -- Lock button using ReactiveUI Elements
    _lockBtn = ChatWindow._createLockButton(window, 22, 0)
    window:addChild(_lockBtn)
    
    -- Gear button using ReactiveUI Elements
    _gearBtn = ChatWindow._createGearButton(window)
    window:addChild(_gearBtn)
    
    -- Tabs
    _tabs = ChatUI.Components.ChatTabs.create(window)
    
    -- Messages
    _messages = ChatUI.Components.ChatMessages.create(window)
    window:addChild(_messages)
    
    -- Input
    _input = ChatUI.Components.ChatInput.create(window)
    window:addChild(_input)
    
    -- Typing indicator
    _typing = ChatUI.Components.TypingIndicator.create(window)
    window:addChild(_typing)
end

function ChatWindow._createLockButton(window, x, y)
    local locked = ChatUI.State:get("locked")
    local tex = locked and getTexture("media/ui/inventoryPanes/Button_Lock.png")
                       or getTexture("media/ui/inventoryPanes/Button_LockOpen.png")
    
    -- Elements.Button auto-initializes
    local btn = Elements.Button({
        x = x,
        y = y,
        width = 16,
        height = window:titleBarHeight(),
        text = "",
        image = tex,
        backgroundColor = { r = 0, g = 0, b = 0, a = 0 },
        borderColor = { r = 0, g = 0, b = 0, a = 0 },
        onClick = ChatWindow._onLockClick,
    })
    return btn
end

function ChatWindow._createGearButton(window)
    local th = window:titleBarHeight()
    local pad = ChatUI.Constants.PADDING
    local btnSize = 16
    
    -- Elements.Button auto-initializes
    local btn = Elements.Button({
        x = window.width - btnSize - pad,
        y = th + pad,
        width = btnSize,
        height = btnSize,
        text = "",
        image = getTexture("media/ui/inventoryPanes/Button_Gear.png"),
        backgroundColor = { r = 0, g = 0, b = 0, a = 0 },
        borderColor = { r = 0, g = 0, b = 0, a = 0 },
        backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0 },
        anchorLeft = false,
        anchorRight = true,
        anchorTop = true,
        anchorBottom = false,
        onClick = ChatWindow._onGearClick,
    })
    return btn
end

function ChatWindow._setupBehaviors(window)
    local origPrerender = window.prerender
    local firstFrame = true
    window.prerender = function(win)
        -- Fix gear button position on first frame (after window is fully laid out)
        if firstFrame then
            firstFrame = false
            ChatWindow._onResize(win)
        end
        ChatWindow._handleFade(win)
        -- Re-focus input if we were focused and clicked inside the window
        if ChatWindow._refocusNextFrame then
            ChatWindow._refocusNextFrame = false
            if ChatUI.State:get("focused") and _input then
                -- Use Input.focus without clearing text
                ChatUI.Components.ChatInput.focus(_input, false)
            end
        end
        origPrerender(win)
    end
    
    local origResize = window.onResize
    window.onResize = function(win)
        if origResize then origResize(win) end
        ChatWindow._onResize(win)
    end
    
    local origMouseDown = window.onMouseDown
    window.onMouseDown = function(win, x, y)
        -- If we're focused, schedule a re-focus for next frame
        -- This ensures the input regains focus after any click inside the window
        if ChatUI.State:get("focused") then
            ChatWindow._refocusNextFrame = true
        end
        
        if ChatUI.State:get("locked") then
            win:bringToTop()
            return
        end
        if origMouseDown then origMouseDown(win, x, y) end
    end
end

function ChatWindow._handleFade(window)
    if not ChatUI.State:get("fadeEnabled") or ChatUI.State:get("focused") then return end
    
    local fadeTimer = ChatUI.State:get("fadeTimer") + (UIManager.getMillisSinceLastRender() / 1000)
    ChatUI.State:set("fadeTimer", fadeTimer)
    
    local fadeTime = ChatUI.State:get("fadeTime")
    if fadeTimer > fadeTime then
        local max = ChatUI.State:get("maxOpaque")
        local min = ChatUI.State:get("minOpaque")
        local progress = math.min((fadeTimer - fadeTime) / 3, 1)
        window.backgroundColor.a = max - (max - min) * progress
    end
end

function ChatWindow._onResize(window)
    ChatUI.Components.ChatTabs.refresh()
    ChatUI.Components.ChatMessages.updateLayout(_messages, window)
    ChatUI.Components.ChatInput.updateLayout(_input, window)
    ChatUI.Components.TypingIndicator.updateLayout(_typing, window)
    
    -- Update gear button position manually since anchoring may not be perfect
    if _gearBtn then
        local pad = ChatUI.Constants.PADDING
        local th = window:titleBarHeight()
        _gearBtn:setX(window.width - 16 - pad)
        _gearBtn:setY(th + pad)
    end
end

function ChatWindow._onLockClick()
    ChatUI.State:set("locked", not ChatUI.State:get("locked"))
    ChatUI.SaveSettings()
end

function ChatWindow._onGearClick()
    ChatUI.Settings.showMenu(_window)
end

function ChatWindow._focus()
    local player = getPlayer()
    if player and player:isDead() then return end
    
    if not _window then return end
    
    _window:setVisible(true)
    _window:bringToTop()
    _window.backgroundColor.a = ChatUI.State:get("maxOpaque")
    ChatUI.State:set("fadeTimer", 0)
    
    -- Clear text when focusing via state change (T key press)
    ChatUI.Components.ChatInput.focus(_input, true)
end

function ChatWindow._unfocus()
    ChatUI.State:set("historyIndex", 0)
    ChatUI.Components.ChatInput.unfocus(_input)
    doKeyPress(false)
    doKeyPress(true)
    if ChatSystem.Client and ChatSystem.Client.StopTyping then
        ChatSystem.Client.StopTyping()
    end
end

function ChatWindow._updateLockState(locked)
    if _window then
        _window:setResizable(not locked)
    end
    if _lockBtn then
        local tex = locked and getTexture("media/ui/inventoryPanes/Button_Lock.png")
                           or getTexture("media/ui/inventoryPanes/Button_LockOpen.png")
        _lockBtn:setImage(tex)
    end
end

-- ==========================================================
-- Utility Functions
-- ==========================================================

--- Ensure the chat window is within screen bounds
function ChatWindow.ensureOnScreen(window)
    if not window then return end
    
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    
    local x = window:getX()
    local y = window:getY()
    local w = window:getWidth()
    local h = window:getHeight()
    local adjusted = false
    
    -- Clamp width and height to screen size
    if w > screenW - 20 then
        w = screenW - 20
        adjusted = true
    end
    if h > screenH - 20 then
        h = screenH - 20
        adjusted = true
    end
    
    -- Ensure minimum size
    w = math.max(w, ChatUI.Constants.MIN_WIDTH)
    h = math.max(h, ChatUI.Constants.MIN_HEIGHT)
    
    -- Clamp position to keep window on screen
    local minVisible = 50
    local newX = math.max(-w + minVisible, math.min(x, screenW - minVisible))
    local newY = math.max(0, math.min(y, screenH - minVisible))
    
    if newX ~= x or newY ~= y then
        adjusted = true
    end
    
    if adjusted then
        window:setX(newX)
        window:setY(newY)
        window:setWidth(w)
        window:setHeight(h)
        ChatWindow._onResize(window)
        print("[ChatSystem] Chat window adjusted to fit screen bounds: " .. math.floor(newX) .. "," .. math.floor(newY) .. " (" .. math.floor(w) .. "x" .. math.floor(h) .. ")")
    end
end

print("[ChatSystem] ChatWindow component loaded (ReactiveUI)")
