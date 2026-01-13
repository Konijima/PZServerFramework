# ReactiveUI Documentation

**ReactiveUI** is a reactive UI framework for Project Zomboid that simplifies UI creation while maintaining full fidelity with PZ's native look and feel.

> **📚 Full Documentation:** See [API.md](API.md) for complete API reference.

## Features

### 1. Declarative Syntax
Describe your UI structure instead of imperative construction:
```lua
local button = ReactiveUI.Elements.Button({
    x = 10, y = 10,
    width = 100, height = 25,
    text = "Click Me",
    onClick = function() print("Clicked!") end
})
-- Elements are auto-initialized, just add to parent
parent:addChild(button)
```

### 2. Reactive State Management
State changes automatically trigger UI updates:
```lua
local state = ReactiveUI.State.create({
    count = 0,
    name = "Player"
})

-- Subscribe to changes
state:subscribe("count", function(newValue, oldValue)
    print("Count changed: " .. oldValue .. " -> " .. newValue)
end)

-- Updates trigger subscribers automatically
state:set("count", state:get("count") + 1)
```

### 3. Component System
Build reusable, encapsulated UI components:
```lua
local Counter = ReactiveUI.Component.define({
    name = "Counter",
    initialState = { count = 0 },
    
    render = function(self, props, state)
        return ReactiveUI.Elements.Button({
            x = props.x, y = props.y,
            width = 150, height = 30,
            text = "Count: " .. state.count,
            onClick = function()
                self:setState({ count = state.count + 1 })
            end
        })
    end
})

local counter = Counter({ x = 100, y = 100 })
counter:addToUIManager()
```

### 4. Layout Helpers
Common layout patterns built-in:
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

-- Grid layout
local grid = ReactiveUI.Layout.grid({
    x = 10, y = 10,
    columns = 3,
    spacing = 10,
    children = items
})
```

### 5. Theming
Consistent colors, fonts, and spacing:
```lua
ReactiveUI.Theme.colors.primary   -- { r = 0.2, g = 0.6, b = 1, a = 1 }
ReactiveUI.Theme.fonts.medium     -- UIFont.Medium
ReactiveUI.Theme.spacing.md       -- 12
```

## Requirements

- **KoniLib** - Core library dependency

## Quick Start

### 1. Simple Element
```lua
require "ReactiveUI/Client"

local button = ReactiveUI.Elements.Button({
    x = 100, y = 100,
    width = 120, height = 25,
    text = "Hello!",
    onClick = function() print("Hello World!") end
})
button:addToUIManager()
```

### 2. Reactive Updates
```lua
-- Create state store
local state = ReactiveUI.State.create({
    health = 100,
    name = "Player"
})

-- Create label that updates automatically
local healthLabel = ReactiveUI.Elements.Label({
    x = 10, y = 10,
    text = "Health: " .. state:get("health")
})

-- Subscribe to health changes
state:subscribe("health", function(newHealth)
    healthLabel:setName("Health: " .. newHealth)
end)

-- Later: update health
state:set("health", 75)  -- Label updates automatically!
```

### 3. Full Component Example
```lua
local InventorySlot = ReactiveUI.Component.define({
    name = "InventorySlot",
    
    defaultProps = {
        size = 48,
        item = nil
    },
    
    initialState = {
        highlighted = false
    },
    
    render = function(self, props, state)
        local bgColor = state.highlighted 
            and ReactiveUI.Theme.colors.primary 
            or ReactiveUI.Theme.colors.background
        
        local panel = ReactiveUI.Elements.Panel({
            x = props.x, y = props.y,
            width = props.size, height = props.size,
            backgroundColor = bgColor
        })
        
        if props.item then
            local icon = ReactiveUI.Elements.Image({
                x = 4, y = 4,
                width = props.size - 8,
                height = props.size - 8,
                texture = props.item:getTexture()
            })
            panel:addChild(icon)
        end
        
        return panel
    end
})
```

## Directory Structure

```
Contents/mods/ReactiveUI/42/media/lua/
├── client/ReactiveUI/
│   ├── Client.lua      -- Entry point (requires all modules)
│   ├── Elements.lua    -- UI element factories
│   └── Layout.lua      -- Layout helpers
└── shared/ReactiveUI/
    ├── Definitions.lua -- Config, theme, types
    ├── State.lua       -- Reactive state management
    ├── Utils.lua       -- Utility functions
    └── Component.lua   -- Component system
```

## Comparison with Vanilla UI

### Creating a Button (Vanilla)
```lua
local button = ISButton:new(10, 10, 100, 25, "Click", self, callback)
button:initialise()
button:instantiate()
parent:addChild(button)
```

### Creating a Button (ReactiveUI)
```lua
local button = ReactiveUI.Elements.Button({
    x = 10, y = 10, width = 100, height = 25,
    text = "Click",
    onClick = callback
})
parent:addChild(button)  -- Already initialized!
```

## Available Elements

| Element | Description |
|---------|-------------|
| `Panel` | Basic container with background |
| `Button` | Clickable button with text/image |
| `Label` | Text display |
| `TextEntry` | Text input field |
| `List` | Scrolling list box |
| `Window` | Draggable, resizable window |
| `Checkbox` | Tick box options |
| `Dropdown` | Combo box selector |
| `Image` | Image/texture display |
| `ProgressBar` | Progress indicator |
| `RichText` | Formatted text panel |
| `TabPanel` | Tabbed container |

## Layout Functions

| Function | Description |
|----------|-------------|
| `vstack` | Vertical stack |
| `hstack` | Horizontal stack |
| `grid` | Grid layout |
| `center` | Center element in container |
| `centerX` | Center horizontally |
| `centerY` | Center vertically |
| `bottom` | Position at bottom |
| `right` | Position at right |
| `fill` | Fill container |
| `flexRow` | Flex-like row with grow |
| `flow` | Wrapping flow layout |

## Configuration

```lua
-- Debug mode (logs state changes)
ReactiveUI.Config.debugMode = false

-- Animation support (future)
ReactiveUI.Config.animationEnabled = true

-- Default transition duration
ReactiveUI.Config.defaultTransitionDuration = 150
```

## Best Practices

1. **Use Components for Reusable UI**: Define components for UI patterns you use multiple times
2. **Centralize State**: Use a single state store per feature/window
3. **Batch Updates**: Use `state:batch()` when updating multiple values
4. **Subscribe Sparingly**: Only subscribe to state keys you actually need
5. **Unsubscribe on Cleanup**: Store unsubscribe functions and call them when removing UI

## License

MIT License - Free for use in any Project Zomboid mod.
