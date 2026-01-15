require "ReactiveUI/Definitions"
require "ReactiveUI/State"
require "ReactiveUI/Binding"
require "ReactiveUI/Utils"

--[[
    ReactiveUI Component System
    
    Provides a declarative way to create UI components that automatically
    react to state changes. Components wrap PZ's native ISUI elements.
    
    Example usage:
    
    -- Define a component
    local MyButton = ReactiveUI.Component.define({
        name = "MyButton",
        
        -- Default props
        defaultProps = {
            text = "Click Me",
            width = 100,
            height = 25,
        },
        
        -- Component state (reactive)
        initialState = {
            clickCount = 0,
        },
        
        -- Create the UI element
        render = function(self, props, state)
            return ReactiveUI.Elements.Button({
                x = props.x,
                y = props.y,
                width = props.width,
                height = props.height,
                text = props.text .. " (" .. state.clickCount .. ")",
                onClick = function()
                    self:setState({ clickCount = state.clickCount + 1 })
                    if props.onClick then props.onClick() end
                end,
            })
        end,
    })
    
    -- Use the component
    local btn = MyButton({
        x = 100,
        y = 100,
        text = "Counter",
        onClick = function() print("clicked!") end,
    })
    btn:addToUIManager()
]]

local Component = ReactiveUI.Component

---@class ReactiveUI.ComponentDefinition
---@field name string Component name
---@field defaultProps table? Default property values
---@field initialState table? Initial state values
---@field render function Render function(self, props, state) -> ISUIElement
---@field onCreate function? Called after component is created
---@field onDestroy function? Called before component is destroyed
---@field onStateChange function? Called when state changes
---@field onPropsChange function? Called when props change

---@class ReactiveUI.ComponentInstance
---@field _definition ReactiveUI.ComponentDefinition
---@field _props table Current props
---@field _state ReactiveUI.StateStore Internal state store
---@field _element ISUIElement The underlying PZ UI element
---@field _mounted boolean Whether component is mounted
---@field _children table Child components
---@field _bindings ReactiveUI.BindingManager Managed bindings
---@field _id string Unique component ID
local ComponentInstance = {}
ComponentInstance.__index = ComponentInstance

--- Define a new component type
---@param definition ReactiveUI.ComponentDefinition
---@return function Component constructor
function Component.define(definition)
    if not definition.name then
        error("Component definition requires a 'name'")
    end
    if not definition.render then
        error("Component definition requires a 'render' function")
    end
    
    -- Return a constructor function
    return function(props)
        return Component._createInstance(definition, props)
    end
end

--- Internal: Create a component instance
---@param definition ReactiveUI.ComponentDefinition
---@param props table
---@return ReactiveUI.ComponentInstance
function Component._createInstance(definition, props)
    local instance = setmetatable({}, ComponentInstance)
    
    instance._definition = definition
    instance._props = ReactiveUI.Utils.merge(definition.defaultProps or {}, props or {})
    instance._state = ReactiveUI.State.create(definition.initialState or {})
    instance._element = nil
    instance._mounted = false
    instance._children = {}
    instance._id = ReactiveUI.Utils.generateId(definition.name)
    instance._bindings = ReactiveUI.Binding.createManager()
    
    -- Subscribe to state changes
    instance._state:subscribeAll(function(key, newValue, oldValue)
        instance:_onStateChange(key, newValue, oldValue)
    end)
    
    -- Initial render
    instance:_render()
    
    -- Call onCreate hook
    if definition.onCreate then
        definition.onCreate(instance, instance._props, instance._state:getAll())
    end
    
    return instance
end

--- Get the underlying PZ UI element
---@return ISUIElement
function ComponentInstance:getElement()
    return self._element
end

--- Get current props
---@return table
function ComponentInstance:getProps()
    return self._props
end

--- Get a specific prop value
---@param key string
---@return any
function ComponentInstance:getProp(key)
    return self._props[key]
end

--- Update props and re-render
---@param newProps table
function ComponentInstance:setProps(newProps)
    local oldProps = self._props
    self._props = ReactiveUI.Utils.merge(self._props, newProps)
    
    if self._definition.onPropsChange then
        self._definition.onPropsChange(self, self._props, oldProps)
    end
    
    self:_render()
end

--- Get current state
---@return table
function ComponentInstance:getState()
    return self._state:getAll()
end

--- Get a specific state value
---@param key string
---@return any
function ComponentInstance:getStateValue(key)
    return self._state:get(key)
end

--- Update state (triggers re-render)
---@param updates table Key-value pairs to update
function ComponentInstance:setState(updates)
    self._state:setMany(updates)
end

--- Internal: Handle state changes
---@param key string
---@param newValue any
---@param oldValue any
function ComponentInstance:_onStateChange(key, newValue, oldValue)
    if self._definition.onStateChange then
        self._definition.onStateChange(self, key, newValue, oldValue)
    end
    
    self:_render()
end

--- Internal: Render the component
function ComponentInstance:_render()
    local props = self._props
    local state = self._state:getAll()
    
    -- Store old element reference
    local oldElement = self._element
    local wasVisible = oldElement and oldElement:getIsVisible()
    local wasInUIManager = oldElement and oldElement.javaObject ~= nil
    
    -- Call render function to get new element
    local newElement = self._definition.render(self, props, state)
    
    if newElement then
        self._element = newElement
        
        -- If old element was in UI manager, replace it
        if wasInUIManager and oldElement then
            local x, y = oldElement:getX(), oldElement:getY()
            oldElement:removeFromUIManager()
            
            -- Preserve position
            newElement:setX(x)
            newElement:setY(y)
            
            if wasVisible then
                newElement:addToUIManager()
                newElement:setVisible(true)
            end
        end
    end
end

--- Add component to UI manager
function ComponentInstance:addToUIManager()
    if self._element then
        self._element:addToUIManager()
        self._mounted = true
    end
end

--- Remove component from UI manager
function ComponentInstance:removeFromUIManager()
    if self._definition.onDestroy then
        self._definition.onDestroy(self)
    end
    
    if self._element then
        self._element:removeFromUIManager()
        self._mounted = false
    end
    
    -- Clean up bindings
    self._bindings:unbindAll()
    
    self._state:clearSubscribers()
end

--- Set visibility
---@param visible boolean
function ComponentInstance:setVisible(visible)
    if self._element then
        self._element:setVisible(visible)
    end
end

--- Check if visible
---@return boolean
function ComponentInstance:isVisible()
    return self._element and self._element:getIsVisible() or false
end

--- Set position
---@param x number
---@param y number
function ComponentInstance:setPosition(x, y)
    if self._element then
        self._element:setX(x)
        self._element:setY(y)
    end
end

--- Get position
---@return number, number
function ComponentInstance:getPosition()
    if self._element then
        return self._element:getX(), self._element:getY()
    end
    return 0, 0
end

--- Set size
---@param width number
---@param height number
function ComponentInstance:setSize(width, height)
    if self._element then
        self._element:setWidth(width)
        self._element:setHeight(height)
    end
end

--- Get size
---@return number, number
function ComponentInstance:getSize()
    if self._element then
        return self._element:getWidth(), self._element:getHeight()
    end
    return 0, 0
end

--- Bring to top
function ComponentInstance:bringToTop()
    if self._element then
        self._element:bringToTop()
    end
end

--- Add a child component
---@param child ReactiveUI.ComponentInstance
function ComponentInstance:addChild(child)
    table.insert(self._children, child)
    if self._element and child._element then
        self._element:addChild(child._element)
    end
end

--- Remove a child component
---@param child ReactiveUI.ComponentInstance
function ComponentInstance:removeChild(child)
    for i, c in ipairs(self._children) do
        if c == child then
            table.remove(self._children, i)
            if child._element and self._element then
                self._element:removeChild(child._element)
            end
            break
        end
    end
end

--- Create a binding from component state to element property
---@param key string State key to bind
---@return ReactiveUI.BindingInstance
function ComponentInstance:bind(key)
    return self._bindings:bind(self._state, key)
end

--- Create a computed binding from multiple state keys
---@param keys table Array of state keys
---@return ReactiveUI.BindingInstance
function ComponentInstance:bindComputed(keys)
    return self._bindings:bindComputed(self._state, keys)
end

--- Get the binding manager
---@return ReactiveUI.BindingManager
function ComponentInstance:getBindings()
    return self._bindings
end

return Component
