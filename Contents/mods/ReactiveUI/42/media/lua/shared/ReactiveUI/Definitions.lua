---@class ReactiveUI
---@field Version string Module version
---@field State table State management module
---@field Component table Component creation module
---@field Elements table UI element wrappers
---@field Utils table Utility functions
ReactiveUI = ReactiveUI or {}

ReactiveUI.Version = "1.0.0"

-- Submodule placeholders (populated by other files)
ReactiveUI.State = {}
ReactiveUI.Component = {}
ReactiveUI.Elements = {}
ReactiveUI.Utils = {}

---@class ReactiveUI.Config
---@field debugMode boolean Enable debug logging
---@field animationEnabled boolean Enable UI animations
---@field defaultTransitionDuration number Default transition duration in ms
ReactiveUI.Config = {
    debugMode = false,
    animationEnabled = true,
    defaultTransitionDuration = 150,
}

---@class ReactiveUI.Theme
---@field colors table Color definitions
---@field fonts table Font definitions
---@field spacing table Spacing definitions
ReactiveUI.Theme = {
    colors = {
        background = { r = 0, g = 0, b = 0, a = 0.8 },
        backgroundHover = { r = 0.3, g = 0.3, b = 0.3, a = 1.0 },
        border = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
        text = { r = 1, g = 1, b = 1, a = 1 },
        textDisabled = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
        primary = { r = 0.2, g = 0.6, b = 1, a = 1 },
        success = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
        danger = { r = 0.8, g = 0.2, b = 0.2, a = 1 },
        warning = { r = 0.9, g = 0.7, b = 0.2, a = 1 },
    },
    fonts = {
        small = UIFont.Small,
        medium = UIFont.Medium,
        large = UIFont.Large,
        title = UIFont.Title,
    },
    spacing = {
        xs = 4,
        sm = 8,
        md = 12,
        lg = 16,
        xl = 24,
    },
}
