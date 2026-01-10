require "ISUI/ISCollapsableWindow"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "ISUI/ISLayoutManager"
require "ChatSystem/Definitions"
require "ChatSystem/Client"

---@class ISCustomChat : ISCollapsableWindow
ISCustomChat = ISCollapsableWindow:derive("ISCustomChat")

ISCustomChat.instance = nil
ISCustomChat.maxLine = 200
ISCustomChat.focused = false

-- ==========================================================
-- Initialization
-- ==========================================================

function ISCustomChat:initialise()
    ISCollapsableWindow.initialise(self)
    self.title = "Chat"
    self.pin = true
    self.resizable = true
    self.drawFrame = true
    
    -- Opacity settings
    self.minOpaque = 0.3
    self.maxOpaque = 0.9
    self.fadeTime = 5
    self.backgroundColor = { r = 0, g = 0, b = 0, a = self.maxOpaque }
    self.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    
    -- Fade system
    self.fadeTimer = 0
    self.isFading = false
    
    -- Timer to re-enable key presses after sending message
    self.timerTextEntry = 0
end

function ISCustomChat:createChildren()
    ISCollapsableWindow.createChildren(self)
    
    local th = self:titleBarHeight()
    local btnSize = 20
    local padding = 5
    local entryHeight = 25
    
    -- Channel selector button
    self.channelBtn = ISButton:new(padding, th + padding, 80, btnSize, "Local", self, ISCustomChat.onChannelClick)
    self.channelBtn:initialise()
    self.channelBtn:instantiate()
    self.channelBtn.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
    self.channelBtn.backgroundColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 }
    self:addChild(self.channelBtn)
    
    -- Settings gear button
    self.gearBtn = ISButton:new(self.width - btnSize - padding, th + padding, btnSize, btnSize, "", self, ISCustomChat.onGearClick)
    self.gearBtn:initialise()
    self.gearBtn:instantiate()
    self.gearBtn:setImage(getTexture("media/ui/inventoryPanes/Button_Gear.png"))
    self.gearBtn.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.gearBtn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.gearBtn.anchorLeft = false
    self.gearBtn.anchorRight = true
    self.gearBtn.anchorTop = true
    self.gearBtn.anchorBottom = false
    self:addChild(self.gearBtn)
    
    -- Chat text panel (account for bottom padding)
    local bottomPadding = padding + 3
    local chatY = th + btnSize + padding * 2
    local chatHeight = self.height - chatY - entryHeight - bottomPadding - padding
    
    self.chatText = ISRichTextPanel:new(padding, chatY, self.width - padding * 2, chatHeight)
    self.chatText:initialise()
    self.chatText.background = false
    self.chatText:setAnchorBottom(true)
    self.chatText:setAnchorRight(true)
    self.chatText:setAnchorTop(true)
    self.chatText:setAnchorLeft(true)
    self.chatText.marginTop = 5
    self.chatText.marginBottom = 5
    self.chatText.autosetheight = false
    self.chatText:addScrollBars()
    self.chatText.vscroll:setVisible(false)
    self.chatText.vscroll.background = false
    self.chatText.chatLines = {}
    self:addChild(self.chatText)
    
    -- Text entry (uses bottomPadding defined above)
    self.textEntry = ISTextEntryBox:new("", padding, self.height - entryHeight - bottomPadding, self.width - padding * 2, entryHeight)
    self.textEntry:initialise()
    self.textEntry:instantiate()
    self.textEntry.font = UIFont.Medium
    self.textEntry.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    self.textEntry.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
    self.textEntry:setAnchorTop(false)
    self.textEntry:setAnchorBottom(true)
    self.textEntry:setAnchorRight(true)
    self.textEntry.onCommandEntered = ISCustomChat.onCommandEntered
    self.textEntry.onOtherKey = ISCustomChat.onOtherKey
    self.textEntry.onTextChange = ISCustomChat.onTextChange
    self.textEntry:setMaxLines(1)
    self.textEntry:setMaxTextLength(ChatSystem.Settings.maxMessageLength)
    self:addChild(self.textEntry)
    
    -- Typing indicator label (above text entry)
    self.typingLabel = ISLabel:new(padding, self.height - entryHeight - bottomPadding - 16, 14, "", 0.6, 0.6, 0.6, 0.9, UIFont.Small, true)
    self.typingLabel:initialise()
    self.typingLabel:setAnchorTop(false)
    self.typingLabel:setAnchorBottom(true)
    self.typingLabel:setVisible(false)
    self:addChild(self.typingLabel)
    
    -- Typing users state
    self.typingUsers = {}
    
    -- Set minimum size
    self.minimumWidth = 250
    self.minimumHeight = 150
    
    -- Command history
    self.commandHistory = {}
    self.historyIndex = 0
    
    -- Message storage (we store raw messages, rebuild display on channel change)
    self.messages = {}
    
    -- Register for message events
    ChatSystem.Events.OnMessageReceived:Add(function(message)
        self:addMessage(message)
    end)
    
    ChatSystem.Events.OnChannelChanged:Add(function(channel)
        self:updateChannelButton()
        self:rebuildText()  -- Rebuild text when channel changes to filter messages
    end)
    
    -- Register for typing indicator events
    ChatSystem.Events.OnTypingChanged:Add(function(channel, users)
        self:updateTypingIndicator(channel, users)
    end)
    
    -- Initial state
    self:updateChannelButton()
    self:unfocus()
end

-- ==========================================================
-- Message Display
-- ==========================================================

---@param message ChatMessage
function ISCustomChat:addMessage(message)
    print("[ChatSystem] UI: addMessage called - author: " .. tostring(message.author) .. ", text: " .. tostring(message.text))
    
    -- Store the raw message
    table.insert(self.messages, message)
    
    -- Trim old messages
    while #self.messages > ISCustomChat.maxLine do
        table.remove(self.messages, 1)
    end
    
    -- Rebuild text (will filter by current channel)
    self:rebuildText()
    
    -- Reset fade timer
    self.fadeTimer = 0
    self.isFading = false
    self.backgroundColor.a = self.maxOpaque
end

--- Format a message into a display line
---@param message ChatMessage
---@return string
function ISCustomChat:formatMessage(message)
    local color = message.color or ChatSystem.ChannelColors[message.channel] or { r = 1, g = 1, b = 1 }
    local channelName = ChatSystem.ChannelNames[message.channel] or message.channel
    
    local line = ""
    
    -- Timestamp [HH:MM]
    if self.showTimestamp then
        local time = os.date("%H:%M", message.timestamp / 1000)
        line = "[" .. time .. "]"
    end
    
    -- Channel tag [Channel]
    local cr, cg, cb = color.r * 0.7, color.g * 0.7, color.b * 0.7
    line = line .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", cr, cg, cb) .. ">[" .. channelName .. "]"
    
    -- Author name
    if message.isSystem then
        line = line .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", color.r, color.g, color.b) .. ">*" .. message.author .. ":"
    else
        line = line .. " <SPACE> <RGB:1,1,1>" .. message.author .. ":"
    end
    
    -- PM indicator
    if message.channel == ChatSystem.ChannelType.PRIVATE then
        if message.metadata and message.metadata.to then
            line = line .. " <SPACE> <RGB:0.8,0.5,0.8>->" .. message.metadata.to .. ":"
        end
    end
    
    -- Message text
    line = line .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", color.r, color.g, color.b) .. ">" .. message.text
    
    -- Yell indicator
    if message.metadata and message.metadata.isYell then
        line = line .. " <SPACE> <RGB:1,0.5,0.5>(!)"
    end
    
    return line
end

function ISCustomChat:rebuildText()
    local vscroll = self.chatText.vscroll
    local scrolledToBottom = (self.chatText:getScrollHeight() <= self.chatText:getHeight()) or (vscroll and vscroll.pos == 1)
    
    local currentChannel = ChatSystem.Client.currentChannel
    local lines = {}
    
    -- Filter messages by current channel
    for _, message in ipairs(self.messages) do
        if message.channel == currentChannel then
            table.insert(lines, self:formatMessage(message))
        end
    end
    
    -- Build text
    self.chatText.text = ""
    for i, line in ipairs(lines) do
        self.chatText.text = self.chatText.text .. line
        if i < #lines then
            self.chatText.text = self.chatText.text .. " <LINE> "
        end
    end
    
    self.chatText:paginate()
    
    if scrolledToBottom then
        self.chatText:setYScroll(-10000)
    end
end

-- ==========================================================
-- Input Handling
-- ==========================================================

function ISCustomChat:onCommandEntered()
    local chat = ISCustomChat.instance
    local text = chat.textEntry:getText()
    
    -- Stop typing indicator
    ChatSystem.Client.StopTyping()
    
    if text and text ~= "" then
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
            -- Add to history (original input)
            table.insert(chat.commandHistory, 1, chat.textEntry:getText())
            if #chat.commandHistory > 50 then
                table.remove(chat.commandHistory)
            end
            chat.historyIndex = 0
            
            -- Send message using current channel (no prefix needed)
            ChatSystem.Client.SendMessageDirect(text)
        end
    end
    
    chat:unfocus()
end

function ISCustomChat:onTextChange()
    local chat = ISCustomChat.instance
    local text = chat.textEntry:getText()
    
    if text and text ~= "" then
        -- Parse to detect which channel user is typing in
        local channel, _, _ = ChatSystem.Client.ParseInput(text)
        ChatSystem.Client.StartTyping(channel)
    else
        ChatSystem.Client.StopTyping()
    end
end

function ISCustomChat:onOtherKey(key)
    local chat = ISCustomChat.instance
    
    if key == Keyboard.KEY_ESCAPE then
        chat:unfocus()
    elseif key == Keyboard.KEY_UP then
        -- History up
        if #chat.commandHistory > 0 then
            chat.historyIndex = math.min(chat.historyIndex + 1, #chat.commandHistory)
            chat.textEntry:setText(chat.commandHistory[chat.historyIndex] or "")
        end
    elseif key == Keyboard.KEY_DOWN then
        -- History down
        chat.historyIndex = math.max(chat.historyIndex - 1, 0)
        if chat.historyIndex > 0 then
            chat.textEntry:setText(chat.commandHistory[chat.historyIndex] or "")
        else
            chat.textEntry:setText("")
        end
    elseif key == Keyboard.KEY_TAB then
        -- Cycle channels
        chat:cycleChannel()
    end
end

-- ==========================================================
-- Focus Management
-- ==========================================================

function ISCustomChat:focus()
    self:setVisible(true)
    ISCustomChat.focused = true
    self.textEntry:setEditable(true)
    self.textEntry:focus()
    self.textEntry:ignoreFirstInput()
    
    -- Don't set prefix - we use the dropdown for channel selection
    self.textEntry:setText("")
    
    -- Reset fade
    self.fadeTimer = 0
    self.isFading = false
    self.backgroundColor.a = self.maxOpaque
end

function ISCustomChat:unfocus()
    self.textEntry:unfocus()
    self.textEntry:setText("")
    ISCustomChat.focused = false
    self.textEntry:setEditable(false)
    self.historyIndex = 0
    
    -- Stop typing indicator
    ChatSystem.Client.StopTyping()
    
    -- Set timer to re-enable key presses (same approach as vanilla ISChat)
    self.timerTextEntry = 20
    doKeyPress(false)
end

-- ==========================================================
-- Channel Management
-- ==========================================================

function ISCustomChat:onChannelClick()
    local context = ISContextMenu.get(0, self:getAbsoluteX() + self.channelBtn:getX(), self:getAbsoluteY() + self.channelBtn:getY() + self.channelBtn:getHeight())
    
    local channels = ChatSystem.Client.GetAvailableChannels()
    for _, channel in ipairs(channels) do
        local name = ChatSystem.ChannelNames[channel]
        local color = ChatSystem.ChannelColors[channel]
        local option = context:addOption(name, self, ISCustomChat.onChannelSelect, channel)
        
        if channel == ChatSystem.Client.currentChannel then
            context:setOptionChecked(option, true)
        end
    end
end

function ISCustomChat:onChannelSelect(channel)
    ChatSystem.Client.SetChannel(channel)
end

function ISCustomChat:updateChannelButton()
    local channel = ChatSystem.Client.currentChannel
    local name = ChatSystem.ChannelNames[channel] or channel
    local color = ChatSystem.ChannelColors[channel] or { r = 1, g = 1, b = 1 }
    
    self.channelBtn:setTitle(name)
    self.channelBtn.textColor = { r = color.r, g = color.g, b = color.b, a = 1 }
    
    -- Refresh typing indicator for new channel
    self:refreshTypingLabel()
end

function ISCustomChat:cycleChannel()
    local channels = ChatSystem.Client.GetAvailableChannels()
    local currentIdx = 1
    
    for i, channel in ipairs(channels) do
        if channel == ChatSystem.Client.currentChannel then
            currentIdx = i
            break
        end
    end
    
    local nextIdx = (currentIdx % #channels) + 1
    ChatSystem.Client.SetChannel(channels[nextIdx])
    
    -- Update text entry with new channel command
    local prefix = ChatSystem.Client.GetChannelCommand(channels[nextIdx])
    self.textEntry:setText(prefix)
end

-- ==========================================================
-- Settings
-- ==========================================================

function ISCustomChat:onGearClick()
    local context = ISContextMenu.get(0, self:getAbsoluteX() + self.gearBtn:getX(), self:getAbsoluteY() + self.gearBtn:getY() + self.gearBtn:getHeight())
    
    -- Timestamp toggle
    local tsOption = context:addOption(self.showTimestamp and "Hide Timestamps" or "Show Timestamps", self, ISCustomChat.toggleTimestamp)
    
    -- Clear chat
    context:addOption("Clear Chat", self, ISCustomChat.clearChat)
    
    -- Font size submenu
    local fontOption = context:addOption("Font Size", self)
    local fontSubMenu = context:getNew(context)
    context:addSubMenu(fontOption, fontSubMenu)
    fontSubMenu:addOption("Small", self, ISCustomChat.setFontSize, "small")
    fontSubMenu:addOption("Medium", self, ISCustomChat.setFontSize, "medium")
    fontSubMenu:addOption("Large", self, ISCustomChat.setFontSize, "large")
end

function ISCustomChat:toggleTimestamp()
    self.showTimestamp = not self.showTimestamp
    -- Rebuild text to apply change
    self.chatText.chatLines = {}
    for _, msg in ipairs(ChatSystem.Client.messages) do
        self:addMessage(msg)
    end
end

function ISCustomChat:clearChat()
    self.messages = {}
    self.chatText.text = ""
    self.chatText:paginate()
    ChatSystem.Client.ClearMessages()
end

function ISCustomChat:setFontSize(size)
    local font
    if size == "small" then
        font = UIFont.Small
    elseif size == "medium" then
        font = UIFont.Medium
    elseif size == "large" then
        font = UIFont.Large
    else
        font = UIFont.Medium
    end
    
    -- Must set both font and defaultFont for ISRichTextPanel
    self.chatText.font = font
    self.chatText.defaultFont = font
    self.chatFont = size
    
    self:rebuildText()
end

-- ==========================================================
-- Typing Indicator
-- ==========================================================

---@param channel string
---@param users table Array of usernames
function ISCustomChat:updateTypingIndicator(channel, users)
    -- Store for the current channel
    self.typingUsers[channel] = users
    
    -- Update display for the currently selected channel
    self:refreshTypingLabel()
end

function ISCustomChat:refreshTypingLabel()
    local channel = ChatSystem.Client.currentChannel
    local users = self.typingUsers[channel] or {}
    
    if #users == 0 then
        self.typingLabel:setVisible(false)
        return
    end
    
    local color = ChatSystem.ChannelColors[channel] or { r = 0.6, g = 0.6, b = 0.6 }
    local text = ""
    
    if #users == 1 then
        text = users[1] .. " is typing..."
    elseif #users == 2 then
        text = users[1] .. " and " .. users[2] .. " are typing..."
    elseif #users > 2 then
        text = users[1] .. ", " .. users[2] .. " and " .. (#users - 2) .. " more are typing..."
    end
    
    self.typingLabel:setName(text)
    self.typingLabel:setColor(color.r, color.g, color.b)
    self.typingLabel:setVisible(true)
end

-- ==========================================================
-- Rendering & Updates
-- ==========================================================

function ISCustomChat:prerender()
    -- Handle fade
    if not ISCustomChat.focused and self.fadeTime > 0 then
        self.fadeTimer = self.fadeTimer + (UIManager.getMillisSinceLastRender() / 1000)
        
        if self.fadeTimer > self.fadeTime then
            local fadeProgress = math.min((self.fadeTimer - self.fadeTime) / 3, 1)
            self.backgroundColor.a = self.maxOpaque - (self.maxOpaque - self.minOpaque) * fadeProgress
        end
    end
    
    ISCollapsableWindow.prerender(self)
end

function ISCustomChat:render()
    ISCollapsableWindow.render(self)
end

function ISCustomChat:onResize()
    ISCollapsableWindow.onResize(self)
    
    -- Manually reposition gear button (anchoring doesn't work well for buttons)
    local btnSize = 20
    local padding = 5
    local th = self:titleBarHeight()
    self.gearBtn:setX(self.width - btnSize - padding)
    self.gearBtn:setY(th + padding)
end

-- ==========================================================
-- Layout Persistence
-- ==========================================================

function ISCustomChat:SaveLayout(name, layout)
    ISLayoutManager.DefaultSaveWindow(self, layout)
    layout.showTimestamp = tostring(self.showTimestamp or false)
end

function ISCustomChat:RestoreLayout(name, layout)
    ISLayoutManager.DefaultRestoreWindow(self, layout)
    if layout.showTimestamp == 'true' then
        self.showTimestamp = true
    elseif layout.showTimestamp == 'false' then
        self.showTimestamp = false
    end
end

-- ==========================================================
-- Static Methods & Events
-- ==========================================================

function ISCustomChat.OnToggleChat(key)
    if ISCustomChat.instance == nil then return end
    
    if getCore():isKey("Toggle chat", key) then
        ISCustomChat.instance:focus()
    end
end

function ISCustomChat.OnMouseDown()
    if ISCustomChat.instance and ISCustomChat.focused then
        -- Check if click is outside chat window
        local mx, my = getMouseX(), getMouseY()
        local chat = ISCustomChat.instance
        
        if mx < chat:getAbsoluteX() or mx > chat:getAbsoluteX() + chat:getWidth() or
           my < chat:getAbsoluteY() or my > chat:getAbsoluteY() + chat:getHeight() then
            chat:unfocus()
        end
    end
end

-- Hide vanilla chat
function ISCustomChat.HideVanillaChat()
    if ISChat and ISChat.instance then
        ISChat.instance:setVisible(false)
        ISChat.instance:removeFromUIManager()
    end
end

-- Tick handler to manage key press timer
function ISCustomChat.OnTick()
    local chat = ISCustomChat.instance
    if chat then
        if chat.timerTextEntry > 0 then
            chat.timerTextEntry = chat.timerTextEntry - 1
            if chat.timerTextEntry == 0 then
                doKeyPress(true)
            end
        end
    end
end

-- Create custom chat
function ISCustomChat.CreateChat()
    if not isClient() and isServer() then return end
    
    -- Hide vanilla chat
    ISCustomChat.HideVanillaChat()
    
    -- Create our chat
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    
    local chatW = 450
    local chatH = 250
    local chatX = 15
    local chatY = screenH - chatH - 150
    
    local chat = ISCustomChat:new(chatX, chatY, chatW, chatH)
    chat:initialise()
    chat:addToUIManager()
    chat:setVisible(true)
    chat:bringToTop()
    chat.showTimestamp = true
    
    ISCustomChat.instance = chat
    
    -- Register with ISLayoutManager for position/size persistence
    ISLayoutManager.RegisterWindow('customchat', ISCustomChat, chat)
    
    -- Load any messages that were received before the UI was created
    if ChatSystem.Client and ChatSystem.Client.messages then
        for _, message in ipairs(ChatSystem.Client.messages) do
            chat:addMessage(message)
        end
    end
    
    -- Register events
    Events.OnKeyPressed.Add(ISCustomChat.OnToggleChat)
    Events.OnMouseDown.Add(ISCustomChat.OnMouseDown)
    Events.OnTick.Add(ISCustomChat.OnTick)
    
    print("[ChatSystem] Custom Chat UI Created")
end

-- Initialize after game starts (with delay to ensure vanilla chat is created first)
local function OnGameStart()
    -- Delay to let vanilla chat initialize
    local tickCount = 0
    local function delayedInit()
        tickCount = tickCount + 1
        if tickCount > 10 then
            Events.OnTick.Remove(delayedInit)
            ISCustomChat.CreateChat()
        end
    end
    Events.OnTick.Add(delayedInit)
end

Events.OnGameStart.Add(OnGameStart)

print("[ChatSystem] Chat UI Loaded")
