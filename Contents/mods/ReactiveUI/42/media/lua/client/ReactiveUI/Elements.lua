require "ISUI/ISUIElement"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISTickBox"
require "ISUI/ISComboBox"
require "ISUI/ISImage"
require "ISUI/ISProgressBar"
require "ISUI/ISRichTextPanel"
require "ISUI/ISTabPanel"

require "ReactiveUI/Definitions"
require "ReactiveUI/Utils"

--[[
    ReactiveUI Elements
    
    Factory functions that create PZ native UI elements with a cleaner,
    more declarative API. These wrap ISUIElement and its derivatives.
    
    All elements are automatically initialized (initialise + instantiate called).
    Just create and add to parent:
    
    Example:
    
    local button = ReactiveUI.Elements.Button({
        x = 10,
        y = 10,
        width = 100,
        height = 25,
        text = "Click Me",
        onClick = function(button) print("Clicked!") end,
    })
    parent:addChild(button)
    
    All elements accept common properties:
    - x, y: Position
    - width, height: Size
    - visible: Initial visibility
    - anchorLeft, anchorRight, anchorTop, anchorBottom: Anchoring
    - backgroundColor, borderColor: Colors as {r, g, b, a} tables
]]

local Elements = ReactiveUI.Elements
local Utils = ReactiveUI.Utils

--- Initialize an element (calls initialise and instantiate)
---@param element ISUIElement
---@param postInitFn function? Optional function to call after initialization
local function initElement(element, postInitFn)
    element:initialise()
    element:instantiate()
    if postInitFn then
        postInitFn(element)
    end
    return element
end

--- Apply common properties to any ISUIElement
---@param element ISUIElement
---@param props table
local function applyCommonProps(element, props)
    if props.visible ~= nil then
        element:setVisible(props.visible)
    end
    
    if props.anchorLeft ~= nil then
        element.anchorLeft = props.anchorLeft
    end
    if props.anchorRight ~= nil then
        element.anchorRight = props.anchorRight
    end
    if props.anchorTop ~= nil then
        element.anchorTop = props.anchorTop
    end
    if props.anchorBottom ~= nil then
        element.anchorBottom = props.anchorBottom
    end
    
    if props.backgroundColor then
        element.backgroundColor = props.backgroundColor
    end
    if props.borderColor then
        element.borderColor = props.borderColor
    end
end

--- Create a Panel element
---@param props table { x, y, width, height, background?, backgroundColor?, borderColor?, children? }
---@return ISPanel
function Elements.Panel(props)
    local panel = ISPanel:new(
        props.x or 0,
        props.y or 0,
        props.width or 100,
        props.height or 100
    )
    
    if props.background ~= nil then
        panel.background = props.background
    end
    
    applyCommonProps(panel, props)
    
    -- Allow custom prerender/render
    if props.onPrerender then
        local originalPrerender = panel.prerender
        panel.prerender = function(self)
            originalPrerender(self)
            props.onPrerender(self)
        end
    end
    
    if props.onRender then
        local originalRender = panel.render
        panel.render = function(self)
            if originalRender then originalRender(self) end
            props.onRender(self)
        end
    end
    
    return initElement(panel)
end

--- Create a Button element
---@param props table { x, y, width, height, text, onClick?, onMouseDown?, tooltip?, enabled?, font? }
---@return ISButton
function Elements.Button(props)
    local button = ISButton:new(
        props.x or 0,
        props.y or 0,
        props.width or 100,
        props.height or Utils.calcButtonHeight(props.font),
        props.text or "",
        props.target or props, -- clicktarget
        props.onClick,
        props.onMouseDown
    )
    
    applyCommonProps(button, props)
    
    if props.font then
        button.font = props.font
    end
    
    if props.image then
        button:setImage(props.image)
    end
    
    if props.displayBackground ~= nil then
        button:setDisplayBackground(props.displayBackground)
    end
    
    if props.backgroundColorMouseOver then
        button.backgroundColorMouseOver = props.backgroundColorMouseOver
    end
    
    if props.textColor then
        button.textColor = props.textColor
    end
    
    return initElement(button, function(btn)
        -- These require initialization first
        if props.tooltip then
            btn:setTooltip(props.tooltip)
        end
        if props.enabled ~= nil then
            btn:setEnable(props.enabled)
        end
    end)
end

--- Create a Label element
---@param props table { x, y, height?, text, font?, color?, left? }
---@return ISLabel
function Elements.Label(props)
    local color = props.color or ReactiveUI.Theme.colors.text
    local font = props.font or UIFont.Small
    
    local label = ISLabel:new(
        props.x or 0,
        props.y or 0,
        props.height or Utils.getFontHeight(font),
        props.text or "",
        color.r,
        color.g,
        color.b,
        color.a or 1,
        font,
        props.left ~= false -- default to left-aligned
    )
    
    applyCommonProps(label, props)
    
    return initElement(label)
end

--- Create a TextEntry (input) element
---@param props table { x, y, width, height, text?, placeholder?, onChange?, onEnter?, maxLength?, masked?, editable? }
---@return ISTextEntryBox
function Elements.TextEntry(props)
    local entry = ISTextEntryBox:new(
        props.text or "",
        props.x or 0,
        props.y or 0,
        props.width or 200,
        props.height or Utils.calcButtonHeight(props.font)
    )
    
    applyCommonProps(entry, props)
    
    if props.font then
        entry.font = props.font
    end
    
    if props.onChange then
        entry.onTextChangeFunction = props.onChange
        entry.target = props.target or entry
    end
    
    if props.onEnter then
        local originalOnCommandEntered = entry.onCommandEntered
        entry.onCommandEntered = function(self)
            if originalOnCommandEntered then originalOnCommandEntered(self) end
            props.onEnter(self)
        end
    end
    
    return initElement(entry, function(e)
        -- These methods require initialization first
        if props.placeholder then
            e:setPlaceholderText(props.placeholder)
        end
        if props.maxLength then
            e:setMaxTextLength(props.maxLength)
        end
        if props.masked then
            e:setMasked(props.masked)
        end
        if props.editable ~= nil then
            e:setEditable(props.editable)
        end
        if props.tooltip then
            e:setTooltip(props.tooltip)
        end
        -- Always unfocus after creation to prevent keyboard capture
        e:unfocus()
    end)
end

--- Create a ScrollingListBox element
---@param props table { x, y, width, height, items?, onSelect?, onRightClick?, font?, itemHeight? }
---@return ISScrollingListBox
function Elements.List(props)
    local list = ISScrollingListBox:new(
        props.x or 0,
        props.y or 0,
        props.width or 200,
        props.height or 200
    )
    
    applyCommonProps(list, props)
    
    if props.font then
        list.font = props.font
        list.fontHgt = Utils.getFontHeight(props.font)
    end
    
    if props.itemHeight then
        list.itemheight = props.itemHeight
    end
    
    if props.onSelect then
        list.doDrawItem = list.doDrawItem -- ensure it exists
        list.onmousedown = function(self, x, y)
            ISScrollingListBox.onMouseDown(self, x, y)
            local item = self:getItemAtPosition(x, y)
            if item then
                props.onSelect(self, item)
            end
        end
    end
    
    if props.onRightClick then
        list.onRightMouseDown = function(self, x, y)
            local item = self:getItemAtPosition(x, y)
            if item then
                props.onRightClick(self, item, x, y)
            end
        end
    end
    
    return initElement(list, function(l)
        -- Add items after init if provided
        if props.items then
            for _, item in ipairs(props.items) do
                if type(item) == "table" then
                    l:addItem(item.text or item.name or tostring(item), item)
                else
                    l:addItem(tostring(item), item)
                end
            end
        end
    end)
end

--- Create a Window element
---@param props table { x, y, width, height, title?, resizable?, closeable?, onClose? }
---@return ISCollapsableWindow
function Elements.Window(props)
    local window = ISCollapsableWindow:new(
        props.x or 100,
        props.y or 100,
        props.width or 400,
        props.height or 300
    )
    
    applyCommonProps(window, props)
    
    if props.resizable ~= nil then
        window.resizable = props.resizable
    end
    
    if props.onClose then
        local originalClose = window.close
        window.close = function(self)
            props.onClose(self)
            originalClose(self)
        end
    end
    
    return initElement(window, function(w)
        if props.title then
            w:setTitle(props.title)
        end
    end)
end

--- Create a Checkbox/TickBox element
---@param props table { x, y, width, height?, options?, onChange?, selected? }
---@return ISTickBox
function Elements.Checkbox(props)
    local checkbox = ISTickBox:new(
        props.x or 0,
        props.y or 0,
        props.width or 200,
        props.height or 20,
        "",
        props.target,
        props.onChange
    )
    
    applyCommonProps(checkbox, props)
    
    if props.font then
        checkbox.font = props.font
    end
    
    return initElement(checkbox, function(cb)
        -- Add options after init if provided
        if props.options then
            for i, option in ipairs(props.options) do
                if type(option) == "table" then
                    cb:addOption(option.text or option.name, option.data)
                else
                    cb:addOption(tostring(option))
                end
            end
        end
        -- Set selected state AFTER options are added
        if props.selected then
            for i, sel in pairs(props.selected) do
                cb:setSelected(i, sel)
            end
        end
    end)
end

--- Create a ComboBox (dropdown) element
---@param props table { x, y, width, height, options?, onChange?, selected? }
---@return ISComboBox
function Elements.Dropdown(props)
    local combo = ISComboBox:new(
        props.x or 0,
        props.y or 0,
        props.width or 150,
        props.height or Utils.calcButtonHeight(props.font),
        props.target,
        props.onChange
    )
    
    applyCommonProps(combo, props)
    
    if props.font then
        combo.font = props.font
    end
    
    -- Set selected
    if props.selected then
        combo:select(props.selected)
    end
    
    return initElement(combo, function(c)
        -- Add options after init
        if props.options then
            for _, option in ipairs(props.options) do
                if type(option) == "table" then
                    c:addOption(option.text or option.name, option.data)
                else
                    c:addOption(tostring(option))
                end
            end
        end
    end)
end

--- Create an Image element
---@param props table { x, y, width, height, texture, color? }
---@return ISImage
function Elements.Image(props)
    local image = ISImage:new(
        props.x or 0,
        props.y or 0,
        props.width or 32,
        props.height or 32,
        props.texture
    )
    
    applyCommonProps(image, props)
    
    if props.color then
        image:setColor(props.color.r, props.color.g, props.color.b)
    end
    
    return initElement(image)
end

--- Create a ProgressBar element
---@param props table { x, y, width, height, value?, min?, max?, text? }
---@return ISProgressBar
function Elements.ProgressBar(props)
    local bar = ISProgressBar:new(
        props.x or 0,
        props.y or 0,
        props.width or 200,
        props.height or 20,
        props.text or ""
    )
    
    applyCommonProps(bar, props)
    
    if props.min then
        bar.minimum = props.min
    end
    if props.max then
        bar.maximum = props.max
    end
    if props.value then
        bar:setValue(props.value)
    end
    
    return initElement(bar)
end

--- Create a RichText element
---@param props table { x, y, width, height, text? }
---@return ISRichTextPanel
function Elements.RichText(props)
    local panel = ISRichTextPanel:new(
        props.x or 0,
        props.y or 0,
        props.width or 300,
        props.height or 200
    )
    
    applyCommonProps(panel, props)
    
    if props.text then
        panel:setText(props.text)
    end
    
    return initElement(panel)
end

--- Create a TabPanel element
---@param props table { x, y, width, height, tabs?, onTabSelect? }
---@return ISTabPanel
function Elements.TabPanel(props)
    local tabPanel = ISTabPanel:new(
        props.x or 0,
        props.y or 0,
        props.width or 400,
        props.height or 300
    )
    
    applyCommonProps(tabPanel, props)
    
    if props.onTabSelect then
        tabPanel.onActivateView = props.onTabSelect
    end
    
    return initElement(tabPanel)
end

return Elements
