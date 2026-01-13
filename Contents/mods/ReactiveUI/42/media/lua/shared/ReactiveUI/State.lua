require "ReactiveUI/Definitions"

--[[
    ReactiveUI State Management System
    
    Provides reactive state management similar to React's useState/useReducer patterns.
    State changes automatically trigger UI updates in subscribed components.
    
    Example usage:
    
    -- Create a reactive state store
    local state = ReactiveUI.State.create({
        count = 0,
        name = "Player",
        items = {}
    })
    
    -- Subscribe to state changes
    state:subscribe("count", function(newValue, oldValue)
        print("Count changed from " .. oldValue .. " to " .. newValue)
    end)
    
    -- Update state (triggers subscribers)
    state:set("count", state:get("count") + 1)
    
    -- Batch updates (single notification)
    state:batch(function()
        state:set("count", 0)
        state:set("name", "NewPlayer")
    end)
]]

local State = ReactiveUI.State

---@class ReactiveUI.StateStore
---@field _data table Internal state data
---@field _subscribers table Subscribers for each key
---@field _globalSubscribers table Subscribers for any change
---@field _batching boolean Whether currently batching updates
---@field _pendingNotifications table Pending notifications during batch
local StateStore = {}
StateStore.__index = StateStore

--- Create a new state store with initial values
---@param initialState table Initial state values
---@return ReactiveUI.StateStore
function State.create(initialState)
    local store = setmetatable({}, StateStore)
    store._data = {}
    store._subscribers = {}
    store._globalSubscribers = {}
    store._batching = false
    store._pendingNotifications = {}
    
    -- Initialize with initial state
    if initialState then
        for key, value in pairs(initialState) do
            store._data[key] = value
        end
    end
    
    return store
end

--- Get a value from the state
---@param key string The key to get
---@return any
function StateStore:get(key)
    return self._data[key]
end

--- Get all state data (shallow copy)
---@return table
function StateStore:getAll()
    local copy = {}
    for key, value in pairs(self._data) do
        copy[key] = value
    end
    return copy
end

--- Set a value in the state
---@param key string The key to set
---@param value any The new value
function StateStore:set(key, value)
    local oldValue = self._data[key]
    
    -- Skip if value hasn't changed (shallow comparison)
    if oldValue == value then
        return
    end
    
    self._data[key] = value
    
    if self._batching then
        self._pendingNotifications[key] = { new = value, old = oldValue }
    else
        self:_notifySubscribers(key, value, oldValue)
    end
end

--- Update multiple values at once
---@param updates table Key-value pairs to update
function StateStore:setMany(updates)
    self:batch(function()
        for key, value in pairs(updates) do
            self:set(key, value)
        end
    end)
end

--- Batch multiple updates into a single notification cycle
---@param fn function Function containing multiple set() calls
function StateStore:batch(fn)
    self._batching = true
    self._pendingNotifications = {}
    
    local success, err = pcall(fn)
    
    self._batching = false
    
    -- Notify all pending changes
    for key, change in pairs(self._pendingNotifications) do
        self:_notifySubscribers(key, change.new, change.old)
    end
    self._pendingNotifications = {}
    
    if not success then
        error(err)
    end
end

--- Subscribe to changes on a specific key
---@param key string The key to watch
---@param callback function Callback(newValue, oldValue, key)
---@return function Unsubscribe function
function StateStore:subscribe(key, callback)
    if not self._subscribers[key] then
        self._subscribers[key] = {}
    end
    
    table.insert(self._subscribers[key], callback)
    
    -- Return unsubscribe function
    return function()
        for i, cb in ipairs(self._subscribers[key]) do
            if cb == callback then
                table.remove(self._subscribers[key], i)
                break
            end
        end
    end
end

--- Subscribe to any state change
---@param callback function Callback(key, newValue, oldValue)
---@return function Unsubscribe function
function StateStore:subscribeAll(callback)
    table.insert(self._globalSubscribers, callback)
    
    return function()
        for i, cb in ipairs(self._globalSubscribers) do
            if cb == callback then
                table.remove(self._globalSubscribers, i)
                break
            end
        end
    end
end

--- Internal: Notify subscribers of a change
---@param key string
---@param newValue any
---@param oldValue any
function StateStore:_notifySubscribers(key, newValue, oldValue)
    -- Key-specific subscribers
    if self._subscribers[key] then
        for _, callback in ipairs(self._subscribers[key]) do
            callback(newValue, oldValue, key)
        end
    end
    
    -- Global subscribers
    for _, callback in ipairs(self._globalSubscribers) do
        callback(key, newValue, oldValue)
    end
end

--- Compute a derived value from state
---@param keys table Array of keys to watch
---@param computeFn function Function to compute derived value
---@param callback function Callback when derived value changes
---@return function Unsubscribe function
function StateStore:computed(keys, computeFn, callback)
    local lastValue = computeFn(self)
    
    local unsubscribers = {}
    
    for _, key in ipairs(keys) do
        local unsub = self:subscribe(key, function()
            local newValue = computeFn(self)
            if newValue ~= lastValue then
                local oldValue = lastValue
                lastValue = newValue
                callback(newValue, oldValue)
            end
        end)
        table.insert(unsubscribers, unsub)
    end
    
    -- Return unsubscribe function that removes all
    return function()
        for _, unsub in ipairs(unsubscribers) do
            unsub()
        end
    end
end

--- Clear all subscribers
function StateStore:clearSubscribers()
    self._subscribers = {}
    self._globalSubscribers = {}
end

--- Reset state to initial values
---@param initialState table New initial state
function StateStore:reset(initialState)
    self:batch(function()
        -- Clear existing keys
        for key in pairs(self._data) do
            self:set(key, nil)
        end
        -- Set new initial state
        if initialState then
            for key, value in pairs(initialState) do
                self:set(key, value)
            end
        end
    end)
end

return State
