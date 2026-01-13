require "ReactiveUI/Definitions"
require "ReactiveUI/Utils"

--[[
    ReactiveUI Layout System
    
    Provides helper functions for common layout patterns like
    rows, columns, grids, and automatic positioning.
    
    Example usage:
    
    -- Vertical stack of buttons
    local buttons = ReactiveUI.Layout.vstack({
        x = 10,
        y = 10,
        spacing = 5,
        children = {
            ReactiveUI.Elements.Button({ text = "Button 1", width = 100, height = 25 }),
            ReactiveUI.Elements.Button({ text = "Button 2", width = 100, height = 25 }),
            ReactiveUI.Elements.Button({ text = "Button 3", width = 100, height = 25 }),
        }
    })
    
    -- Horizontal row
    local row = ReactiveUI.Layout.hstack({
        x = 10,
        y = 10,
        spacing = 10,
        children = { ... }
    })
]]

ReactiveUI.Layout = ReactiveUI.Layout or {}
local Layout = ReactiveUI.Layout
local Utils = ReactiveUI.Utils

---@class LayoutOptions
---@field x number Starting X position
---@field y number Starting Y position
---@field spacing number? Space between children (default 0)
---@field padding number|table? Padding around content (number or {top, right, bottom, left})
---@field children table Array of UI elements

--- Parse padding into {top, right, bottom, left}
---@param padding number|table|nil
---@return table
local function parsePadding(padding)
    if not padding then
        return { top = 0, right = 0, bottom = 0, left = 0 }
    end
    
    if type(padding) == "number" then
        return { top = padding, right = padding, bottom = padding, left = padding }
    end
    
    if type(padding) == "table" then
        if #padding == 1 then
            return { top = padding[1], right = padding[1], bottom = padding[1], left = padding[1] }
        elseif #padding == 2 then
            return { top = padding[1], right = padding[2], bottom = padding[1], left = padding[2] }
        elseif #padding == 4 then
            return { top = padding[1], right = padding[2], bottom = padding[3], left = padding[4] }
        else
            return {
                top = padding.top or 0,
                right = padding.right or 0,
                bottom = padding.bottom or 0,
                left = padding.left or 0
            }
        end
    end
    
    return { top = 0, right = 0, bottom = 0, left = 0 }
end

--- Vertical stack layout - positions children vertically
---@param options LayoutOptions
---@return table results { elements, totalHeight, maxWidth }
function Layout.vstack(options)
    local x = options.x or 0
    local y = options.y or 0
    local spacing = options.spacing or 0
    local padding = parsePadding(options.padding)
    local children = options.children or {}
    
    local currentY = y + padding.top
    local maxWidth = 0
    local elements = {}
    
    for i, child in ipairs(children) do
        if child then
            child:setX(x + padding.left)
            child:setY(currentY)
            
            local childWidth = child.width or 0
            local childHeight = child.height or 0
            
            maxWidth = math.max(maxWidth, childWidth)
            currentY = currentY + childHeight
            
            if i < #children then
                currentY = currentY + spacing
            end
            
            table.insert(elements, child)
        end
    end
    
    local totalHeight = currentY - y + padding.bottom
    
    return {
        elements = elements,
        totalHeight = totalHeight,
        maxWidth = maxWidth + padding.left + padding.right,
    }
end

--- Horizontal stack layout - positions children horizontally
---@param options LayoutOptions
---@return table results { elements, totalWidth, maxHeight }
function Layout.hstack(options)
    local x = options.x or 0
    local y = options.y or 0
    local spacing = options.spacing or 0
    local padding = parsePadding(options.padding)
    local children = options.children or {}
    
    local currentX = x + padding.left
    local maxHeight = 0
    local elements = {}
    
    for i, child in ipairs(children) do
        if child then
            child:setX(currentX)
            child:setY(y + padding.top)
            
            local childWidth = child.width or 0
            local childHeight = child.height or 0
            
            maxHeight = math.max(maxHeight, childHeight)
            currentX = currentX + childWidth
            
            if i < #children then
                currentX = currentX + spacing
            end
            
            table.insert(elements, child)
        end
    end
    
    local totalWidth = currentX - x + padding.right
    
    return {
        elements = elements,
        totalWidth = totalWidth,
        maxHeight = maxHeight + padding.top + padding.bottom,
    }
end

--- Grid layout - positions children in a grid
---@param options table { x, y, columns, spacing, cellWidth?, cellHeight?, children }
---@return table results { elements, totalWidth, totalHeight, rows, cols }
function Layout.grid(options)
    local x = options.x or 0
    local y = options.y or 0
    local columns = options.columns or 3
    local spacing = options.spacing or 0
    local cellWidth = options.cellWidth
    local cellHeight = options.cellHeight
    local padding = parsePadding(options.padding)
    local children = options.children or {}
    
    local elements = {}
    local maxWidth = 0
    local maxHeight = 0
    local rowCount = 0
    
    for i, child in ipairs(children) do
        if child then
            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            
            local childW = cellWidth or child.width or 0
            local childH = cellHeight or child.height or 0
            
            local posX = x + padding.left + col * (childW + spacing)
            local posY = y + padding.top + row * (childH + spacing)
            
            child:setX(posX)
            child:setY(posY)
            
            if cellWidth then
                child:setWidth(cellWidth)
            end
            if cellHeight then
                child:setHeight(cellHeight)
            end
            
            maxWidth = math.max(maxWidth, posX + childW - x)
            maxHeight = math.max(maxHeight, posY + childH - y)
            rowCount = math.max(rowCount, row + 1)
            
            table.insert(elements, child)
        end
    end
    
    return {
        elements = elements,
        totalWidth = maxWidth + padding.right,
        totalHeight = maxHeight + padding.bottom,
        rows = rowCount,
        cols = columns,
    }
end

--- Center an element within a container
---@param element ISUIElement Element to center
---@param containerWidth number Container width
---@param containerHeight number Container height
---@param offsetX number? Optional X offset
---@param offsetY number? Optional Y offset
function Layout.center(element, containerWidth, containerHeight, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    
    local x = (containerWidth - element.width) / 2 + offsetX
    local y = (containerHeight - element.height) / 2 + offsetY
    
    element:setX(x)
    element:setY(y)
end

--- Center horizontally within a container
---@param element ISUIElement
---@param containerWidth number
---@param offsetX number?
function Layout.centerX(element, containerWidth, offsetX)
    offsetX = offsetX or 0
    local x = (containerWidth - element.width) / 2 + offsetX
    element:setX(x)
end

--- Center vertically within a container
---@param element ISUIElement
---@param containerHeight number
---@param offsetY number?
function Layout.centerY(element, containerHeight, offsetY)
    offsetY = offsetY or 0
    local y = (containerHeight - element.height) / 2 + offsetY
    element:setY(y)
end

--- Position element at bottom of container
---@param element ISUIElement
---@param containerHeight number
---@param margin number? Margin from bottom
function Layout.bottom(element, containerHeight, margin)
    margin = margin or 0
    element:setY(containerHeight - element.height - margin)
end

--- Position element at right of container
---@param element ISUIElement
---@param containerWidth number
---@param margin number? Margin from right
function Layout.right(element, containerWidth, margin)
    margin = margin or 0
    element:setX(containerWidth - element.width - margin)
end

--- Fill element to container size
---@param element ISUIElement
---@param containerWidth number
---@param containerHeight number
---@param padding number|table? Padding
function Layout.fill(element, containerWidth, containerHeight, padding)
    padding = parsePadding(padding)
    
    element:setX(padding.left)
    element:setY(padding.top)
    element:setWidth(containerWidth - padding.left - padding.right)
    element:setHeight(containerHeight - padding.top - padding.bottom)
end

--- Create a flex-like row with items that can grow
---@param options table { x, y, width, spacing?, children, grow? }
---@return table results
function Layout.flexRow(options)
    local x = options.x or 0
    local y = options.y or 0
    local totalWidth = options.width or 400
    local spacing = options.spacing or 0
    local children = options.children or {}
    local growIndices = options.grow or {} -- indices of children that should grow
    
    -- Calculate fixed width and count grow items
    local fixedWidth = 0
    local growCount = 0
    local growMap = {}
    
    for i, idx in ipairs(growIndices) do
        growMap[idx] = true
    end
    
    for i, child in ipairs(children) do
        if not growMap[i] then
            fixedWidth = fixedWidth + (child.width or 0)
        else
            growCount = growCount + 1
        end
    end
    
    -- Calculate space for growing items
    local spacingTotal = spacing * (#children - 1)
    local remainingWidth = totalWidth - fixedWidth - spacingTotal
    local growWidth = growCount > 0 and (remainingWidth / growCount) or 0
    
    -- Position children
    local currentX = x
    local maxHeight = 0
    local elements = {}
    
    for i, child in ipairs(children) do
        if child then
            child:setX(currentX)
            child:setY(y)
            
            if growMap[i] then
                child:setWidth(growWidth)
            end
            
            local childWidth = child.width or 0
            local childHeight = child.height or 0
            
            maxHeight = math.max(maxHeight, childHeight)
            currentX = currentX + childWidth + spacing
            
            table.insert(elements, child)
        end
    end
    
    return {
        elements = elements,
        totalWidth = totalWidth,
        maxHeight = maxHeight,
    }
end

--- Calculate positions for elements in a flow layout (wrapping)
---@param options table { x, y, width, spacing?, children }
---@return table results
function Layout.flow(options)
    local x = options.x or 0
    local y = options.y or 0
    local maxWidth = options.width or 400
    local spacing = options.spacing or 0
    local children = options.children or {}
    
    local currentX = x
    local currentY = y
    local rowHeight = 0
    local elements = {}
    local totalHeight = 0
    
    for _, child in ipairs(children) do
        if child then
            local childWidth = child.width or 0
            local childHeight = child.height or 0
            
            -- Check if we need to wrap
            if currentX + childWidth > x + maxWidth and currentX > x then
                currentX = x
                currentY = currentY + rowHeight + spacing
                rowHeight = 0
            end
            
            child:setX(currentX)
            child:setY(currentY)
            
            rowHeight = math.max(rowHeight, childHeight)
            currentX = currentX + childWidth + spacing
            totalHeight = math.max(totalHeight, currentY + childHeight - y)
            
            table.insert(elements, child)
        end
    end
    
    return {
        elements = elements,
        totalHeight = totalHeight,
        totalWidth = maxWidth,
    }
end

return Layout
