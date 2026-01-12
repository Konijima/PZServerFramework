-- ChatSystem Channel Manager Module
-- Handles channel availability, selection, and membership tracking
-- Must be loaded after Client.lua initializes ChatSystem.Client

if isServer() then return end
if not isClient() then return end

require "ChatSystem/Definitions"

-- Ensure Client exists (will be populated by Client.lua)
ChatSystem.Client = ChatSystem.Client or {}
local Client = ChatSystem.Client

-- ==========================================================
-- Channel Availability
-- ==========================================================

--- Check if a channel is currently available
---@param channel string
---@return boolean
function Client.IsChannelAvailable(channel)
    local available = Client.GetAvailableChannels()
    for _, ch in ipairs(available) do
        if ch == channel then
            return true
        end
    end
    return false
end

--- Set the current default channel
---@param channel string
function Client.SetChannel(channel)
    -- Only allow setting to available channels
    if ChatSystem.ChannelColors[channel] and Client.IsChannelAvailable(channel) then
        Client.currentChannel = channel
        ChatSystem.Events.OnChannelChanged:Trigger(channel)
    end
end

--- Get available channels for the current player
---@return table Array of channel types
function Client.GetAvailableChannels()
    local channels = {}
    local settings = ChatSystem.Settings
    
    -- Add global chat if enabled
    if settings.enableGlobalChat then
        table.insert(channels, ChatSystem.ChannelType.GLOBAL)
    end
    
    -- Local chat is always available
    table.insert(channels, ChatSystem.ChannelType.LOCAL)
    
    local player = getPlayer()
    if player then
        -- Check faction (only if faction chat is enabled and player is in a faction)
        if settings.enableFactionChat and Faction and Faction.getPlayerFaction and Faction.getPlayerFaction(player) then
            table.insert(channels, ChatSystem.ChannelType.FACTION)
        end
        
        -- Check safehouse (only if safehouse chat is enabled and player has a safehouse)
        if settings.enableSafehouseChat and SafeHouse and SafeHouse.hasSafehouse and SafeHouse.hasSafehouse(player) then
            table.insert(channels, ChatSystem.ChannelType.SAFEHOUSE)
        end
        
        -- Check admin (only if admin chat is enabled and player is actual admin)
        if settings.enableAdminChat then
            -- Try player method first (may be more up-to-date than global function)
            local accessLevel = player.getAccessLevel and player:getAccessLevel()
            if not accessLevel or accessLevel == "" then
                accessLevel = getAccessLevel and getAccessLevel()
            end
            -- Only "admin" access level can see admin chat (not moderator, observer, etc.)
            if accessLevel and accessLevel ~= "" and string.lower(accessLevel) == "admin" then
                table.insert(channels, ChatSystem.ChannelType.ADMIN)
            end
        end
        
        -- Check staff (only if staff chat is enabled and player is admin, mod, or GM)
        if settings.enableStaffChat then
            local isStaff = false
            
            -- Check role capabilities (SeePlayersConnected or AnswerTickets = staff)
            local role = player:getRole()
            if role and Capability then
                -- Admin power means staff
                local success, hasAdmin = pcall(function()
                    return role:hasAdminPower()
                end)
                if success and hasAdmin then
                    isStaff = true
                end
                
                -- Staff capabilities
                if not isStaff then
                    local success2, hasStaffCap = pcall(function()
                        return role:hasCapability(Capability.SeePlayersConnected) or
                               role:hasCapability(Capability.AnswerTickets)
                    end)
                    if success2 and hasStaffCap then
                        isStaff = true
                    end
                end
            end
            
            -- Fallback: check specific staff roles (not observer)
            if not isStaff then
                -- Try player method first (may be more up-to-date than global function)
                local accessLevel = player.getAccessLevel and player:getAccessLevel()
                if not accessLevel or accessLevel == "" then
                    accessLevel = getAccessLevel and getAccessLevel()
                end
                if accessLevel and accessLevel ~= "" then
                    local level = string.lower(accessLevel)
                    -- Staff roles: admin, moderator, overseer, gm (NOT observer)
                    isStaff = level == "admin" or level == "moderator" or level == "overseer" or level == "gm"
                end
            end
            
            if isStaff then
                table.insert(channels, ChatSystem.ChannelType.STAFF)
            end
        end
    end
    
    -- Radio if player has one
    -- TODO: Check for radio item
    -- table.insert(channels, ChatSystem.ChannelType.RADIO)
    
    return channels
end

--- Get the command prefix for a channel
---@param channel string
---@return string
function Client.GetChannelCommand(channel)
    local commands = ChatSystem.ChannelCommands[channel]
    if commands and commands[1] then
        return commands[1]
    end
    return ""
end

-- ==========================================================
-- Channel Change Detection
-- ==========================================================

--- Handle access level changes (from KoniLib event)
---@param newLevel string|nil
---@param oldLevel string|nil
local function OnAccessLevelChanged(newLevel, oldLevel)
    Client.RefreshAvailableChannels()
end

--- Refresh available channels and update UI if changed
function Client.RefreshAvailableChannels()
    local currentChannels = Client.GetAvailableChannels()
    local channelsChanged = false
    
    if Client.lastAvailableChannels then
        -- Compare channel lists
        if #currentChannels ~= #Client.lastAvailableChannels then
            channelsChanged = true
        else
            for i, ch in ipairs(currentChannels) do
                if ch ~= Client.lastAvailableChannels[i] then
                    channelsChanged = true
                    break
                end
            end
        end
    else
        channelsChanged = true
    end
    
    if channelsChanged then
        Client.lastAvailableChannels = currentChannels
        
        -- Trigger settings changed event to update UI (tabs, etc.)
        ChatSystem.Events.OnSettingsChanged:Trigger(ChatSystem.Settings)
    end
end

-- ==========================================================
-- Faction/Safehouse Membership Tracking
-- ==========================================================

--- Handle faction sync event (triggered when faction membership changes)
---@param factionName string The name of the faction that was synced
local function OnSyncFaction(factionName)
    -- Check if this affects our player
    Client.CheckFactionSafehouseChanges()
end

--- Handle safehouse changes event
local function OnSafehousesChanged()
    -- Check if this affects our player
    Client.CheckFactionSafehouseChanges()
end

--- Handle accepted faction invite
local function OnAcceptedFactionInvite(factionName, playerName)
    -- If we accepted, refresh channels
    local player = getPlayer()
    if player and player:getUsername() == playerName then
        print("[ChatSystem] Client: Accepted faction invite to " .. tostring(factionName))
        Client.CheckFactionSafehouseChanges()
    end
end

--- Handle accepted safehouse invite
local function OnAcceptedSafehouseInvite(safehouse, playerName)
    -- If we accepted, refresh channels
    local player = getPlayer()
    if player and player:getUsername() == playerName then
        print("[ChatSystem] Client: Accepted safehouse invite")
        Client.CheckFactionSafehouseChanges()
    end
end

--- Check for faction/safehouse membership changes
--- Updates tracking state and refreshes channels if changed
function Client.CheckFactionSafehouseChanges()
    local player = getPlayer()
    if not player then return end
    
    local changed = false
    
    -- Check faction
    local currentFactionName = nil
    if Faction and Faction.getPlayerFaction then
        local faction = Faction.getPlayerFaction(player)
        if faction then
            currentFactionName = faction:getName()
        end
    end
    
    if currentFactionName ~= Client.lastFactionName then
        if Client.lastFactionName and not currentFactionName then
            print("[ChatSystem] Client: Player left faction: " .. tostring(Client.lastFactionName))
        elseif not Client.lastFactionName and currentFactionName then
            print("[ChatSystem] Client: Player joined faction: " .. tostring(currentFactionName))
        elseif Client.lastFactionName and currentFactionName then
            print("[ChatSystem] Client: Player changed faction from " .. tostring(Client.lastFactionName) .. " to " .. tostring(currentFactionName))
        end
        Client.lastFactionName = currentFactionName
        changed = true
    end
    
    -- Check safehouse (use coordinates as unique ID)
    local currentSafehouseId = nil
    if SafeHouse and SafeHouse.hasSafehouse then
        local safehouse = SafeHouse.hasSafehouse(player)
        if safehouse then
            currentSafehouseId = tostring(safehouse:getX()) .. "_" .. tostring(safehouse:getY())
        end
    end
    
    if currentSafehouseId ~= Client.lastSafehouseId then
        if Client.lastSafehouseId and not currentSafehouseId then
            print("[ChatSystem] Client: Player left safehouse")
        elseif not Client.lastSafehouseId and currentSafehouseId then
            print("[ChatSystem] Client: Player joined safehouse")
        elseif Client.lastSafehouseId and currentSafehouseId then
            print("[ChatSystem] Client: Player changed safehouse")
        end
        Client.lastSafehouseId = currentSafehouseId
        changed = true
    end
    
    -- Refresh channels if faction or safehouse changed
    if changed then
        Client.RefreshAvailableChannels()
    end
end

-- ==========================================================
-- Initialization
-- ==========================================================

--- Initialize channel manager (call from Client OnGameStart)
function Client.InitChannelManager()
    -- Register for KoniLib access level changes
    if KoniLib and KoniLib.Events and KoniLib.Events.OnAccessLevelChanged then
        KoniLib.Events.OnAccessLevelChanged:Add(OnAccessLevelChanged)
        print("[ChatSystem] ChannelManager: Registered OnAccessLevelChanged handler")
    end
    
    -- Initialize channel tracking
    Client.lastAvailableChannels = Client.GetAvailableChannels()
    
    -- Initialize faction/safehouse tracking
    local player = getPlayer()
    if player then
        if Faction and Faction.getPlayerFaction then
            local faction = Faction.getPlayerFaction(player)
            if faction then
                Client.lastFactionName = faction:getName()
            end
        end
        if SafeHouse and SafeHouse.hasSafehouse then
            local safehouse = SafeHouse.hasSafehouse(player)
            if safehouse then
                Client.lastSafehouseId = tostring(safehouse:getX()) .. "_" .. tostring(safehouse:getY())
            end
        end
    end
    
    -- Register for vanilla faction/safehouse events
    Events.SyncFaction.Add(OnSyncFaction)
    Events.OnSafehousesChanged.Add(OnSafehousesChanged)
    Events.AcceptedFactionInvite.Add(OnAcceptedFactionInvite)
    Events.AcceptedSafehouseInvite.Add(OnAcceptedSafehouseInvite)
    print("[ChatSystem] ChannelManager: Registered faction/safehouse event handlers")
end

print("[ChatSystem] ChannelManager module loaded")
