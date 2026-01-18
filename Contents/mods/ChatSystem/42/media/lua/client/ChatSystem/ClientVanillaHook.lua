-- ChatSystem Vanilla Message Hook
-- Captures vanilla chat messages (yells, server announcements) for our custom chat
-- Returns a module table to be merged into ChatSystem.Client

require "ChatSystem/Definitions"
require "ChatSystem/PlayerUtils"

local Module = {}

-- ==========================================================
-- Vanilla Message Filtering
-- ==========================================================

-- List of vanilla server message patterns to filter out (not shown in custom chat)
local filteredVanillaPatterns = {
    "^Safety:" -- Safety restore messages
}

--- Check if a vanilla message should be filtered (not shown in chat)
---@param text string
---@return boolean
local function shouldFilterVanillaMessage(text)
    if not text then return true end
    for _, pattern in ipairs(filteredVanillaPatterns) do
        if text:match(pattern) then
            return true
        end
    end
    return false
end

-- ==========================================================
-- Vanilla Message Handler
-- ==========================================================

--- Hook into vanilla chat messages (yells, server messages, etc.)
--- This captures messages that bypass our custom chat system
local function OnVanillaMessage(message, tabID)
    local Client = ChatSystem.Client
    local author = message:getAuthor()
    local text = message:getText()
    local textWithPrefix = message:getTextWithPrefix()
    
    if not text or text == "" then return end
    
    -- Debug: print the message details
    print("[ChatSystem] Vanilla message - author: " .. tostring(author) .. ", text: " .. tostring(text) .. ", prefix: " .. tostring(textWithPrefix))
    
    -- Filter out unwanted server messages
    if author == "Server" and shouldFilterVanillaMessage(text) then
        print("[ChatSystem] Filtered vanilla message: " .. text)
        return
    end
    
    -- Determine channel based on message source
    local channel = ChatSystem.ChannelType.LOCAL
    local isSystem = false
    local isYell = false
    local color = nil
    
    if author == "Server" then
        -- Server system messages (sandbox changes, etc.)
        channel = ChatSystem.ChannelType.GLOBAL
        isSystem = true
        color = { r = 1, g = 0.9, b = 0.5 } -- Yellow-ish
    else
        -- Player messages (yells, says, etc.) - these are local chat
        channel = ChatSystem.ChannelType.LOCAL
        
        -- Check if this is a yell by looking at the prefix text
        -- Vanilla yell format usually contains [Shout] or similar, or text is uppercase
        if textWithPrefix then
            local lowerPrefix = textWithPrefix:lower()
            if lowerPrefix:find("%[shout%]") or lowerPrefix:find("%[yell%]") then
                isYell = true
            end
        end
        
        -- Also check if the text is all uppercase (common yell indicator)
        if not isYell and text == text:upper() and #text > 0 and text:match("%a") then
            isYell = true
        end
        
        if isYell then
            color = { r = 1, g = 0.3, b = 0.3 } -- Red for yells
        end
    end
    
    -- Create message for our custom chat
    local msg
    if isSystem then
        msg = ChatSystem.CreateSystemMessage(text, channel)
    else
        msg = ChatSystem.CreateMessage(channel, author or "Unknown", text)
    end
    
    -- In roleplay mode, try to get character name for local players
    if ChatSystem.PlayerUtils.IsRoleplayMode() and author and not isSystem then
        local otherPlayer = ChatSystem.PlayerUtils.GetPlayerByUsername(author)
        if otherPlayer then
            local charName = ChatSystem.PlayerUtils.GetCharacterNameFromDescriptor(otherPlayer:getDescriptor())
            if charName then
                msg.metadata.characterName = charName
            end
        end
    end
    
    if color then
        msg.color = color
    end
    if isYell then
        msg.metadata.isYell = true
    end
    msg.metadata.isVanilla = true
    
    -- Add to message history
    table.insert(Client.messages, msg)
    
    -- Trim old messages
    while #Client.messages > ChatSystem.Settings.maxMessagesStored do
        table.remove(Client.messages, 1)
    end
    
    -- Trigger event for UI update
    ChatSystem.Events.OnMessageReceived:Trigger(msg)
    
    print("[ChatSystem] Client: Captured vanilla message from " .. tostring(author) .. ": " .. text)
end

-- ==========================================================
-- Initialization
-- ==========================================================

--- Initialize vanilla message hook
function Module.Init()
    Events.OnAddMessage.Add(OnVanillaMessage)
    print("[ChatSystem] VanillaHook module initialized")
end

print("[ChatSystem] VanillaHook module loaded")

return Module
