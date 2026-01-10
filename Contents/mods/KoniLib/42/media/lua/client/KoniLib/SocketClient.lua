if not KoniLib then KoniLib = {} end

local Socket = require("KoniLib/Socket")
local MP = KoniLib.MP

---@class SocketClient
---@field namespace string The namespace this socket belongs to
---@field connected boolean Whether the socket is connected
---@field auth table|nil Authentication data
---@field handlers table Event handlers
---@field pendingAcks table Pending acknowledgment callbacks
---@field rooms table Rooms this client has joined
KoniLib.SocketClient = {}
KoniLib.SocketClient.__index = KoniLib.SocketClient

local SocketClient = KoniLib.SocketClient

---Create a new client socket
---@param namespace string
---@param options? table
---@return SocketClient
function SocketClient.new(namespace, options)
    local self = setmetatable({}, SocketClient)
    
    self.namespace = namespace
    self.connected = false
    self.auth = options and options.auth or nil
    self.handlers = {}
    self.onceHandlers = {}
    self.pendingAcks = {}
    self.rooms = {}
    self.autoConnect = options and options.autoConnect ~= false or true
    
    -- Auto-connect if auth provided or autoConnect is true
    if self.autoConnect then
        -- Delay connect to next tick to allow event registration
        Events.OnTick.Add(function()
            if not self.connected then
                self:connect(self.auth)
            end
            Events.OnTick.Remove(self._autoConnectFunc)
        end)
    end
    
    Socket.Log("SocketClient created for: " .. namespace)
    return self
end

---Connect to the server namespace with optional auth data
---@param auth? table Authentication data to send
function SocketClient:connect(auth)
    if self.connected then
        Socket.Log("Already connected to: " .. self.namespace)
        return
    end
    
    self.auth = auth or self.auth or {}
    
    Socket.Log("Connecting to: " .. self.namespace)
    MP.Send(getPlayer(), Socket.MODULE, Socket.CMD.CONNECT, {
        ns = self.namespace,
        auth = self.auth
    })
end

---Disconnect from the server namespace
function SocketClient:disconnect()
    if not self.connected then return end
    
    Socket.Log("Disconnecting from: " .. self.namespace)
    MP.Send(getPlayer(), Socket.MODULE, Socket.CMD.DISCONNECT, {
        ns = self.namespace
    })
    
    self.connected = false
    self.rooms = {}
    self:_trigger(Socket.EVENTS.DISCONNECT)
end

---Check if connected
---@return boolean
function SocketClient:isConnected()
    return self.connected
end

---Register an event handler
---@param event string Event name
---@param callback function Callback function(data)
---@return SocketClient self for chaining
function SocketClient:on(event, callback)
    if not self.handlers[event] then
        self.handlers[event] = {}
    end
    table.insert(self.handlers[event], callback)
    return self
end

---Register a one-time event handler
---@param event string Event name
---@param callback function Callback function(data)
---@return SocketClient self for chaining
function SocketClient:once(event, callback)
    if not self.onceHandlers[event] then
        self.onceHandlers[event] = {}
    end
    table.insert(self.onceHandlers[event], callback)
    return self
end

---Remove an event handler
---@param event string Event name
---@param callback? function Specific callback to remove (nil = remove all)
---@return SocketClient self for chaining
function SocketClient:off(event, callback)
    if callback then
        -- Remove specific callback
        if self.handlers[event] then
            for i, cb in ipairs(self.handlers[event]) do
                if cb == callback then
                    table.remove(self.handlers[event], i)
                    break
                end
            end
        end
        if self.onceHandlers[event] then
            for i, cb in ipairs(self.onceHandlers[event]) do
                if cb == callback then
                    table.remove(self.onceHandlers[event], i)
                    break
                end
            end
        end
    else
        -- Remove all handlers for event
        self.handlers[event] = nil
        self.onceHandlers[event] = nil
    end
    return self
end

---Emit an event to the server
---@param event string Event name
---@param data? table Data to send
---@param ackCallback? function Acknowledgment callback function(response)
---@return SocketClient self for chaining
function SocketClient:emit(event, data, ackCallback)
    if not self.connected then
        Socket.Log("Warning: Emitting while not connected: " .. event)
    end
    
    local args = {
        ns = self.namespace,
        event = event,
        data = data or {}
    }
    
    -- Handle acknowledgment
    if ackCallback then
        local ackId = Socket.GenerateAckId()
        self.pendingAcks[ackId] = {
            callback = ackCallback,
            timestamp = os.time()
        }
        args.ackId = ackId
    end
    
    MP.Send(getPlayer(), Socket.MODULE, Socket.CMD.EMIT, args)
    return self
end

---Request to join a room
---@param room string Room name
---@param ackCallback? function Acknowledgment callback
---@return SocketClient self for chaining
function SocketClient:joinRoom(room, ackCallback)
    local args = {
        ns = self.namespace,
        room = room
    }
    
    if ackCallback then
        local ackId = Socket.GenerateAckId()
        self.pendingAcks[ackId] = {
            callback = ackCallback,
            timestamp = os.time()
        }
        args.ackId = ackId
    end
    
    MP.Send(getPlayer(), Socket.MODULE, Socket.CMD.JOIN, args)
    return self
end

---Request to leave a room
---@param room string Room name
---@return SocketClient self for chaining
function SocketClient:leaveRoom(room)
    MP.Send(getPlayer(), Socket.MODULE, Socket.CMD.LEAVE, {
        ns = self.namespace,
        room = room
    })
    return self
end

---Get rooms this client has joined
---@return table
function SocketClient:getRooms()
    return Socket.DeepCopy(self.rooms)
end

---Check if in a specific room
---@param room string
---@return boolean
function SocketClient:inRoom(room)
    return self.rooms[room] == true
end

---Internal: Trigger local event handlers
---@param event string
---@param ... any
function SocketClient:_trigger(event, ...)
    -- Regular handlers
    if self.handlers[event] then
        for _, callback in ipairs(self.handlers[event]) do
            local success, err = pcall(callback, ...)
            if not success then
                Socket.Log("Error in handler for '" .. event .. "': " .. tostring(err))
            end
        end
    end
    
    -- Once handlers (remove after calling)
    if self.onceHandlers[event] then
        local handlers = self.onceHandlers[event]
        self.onceHandlers[event] = nil
        for _, callback in ipairs(handlers) do
            local success, err = pcall(callback, ...)
            if not success then
                Socket.Log("Error in once handler for '" .. event .. "': " .. tostring(err))
            end
        end
    end
end

---Internal: Handle acknowledgment response
---@param ackId string
---@param response table
function SocketClient:_handleAck(ackId, response)
    local pending = self.pendingAcks[ackId]
    if pending then
        self.pendingAcks[ackId] = nil
        local success, err = pcall(pending.callback, response)
        if not success then
            Socket.Log("Error in ack callback: " .. tostring(err))
        end
    end
end

---Internal: Handle server messages
---@param command string
---@param args table
function SocketClient:_handleServerMessage(command, args)
    if command == Socket.CMD.CONNECTED then
        self.connected = true
        Socket.Log("Connected to: " .. self.namespace)
        self:_trigger(Socket.EVENTS.CONNECT)
        
    elseif command == Socket.CMD.DISCONNECTED then
        self.connected = false
        self.rooms = {}
        Socket.Log("Disconnected from: " .. self.namespace .. " - " .. tostring(args.reason))
        self:_trigger(Socket.EVENTS.DISCONNECT, args.reason)
        
    elseif command == Socket.CMD.ERROR then
        Socket.Log("Error from " .. self.namespace .. ": " .. tostring(args.reason))
        self:_trigger(Socket.EVENTS.ERROR, args.reason)
        
    elseif command == Socket.CMD.JOINED then
        self.rooms[args.room] = true
        Socket.Log("Joined room: " .. args.room)
        self:_trigger(Socket.EVENTS.JOINED, args.room)
        if args.ackId then
            self:_handleAck(args.ackId, { success = true, room = args.room })
        end
        
    elseif command == Socket.CMD.LEFT then
        self.rooms[args.room] = nil
        Socket.Log("Left room: " .. args.room)
        self:_trigger(Socket.EVENTS.LEFT, args.room)
        
    elseif command == Socket.CMD.KICKED then
        self.rooms[args.room] = nil
        Socket.Log("Kicked from room: " .. args.room .. " - " .. tostring(args.reason))
        self:_trigger(Socket.EVENTS.KICKED, args.room, args.reason)
        
    elseif command == Socket.CMD.EMIT then
        -- Server emitting an event to us
        self:_trigger(args.event, args.data)
        
    elseif command == Socket.CMD.ACK then
        -- Acknowledgment response
        if args.ackId then
            self:_handleAck(args.ackId, args.response or {})
        end
    end
end

---Destroy this socket
function SocketClient:destroy()
    self:disconnect()
    self.handlers = {}
    self.onceHandlers = {}
    self.pendingAcks = {}
end

-- ==========================================================
-- MP Handler Registration
-- ==========================================================

MP.Register(Socket.MODULE, Socket.CMD.CONNECTED, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.CONNECTED, args) end
end)

MP.Register(Socket.MODULE, Socket.CMD.DISCONNECTED, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.DISCONNECTED, args) end
end)

MP.Register(Socket.MODULE, Socket.CMD.ERROR, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.ERROR, args) end
end)

MP.Register(Socket.MODULE, Socket.CMD.JOINED, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.JOINED, args) end
end)

MP.Register(Socket.MODULE, Socket.CMD.LEFT, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.LEFT, args) end
end)

MP.Register(Socket.MODULE, Socket.CMD.KICKED, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.KICKED, args) end
end)

MP.Register(Socket.MODULE, Socket.CMD.EMIT, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.EMIT, args) end
end)

MP.Register(Socket.MODULE, Socket.CMD.ACK, function(player, args)
    local socket = Socket.get(args.ns)
    if socket then socket:_handleServerMessage(Socket.CMD.ACK, args) end
end)

return KoniLib.SocketClient
