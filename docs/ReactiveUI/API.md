# ReactiveUI API Reference

Complete API documentation for ReactiveUI v1.0.0.

## Table of Contents

- [State Management](#state-management)
- [Component System](#component-system)
- [Elements](#elements)
- [Layout Helpers](#layout-helpers)
- [Theme](#theme)
- [Utilities](#utilities)

---

## State Management

### `ReactiveUI.State`

Reactive state store with subscription support.

#### `State.create(initialState)`

Creates a new state store.

```lua
local state = ReactiveUI.State.create({
    count = 0,
    items = {},
    user = { name = "Player", level = 1 }
})
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `initialState` | `table` | Initial state values |

**Returns:** `StateStore` - The state store instance

---

#### `state:get(key)`

Gets a value from the state store.

```lua
local count = state:get("count")
local level = state:get("user.level")  -- Dot notation for nested values
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `key` | `string` | The state key (supports dot notation) |

**Returns:** `any` - The value or nil if not found

---

#### `state:set(key, value)`

Sets a value in the state store and notifies subscribers.

```lua
state:set("count", 5)
state:set("user.name", "Hero")  -- Nested update
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `key` | `string` | The state key |
| `value` | `any` | The new value |

---

#### `state:subscribe(key, callback)`

Subscribes to state changes for a specific key.

```lua
local unsubscribe = state:subscribe("count", function(newValue, oldValue)
    print("Count: " .. oldValue .. " -> " .. newValue)
end)

-- Later: stop listening
unsubscribe()
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `key` | `string` | The state key to watch |
| `callback` | `function(newValue, oldValue)` | Called when value changes |

**Returns:** `function` - Unsubscribe function

---

#### `state:batch(fn)`

Batches multiple state updates, notifying subscribers only once at the end.

```lua
state:batch(function()
    state:set("x", 10)
    state:set("y", 20)
    state:set("z", 30)
end)  -- Subscribers notified once after all updates
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `fn` | `function` | Function containing multiple state updates |

---

#### `state:getAll()`

Returns the entire state table (read-only reference).

```lua
local snapshot = state:getAll()
```

**Returns:** `table` - The full state table

---

#### `state:reset()`

Resets state to initial values.

```lua
state:reset()
```

---

## Component System

### `ReactiveUI.Component`

Component definition and lifecycle management.

#### `Component.define(spec)`

Defines a new component type.

```lua
local MyComponent = ReactiveUI.Component.define({
    name = "MyComponent",
    
    defaultProps = {
        size = 100,
        color = { r = 1, g = 1, b = 1, a = 1 }
    },
    
    initialState = {
        visible = true,
        count = 0
    },
    
    -- Lifecycle hooks
    onCreate = function(self)
        print("Component created")
    end,
    
    onMount = function(self)
        print("Component mounted")
    end,
    
    onUnmount = function(self)
        print("Component unmounted")
    end,
    
    -- Render function (required)
    render = function(self, props, state)
        return ReactiveUI.Elements.Panel({
            x = props.x,
            y = props.y,
            width = props.size,
            height = props.size
        })
    end
})
```

**Component Spec:**
| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Component name (for debugging) |
| `defaultProps` | `table` | Default prop values |
| `initialState` | `table` | Initial component state |
| `onCreate` | `function(self)` | Called when instance created |
| `onMount` | `function(self)` | Called when added to UI |
| `onUnmount` | `function(self)` | Called when removed from UI |
| `render` | `function(self, props, state)` | Returns UI element (required) |

**Returns:** `ComponentFactory` - Factory function to create instances

---

#### Component Instance Methods

##### `instance:setState(updates)`

Updates component state and re-renders.

```lua
self:setState({ count = self.state.count + 1 })
```

##### `instance:forceUpdate()`

Forces a re-render without state change.

```lua
self:forceUpdate()
```

##### `instance:getElement()`

Returns the rendered PZ UI element.

```lua
local element = instance:getElement()
```

##### `instance:addToUIManager()`

Adds the component's element to UI manager.

```lua
instance:addToUIManager()
```

##### `instance:removeFromUIManager()`

Removes from UI manager and calls onUnmount.

```lua
instance:removeFromUIManager()
```

---

## Elements

### `ReactiveUI.Elements`

Factory functions for PZ UI elements. All elements are auto-initialized.

#### Common Props

All elements accept these common properties:

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `x` | `number` | `0` | X position |
| `y` | `number` | `0` | Y position |
| `width` | `number` | varies | Element width |
| `height` | `number` | varies | Element height |

---

### `Elements.Panel(props)`

Basic container with background.

```lua
local panel = ReactiveUI.Elements.Panel({
    x = 10, y = 10,
    width = 200, height = 150,
    backgroundColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.9 }
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `backgroundColor` | `{r,g,b,a}` | Theme bg | Background color |
| `borderColor` | `{r,g,b,a}` | nil | Border color |

---

### `Elements.Button(props)`

Clickable button with text.

```lua
local button = ReactiveUI.Elements.Button({
    x = 10, y = 10,
    width = 120, height = 25,
    text = "Click Me",
    onClick = function()
        print("Clicked!")
    end
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `text` | `string` | `""` | Button label |
| `onClick` | `function` | nil | Click handler |
| `enabled` | `boolean` | `true` | Enable/disable |
| `tooltip` | `string` | nil | Hover tooltip |

---

### `Elements.Label(props)`

Text display element.

```lua
local label = ReactiveUI.Elements.Label({
    x = 10, y = 10,
    text = "Hello World",
    font = UIFont.Large,
    color = { r = 1, g = 1, b = 1, a = 1 }
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `text` | `string` | `""` | Display text |
| `font` | `UIFont` | Theme font | Text font |
| `color` | `{r,g,b,a}` | Theme text | Text color |

---

### `Elements.TextEntry(props)`

Text input field.

```lua
local input = ReactiveUI.Elements.TextEntry({
    x = 10, y = 10,
    width = 200, height = 25,
    placeholder = "Enter name...",
    onTextChange = function(text)
        print("Text: " .. text)
    end,
    onEnter = function(text)
        print("Submitted: " .. text)
    end
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `text` | `string` | `""` | Initial text |
| `placeholder` | `string` | `""` | Placeholder text |
| `onTextChange` | `function(text)` | nil | Text change handler |
| `onEnter` | `function(text)` | nil | Enter key handler |
| `maxLength` | `number` | nil | Max character count |

---

### `Elements.List(props)`

Scrolling list container.

```lua
local list = ReactiveUI.Elements.List({
    x = 10, y = 10,
    width = 200, height = 300,
    items = { "Item 1", "Item 2", "Item 3" },
    onSelect = function(item, index)
        print("Selected: " .. item)
    end
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `items` | `table` | `{}` | List items |
| `onSelect` | `function(item, index)` | nil | Selection handler |
| `itemHeight` | `number` | `25` | Height per item |

---

### `Elements.Window(props)`

Draggable, resizable window.

```lua
local window = ReactiveUI.Elements.Window({
    x = 100, y = 100,
    width = 400, height = 300,
    title = "My Window",
    resizable = true,
    onClose = function()
        print("Window closed")
    end
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | `string` | `""` | Window title |
| `resizable` | `boolean` | `true` | Allow resizing |
| `onClose` | `function` | nil | Close button handler |

---

### `Elements.Checkbox(props)`

Checkbox toggle.

```lua
local checkbox = ReactiveUI.Elements.Checkbox({
    x = 10, y = 10,
    text = "Enable feature",
    checked = false,
    onChange = function(checked)
        print("Checked: " .. tostring(checked))
    end
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `text` | `string` | `""` | Label text |
| `checked` | `boolean` | `false` | Initial state |
| `onChange` | `function(checked)` | nil | Change handler |

---

### `Elements.Dropdown(props)`

Combo box selector.

```lua
local dropdown = ReactiveUI.Elements.Dropdown({
    x = 10, y = 10,
    width = 150, height = 25,
    options = { "Option A", "Option B", "Option C" },
    selected = 1,
    onChange = function(option, index)
        print("Selected: " .. option)
    end
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `options` | `table` | `{}` | List of options |
| `selected` | `number` | `1` | Selected index |
| `onChange` | `function(option, index)` | nil | Change handler |

---

### `Elements.Image(props)`

Image/texture display.

```lua
local image = ReactiveUI.Elements.Image({
    x = 10, y = 10,
    width = 64, height = 64,
    texture = getTexture("media/ui/icon.png")
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `texture` | `Texture` | nil | Image texture |
| `tint` | `{r,g,b,a}` | nil | Color tint |

---

### `Elements.ProgressBar(props)`

Progress indicator bar.

```lua
local progress = ReactiveUI.Elements.ProgressBar({
    x = 10, y = 10,
    width = 200, height = 20,
    value = 0.75,  -- 75%
    color = { r = 0, g = 0.8, b = 0, a = 1 }
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `value` | `number` | `0` | Progress (0-1) |
| `color` | `{r,g,b,a}` | Theme primary | Bar color |
| `showText` | `boolean` | `false` | Show percentage |

---

### `Elements.RichText(props)`

Formatted text panel with PZ rich text support.

```lua
local richText = ReactiveUI.Elements.RichText({
    x = 10, y = 10,
    width = 300, height = 200,
    text = " <RGB:1,0,0> Red text <LINE> <RGB:0,1,0> Green text "
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `text` | `string` | `""` | Rich text content |

---

### `Elements.TabPanel(props)`

Tabbed container panel.

```lua
local tabs = ReactiveUI.Elements.TabPanel({
    x = 10, y = 10,
    width = 400, height = 300,
    tabs = {
        { name = "General", content = generalPanel },
        { name = "Settings", content = settingsPanel },
        { name = "About", content = aboutPanel }
    },
    activeTab = 1,
    onTabChange = function(index, name)
        print("Tab changed to: " .. name)
    end
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `tabs` | `table` | `{}` | Array of `{name, content}` |
| `activeTab` | `number` | `1` | Initially active tab |
| `onTabChange` | `function(index, name)` | nil | Tab change handler |

---

## Layout Helpers

### `ReactiveUI.Layout`

Layout utility functions for arranging elements.

---

### `Layout.vstack(props)`

Arranges children vertically.

```lua
local stack = ReactiveUI.Layout.vstack({
    x = 10, y = 10,
    spacing = 8,
    children = {
        ReactiveUI.Elements.Label({ text = "Name:" }),
        ReactiveUI.Elements.TextEntry({ width = 200, height = 25 }),
        ReactiveUI.Elements.Button({ text = "Submit", width = 100, height = 25 })
    }
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `spacing` | `number` | `0` | Space between children |
| `children` | `table` | `{}` | Child elements |
| `align` | `string` | `"left"` | Alignment: left, center, right |

**Returns:** `table` - Container with positioned children

---

### `Layout.hstack(props)`

Arranges children horizontally.

```lua
local row = ReactiveUI.Layout.hstack({
    x = 10, y = 10,
    spacing = 10,
    children = {
        ReactiveUI.Elements.Button({ text = "A", width = 50, height = 25 }),
        ReactiveUI.Elements.Button({ text = "B", width = 50, height = 25 }),
        ReactiveUI.Elements.Button({ text = "C", width = 50, height = 25 })
    }
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `spacing` | `number` | `0` | Space between children |
| `children` | `table` | `{}` | Child elements |
| `align` | `string` | `"top"` | Alignment: top, center, bottom |

---

### `Layout.grid(props)`

Arranges children in a grid.

```lua
local grid = ReactiveUI.Layout.grid({
    x = 10, y = 10,
    columns = 4,
    spacing = 5,
    children = inventorySlots  -- Array of elements
})
```

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `columns` | `number` | `1` | Number of columns |
| `spacing` | `number` | `0` | Space between cells |
| `children` | `table` | `{}` | Child elements |

---

### `Layout.center(element, container)`

Centers element within container bounds.

```lua
local centered = ReactiveUI.Layout.center(myElement, {
    width = 400,
    height = 300
})
```

---

### `Layout.centerX(element, containerWidth)`

Centers element horizontally.

```lua
local xCentered = ReactiveUI.Layout.centerX(button, 400)
```

---

### `Layout.centerY(element, containerHeight)`

Centers element vertically.

```lua
local yCentered = ReactiveUI.Layout.centerY(button, 300)
```

---

### `Layout.bottom(element, containerHeight, margin)`

Positions element at bottom of container.

```lua
local bottomBtn = ReactiveUI.Layout.bottom(button, 300, 10)
```

---

### `Layout.right(element, containerWidth, margin)`

Positions element at right of container.

```lua
local rightBtn = ReactiveUI.Layout.right(button, 400, 10)
```

---

### `Layout.fill(element, container, padding)`

Fills element to container size with optional padding.

```lua
local filled = ReactiveUI.Layout.fill(panel, {
    width = 400,
    height = 300
}, 10)  -- 10px padding
```

---

### `Layout.flexRow(props)`

Flex-like row layout with grow support.

```lua
local row = ReactiveUI.Layout.flexRow({
    x = 10, y = 10,
    width = 400,
    spacing = 10,
    children = {
        { element = label, grow = 0 },      -- Fixed size
        { element = input, grow = 1 },      -- Takes remaining space
        { element = button, grow = 0 }      -- Fixed size
    }
})
```

---

### `Layout.flow(props)`

Wrapping flow layout.

```lua
local flow = ReactiveUI.Layout.flow({
    x = 10, y = 10,
    width = 300,
    spacing = 5,
    children = tags  -- Will wrap to next line when full
})
```

---

## Theme

### `ReactiveUI.Theme`

Global theme configuration.

#### Colors

```lua
ReactiveUI.Theme.colors = {
    primary    = { r = 0.2, g = 0.6, b = 1, a = 1 },     -- Blue accent
    secondary  = { r = 0.4, g = 0.4, b = 0.4, a = 1 },   -- Gray
    background = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }, -- Dark bg
    surface    = { r = 0.15, g = 0.15, b = 0.15, a = 1 },-- Panel bg
    text       = { r = 1, g = 1, b = 1, a = 1 },         -- White text
    textMuted  = { r = 0.7, g = 0.7, b = 0.7, a = 1 },   -- Gray text
    border     = { r = 0.3, g = 0.3, b = 0.3, a = 1 },   -- Border color
    success    = { r = 0.2, g = 0.8, b = 0.2, a = 1 },   -- Green
    warning    = { r = 1, g = 0.7, b = 0, a = 1 },       -- Orange
    error      = { r = 1, g = 0.2, b = 0.2, a = 1 }      -- Red
}
```

#### Fonts

```lua
ReactiveUI.Theme.fonts = {
    small  = UIFont.Small,
    medium = UIFont.Medium,
    large  = UIFont.Large,
    title  = UIFont.Title
}
```

#### Spacing

```lua
ReactiveUI.Theme.spacing = {
    xs = 4,
    sm = 8,
    md = 12,
    lg = 16,
    xl = 24
}
```

---

## Utilities

### `ReactiveUI.Utils`

Utility functions.

---

### `Utils.deepCopy(tbl)`

Deep copies a table.

```lua
local copy = ReactiveUI.Utils.deepCopy(originalTable)
```

---

### `Utils.merge(target, source)`

Merges source into target (shallow).

```lua
local merged = ReactiveUI.Utils.merge({ a = 1 }, { b = 2 })
-- { a = 1, b = 2 }
```

---

### `Utils.rgba(r, g, b, a)`

Creates a color table.

```lua
local red = ReactiveUI.Utils.rgba(1, 0, 0, 1)
-- { r = 1, g = 0, b = 0, a = 1 }
```

---

### `Utils.lerp(a, b, t)`

Linear interpolation.

```lua
local mid = ReactiveUI.Utils.lerp(0, 100, 0.5)  -- 50
```

---

### `Utils.clamp(value, min, max)`

Clamps value to range.

```lua
local clamped = ReactiveUI.Utils.clamp(150, 0, 100)  -- 100
```

---

### `Utils.debounce(fn, delay)`

Creates debounced function.

```lua
local debouncedSearch = ReactiveUI.Utils.debounce(function(query)
    performSearch(query)
end, 300)

-- Rapid calls only execute once after 300ms pause
debouncedSearch("a")
debouncedSearch("ab")
debouncedSearch("abc")  -- Only this executes
```

---

### `Utils.throttle(fn, interval)`

Creates throttled function.

```lua
local throttledUpdate = ReactiveUI.Utils.throttle(function()
    updateUI()
end, 100)

-- At most once per 100ms
```

---

### `Utils.generateId(prefix)`

Generates unique ID.

```lua
local id = ReactiveUI.Utils.generateId("btn")  -- "btn_1", "btn_2", ...
```
