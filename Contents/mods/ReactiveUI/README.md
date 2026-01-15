# ReactiveUI

A reactive UI framework for Project Zomboid that simplifies UI creation while maintaining full fidelity with PZ's native look and feel.

## 📚 [Full Documentation](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Overview)

Visit the **[ReactiveUI Wiki](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Overview)** for complete documentation.

## Quick Links

- **[State Management](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-State)** - Reactive state system
- **[Binding System](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Binding)** - Automatic state-to-UI binding
- **[Components](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Components)** - Build reusable components
- **[Elements](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Elements)** - UI element reference
- **[Layouts](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Layouts)** - Layout helpers

## Features

- **Declarative Syntax**: Describe your UI structure, not imperative construction
- **Reactive State**: State changes automatically update the UI
- **Automatic Bindings**: Connect state to UI elements without manual subscriptions
- **Component System**: Build reusable, encapsulated UI components
- **Layout Helpers**: Easy vertical/horizontal stacks, grids, and flow layouts
- **Theming**: Consistent colors, fonts, and spacing
- **Full PZ Fidelity**: Uses native ISUI elements - looks exactly like vanilla

## Installation

Requires **KoniLib** as a dependency.

## Quick Start

### Simple Button
```lua
local button = ReactiveUI.Elements.Button({
    x = 100, y = 100,
    width = 120, height = 25,
    text = "Click Me!",
    onClick = function(btn)
        print("Button clicked!")
    end
})
button:initialise()
button:instantiate()
button:addToUIManager()
```

### Reactive State
```lua
-- Create a state store
local state = ReactiveUI.State.create({
    count = 0,
    name = "Player"
})

-- Subscribe to changes
state:subscribe("count", function(newValue, oldValue)
    print("Count changed: " .. oldValue .. " -> " .. newValue)
end)

-- Update state (triggers subscribers)
state:set("count", state:get("count") + 1)
```

### Layout Helpers
```lua
-- Vertical stack
local layout = ReactiveUI.Layout.vstack({
    x = 10, y = 10,
    spacing = 5,
    children = {
        ReactiveUI.Elements.Label({ text = "Name:" }),
        ReactiveUI.Elements.TextEntry({ width = 200, height = 25 }),
        ReactiveUI.Elements.Button({ text = "Submit", width = 100, height = 25 })
    }
})

-- Add all children to parent
for _, element in ipairs(layout.elements) do
    element:initialise()
    parentPanel:addChild(element)
end
```

### Component Definition
```lua
local Counter = ReactiveUI.Component.define({
    name = "Counter",
    
    defaultProps = {
        initialValue = 0
    },
    
    initialState = {
        count = 0
    },
    
    onCreate = function(self, props, state)
        self:setState({ count = props.initialValue })
    end,
    
    render = function(self, props, state)
        return ReactiveUI.Elements.Button({
            x = props.x or 0,
            y = props.y or 0,
            width = 150,
            height = 30,
            text = "Count: " .. state.count,
            onClick = function()
                self:setState({ count = state.count + 1 })
            end
        })
    end
})

-- Usage
local counter = Counter({ x = 100, y = 100, initialValue = 5 })
counter:addToUIManager()
```

### Component with Bindings (Recommended)
```lua
local Counter = ReactiveUI.Component.define({
    name = "Counter",
    
    initialState = {
        count = 0
    },
    
    render = function(self, props, state)
        local panel = ReactiveUI.Elements.Panel({ x = 0, y = 0, width = 200, height = 100 })
        
        -- Create label
        local label = ReactiveUI.Elements.Label({ x = 10, y = 10, width = 180, height = 20 })
        panel:addChild(label)
        
        -- Bind state to label (automatically updates when count changes)
        self:bind("count"):to(label, "text", function(value)
            return "Count: " .. tostring(value)
        end)
        
        -- Button to increment
        local button = ReactiveUI.Elements.Button({
            x = 10, y = 40,
            width = 100, height = 25,
            text = "Increment",
            onClick = function()
                self:setState({ count = state.count + 1 })
            end
        })
        panel:addChild(button)
        
        return panel
    end
})
```

## API Reference

### Binding System

Automatic state-to-UI binding without manual subscription management:

```lua
-- One-way binding: state -> UI
self:bind("count"):to(label, "text", function(value)
    return "Count: " .. value
end)

-- Two-way binding: state <-> input
self:bind("username"):toInput(textBox)

-- Computed binding: multiple state keys
self:bindComputed({"firstName", "lastName"}):to(label, "text", 
    function(firstName, lastName)
        return firstName .. " " .. lastName
    end
)

-- Conditional visibility
self:bind("hasError"):toVisible(errorPanel)

-- Conditional enabled state
self:bind("isValid"):toEnabled(submitButton)

-- Custom callback
self:bind("status"):toCallback(function(status)
    print("Status changed: " .. status)
end)
```

See **[Binding Documentation](https://github.com/Konijima/PZServerFramework/wiki/ReactiveUI-Binding)** for complete guide.

### State Management

```lua
-- Create store with initial values
local store = ReactiveUI.State.create({
    key1 = value1,
    key2 = value2
})

-- Get value
local value = store:get("key")

-- Set value (triggers subscribers)
store:set("key", newValue)

-- Set multiple values
store:setMany({ key1 = val1, key2 = val2 })

-- Batch updates (single notification cycle)
store:batch(function()
    store:set("key1", val1)
    store:set("key2", val2)
end)

-- Subscribe to key changes
local unsubscribe = store:subscribe("key", function(newValue, oldValue, key)
    -- Handle change
end)

-- Subscribe to any change
local unsubscribe = store:subscribeAll(function(key, newValue, oldValue)
    -- Handle change
end)

-- Computed values
store:computed({"key1", "key2"}, function(store)
    return store:get("key1") + store:get("key2")
end, function(computedValue)
    -- Called when computed value changes
end)
```

### Elements

All elements accept common props:
- `x`, `y`: Position
- `width`, `height`: Size
- `visible`: Boolean
- `anchorLeft`, `anchorRight`, `anchorTop`, `anchorBottom`: Anchoring
- `backgroundColor`, `borderColor`: Color tables `{r, g, b, a}`

#### Panel
```lua
ReactiveUI.Elements.Panel({
    x = 0, y = 0,
    width = 200, height = 100,
    background = true,
    backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
})
```

#### Button
```lua
ReactiveUI.Elements.Button({
    text = "Click",
    onClick = function(button) end,
    onMouseDown = function(button, x, y) end,
    tooltip = "Hover text",
    enabled = true,
    font = UIFont.Small,
    image = getTexture("..."),
})
```

#### Label
```lua
ReactiveUI.Elements.Label({
    text = "Hello",
    font = UIFont.Small,
    color = { r = 1, g = 1, b = 1, a = 1 },
    left = true  -- Left-aligned
})
```

#### TextEntry
```lua
ReactiveUI.Elements.TextEntry({
    text = "",
    placeholder = "Enter name...",
    onChange = function(target, entry) end,
    onEnter = function(entry) end,
    maxLength = 50,
    masked = false,  -- Password mode
    editable = true
})
```

#### List
```lua
ReactiveUI.Elements.List({
    items = { "Item 1", "Item 2", "Item 3" },
    -- Or with data:
    items = {
        { text = "Item 1", data = someObject },
        { text = "Item 2", data = anotherObject }
    },
    onSelect = function(list, item) end,
    onRightClick = function(list, item, x, y) end,
    itemHeight = 25
})
```

#### Window
```lua
ReactiveUI.Elements.Window({
    title = "My Window",
    resizable = true,
    onClose = function(window) end
})
```

#### Checkbox
```lua
ReactiveUI.Elements.Checkbox({
    options = { "Option 1", "Option 2", "Option 3" },
    selected = { [1] = true, [2] = false },
    onChange = function(target, checkbox) end
})
```

#### Dropdown
```lua
ReactiveUI.Elements.Dropdown({
    options = { "Choice A", "Choice B", "Choice C" },
    selected = 1,
    onChange = function(target, combo) end
})
```

### Layout

#### vstack (Vertical Stack)
```lua
ReactiveUI.Layout.vstack({
    x = 0, y = 0,
    spacing = 5,
    padding = 10,  -- or { top = 10, right = 10, bottom = 10, left = 10 }
    children = { element1, element2, element3 }
})
-- Returns: { elements, totalHeight, maxWidth }
```

#### hstack (Horizontal Stack)
```lua
ReactiveUI.Layout.hstack({
    x = 0, y = 0,
    spacing = 10,
    children = { element1, element2 }
})
-- Returns: { elements, totalWidth, maxHeight }
```

#### grid
```lua
ReactiveUI.Layout.grid({
    x = 0, y = 0,
    columns = 3,
    spacing = 5,
    cellWidth = 50,  -- Optional, fixed cell width
    cellHeight = 50, -- Optional, fixed cell height
    children = { ... }
})
-- Returns: { elements, totalWidth, totalHeight, rows, cols }
```

#### Positioning Helpers
```lua
ReactiveUI.Layout.center(element, containerWidth, containerHeight)
ReactiveUI.Layout.centerX(element, containerWidth)
ReactiveUI.Layout.centerY(element, containerHeight)
ReactiveUI.Layout.bottom(element, containerHeight, margin)
ReactiveUI.Layout.right(element, containerWidth, margin)
ReactiveUI.Layout.fill(element, containerWidth, containerHeight, padding)
```

### Utilities

```lua
ReactiveUI.Utils.deepCopy(table)
ReactiveUI.Utils.merge(table1, table2, ...)
ReactiveUI.Utils.rgba(r, g, b, a)
ReactiveUI.Utils.lerp(a, b, t)
ReactiveUI.Utils.lerpColor(colorA, colorB, t)
ReactiveUI.Utils.clamp(value, min, max)
ReactiveUI.Utils.generateId(prefix)
ReactiveUI.Utils.getFontHeight(font)
ReactiveUI.Utils.measureTextWidth(text, font)
ReactiveUI.Utils.calcButtonHeight(font, padding)
ReactiveUI.Utils.debounce(fn, delayMs)
ReactiveUI.Utils.throttle(fn, intervalMs)
```

### Theme

```lua
-- Colors
ReactiveUI.Theme.colors.background
ReactiveUI.Theme.colors.backgroundHover
ReactiveUI.Theme.colors.border
ReactiveUI.Theme.colors.text
ReactiveUI.Theme.colors.textDisabled
ReactiveUI.Theme.colors.primary
ReactiveUI.Theme.colors.success
ReactiveUI.Theme.colors.danger
ReactiveUI.Theme.colors.warning

-- Fonts
ReactiveUI.Theme.fonts.small
ReactiveUI.Theme.fonts.medium
ReactiveUI.Theme.fonts.large
ReactiveUI.Theme.fonts.title

-- Spacing
ReactiveUI.Theme.spacing.xs  -- 4
ReactiveUI.Theme.spacing.sm  -- 8
ReactiveUI.Theme.spacing.md  -- 12
ReactiveUI.Theme.spacing.lg  -- 16
ReactiveUI.Theme.spacing.xl  -- 24
```

## Configuration

```lua
ReactiveUI.Config.debugMode = false
ReactiveUI.Config.animationEnabled = true
ReactiveUI.Config.defaultTransitionDuration = 150
```

## License

MIT License - Free for use in any Project Zomboid mod.
