if not KoniLib then KoniLib = {} end

---@class KoniLib.Event
---@field name string The name of the event
KoniLib.Event = {}
KoniLib.Event.__index = KoniLib.Event

---Creates a new custom event or wraps an existing one.
---Automatically registers the event with LuaEventManager if it doesn't exist.
---@param name string The unique name of the event.
---@return KoniLib.Event
function KoniLib.Event.new(name)
    local self = setmetatable({}, KoniLib.Event)
    self.name = name

    if not Events[name] then
        LuaEventManager.AddEvent(name)
        print("[KoniLib.Event] Registered new event: " .. tostring(name))
    end

    return self
end

---Adds a callback function to the event.
---@param func function The function to call when the event is triggered.
function KoniLib.Event:Add(func)
    if Events[self.name] then
        Events[self.name].Add(func)
    else
        print("[KoniLib.Event] Error: Event '" .. tostring(self.name) .. "' does not exist in global Events table.")
    end
end

---Removes a callback function from the event.
---@param func function The function to remove.
function KoniLib.Event:Remove(func)
    if Events[self.name] then
        Events[self.name].Remove(func)
    end
end

---Triggers the event with the provided arguments.
---@vararg any Arguments to pass to the event listeners.
function KoniLib.Event:Trigger(...)
    triggerEvent(self.name, ...)
end

return KoniLib.Event
