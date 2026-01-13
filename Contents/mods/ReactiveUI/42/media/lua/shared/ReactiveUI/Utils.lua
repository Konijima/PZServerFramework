require "ReactiveUI/Definitions"

--[[
    ReactiveUI Utility Functions
    
    Common utility functions used throughout the ReactiveUI framework.
]]

local Utils = ReactiveUI.Utils

--- Deep copy a table
---@param orig table Original table
---@param copies table? Internal tracking table for circular references
---@return table
function Utils.deepCopy(orig, copies)
    copies = copies or {}
    local origType = type(orig)
    local copy
    
    if origType == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for origKey, origValue in next, orig, nil do
                copy[Utils.deepCopy(origKey, copies)] = Utils.deepCopy(origValue, copies)
            end
            setmetatable(copy, Utils.deepCopy(getmetatable(orig), copies))
        end
    else
        copy = orig
    end
    
    return copy
end

--- Shallow merge tables (later tables override earlier)
---@param ... table Tables to merge
---@return table
function Utils.merge(...)
    local result = {}
    local tables = { ... }
    
    for _, tbl in ipairs(tables) do
        if type(tbl) == "table" then
            for key, value in pairs(tbl) do
                result[key] = value
            end
        end
    end
    
    return result
end

--- Create a color table from RGBA values
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number? Alpha (0-1), defaults to 1
---@return table
function Utils.rgba(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

--- Lerp between two values
---@param a number Start value
---@param b number End value
---@param t number Progress (0-1)
---@return number
function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

--- Lerp between two colors
---@param colorA table Start color
---@param colorB table End color
---@param t number Progress (0-1)
---@return table
function Utils.lerpColor(colorA, colorB, t)
    return {
        r = Utils.lerp(colorA.r, colorB.r, t),
        g = Utils.lerp(colorA.g, colorB.g, t),
        b = Utils.lerp(colorA.b, colorB.b, t),
        a = Utils.lerp(colorA.a or 1, colorB.a or 1, t),
    }
end

--- Clamp a value between min and max
---@param value number Value to clamp
---@param min number Minimum value
---@param max number Maximum value
---@return number
function Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

--- Check if a value is nil or empty string
---@param value any
---@return boolean
function Utils.isEmpty(value)
    return value == nil or value == ""
end

--- Generate a unique ID
---@param prefix string? Optional prefix
---@return string
function Utils.generateId(prefix)
    prefix = prefix or "rui"
    return prefix .. "_" .. tostring(getRandomUUID())
end

--- Get font height for a given font
---@param font any UIFont enum value
---@return number
function Utils.getFontHeight(font)
    return getTextManager():getFontHeight(font or UIFont.Small)
end

--- Measure text width
---@param text string Text to measure
---@param font any UIFont enum value
---@return number
function Utils.measureTextWidth(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, text or "")
end

--- Calculate button height based on font
---@param font any UIFont enum value
---@param padding number? Vertical padding
---@return number
function Utils.calcButtonHeight(font, padding)
    padding = padding or 6
    return Utils.getFontHeight(font or UIFont.Small) + padding
end

--- Safe call - wraps a function call in pcall and logs errors
---@param fn function Function to call
---@param ... any Arguments to pass
---@return boolean, any Success and result
function Utils.safeCall(fn, ...)
    if not fn then return false, nil end
    
    local success, result = pcall(fn, ...)
    
    if not success then
        KoniLib.Log.Print("ReactiveUI", "Error in safeCall: " .. tostring(result))
    end
    
    return success, result
end

--- Debounce a function (delay execution until calls stop)
---@param fn function Function to debounce
---@param delay number Delay in milliseconds
---@return function
function Utils.debounce(fn, delay)
    local lastCall = 0
    local scheduled = false
    
    return function(...)
        local args = { ... }
        lastCall = getTimestampMs()
        
        if not scheduled then
            scheduled = true
            
            Events.OnTick.Add(function()
                if getTimestampMs() - lastCall >= delay then
                    scheduled = false
                    Events.OnTick.Remove(Utils.debounce) -- Remove this specific tick handler
                    fn(unpack(args))
                end
            end)
        end
    end
end

--- Throttle a function (limit execution rate)
---@param fn function Function to throttle
---@param interval number Minimum interval in milliseconds
---@return function
function Utils.throttle(fn, interval)
    local lastExecution = 0
    
    return function(...)
        local now = getTimestampMs()
        
        if now - lastExecution >= interval then
            lastExecution = now
            fn(...)
        end
    end
end

return Utils
