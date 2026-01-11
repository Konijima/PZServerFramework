require "ISUI/ISCollapsableWindow"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "ISUI/ISLayoutManager"
require "ISUI/ISContextMenu"
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
    self.locked = false
    
    -- Opacity settings
    self.minOpaque = 0.3
    self.maxOpaque = 0.9
    self.fadeTime = 5
    self.fadeEnabled = true
    self.backgroundColor = { r = 0, g = 0, b = 0, a = self.maxOpaque }
    self.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    
    -- Fade system
    self.fadeTimer = 0
    self.isFading = false
    
    -- Timer to re-enable key presses after sending message
    self.timerTextEntry = 0
    
    -- Tab system
    self.tabs = {}           -- { [channel or "pm:username"] = button }
    self.pmTabs = {}         -- { [username] = button } - PM conversation tabs
    self.tabHeight = 20
    self.unreadMessages = {} -- { [channel or "pm:username"] = count }
    self.flashingTabs = {}   -- { [channel or "pm:username"] = true }
    self.flashTimer = 0
    self.flashState = false
    self.newPmBtn = nil      -- "+" button for new PM
end

function ISCustomChat:createChildren()
    ISCollapsableWindow.createChildren(self)
    
    local th = self:titleBarHeight()
    local btnSize = 16
    local padding = 5
    local entryHeight = 25
    local bottomPadding = 15  -- Increased to avoid resize handle
    
    -- Lock button in title bar (to the left of the close button)
    self.lockButton = ISButton:new(btnSize + 6, 0, btnSize, th, "", self, ISCustomChat.onLockClick)
    self.lockButton:initialise()
    self.lockButton:instantiate()
    self.lockButton.anchorRight = false
    self.lockButton.anchorLeft = true
    self.lockButton.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.lockButton.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.lockButton.backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0 }
    self.lockButton:setImage(getTexture("media/ui/inventoryPanes/Button_LockOpen.png"))
    self:addChild(self.lockButton)
    
    -- Settings gear button (in title bar area, right side)
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
    
    -- Create channel tabs
    self:createTabs()
    
    -- Chat text panel (leave space for tabs and typing indicator)
    local typingIndicatorHeight = 16
    local tabY = th + padding
    local chatY = tabY + self.tabHeight + padding
    local chatHeight = self.height - chatY - entryHeight - bottomPadding - padding - typingIndicatorHeight
    
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
    
    -- Text entry
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
    self.minimumWidth = 300
    self.minimumHeight = 180
    
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
        self:updateTabs()
        self:rebuildText()
    end)
    
    -- Register for typing indicator events
    ChatSystem.Events.OnTypingChanged:Add(function(channel, users, target)
        self:updateTypingIndicator(channel, users, target)
    end)
    
    -- Initial state
    self:updateTabs()
    self:unfocus()
end

-- ==========================================================
-- Tab System
-- ==========================================================

function ISCustomChat:createTabs()
    local th = self:titleBarHeight()
    local padding = 5
    local tabY = th + padding
    
    -- Remove existing tabs
    for _, tab in pairs(self.tabs) do
        self:removeChild(tab)
    end
    self.tabs = {}
    
    -- Remove existing PM tabs
    for _, tab in pairs(self.pmTabs) do
        if tab.closeBtn then
            self:removeChild(tab.closeBtn)
        end
        self:removeChild(tab)
    end
    self.pmTabs = {}
    
    -- Remove new PM button if exists
    if self.newPmBtn then
        self:removeChild(self.newPmBtn)
        self.newPmBtn = nil
    end
    
    local defaultChannels = { "global", "local" }
    local channels = (ChatSystem.Client and ChatSystem.Client.GetAvailableChannels and ChatSystem.Client.GetAvailableChannels()) or defaultChannels
    local conversations = (ChatSystem.Client and ChatSystem.Client.GetConversations and ChatSystem.Client.GetConversations()) or {}
    
    -- Count total tabs needed
    local numConversations = 0
    for _ in pairs(conversations) do
        numConversations = numConversations + 1
    end
    
    local tabX = padding
    local baseTabWidth = 50
    local pmTabWidth = 60
    local newPmBtnWidth = 22
    local gearSpace = 25
    
    -- Calculate available width
    local availableWidth = self.width - padding * 2 - gearSpace - newPmBtnWidth - 4
    local totalTabs = #channels + numConversations
    local tabWidth = baseTabWidth
    
    if totalTabs > 0 then
        local neededWidth = (#channels * baseTabWidth) + (numConversations * pmTabWidth) + (totalTabs * 2)
        if neededWidth > availableWidth then
            -- Shrink tabs to fit
            tabWidth = math.floor((availableWidth - (totalTabs * 2)) / totalTabs)
            tabWidth = math.max(tabWidth, 30) -- Minimum width
        end
    end
    
    -- Create channel tabs
    for i, channel in ipairs(channels) do
        local shortNames = {
            ["local"] = "Local",
            ["global"] = "Global",
            ["faction"] = "Fac",
            ["safehouse"] = "Safe",
            ["admin"] = "Admin",
            ["radio"] = "Radio",
        }
        local tabName = shortNames[channel] or (type(channel) == "string" and channel:sub(1, 5) or "???")
        
        local tab = ISButton:new(tabX, tabY, tabWidth, self.tabHeight, tabName, self, ISCustomChat.onTabClick)
        tab:initialise()
        tab:instantiate()
        tab.internal = channel
        tab.isChannel = true
        tab.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
        tab.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 }
        tab.backgroundColorMouseOver = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
        tab.font = UIFont.Small
        self:addChild(tab)
        
        self.tabs[channel] = tab
        if not self.unreadMessages[channel] then
            self.unreadMessages[channel] = 0
        end
        
        tabX = tabX + tabWidth + 2
    end
    
    -- Create PM conversation tabs with close buttons
    local pmTabWidth = tabWidth - 16  -- Smaller to make room for close button
    local closeButtonSize = 14
    
    for username, convData in pairs(conversations) do
        local pmKey = "pm:" .. username
        local displayName = username:sub(1, 5)
        if #username > 5 then
            displayName = displayName .. ".."
        end
        
        -- Create the tab button
        local tab = ISButton:new(tabX, tabY, pmTabWidth, self.tabHeight, displayName, self, ISCustomChat.onPmTabClick)
        tab:initialise()
        tab:instantiate()
        tab.internal = username
        tab.isPmTab = true
        tab.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
        tab.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 }
        tab.backgroundColorMouseOver = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
        tab.font = UIFont.Small
        tab:setTooltip(username)
        self:addChild(tab)
        
        -- Create close button for the PM tab
        local closeBtn = ISButton:new(tabX + pmTabWidth, tabY, closeButtonSize, self.tabHeight, "x", self, ISCustomChat.onClosePmTabClick)
        closeBtn:initialise()
        closeBtn:instantiate()
        closeBtn.internal = username
        closeBtn.borderColor = { r = 0.5, g = 0.3, b = 0.3, a = 0.8 }
        closeBtn.backgroundColor = { r = 0.2, g = 0.1, b = 0.1, a = 0.8 }
        closeBtn.backgroundColorMouseOver = { r = 0.5, g = 0.2, b = 0.2, a = 0.9 }
        closeBtn.textColor = { r = 1, g = 0.6, b = 0.6, a = 1 }
        closeBtn.font = UIFont.Small
        closeBtn:setTooltip("Close conversation")
        self:addChild(closeBtn)
        tab.closeBtn = closeBtn
        
        self.pmTabs[username] = tab
        self.tabs[pmKey] = tab
        if not self.unreadMessages[pmKey] then
            self.unreadMessages[pmKey] = convData.unread or 0
        end
        
        tabX = tabX + pmTabWidth + closeButtonSize + 2
    end
    
    -- Create "+" button for new PM (only in multiplayer)
    if isClient() or isServer() then
        self.newPmBtn = ISButton:new(tabX, tabY, newPmBtnWidth, self.tabHeight, "+", self, ISCustomChat.onNewPmClick)
        self.newPmBtn:initialise()
        self.newPmBtn:instantiate()
        self.newPmBtn.borderColor = { r = 0.4, g = 0.6, b = 0.4, a = 0.8 }
        self.newPmBtn.backgroundColor = { r = 0.1, g = 0.2, b = 0.1, a = 0.8 }
        self.newPmBtn.backgroundColorMouseOver = { r = 0.2, g = 0.35, b = 0.2, a = 0.9 }
        self.newPmBtn.textColor = { r = 0.5, g = 1, b = 0.5, a = 1 }
        self.newPmBtn.font = UIFont.Small
        self.newPmBtn:setTooltip("Start new conversation")
        self:addChild(self.newPmBtn)
    end
    
    self:updateTabs()
end

function ISCustomChat:onTabClick(button)
    local channel = button.internal
    if channel then
        -- Deactivate any PM conversation
        ChatSystem.Client.DeactivateConversation()
        ChatSystem.Client.SetChannel(channel)
        -- Clear unread count for this channel
        self.unreadMessages[channel] = 0
        self.flashingTabs[channel] = nil
        self:updateTabs()
        self:rebuildText()
    end
end

function ISCustomChat:onPmTabClick(button)
    local username = button.internal
    if username then
        ChatSystem.Client.OpenConversation(username)
        local pmKey = "pm:" .. username
        self.unreadMessages[pmKey] = 0
        self.flashingTabs[pmKey] = nil
        self:updateTabs()
        self:rebuildText()
    end
end

function ISCustomChat:onNewPmClick()
    -- Show dropdown of online players
    local x = self:getAbsoluteX() + (self.newPmBtn and self.newPmBtn:getX() or 0)
    local y = self:getAbsoluteY() + (self.newPmBtn and (self.newPmBtn:getY() + self.newPmBtn:getHeight()) or 0)
    
    local context = ISContextMenu.get(0, x, y)
    if not context then return end
    
    -- Get online players from game API directly
    local myUsername = getPlayer() and getPlayer():getUsername() or ""
    local hasPlayers = false
    
    -- Use the game's connected players list
    local connectedPlayers = getOnlinePlayers()
    if connectedPlayers and connectedPlayers:size() > 0 then
        for i = 0, connectedPlayers:size() - 1 do
            local player = connectedPlayers:get(i)
            if player then
                local playerName = player:getUsername()
                -- Ensure playerName is a valid string
                if playerName and type(playerName) == "string" and playerName ~= "" and playerName ~= myUsername then
                    context:addOption(tostring(playerName), self, ISCustomChat.onSelectPlayerForPm, tostring(playerName))
                    hasPlayers = true
                end
            end
        end
    end
    
    if not hasPlayers then
        context:addOption("No other players online", self, nil)
    end
end

function ISCustomChat:onSelectPlayerForPm(username)
    ChatSystem.Client.OpenConversation(username)
    self:createTabs()
    self:rebuildText()
end

function ISCustomChat:onClosePmTabClick(button)
    local username = button.internal
    if username then
        self:onClosePmTab(username)
    end
end

function ISCustomChat:onClosePmTab(username)
    ChatSystem.Client.CloseConversation(username)
    local pmKey = "pm:" .. username
    self.unreadMessages[pmKey] = nil
    self.flashingTabs[pmKey] = nil
    self:createTabs()
    self:rebuildText()
end

function ISCustomChat:updateTabs()
    local currentChannel = (ChatSystem.Client and ChatSystem.Client.currentChannel) or "local"
    local activeConversation = ChatSystem.Client and ChatSystem.Client.activeConversation
    local pmColor = (ChatSystem.ChannelColors and ChatSystem.ChannelColors["private"]) or { r = 0.8, g = 0.5, b = 0.8 }
    
    -- Update channel tabs
    for channel, tab in pairs(self.tabs) do
        if tab.isChannel then
            local color = (ChatSystem.ChannelColors and ChatSystem.ChannelColors[channel]) or { r = 1, g = 1, b = 1 }
            local isActive = (channel == currentChannel and not activeConversation)
            
            if isActive then
                tab.backgroundColor = { r = 0.3, g = 0.3, b = 0.35, a = 0.95 }
                tab.backgroundColorMouseOver = { r = 0.35, g = 0.35, b = 0.4, a = 1 }
                tab.borderColor = { r = color.r * 0.8, g = color.g * 0.8, b = color.b * 0.8, a = 1 }
                tab.textColor = { r = color.r, g = color.g, b = color.b, a = 1 }
            else
                tab.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.7 }
                tab.backgroundColorMouseOver = { r = 0.25, g = 0.25, b = 0.25, a = 0.8 }
                tab.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
                tab.textColor = { r = color.r * 0.6, g = color.g * 0.6, b = color.b * 0.6, a = 0.8 }
            end
            
            -- Update title with unread count
            local unread = self.unreadMessages[channel] or 0
            local shortNames = {
                ["local"] = "Local",
                ["global"] = "Global",
                ["faction"] = "Fac",
                ["safehouse"] = "Safe",
                ["admin"] = "Admin",
                ["radio"] = "Radio",
            }
            local tabName = shortNames[channel] or (type(channel) == "string" and channel:sub(1, 5) or "???")
            local newTitle = tabName
            
            if unread > 0 and not isActive then
                newTitle = tabName .. " (" .. (unread > 9 and "9+" or unread) .. ")"
            end
            
            tab:setTitle(newTitle)
            
            -- Resize button to fit the new title
            local textWidth = getTextManager():MeasureStringX(tab.font or UIFont.Small, newTitle)
            local newWidth = math.max(textWidth + 12, 30) -- 12px padding, minimum 30px
            tab:setWidth(newWidth)
        end
    end
    
    -- Update PM tabs
    for username, tab in pairs(self.pmTabs) do
        local isActive = (activeConversation == username)
        local pmKey = "pm:" .. username
        
        if isActive then
            tab.backgroundColor = { r = 0.35, g = 0.25, b = 0.35, a = 0.95 }
            tab.backgroundColorMouseOver = { r = 0.4, g = 0.3, b = 0.4, a = 1 }
            tab.borderColor = { r = pmColor.r * 0.8, g = pmColor.g * 0.8, b = pmColor.b * 0.8, a = 1 }
            tab.textColor = { r = pmColor.r, g = pmColor.g, b = pmColor.b, a = 1 }
        else
            tab.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.7 }
            tab.backgroundColorMouseOver = { r = 0.25, g = 0.25, b = 0.25, a = 0.8 }
            tab.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
            tab.textColor = { r = pmColor.r * 0.6, g = pmColor.g * 0.6, b = pmColor.b * 0.6, a = 0.8 }
        end
        
        -- Update title with unread count
        local convData = ChatSystem.Client and ChatSystem.Client.conversations and ChatSystem.Client.conversations[username]
        local unread = convData and convData.unread or 0
        local displayName = username:sub(1, 6)
        if #username > 6 then
            displayName = displayName .. ".."
        end
        
        local newTitle = displayName
        if unread > 0 and not isActive then
            newTitle = displayName .. " (" .. (unread > 9 and "9+" or unread) .. ")"
        end
        
        tab:setTitle(newTitle)
        
        -- Resize button to fit the new title
        local textWidth = getTextManager():MeasureStringX(tab.font or UIFont.Small, newTitle)
        local newWidth = math.max(textWidth + 12, 30) -- 12px padding, minimum 30px
        tab:setWidth(newWidth)
        
        -- Reposition close button next to tab
        if tab.closeBtn then
            tab.closeBtn:setX(tab:getX() + tab:getWidth())
        end
    end
    
    -- Reposition all tabs after resizing to prevent overlaps
    self:repositionTabs()
    
    -- Refresh typing indicator
    self:refreshTypingLabel()
end

--- Reposition all tabs after width changes
function ISCustomChat:repositionTabs()
    local padding = 5
    local tabX = padding
    local tabY = self:titleBarHeight() + 2
    
    -- Get ordered channels list
    local defaultChannels = { "global", "local" }
    local channels = (ChatSystem.Client and ChatSystem.Client.GetAvailableChannels and ChatSystem.Client.GetAvailableChannels()) or defaultChannels
    
    -- Reposition channel tabs in order
    for _, channel in ipairs(channels) do
        local tab = self.tabs[channel]
        if tab then
            tab:setX(tabX)
            tabX = tabX + tab:getWidth() + 2
        end
    end
    
    -- Reposition PM tabs
    local closeButtonSize = 14
    for username, tab in pairs(self.pmTabs) do
        tab:setX(tabX)
        if tab.closeBtn then
            tab.closeBtn:setX(tabX + tab:getWidth())
        end
        tabX = tabX + tab:getWidth() + closeButtonSize + 2
    end
    
    -- Reposition the "+" button
    if self.newPmBtn then
        self.newPmBtn:setX(tabX)
    end
end

function ISCustomChat:refreshTabs()
    -- Check if we need to add new PM tabs
    local conversations = ChatSystem.Client and ChatSystem.Client.GetConversations and ChatSystem.Client.GetConversations() or {}
    local needsRebuild = false
    
    for username, _ in pairs(conversations) do
        if not self.pmTabs[username] then
            needsRebuild = true
            break
        end
    end
    
    if needsRebuild then
        self:createTabs()
    end
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
    
    -- Track unread messages for non-active channels or PM conversations
    local currentChannel = (ChatSystem.Client and ChatSystem.Client.currentChannel) or "local"
    local activeConversation = ChatSystem.Client and ChatSystem.Client.activeConversation
    
    if message.channel == "private" then
        -- For PM messages, check if this is the active conversation
        local myUsername = getPlayer() and getPlayer():getUsername() or ""
        local otherPerson = message.author
        if message.metadata and message.metadata.to and message.author == myUsername then
            otherPerson = message.metadata.to
        end
        
        if activeConversation ~= otherPerson then
            -- Not viewing this conversation, mark as unread (handled in Client.lua)
            local pmKey = "pm:" .. otherPerson
            self.flashingTabs[pmKey] = true
            self:refreshTabs()  -- Make sure the tab exists
            self:updateTabs()
        end
    elseif message.channel ~= currentChannel or activeConversation then
        -- Not on this channel tab (or we're in a PM conversation)
        self.unreadMessages[message.channel] = (self.unreadMessages[message.channel] or 0) + 1
        self.flashingTabs[message.channel] = true
        self:updateTabs()
    end
    
    -- Rebuild text (will filter by current channel or conversation)
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
    -- Safety: ensure message is a table and has required fields
    if not message or type(message) ~= "table" then
        return ""
    end
    
    local color = message.color or (ChatSystem.ChannelColors and ChatSystem.ChannelColors[message.channel]) or { r = 1, g = 1, b = 1 }
    local channelName = (ChatSystem.ChannelNames and ChatSystem.ChannelNames[message.channel]) or message.channel or "unknown"
    
    -- Ensure text and author are strings
    local msgText = type(message.text) == "string" and message.text or tostring(message.text or "")
    local msgAuthor = type(message.author) == "string" and message.author or tostring(message.author or "???")
    
    -- Convert newlines to <LINE> tags for proper display
    msgText = msgText:gsub("\n", " <LINE> ")
    
    local line = ""
    
    -- Timestamp [HH:MM]
    if self.showTimestamp and message.timestamp then
        local time = os.date("%H:%M", (tonumber(message.timestamp) or 0) / 1000)
        line = "[" .. tostring(time) .. "]"
    end
    
    -- Handle special message types (emotes and system messages)
    if message.metadata and message.metadata.isEmote then
        -- Emote format: just the text (already formatted as "* Name action *")
        line = line .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", color.r, color.g, color.b) .. ">" .. msgText
        return line
    elseif message.isSystem then
        -- System message: no author prefix, just the text
        line = line .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", color.r, color.g, color.b) .. ">" .. msgText
        return line
    end
    
    -- Regular message: Author name
    line = line .. " <SPACE> <RGB:1,1,1>" .. msgAuthor .. ":"
    
    -- Message text
    line = line .. " <SPACE> <RGB:" .. string.format("%.1f,%.1f,%.1f", color.r, color.g, color.b) .. ">" .. msgText
    
    -- Yell indicator
    if message.metadata and message.metadata.isYell then
        line = line .. " <SPACE> <RGB:1,0.5,0.5>(!)"
    end
    
    return line
end

function ISCustomChat:rebuildText()
    local vscroll = self.chatText.vscroll
    local scrolledToBottom = (self.chatText:getScrollHeight() <= self.chatText:getHeight()) or (vscroll and vscroll.pos == 1)
    
    local currentChannel = (ChatSystem.Client and ChatSystem.Client.currentChannel) or "local"
    local activeConversation = ChatSystem.Client and ChatSystem.Client.activeConversation
    local myUsername = getPlayer() and getPlayer():getUsername() or ""
    local lines = {}
    
    if activeConversation then
        -- Show PM conversation messages
        local conversationMessages = ChatSystem.Client and ChatSystem.Client.GetConversationMessages and ChatSystem.Client.GetConversationMessages(activeConversation) or {}
        for _, message in ipairs(conversationMessages) do
            table.insert(lines, self:formatMessage(message))
        end
    else
        -- Filter messages by current channel (but always show global system messages)
        for _, message in ipairs(self.messages) do
            local showMessage = message.channel == currentChannel
            -- Always show system messages from global channel (announcements, etc.)
            if message.isSystem and message.channel == "global" then
                showMessage = true
            end
            -- Don't show PMs in regular channel tabs
            if message.channel == "private" then
                showMessage = false
            end
            if showMessage then
                table.insert(lines, self:formatMessage(message))
            end
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
        local activeConversation = ChatSystem.Client.activeConversation
        
        -- If we're in a PM conversation, send as PM
        if activeConversation then
            -- Add to history
            table.insert(chat.commandHistory, 1, text)
            if #chat.commandHistory > 50 then
                table.remove(chat.commandHistory)
            end
            chat.historyIndex = 0
            
            -- Send as PM
            ChatSystem.Client.SendPrivateMessage(activeConversation, text)
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
    end
    
    chat:unfocus()
end

function ISCustomChat:onTextChange()
    local chat = ISCustomChat.instance
    local text = chat.textEntry:getText()
    
    if text and text ~= "" then
        local activeConversation = ChatSystem.Client.activeConversation
        if activeConversation then
            -- In a PM conversation, send typing to that specific person
            ChatSystem.Client.StartTyping("private", activeConversation)
        else
            -- Parse to detect which channel user is typing in
            local channel, _, _ = ChatSystem.Client.ParseInput(text)
            ChatSystem.Client.StartTyping(channel)
        end
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
    -- Prevent focusing if player is dead
    local player = getPlayer()
    if player and player:isDead() then
        return
    end
    
    self:setVisible(true)
    ISCustomChat.focused = true
    
    -- Ensure text entry is visible and editable
    self.textEntry:setVisible(true)
    self.textEntry:setEditable(true)
    self.textEntry:focus()
    self.textEntry:ignoreFirstInput()
    
    -- Don't set prefix - we use the dropdown for channel selection
    self.textEntry:setText("")
    
    -- Reset fade
    self.fadeTimer = 0
    self.isFading = false
    self.backgroundColor.a = self.maxOpaque
    
    -- Update positions in case layout changed
    self:updateLockState()
end

function ISCustomChat:unfocus()
    self.textEntry:unfocus()
    self.textEntry:setText("")
    ISCustomChat.focused = false
    self.textEntry:setEditable(false)
    -- Don't hide textEntry, just make it non-editable
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

function ISCustomChat:cycleChannel()
    -- Deactivate any PM conversation first
    ChatSystem.Client.DeactivateConversation()
    
    local channels = ChatSystem.Client.GetAvailableChannels()
    local currentIdx = 1
    
    for i, channel in ipairs(channels) do
        if channel == ChatSystem.Client.currentChannel then
            currentIdx = i
            break
        end
    end
    
    local nextIdx = (currentIdx % #channels) + 1
    local nextChannel = channels[nextIdx]
    
    -- Clear unread for the channel we're switching to
    self.unreadMessages[nextChannel] = 0
    self.flashingTabs[nextChannel] = nil
    
    ChatSystem.Client.SetChannel(nextChannel)
    self:updateTabs()
    self:rebuildText()
    
    -- Update text entry with new channel command
    local prefix = ChatSystem.Client.GetChannelCommand(nextChannel)
    self.textEntry:setText(prefix)
end

-- ==========================================================
-- Settings
-- ==========================================================

function ISCustomChat:onGearClick()
    local context = ISContextMenu.get(0, self:getAbsoluteX() + self.gearBtn:getX(), self:getAbsoluteY() + self.gearBtn:getY() + self.gearBtn:getHeight())
    
    -- Timestamp toggle
    context:addOption(self.showTimestamp and "Hide Timestamps" or "Show Timestamps", self, ISCustomChat.toggleTimestamp)
    
    -- Fade toggle
    context:addOption(self.fadeEnabled and "Disable Fading" or "Enable Fading", self, ISCustomChat.toggleFade)
    
    -- Fade opacity submenu (only show if fading is enabled)
    if self.fadeEnabled then
        local fadeOption = context:addOption("Fade Opacity", self)
        local fadeSubMenu = context:getNew(context)
        context:addSubMenu(fadeOption, fadeSubMenu)
        
        local opacities = { 0, 25, 50, 75 }
        for _, pct in ipairs(opacities) do
            local option = fadeSubMenu:addOption(pct .. "%", self, ISCustomChat.setFadeOpacity, pct / 100)
            if math.floor(self.minOpaque * 100) == pct then
                fadeSubMenu:setOptionChecked(option, true)
            end
        end
    end
    
    -- Font size submenu
    local fontOption = context:addOption("Font Size", self)
    local fontSubMenu = context:getNew(context)
    context:addSubMenu(fontOption, fontSubMenu)
    local smallOpt = fontSubMenu:addOption("Small", self, ISCustomChat.setFontSize, "small")
    local medOpt = fontSubMenu:addOption("Medium", self, ISCustomChat.setFontSize, "medium")
    local largeOpt = fontSubMenu:addOption("Large", self, ISCustomChat.setFontSize, "large")
    if self.chatFont == "small" then
        fontSubMenu:setOptionChecked(smallOpt, true)
    elseif self.chatFont == "large" then
        fontSubMenu:setOptionChecked(largeOpt, true)
    else
        fontSubMenu:setOptionChecked(medOpt, true)
    end
    
    -- Clear chat
    context:addOption("Clear Chat", self, ISCustomChat.clearChat)
end

function ISCustomChat:toggleTimestamp()
    self.showTimestamp = not self.showTimestamp
    self:rebuildText()
end

function ISCustomChat:toggleFade()
    self.fadeEnabled = not self.fadeEnabled
    if not self.fadeEnabled then
        -- Reset to full opacity when disabling fade
        self.backgroundColor.a = self.maxOpaque
    end
end

function ISCustomChat:setFadeOpacity(opacity)
    self.minOpaque = opacity
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
---@param target string|nil Optional target for PM typing
function ISCustomChat:updateTypingIndicator(channel, users, target)
    local key = channel
    
    -- For PM typing, use a special key based on the typer (who is typing to me)
    if channel == "private" and target then
        -- When someone is typing a PM to me, target is my username
        -- We need to store it by who is typing
        -- The "users" array contains who is typing
        if #users > 0 then
            key = "pm:" .. users[1]  -- The person typing to me
        end
    elseif channel == "private" then
        -- Store by channel if no specific target
        key = channel
    end
    
    -- Store for the appropriate key
    self.typingUsers[key] = users
    
    -- Update display for the currently selected channel/conversation
    self:refreshTypingLabel()
end

function ISCustomChat:refreshTypingLabel()
    -- Safety check - ensure typingLabel exists
    if not self.typingLabel then
        return
    end
    
    local activeConversation = ChatSystem.Client and ChatSystem.Client.activeConversation
    local users = {}
    local color
    
    if activeConversation then
        -- Check PM typing for this conversation
        local pmKey = "pm:" .. activeConversation
        users = self.typingUsers[pmKey] or {}
        color = (ChatSystem.ChannelColors and ChatSystem.ChannelColors["private"]) or { r = 0.8, g = 0.5, b = 0.8 }
    else
        -- Check channel typing
        local channel = (ChatSystem.Client and ChatSystem.Client.currentChannel) or "local"
        users = self.typingUsers[channel] or {}
        color = (ChatSystem.ChannelColors and ChatSystem.ChannelColors[channel]) or { r = 0.6, g = 0.6, b = 0.6 }
    end
    
    if #users == 0 then
        self.typingLabel:setVisible(false)
        return
    end
    
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
    -- Handle fade (only if enabled)
    if self.fadeEnabled and not ISCustomChat.focused and self.fadeTime > 0 then
        self.fadeTimer = self.fadeTimer + (UIManager.getMillisSinceLastRender() / 1000)
        
        if self.fadeTimer > self.fadeTime then
            local fadeProgress = math.min((self.fadeTimer - self.fadeTime) / 3, 1)
            self.backgroundColor.a = self.maxOpaque - (self.maxOpaque - self.minOpaque) * fadeProgress
        end
    elseif not self.fadeEnabled then
        -- Keep at max opacity if fading is disabled
        self.backgroundColor.a = self.maxOpaque
    end
    
    -- Handle tab flashing for unread messages
    self.flashTimer = self.flashTimer + (UIManager.getMillisSinceLastRender() / 1000)
    if self.flashTimer > 0.5 then
        self.flashTimer = 0
        self.flashState = not self.flashState
        
        local pmColor = (ChatSystem.ChannelColors and ChatSystem.ChannelColors["private"]) or { r = 0.8, g = 0.5, b = 0.8 }
        
        -- Update flashing tabs
        for key, isFlashing in pairs(self.flashingTabs) do
            -- Check if it's a channel tab or PM tab
            local tab = self.tabs[key]
            local color = ChatSystem.ChannelColors[key] or { r = 1, g = 1, b = 1 }
            
            -- Check PM tabs if not found in channel tabs
            if not tab and key:sub(1, 3) == "pm:" then
                local username = key:sub(4)
                tab = self.pmTabs[username]
                color = pmColor
            end
            
            if isFlashing and tab then
                if self.flashState then
                    -- Bright flash
                    tab.backgroundColor = { r = color.r * 0.4, g = color.g * 0.4, b = color.b * 0.4, a = 0.9 }
                    tab.textColor = { r = 1, g = 1, b = 1, a = 1 }
                else
                    -- Normal dim
                    tab.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.7 }
                    tab.textColor = { r = color.r * 0.6, g = color.g * 0.6, b = color.b * 0.6, a = 0.8 }
                end
            end
        end
    end
    
    ISCollapsableWindow.prerender(self)
end

function ISCustomChat:render()
    ISCollapsableWindow.render(self)
end

function ISCustomChat:onResize()
    ISCollapsableWindow.onResize(self)
    
    -- Manually reposition gear button
    local btnSize = 20
    local padding = 5
    local th = self:titleBarHeight()
    self.gearBtn:setX(self.width - btnSize - padding)
    self.gearBtn:setY(th + padding)
    
    -- Recreate tabs to fit new width
    self:createTabs()
end

-- ==========================================================
-- Lock/Unlock
-- ==========================================================

function ISCustomChat:onLockClick()
    self.locked = not self.locked
    self:updateLockState()
end

function ISCustomChat:updateLockState()
    local padding = 5
    local entryHeight = 25
    local bottomPadding = self.locked and 5 or 15  -- Less padding when locked (no resize handle)
    
    if self.locked then
        self.lockButton:setImage(getTexture("media/ui/inventoryPanes/Button_Lock.png"))
        self:setResizable(false)
    else
        self.lockButton:setImage(getTexture("media/ui/inventoryPanes/Button_LockOpen.png"))
        self:setResizable(true)
    end
    
    -- Update text entry position and size
    self.textEntry:setX(padding)
    self.textEntry:setY(self.height - entryHeight - bottomPadding)
    self.textEntry:setWidth(self.width - padding * 2)
    self.textEntry:setHeight(entryHeight)
    
    -- Update chat panel height (account for tabs and typing indicator)
    local th = self:titleBarHeight()
    local typingIndicatorHeight = 16
    local tabY = th + padding
    local chatY = tabY + self.tabHeight + padding
    local chatHeight = self.height - chatY - entryHeight - bottomPadding - padding - typingIndicatorHeight
    self.chatText:setY(chatY)
    self.chatText:setHeight(chatHeight)
end

function ISCustomChat:isMouseOverTitleBar(x, y)
    -- If locked, don't allow dragging
    if self.locked then
        return false
    end
    return ISCollapsableWindow.isMouseOverTitleBar(self, x, y)
end

function ISCustomChat:onMouseDown(x, y)
    -- If locked, don't allow dragging (but still allow bringToTop)
    if self.locked then
        self:bringToTop()
        return
    end
    ISCollapsableWindow.onMouseDown(self, x, y)
end

-- ==========================================================
-- Layout Persistence
-- ==========================================================

function ISCustomChat:SaveLayout(name, layout)
    ISLayoutManager.DefaultSaveWindow(self, layout)
    layout.showTimestamp = tostring(self.showTimestamp or false)
    layout.locked = tostring(self.locked or false)
    layout.chatFont = self.chatFont or "medium"
    layout.fadeEnabled = tostring(self.fadeEnabled)
    layout.minOpaque = tostring(self.minOpaque)
end

function ISCustomChat:RestoreLayout(name, layout)
    ISLayoutManager.DefaultRestoreWindow(self, layout)
    if layout.showTimestamp == 'true' then
        self.showTimestamp = true
    elseif layout.showTimestamp == 'false' then
        self.showTimestamp = false
    end
    
    if layout.locked == 'true' then
        self.locked = true
    else
        self.locked = false
    end
    self:updateLockState()
    
    if layout.fadeEnabled == 'true' then
        self.fadeEnabled = true
    elseif layout.fadeEnabled == 'false' then
        self.fadeEnabled = false
    end
    
    if layout.minOpaque then
        self.minOpaque = tonumber(layout.minOpaque) or 0.3
    end
    
    if layout.chatFont then
        self:setFontSize(layout.chatFont)
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

-- Handle player death - unfocus chat
function ISCustomChat.OnPlayerDeath(player)
    if ISCustomChat.instance and ISCustomChat.focused then
        ISCustomChat.instance:unfocus()
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
    Events.OnPlayerDeath.Add(ISCustomChat.OnPlayerDeath)
    
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
