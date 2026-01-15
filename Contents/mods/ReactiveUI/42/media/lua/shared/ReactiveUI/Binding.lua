require "ReactiveUI/Definitions"

--[[
    ReactiveUI Binding System
    
    Provides automatic data binding between state stores and UI elements.
    Bindings automatically subscribe/unsubscribe and update UI when state changes.
    
    Example usage:
    
    -- Basic property binding
    local binding = ReactiveUI.Binding.create(myStateStore, "count")
    binding:to(myLabel, "text", function(value)
        return "Count: " .. tostring(value)
    end)
    
    -- Two-way binding for input
    local binding = ReactiveUI.Binding.create(myStateStore, "username")
    binding:toInput(myTextBox)
    
    -- Computed binding (multiple state keys)
    local binding = ReactiveUI.Binding.computed(myStateStore, {"firstName", "lastName"})
    binding:to(myLabel, "text", function(firstName, lastName)
        return firstName .. " " .. lastName
    end)
    
    -- Cleanup (automatic on component destroy)
    binding:unbind()
]]

local Binding = ReactiveUI.Binding

---@class ReactiveUI.BindingInstance
---@field _store ReactiveUI.StateStore The state store
---@field _keys table Array of state keys to watch
---@field _element ISUIElement The UI element to update
---@field _property string The property to update
---@field _transform function? Optional transform function
---@field _unsubscribe function? Cleanup function
---@field _active boolean Whether binding is active
local BindingInstance = {}
BindingInstance.__index = BindingInstance

--- Create a one-way binding from state to UI element
---@param store ReactiveUI.StateStore The state store to bind from
---@param key string The state key to watch
---@return ReactiveUI.BindingInstance
function Binding.create(store, key)
    local instance = setmetatable({}, BindingInstance)
    instance._store = store
    instance._keys = {key}
    instance._element = nil
    instance._property = nil
    instance._transform = nil
    instance._unsubscribe = nil
    instance._active = false
    return instance
end

--- Create a computed binding from multiple state keys
---@param store ReactiveUI.StateStore The state store to bind from
---@param keys table Array of state keys to watch
---@return ReactiveUI.BindingInstance
function Binding.computed(store, keys)
    local instance = setmetatable({}, BindingInstance)
    instance._store = store
    instance._keys = keys
    instance._element = nil
    instance._property = nil
    instance._transform = nil
    instance._unsubscribe = nil
    instance._active = false
    return instance
end

--- Bind to a UI element property
---@param element ISUIElement The element to update
---@param property string The property name to update (e.g., "text", "width")
---@param transform function? Optional transform function(value) or function(val1, val2, ...) for computed
---@return ReactiveUI.BindingInstance Self for chaining
function BindingInstance:to(element, property, transform)
    if self._active then
        self:unbind()
    end
    
    self._element = element
    self._property = property
    self._transform = transform
    
    -- Set up subscription
    if #self._keys == 1 then
        -- Single key binding
        local key = self._keys[1]
        
        -- Update function
        local function update(newValue)
            if not self._element then return end
            
            local value = newValue
            if self._transform then
                value = self._transform(value)
            end
            
            self:_updateElement(value)
        end
        
        -- Subscribe to changes
        self._unsubscribe = self._store:subscribe(key, function(newValue, oldValue)
            update(newValue)
        end)
        
        -- Initial update
        update(self._store:get(key))
        
    else
        -- Computed binding (multiple keys)
        local function update()
            if not self._element then return end
            
            -- Gather all values
            local values = {}
            for _, key in ipairs(self._keys) do
                table.insert(values, self._store:get(key))
            end
            
            -- Apply transform
            local value
            if self._transform then
                value = self._transform(unpack(values))
            else
                value = values[1] -- Default to first value
            end
            
            self:_updateElement(value)
        end
        
        -- Subscribe to all keys
        local unsubscribers = {}
        for _, key in ipairs(self._keys) do
            local unsub = self._store:subscribe(key, function()
                update()
            end)
            table.insert(unsubscribers, unsub)
        end
        
        -- Combined unsubscribe function
        self._unsubscribe = function()
            for _, unsub in ipairs(unsubscribers) do
                unsub()
            end
        end
        
        -- Initial update
        update()
    end
    
    self._active = true
    return self
end

--- Bind to an input element with two-way binding
---@param element ISTextEntryBox|ISComboBox Input element
---@param transform function? Optional transform function for display
---@param parse function? Optional parse function for storing (defaults to tostring)
---@return ReactiveUI.BindingInstance Self for chaining
function BindingInstance:toInput(element, transform, parse)
    if #self._keys > 1 then
        error("Two-way binding only supports single state keys")
    end
    
    local key = self._keys[1]
    
    -- One-way binding: state -> UI
    self:to(element, "text", transform)
    
    -- Store original onChange
    local originalOnChange = element.onTextChange or element.onChange
    
    -- Two-way binding: UI -> state (with event handler wrapper)
    if element.onTextChange then
        element.onTextChange = function(...)
            local value = element:getInternalText()
            if parse then
                value = parse(value)
            end
            self._store:set(key, value)
            
            if originalOnChange then
                originalOnChange(...)
            end
        end
    elseif element.onChange then
        element.onChange = function(...)
            local value = element.selected or element:getSelectedText()
            if parse then
                value = parse(value)
            end
            self._store:set(key, value)
            
            if originalOnChange then
                originalOnChange(...)
            end
        end
    end
    
    return self
end

--- Bind to element visibility
---@param element ISUIElement Element to control visibility
---@param condition function? Optional condition function(value) -> boolean
---@return ReactiveUI.BindingInstance Self for chaining
function BindingInstance:toVisible(element, condition)
    return self:to(element, "visible", function(value)
        if condition then
            return condition(value)
        end
        return value and true or false
    end)
end

--- Bind to element enabled state
---@param element ISUIElement Element to control enabled state
---@param condition function? Optional condition function(value) -> boolean
---@return ReactiveUI.BindingInstance Self for chaining
function BindingInstance:toEnabled(element, condition)
    return self:to(element, "enable", function(value)
        if condition then
            return condition(value)
        end
        return value and true or false
    end)
end

--- Bind to a callback function instead of element property
---@param callback function Function to call with value(s)
---@return ReactiveUI.BindingInstance Self for chaining
function BindingInstance:toCallback(callback)
    if self._active then
        self:unbind()
    end
    
    if #self._keys == 1 then
        local key = self._keys[1]
        
        self._unsubscribe = self._store:subscribe(key, function(newValue)
            callback(newValue)
        end)
        
        -- Initial call
        callback(self._store:get(key))
    else
        local function update()
            local values = {}
            for _, key in ipairs(self._keys) do
                table.insert(values, self._store:get(key))
            end
            callback(unpack(values))
        end
        
        local unsubscribers = {}
        for _, key in ipairs(self._keys) do
            local unsub = self._store:subscribe(key, function()
                update()
            end)
            table.insert(unsubscribers, unsub)
        end
        
        self._unsubscribe = function()
            for _, unsub in ipairs(unsubscribers) do
                unsub()
            end
        end
        
        update()
    end
    
    self._active = true
    return self
end

--- Internal: Update the element property
---@param value any The new value
function BindingInstance:_updateElement(value)
    if not self._element or not self._property then return end
    
    -- Handle common property updates
    if self._property == "text" then
        if self._element.setText then
            self._element:setText(tostring(value or ""))
        elseif self._element.setName then
            self._element:setName(tostring(value or ""))
        end
    elseif self._property == "visible" then
        self._element:setVisible(value and true or false)
    elseif self._property == "enable" then
        if value then
            self._element:setEnable(true)
        else
            self._element:setEnable(false)
        end
    elseif self._property == "width" then
        self._element:setWidth(tonumber(value) or 0)
    elseif self._property == "height" then
        self._element:setHeight(tonumber(value) or 0)
    elseif self._property == "x" then
        self._element:setX(tonumber(value) or 0)
    elseif self._property == "y" then
        self._element:setY(tonumber(value) or 0)
    else
        -- Generic property assignment
        self._element[self._property] = value
    end
end

--- Unbind and cleanup
function BindingInstance:unbind()
    if self._unsubscribe then
        self._unsubscribe()
        self._unsubscribe = nil
    end
    self._active = false
end

--- Check if binding is active
---@return boolean
function BindingInstance:isActive()
    return self._active
end

--[[
    Binding Manager - Manages multiple bindings as a group
    Useful for components that need to manage many bindings
]]

---@class ReactiveUI.BindingManager
---@field _bindings table Array of binding instances
local BindingManager = {}
BindingManager.__index = BindingManager

--- Create a binding manager
---@return ReactiveUI.BindingManager
function Binding.createManager()
    local manager = setmetatable({}, BindingManager)
    manager._bindings = {}
    return manager
end

--- Add a binding to the manager
---@param binding ReactiveUI.BindingInstance
function BindingManager:add(binding)
    table.insert(self._bindings, binding)
end

--- Create and add a binding
---@param store ReactiveUI.StateStore
---@param key string
---@return ReactiveUI.BindingInstance
function BindingManager:bind(store, key)
    local binding = Binding.create(store, key)
    self:add(binding)
    return binding
end

--- Create and add a computed binding
---@param store ReactiveUI.StateStore
---@param keys table
---@return ReactiveUI.BindingInstance
function BindingManager:bindComputed(store, keys)
    local binding = Binding.computed(store, keys)
    self:add(binding)
    return binding
end

--- Unbind all managed bindings
function BindingManager:unbindAll()
    for _, binding in ipairs(self._bindings) do
        binding:unbind()
    end
    self._bindings = {}
end

--- Get count of active bindings
---@return number
function BindingManager:count()
    local count = 0
    for _, binding in ipairs(self._bindings) do
        if binding:isActive() then
            count = count + 1
        end
    end
    return count
end

return Binding
