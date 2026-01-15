require "ReactiveUI/Definitions"

--[[
    ReactiveUI Pipe System
    
    Pipes are reusable value transformers for data binding, similar to Angular pipes.
    They provide a clean way to format, filter, and transform data for display.
    
    Example usage:
    
    -- Using built-in pipes
    local binding = ReactiveUI.Binding.create(state, "count")
    binding:pipe(ReactiveUI.Pipe.number({ decimals = 2 }))
           :to(myLabel, "text")
    
    -- Chaining multiple pipes
    local binding = ReactiveUI.Binding.create(state, "name")
    binding:pipe(ReactiveUI.Pipe.uppercase())
           :pipe(ReactiveUI.Pipe.truncate({ length = 20 }))
           :to(myLabel, "text")
    
    -- Using shorthand with pipe names
    local binding = ReactiveUI.Binding.create(state, "date")
    binding:pipe("date", { format = "short" })
           :to(myLabel, "text")
    
    -- Creating custom pipes
    ReactiveUI.Pipe.register("myPipe", function(value, args)
        return "[" .. tostring(value) .. "]"
    end)
    
    -- Using custom pipe
    binding:pipe("myPipe"):to(myLabel, "text")
]]

local Pipe = ReactiveUI.Pipe or {}
ReactiveUI.Pipe = Pipe

---@class ReactiveUI.PipeDefinition
---@field name string Pipe name
---@field transform function Transform function(value, args) -> any

--- Registry of all available pipes
---@type table<string, function>
Pipe._registry = {}

--- Register a new pipe
---@param name string Pipe name
---@param transform function Transform function(value, args) -> any
function Pipe.register(name, transform)
    if type(name) ~= "string" or name == "" then
        error("Pipe name must be a non-empty string")
    end
    if type(transform) ~= "function" then
        error("Pipe transform must be a function")
    end
    Pipe._registry[name] = transform
end

--- Get a pipe by name
---@param name string Pipe name
---@return function? Transform function or nil if not found
function Pipe.get(name)
    return Pipe._registry[name]
end

--- Check if a pipe exists
---@param name string Pipe name
---@return boolean
function Pipe.exists(name)
    return Pipe._registry[name] ~= nil
end

--- Create a pipe instance with arguments
---@param nameOrTransform string|function Pipe name or transform function
---@param args table? Arguments for the pipe
---@return function Configured transform function
function Pipe.create(nameOrTransform, args)
    local transform
    
    if type(nameOrTransform) == "string" then
        transform = Pipe.get(nameOrTransform)
        if not transform then
            error("Unknown pipe: " .. nameOrTransform)
        end
    elseif type(nameOrTransform) == "function" then
        transform = nameOrTransform
    else
        error("Pipe must be a string name or function")
    end
    
    return function(value)
        return transform(value, args or {})
    end
end

--- Chain multiple pipes together
---@param ... function|table Pipe functions or {name, args} tables
---@return function Combined transform function
function Pipe.chain(...)
    local pipes = { ... }
    local transforms = {}
    
    for _, pipe in ipairs(pipes) do
        if type(pipe) == "function" then
            table.insert(transforms, pipe)
        elseif type(pipe) == "table" then
            -- {name, args} or {transform, args}
            local created = Pipe.create(pipe[1], pipe[2])
            table.insert(transforms, created)
        end
    end
    
    return function(value)
        local result = value
        for _, transform in ipairs(transforms) do
            result = transform(result)
        end
        return result
    end
end

--============================================================================
-- BUILT-IN PIPES
--============================================================================

--[[
    Uppercase Pipe
    
    Converts string to uppercase.
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.uppercase())
        binding:pipe("uppercase")
    
    Example:
        "hello world" -> "HELLO WORLD"
]]
Pipe.register("uppercase", function(value, args)
    if value == nil then return "" end
    return string.upper(tostring(value))
end)

function Pipe.uppercase()
    return Pipe.create("uppercase")
end

--[[
    Lowercase Pipe
    
    Converts string to lowercase.
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.lowercase())
        binding:pipe("lowercase")
    
    Example:
        "HELLO WORLD" -> "hello world"
]]
Pipe.register("lowercase", function(value, args)
    if value == nil then return "" end
    return string.lower(tostring(value))
end)

function Pipe.lowercase()
    return Pipe.create("lowercase")
end

--[[
    Capitalize Pipe
    
    Capitalizes first letter of string or each word.
    
    Args:
        words (boolean): If true, capitalize each word. Default: false
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.capitalize())
        binding:pipe(ReactiveUI.Pipe.capitalize({ words = true }))
        binding:pipe("capitalize", { words = true })
    
    Examples:
        "hello world" -> "Hello world"
        "hello world" (words=true) -> "Hello World"
]]
Pipe.register("capitalize", function(value, args)
    if value == nil then return "" end
    local str = tostring(value)
    
    if args.words then
        -- Capitalize each word
        return str:gsub("(%a)([%w_']*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
    else
        -- Capitalize first letter only
        return str:sub(1, 1):upper() .. str:sub(2)
    end
end)

function Pipe.capitalize(args)
    return Pipe.create("capitalize", args)
end

--[[
    Truncate Pipe
    
    Truncates string to specified length with optional suffix.
    
    Args:
        length (number): Maximum length. Default: 50
        suffix (string): Suffix to append when truncated. Default: "..."
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.truncate({ length = 20 }))
        binding:pipe("truncate", { length = 20, suffix = "…" })
    
    Example:
        "This is a very long text" (length=10) -> "This is a..."
]]
Pipe.register("truncate", function(value, args)
    if value == nil then return "" end
    local str = tostring(value)
    local length = args.length or 50
    local suffix = args.suffix or "..."
    
    if #str <= length then
        return str
    end
    
    return str:sub(1, length - #suffix) .. suffix
end)

function Pipe.truncate(args)
    return Pipe.create("truncate", args)
end

--[[
    Number Pipe
    
    Formats numbers with specified decimal places and optional separators.
    
    Args:
        decimals (number): Decimal places. Default: 0
        separator (string): Thousands separator. Default: ","
        decimalPoint (string): Decimal point character. Default: "."
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.number({ decimals = 2 }))
        binding:pipe("number", { decimals = 2, separator = " " })
    
    Examples:
        1234567 -> "1,234,567"
        1234.5678 (decimals=2) -> "1,234.57"
]]
Pipe.register("number", function(value, args)
    if value == nil then return "0" end
    
    local num = tonumber(value) or 0
    local decimals = args.decimals or 0
    local separator = args.separator or ","
    local decimalPoint = args.decimalPoint or "."
    
    -- Round to specified decimals
    local multiplier = 10 ^ decimals
    num = math.floor(num * multiplier + 0.5) / multiplier
    
    -- Split integer and decimal parts
    local intPart = math.floor(math.abs(num))
    local decPart = math.abs(num) - intPart
    
    -- Format integer part with separator
    local intStr = tostring(intPart)
    local formatted = ""
    local count = 0
    
    for i = #intStr, 1, -1 do
        if count > 0 and count % 3 == 0 then
            formatted = separator .. formatted
        end
        formatted = intStr:sub(i, i) .. formatted
        count = count + 1
    end
    
    -- Add decimal part
    if decimals > 0 then
        local decStr = string.format("%." .. decimals .. "f", decPart):sub(3)
        formatted = formatted .. decimalPoint .. decStr
    end
    
    -- Add sign
    if num < 0 then
        formatted = "-" .. formatted
    end
    
    return formatted
end)

function Pipe.number(args)
    return Pipe.create("number", args)
end

--[[
    Percent Pipe
    
    Formats number as percentage.
    
    Args:
        decimals (number): Decimal places. Default: 0
        multiply (boolean): Multiply by 100 first. Default: true
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.percent())
        binding:pipe("percent", { decimals = 1 })
    
    Examples:
        0.75 -> "75%"
        0.756 (decimals=1) -> "75.6%"
]]
Pipe.register("percent", function(value, args)
    if value == nil then return "0%" end
    
    local num = tonumber(value) or 0
    local decimals = args.decimals or 0
    local multiply = args.multiply ~= false -- default true
    
    if multiply then
        num = num * 100
    end
    
    local format = "%." .. decimals .. "f%%"
    return string.format(format, num)
end)

function Pipe.percent(args)
    return Pipe.create("percent", args)
end

--[[
    Currency Pipe
    
    Formats number as currency.
    
    Args:
        symbol (string): Currency symbol. Default: "$"
        decimals (number): Decimal places. Default: 2
        symbolAfter (boolean): Put symbol after number. Default: false
        separator (string): Thousands separator. Default: ","
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.currency())
        binding:pipe("currency", { symbol = "€", symbolAfter = true })
    
    Examples:
        1234.5 -> "$1,234.50"
        1234.5 (symbol="€", symbolAfter=true) -> "1,234.50€"
]]
Pipe.register("currency", function(value, args)
    local symbol = args.symbol or "$"
    local decimals = args.decimals or 2
    local symbolAfter = args.symbolAfter or false
    local separator = args.separator or ","
    
    -- Use number pipe for formatting
    local formatted = Pipe._registry["number"](value, {
        decimals = decimals,
        separator = separator
    })
    
    if symbolAfter then
        return formatted .. symbol
    else
        return symbol .. formatted
    end
end)

function Pipe.currency(args)
    return Pipe.create("currency", args)
end

--[[
    Date Pipe
    
    Formats timestamp or date table.
    
    Args:
        format (string): Format string or preset ("short", "medium", "long", "time")
            Default: "medium"
        Custom format codes:
            %Y = 4-digit year
            %y = 2-digit year
            %m = month (01-12)
            %d = day (01-31)
            %H = hour 24h (00-23)
            %I = hour 12h (01-12)
            %M = minute (00-59)
            %S = second (00-59)
            %p = AM/PM
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.date())
        binding:pipe("date", { format = "short" })
        binding:pipe("date", { format = "%Y-%m-%d" })
    
    Presets:
        "short"  -> "01/15/26"
        "medium" -> "Jan 15, 2026"
        "long"   -> "January 15, 2026"
        "time"   -> "14:30"
]]
local MONTH_NAMES = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
}

local MONTH_SHORT = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
}

Pipe.register("date", function(value, args)
    if value == nil then return "" end
    
    local format = args.format or "medium"
    local dateTable
    
    -- Handle different input types
    if type(value) == "number" then
        -- Assume timestamp in seconds
        dateTable = os.date("*t", value)
    elseif type(value) == "table" then
        dateTable = value
    else
        return tostring(value)
    end
    
    -- Preset formats
    if format == "short" then
        return string.format("%02d/%02d/%02d", 
            dateTable.month, dateTable.day, dateTable.year % 100)
    elseif format == "medium" then
        return string.format("%s %d, %d",
            MONTH_SHORT[dateTable.month], dateTable.day, dateTable.year)
    elseif format == "long" then
        return string.format("%s %d, %d",
            MONTH_NAMES[dateTable.month], dateTable.day, dateTable.year)
    elseif format == "time" then
        return string.format("%02d:%02d",
            dateTable.hour or 0, dateTable.min or 0)
    elseif format == "datetime" then
        return string.format("%s %d, %d %02d:%02d",
            MONTH_SHORT[dateTable.month], dateTable.day, dateTable.year,
            dateTable.hour or 0, dateTable.min or 0)
    else
        -- Custom format string
        local result = format
        result = result:gsub("%%Y", string.format("%04d", dateTable.year))
        result = result:gsub("%%y", string.format("%02d", dateTable.year % 100))
        result = result:gsub("%%m", string.format("%02d", dateTable.month))
        result = result:gsub("%%d", string.format("%02d", dateTable.day))
        result = result:gsub("%%H", string.format("%02d", dateTable.hour or 0))
        result = result:gsub("%%M", string.format("%02d", dateTable.min or 0))
        result = result:gsub("%%S", string.format("%02d", dateTable.sec or 0))
        
        -- 12-hour format
        local hour12 = (dateTable.hour or 0) % 12
        if hour12 == 0 then hour12 = 12 end
        result = result:gsub("%%I", string.format("%02d", hour12))
        result = result:gsub("%%p", (dateTable.hour or 0) >= 12 and "PM" or "AM")
        
        return result
    end
end)

function Pipe.date(args)
    return Pipe.create("date", args)
end

--[[
    Default Pipe
    
    Returns default value if input is nil or empty.
    
    Args:
        value (any): Default value to use. Default: ""
        emptyString (boolean): Treat empty string as nil. Default: true
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.default({ value = "N/A" }))
        binding:pipe("default", { value = "Unknown" })
    
    Example:
        nil -> "N/A"
        "" -> "N/A"
        "hello" -> "hello"
]]
Pipe.register("default", function(value, args)
    local defaultValue = args.value or ""
    local checkEmpty = args.emptyString ~= false
    
    if value == nil then
        return defaultValue
    end
    
    if checkEmpty and value == "" then
        return defaultValue
    end
    
    return value
end)

function Pipe.default(args)
    return Pipe.create("default", args)
end

--[[
    Prefix Pipe
    
    Adds a prefix to the value.
    
    Args:
        text (string): Prefix text. Required.
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.prefix({ text = "$ " }))
        binding:pipe("prefix", { text = "Name: " })
    
    Example:
        "100" (text="$") -> "$100"
]]
Pipe.register("prefix", function(value, args)
    local prefix = args.text or ""
    if value == nil then return prefix end
    return prefix .. tostring(value)
end)

function Pipe.prefix(args)
    return Pipe.create("prefix", args)
end

--[[
    Suffix Pipe
    
    Adds a suffix to the value.
    
    Args:
        text (string): Suffix text. Required.
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.suffix({ text = " items" }))
        binding:pipe("suffix", { text = "%" })
    
    Example:
        "100" (text="%") -> "100%"
]]
Pipe.register("suffix", function(value, args)
    local suffix = args.text or ""
    if value == nil then return suffix end
    return tostring(value) .. suffix
end)

function Pipe.suffix(args)
    return Pipe.create("suffix", args)
end

--[[
    Wrap Pipe
    
    Wraps value in prefix and suffix.
    
    Args:
        prefix (string): Prefix text. Default: ""
        suffix (string): Suffix text. Default: ""
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.wrap({ prefix = "[", suffix = "]" }))
        binding:pipe("wrap", { prefix = "(", suffix = ")" })
    
    Example:
        "hello" (prefix="[", suffix="]") -> "[hello]"
]]
Pipe.register("wrap", function(value, args)
    local prefix = args.prefix or ""
    local suffix = args.suffix or ""
    if value == nil then return prefix .. suffix end
    return prefix .. tostring(value) .. suffix
end)

function Pipe.wrap(args)
    return Pipe.create("wrap", args)
end

--[[
    Replace Pipe
    
    Replaces occurrences in string.
    
    Args:
        pattern (string): Pattern to find. Required.
        replacement (string): Replacement string. Default: ""
        plain (boolean): Use plain matching (no patterns). Default: true
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.replace({ pattern = "_", replacement = " " }))
        binding:pipe("replace", { pattern = "foo", replacement = "bar" })
    
    Example:
        "hello_world" (pattern="_", replacement=" ") -> "hello world"
]]
Pipe.register("replace", function(value, args)
    if value == nil then return "" end
    local str = tostring(value)
    local pattern = args.pattern or ""
    local replacement = args.replacement or ""
    local plain = args.plain ~= false
    
    if plain then
        -- Escape pattern special characters for plain matching
        pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    end
    
    return str:gsub(pattern, replacement)
end)

function Pipe.replace(args)
    return Pipe.create("replace", args)
end

--[[
    Trim Pipe
    
    Removes whitespace from string ends.
    
    Args:
        side (string): "left", "right", or "both". Default: "both"
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.trim())
        binding:pipe("trim", { side = "left" })
    
    Example:
        "  hello  " -> "hello"
]]
Pipe.register("trim", function(value, args)
    if value == nil then return "" end
    local str = tostring(value)
    local side = args.side or "both"
    
    if side == "left" or side == "both" then
        str = str:gsub("^%s+", "")
    end
    if side == "right" or side == "both" then
        str = str:gsub("%s+$", "")
    end
    
    return str
end)

function Pipe.trim(args)
    return Pipe.create("trim", args)
end

--[[
    Pad Pipe
    
    Pads string to specified length.
    
    Args:
        length (number): Target length. Required.
        char (string): Padding character. Default: " "
        side (string): "left", "right", or "both". Default: "left"
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.pad({ length = 5, char = "0" }))
        binding:pipe("pad", { length = 10, side = "right" })
    
    Example:
        "42" (length=5, char="0") -> "00042"
]]
Pipe.register("pad", function(value, args)
    if value == nil then return "" end
    local str = tostring(value)
    local length = args.length or #str
    local char = args.char or " "
    local side = args.side or "left"
    
    local padding = length - #str
    if padding <= 0 then return str end
    
    local padStr = string.rep(char, padding)
    
    if side == "left" then
        return padStr .. str
    elseif side == "right" then
        return str .. padStr
    else -- both
        local leftPad = math.floor(padding / 2)
        local rightPad = padding - leftPad
        return string.rep(char, leftPad) .. str .. string.rep(char, rightPad)
    end
end)

function Pipe.pad(args)
    return Pipe.create("pad", args)
end

--[[
    Slice Pipe
    
    Extracts a portion of a string.
    
    Args:
        start (number): Start position (1-based). Default: 1
        finish (number): End position (1-based, inclusive). Default: end of string
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.slice({ start = 1, finish = 5 }))
        binding:pipe("slice", { start = 3 })
    
    Example:
        "hello world" (start=1, finish=5) -> "hello"
]]
Pipe.register("slice", function(value, args)
    if value == nil then return "" end
    local str = tostring(value)
    local startPos = args.start or 1
    local finishPos = args.finish or #str
    
    return str:sub(startPos, finishPos)
end)

function Pipe.slice(args)
    return Pipe.create("slice", args)
end

--[[
    JSON Pipe
    
    Converts table to JSON string representation.
    
    Args:
        pretty (boolean): Pretty print with indentation. Default: false
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.json())
        binding:pipe("json", { pretty = true })
    
    Example:
        {a=1, b=2} -> '{"a":1,"b":2}'
]]
local function tableToJson(tbl, indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    
    if type(tbl) ~= "table" then
        if type(tbl) == "string" then
            return '"' .. tbl:gsub('"', '\\"') .. '"'
        elseif type(tbl) == "boolean" then
            return tbl and "true" or "false"
        elseif tbl == nil then
            return "null"
        else
            return tostring(tbl)
        end
    end
    
    -- Check if array
    local isArray = #tbl > 0
    local parts = {}
    
    if isArray then
        for _, v in ipairs(tbl) do
            table.insert(parts, tableToJson(v, nextIndent))
        end
        if indent ~= "" then
            return "[\n" .. nextIndent .. table.concat(parts, ",\n" .. nextIndent) .. "\n" .. indent .. "]"
        else
            return "[" .. table.concat(parts, ",") .. "]"
        end
    else
        for k, v in pairs(tbl) do
            local key = '"' .. tostring(k) .. '"'
            local value = tableToJson(v, nextIndent)
            table.insert(parts, key .. ":" .. value)
        end
        if indent ~= "" then
            return "{\n" .. nextIndent .. table.concat(parts, ",\n" .. nextIndent) .. "\n" .. indent .. "}"
        else
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
end

Pipe.register("json", function(value, args)
    if value == nil then return "null" end
    local pretty = args.pretty or false
    return tableToJson(value, pretty and "" or nil)
end)

function Pipe.json(args)
    return Pipe.create("json", args)
end

--[[
    Plural Pipe
    
    Returns singular or plural form based on count.
    
    Args:
        singular (string): Singular form. Required.
        plural (string): Plural form. Default: singular + "s"
        showCount (boolean): Include count in output. Default: true
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.plural({ singular = "item", plural = "items" }))
        binding:pipe("plural", { singular = "person", plural = "people" })
    
    Example:
        1 (singular="item") -> "1 item"
        5 (singular="item") -> "5 items"
]]
Pipe.register("plural", function(value, args)
    local count = tonumber(value) or 0
    local singular = args.singular or "item"
    local plural = args.plural or (singular .. "s")
    local showCount = args.showCount ~= false
    
    local word = math.abs(count) == 1 and singular or plural
    
    if showCount then
        return tostring(count) .. " " .. word
    else
        return word
    end
end)

function Pipe.plural(args)
    return Pipe.create("plural", args)
end

--[[
    Boolean Pipe
    
    Converts value to boolean display string.
    
    Args:
        trueText (string): Text for true. Default: "Yes"
        falseText (string): Text for false. Default: "No"
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.boolean({ trueText = "Enabled", falseText = "Disabled" }))
        binding:pipe("boolean")
    
    Example:
        true -> "Yes"
        false -> "No"
]]
Pipe.register("boolean", function(value, args)
    local trueText = args.trueText or "Yes"
    local falseText = args.falseText or "No"
    
    return value and trueText or falseText
end)

function Pipe.boolean(args)
    return Pipe.create("boolean", args)
end

--[[
    Conditional Pipe
    
    Returns different values based on condition.
    
    Args:
        condition (function): Condition function(value) -> boolean
        trueValue (any): Value when condition is true
        falseValue (any): Value when condition is false
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.conditional({
            condition = function(v) return v > 0 end,
            trueValue = "Positive",
            falseValue = "Non-positive"
        }))
    
    Example:
        5 (condition: v > 0) -> "Positive"
]]
Pipe.register("conditional", function(value, args)
    local condition = args.condition or function(v) return v end
    local trueValue = args.trueValue
    local falseValue = args.falseValue
    
    if condition(value) then
        return trueValue ~= nil and trueValue or value
    else
        return falseValue ~= nil and falseValue or value
    end
end)

function Pipe.conditional(args)
    return Pipe.create("conditional", args)
end

--[[
    Map Pipe
    
    Maps value through a lookup table.
    
    Args:
        map (table): Key-value mapping table. Required.
        default (any): Default value if key not found. Default: original value
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.map({
            map = { ADMIN = "Administrator", USER = "Regular User" },
            default = "Unknown"
        }))
    
    Example:
        "ADMIN" -> "Administrator"
        "GUEST" -> "Unknown"
]]
Pipe.register("map", function(value, args)
    local map = args.map or {}
    local default = args.default
    
    local result = map[value]
    if result ~= nil then
        return result
    end
    
    return default ~= nil and default or value
end)

function Pipe.map(args)
    return Pipe.create("map", args)
end

--[[
    Safe Pipe
    
    Safely converts value to string, handling nil and errors.
    
    Args:
        nilValue (string): Value to use for nil. Default: ""
    
    Usage:
        binding:pipe(ReactiveUI.Pipe.safe())
        binding:pipe("safe", { nilValue = "N/A" })
]]
Pipe.register("safe", function(value, args)
    local nilValue = args.nilValue or ""
    
    if value == nil then
        return nilValue
    end
    
    local success, result = pcall(tostring, value)
    if success then
        return result
    else
        return nilValue
    end
end)

function Pipe.safe(args)
    return Pipe.create("safe", args)
end

return Pipe
