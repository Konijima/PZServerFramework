KoniLib = KoniLib or {}

---@class KoniLib.Log
---Centralized logging utility for KoniLib and dependent mods
KoniLib.Log = KoniLib.Log or {}

local Log = KoniLib.Log

-- Verbose flags per module (default enabled for debugging)
Log.Verbose = {
    MP = true,
    Socket = true,
    Events = true,
}

---Log a message for a specific module
---@param module string The module name (e.g., "MP", "Socket", "Events")
---@param str string The message to log
function Log.Print(module, str)
    if Log.Verbose[module] then
        print("[KoniLib." .. tostring(module) .. "] " .. tostring(str))
    end
end

---Set verbose flag for a module
---@param module string The module name
---@param enabled boolean Whether logging is enabled
function Log.SetVerbose(module, enabled)
    Log.Verbose[module] = enabled
end

---Enable verbose logging for all modules
function Log.EnableAll()
    for k, _ in pairs(Log.Verbose) do
        Log.Verbose[k] = true
    end
end

---Disable verbose logging for all modules
function Log.DisableAll()
    for k, _ in pairs(Log.Verbose) do
        Log.Verbose[k] = false
    end
end

return KoniLib.Log
