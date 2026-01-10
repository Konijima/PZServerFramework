if not KoniLib then KoniLib = {} end

local Socket = require("KoniLib/Socket")

---@class SocketSP
---Singleplayer socket that combines client and server functionality
---Acts as a loopback - client calls are immediately processed by server logic
KoniLib.SocketSP = {}
KoniLib.SocketSP.__index = KoniLib.SocketSP

local SocketSP = KoniLib.SocketSP

---Create a new singleplayer socket
---@param namespace string
---@param options? table
---@return SocketSP
function SocketSP.new(namespace, options)
    local self = setmetatable({}, SocketSP)
    
    self.namespace = namespace
    self.options = options or {}
    self.connected = false
    self.auth = options and options.auth or nil
    
    -- Client-side state
    self.clientHandlers = {}
    self.clientOnceHandlers = {}
    self.rooms = {}
    
    -- Server-side state
    self.connections = {}
    self.serverRooms = {}
    self.playerRooms = {}
    self.middlewares = {
        [Socket.MIDDLEWARE.CONNECTION] = {},
        [Socket.MIDDLEWARE.DISCONNECT] = {},
        [Socket.MIDDLEWARE.JOIN] = {},
        [Socket.MIDDLEWARE.LEAVE] = {},
        [Socket.MIDDLEWARE.EMIT] = {},
    }
    self.serverHandlers = {}
    self.serverOnceHandlers = {}
    
    Socket.Log("SocketSP created for: " .. namespace)
    
    -- Auto-connect
    if self.options.autoConnect ~= false then
        Events.OnTick.Add(function()
            if not self.connected then
                self:connect(self.auth)
            end
        end)
    end
    
    return self
end

-- ==========================================================
-- Client API
-- ==========================================================

---Connect to namespace with optional auth
---@param auth? table
function SocketSP:connect(auth)
    if self.connected then return end
    
    self.auth = auth or self.auth or {}
    local player = getPlayer()
    local username = player:getUsername()
    
    -- Run connection middleware
    local success, result = self:_runMiddleware(Socket.MIDDLEWARE.CONNECTION, player, self.auth)
    
    if not success then
        self:_triggerClient(Socket.EVENTS.ERROR, result)
        Socket.Log("SP Connection rejected: " .. tostring(result))
        return
    end
    
    -- Store connection (server side)
    local context = type(result) == "table" and result or {}
    self.connections[username] = {
        player = player,
        context = context,
        connectedAt = os.time()
    }
    self.playerRooms[username] = {}
    
    self.connected = true
    
    -- Trigger client connect
    self:_triggerClient(Socket.EVENTS.CONNECT)
    
    -- Trigger server connect
    self:_triggerServer(Socket.EVENTS.CONNECT, player, context)
    
    Socket.Log("SP Connected to: " .. self.namespace)
end

---Disconnect from namespace
function SocketSP:disconnect()
    if not self.connected then return end
    
    local player = getPlayer()
    local username = player:getUsername()
    
    -- Run disconnect middleware
    self:_runMiddleware(Socket.MIDDLEWARE.DISCONNECT, player)
    
    -- Leave all rooms
    self:leaveAll(player)
    
    -- Remove connection
    self.connections[username] = nil
    self.connected = false
    self.rooms = {}
    
    -- Trigger events
    self:_triggerClient(Socket.EVENTS.DISCONNECT, "Client disconnect")
    self:_triggerServer(Socket.EVENTS.DISCONNECT, player)
    
    Socket.Log("SP Disconnected from: " .. self.namespace)
end

---Check if connected
---@return boolean
function SocketSP:isConnected()
    return self.connected
end

---Register client-side event handler
---@param event string
---@param callback function
---@return SocketSP
function SocketSP:on(event, callback)
    -- Client handlers receive (data)
    if not self.clientHandlers[event] then
        self.clientHandlers[event] = {}
    end
    table.insert(self.clientHandlers[event], callback)
    return self
end

---Register server-side event handler (for handling client emissions)
---Server handlers receive (player, data, context, ack)
---@param event string
---@param callback function
---@return SocketSP
function SocketSP:onServer(event, callback)
    if not self.serverHandlers[event] then
        self.serverHandlers[event] = {}
    end
    table.insert(self.serverHandlers[event], callback)
    return self
end

---Register one-time client handler
---@param event string
---@param callback function
---@return SocketSP
function SocketSP:once(event, callback)
    if not self.clientOnceHandlers[event] then
        self.clientOnceHandlers[event] = {}
    end
    table.insert(self.clientOnceHandlers[event], callback)
    return self
end

---Register one-time server handler
---@param event string
---@param callback function
---@return SocketSP
function SocketSP:onceServer(event, callback)
    if not self.serverOnceHandlers[event] then
        self.serverOnceHandlers[event] = {}
    end
    table.insert(self.serverOnceHandlers[event], callback)
    return self
end

---Remove client handler
---@param event string
---@param callback? function
---@return SocketSP
function SocketSP:off(event, callback)
    if callback then
        if self.clientHandlers[event] then
            for i, cb in ipairs(self.clientHandlers[event]) do
                if cb == callback then
                    table.remove(self.clientHandlers[event], i)
                    break
                end
            end
        end
    else
        self.clientHandlers[event] = nil
        self.clientOnceHandlers[event] = nil
    end
    return self
end

---Remove server handler
---@param event string
---@param callback? function
---@return SocketSP
function SocketSP:offServer(event, callback)
    if callback then
        if self.serverHandlers[event] then
            for i, cb in ipairs(self.serverHandlers[event]) do
                if cb == callback then
                    table.remove(self.serverHandlers[event], i)
                    break
                end
            end
        end
    else
        self.serverHandlers[event] = nil
        self.serverOnceHandlers[event] = nil
    end
    return self
end

---Emit event (client -> server, immediate loopback)
---@param event string
---@param data? table
---@param ackCallback? function
---@return SocketSP
function SocketSP:emit(event, data, ackCallback)
    if not self.connected then
        Socket.Log("Warning: SP Emitting while not connected: " .. event)
        return self
    end
    
    local player = getPlayer()
    local context = self:getContext(player) or {}
    data = data or {}
    
    -- Run emit middleware
    local success, result = self:_runMiddleware(Socket.MIDDLEWARE.EMIT, player, event, data)
    if not success then
        self:_triggerClient(Socket.EVENTS.ERROR, result)
        if ackCallback then
            ackCallback({ error = result })
        end
        return self
    end
    
    -- Update context if modified
    if type(result) == "table" then
        context = result
    end
    
    -- Create ack function
    local ack = nil
    if ackCallback then
        ack = function(response)
            ackCallback(response or {})
        end
    end
    
    -- Trigger server handlers
    if self.serverHandlers[event] then
        for _, callback in ipairs(self.serverHandlers[event]) do
            local ok, err = pcall(callback, player, data, context, ack)
            if not ok then
                Socket.Log("SP Error in server handler for '" .. event .. "': " .. tostring(err))
            end
        end
    end
    
    return self
end

---Join a room
---@param room string
---@param ackCallback? function
---@return SocketSP
function SocketSP:joinRoom(room, ackCallback)
    local success, err = self:join(getPlayer(), room)
    
    if success then
        self.rooms[room] = true
        self:_triggerClient(Socket.EVENTS.JOINED, room)
        if ackCallback then
            ackCallback({ success = true, room = room })
        end
    else
        self:_triggerClient(Socket.EVENTS.ERROR, err)
        if ackCallback then
            ackCallback({ error = err })
        end
    end
    
    return self
end

---Leave a room
---@param room string
---@return SocketSP
function SocketSP:leaveRoom(room)
    self:leave(getPlayer(), room)
    self.rooms[room] = nil
    self:_triggerClient(Socket.EVENTS.LEFT, room)
    return self
end

---Get rooms client is in
---@return table
function SocketSP:getRooms()
    return Socket.DeepCopy(self.rooms)
end

---Check if in room
---@param room string
---@return boolean
function SocketSP:inRoom(room)
    return self.rooms[room] == true
end

-- ==========================================================
-- Server API
-- ==========================================================

---Add middleware
---@param type string
---@param middleware function
---@return SocketSP
function SocketSP:use(type, middleware)
    if self.middlewares[type] then
        table.insert(self.middlewares[type], middleware)
    end
    return self
end

---Register server-side event handler
---@param event string
---@param callback function
---@return SocketSP
function SocketSP:onServer(event, callback)
    if not self.serverHandlers[event] then
        self.serverHandlers[event] = {}
    end
    table.insert(self.serverHandlers[event], callback)
    return self
end

---Get context for player
---@param player IsoPlayer
---@return table|nil
function SocketSP:getContext(player)
    local username = player:getUsername()
    if self.connections[username] then
        return self.connections[username].context
    end
    return nil
end

---Set context
---@param player IsoPlayer
---@param keyOrTable string|table
---@param value? any
---@return SocketSP
function SocketSP:setContext(player, keyOrTable, value)
    local username = player:getUsername()
    if not self.connections[username] then return self end
    
    if type(keyOrTable) == "table" then
        self.connections[username].context = keyOrTable
    else
        self.connections[username].context[keyOrTable] = value
    end
    return self
end

---Server join (internal)
---@param player IsoPlayer
---@param room string
---@return boolean, string|nil
function SocketSP:join(player, room)
    local username = player:getUsername()
    
    if not self.connections[username] then
        return false, "Not connected"
    end
    
    -- Run join middleware
    local success, result = self:_runMiddleware(Socket.MIDDLEWARE.JOIN, player, room)
    if not success then
        return false, result
    end
    
    -- Add to room
    if not self.serverRooms[room] then
        self.serverRooms[room] = {}
    end
    self.serverRooms[room][username] = true
    
    if not self.playerRooms[username] then
        self.playerRooms[username] = {}
    end
    self.playerRooms[username][room] = true
    
    return true
end

---Server leave (internal)
---@param player IsoPlayer
---@param room string
function SocketSP:leave(player, room)
    local username = player:getUsername()
    
    self:_runMiddleware(Socket.MIDDLEWARE.LEAVE, player, room)
    
    if self.serverRooms[room] then
        self.serverRooms[room][username] = nil
        if not next(self.serverRooms[room]) then
            self.serverRooms[room] = nil
        end
    end
    
    if self.playerRooms[username] then
        self.playerRooms[username][room] = nil
    end
end

---Leave all rooms
---@param player IsoPlayer
function SocketSP:leaveAll(player)
    local username = player:getUsername()
    local rooms = self.playerRooms[username]
    
    if rooms then
        for room, _ in pairs(rooms) do
            if self.serverRooms[room] then
                self.serverRooms[room][username] = nil
                if not next(self.serverRooms[room]) then
                    self.serverRooms[room] = nil
                end
            end
        end
        self.playerRooms[username] = nil
    end
end

---Server emit to room or player (SP: triggers client handlers)
---@param roomOrPlayer string|IsoPlayer Room name or player object
---@return table Emitter-like object
function SocketSP:to(roomOrPlayer)
    local self_ = self
    local player = getPlayer()
    
    return {
        emit = function(_, event, data)
            -- In SP, there's only one player
            -- Check if we're targeting that player
            if type(roomOrPlayer) == "string" then
                -- Room name - check if player is in room
                if self_.rooms[roomOrPlayer] then
                    self_:_triggerClient(event, data)
                end
            else
                -- Player object - check if it's the current player
                if roomOrPlayer and player and roomOrPlayer:getUsername() == player:getUsername() then
                    self_:_triggerClient(event, data)
                end
            end
        end
    }
end

---Broadcast (SP: just triggers client)
---@param excludePlayer? IsoPlayer
---@return table
function SocketSP:broadcast(excludePlayer)
    local self_ = self
    local excluded = excludePlayer
    
    local broadcaster = {
        emit = function(_, event, data)
            -- In SP, there's only one player, so if excluded, don't emit
            if excluded and excluded == getPlayer() then
                return
            end
            self_:_triggerClient(event, data)
        end,
        -- Chain method to exclude a player
        except = function(_, playerToExclude)
            excluded = playerToExclude
            return broadcaster
        end
    }
    
    return broadcaster
end

-- ==========================================================
-- Internal
-- ==========================================================

---Run middleware chain
function SocketSP:_runMiddleware(middlewareType, player, ...)
    local middlewares = self.middlewares[middlewareType] or {}
    local args = {...}
    local context = self:getContext(player) or {}
    
    if #middlewares == 0 then
        return true, context
    end
    
    local index = 0
    local rejected = false
    local rejectReason = nil
    
    local function next(contextUpdate)
        if rejected then return end
        
        if contextUpdate and type(contextUpdate) == "table" then
            for k, v in pairs(contextUpdate) do
                context[k] = v
            end
        end
        
        index = index + 1
        local mw = middlewares[index]
        
        if mw then
            local mwArgs = {player}
            for _, arg in ipairs(args) do
                table.insert(mwArgs, arg)
            end
            table.insert(mwArgs, context)
            table.insert(mwArgs, next)
            table.insert(mwArgs, function(reason)
                rejected = true
                rejectReason = reason or "Rejected"
            end)
            
            local ok, err = pcall(mw, unpack(mwArgs))
            if not ok then
                Socket.Log("SP Middleware error: " .. tostring(err))
                rejected = true
                rejectReason = "Internal error"
            end
        end
    end
    
    next()
    
    if rejected then
        return false, rejectReason
    end
    
    return true, context
end

---Trigger client handlers
function SocketSP:_triggerClient(event, ...)
    if self.clientHandlers[event] then
        for _, cb in ipairs(self.clientHandlers[event]) do
            pcall(cb, ...)
        end
    end
    
    if self.clientOnceHandlers[event] then
        local handlers = self.clientOnceHandlers[event]
        self.clientOnceHandlers[event] = nil
        for _, cb in ipairs(handlers) do
            pcall(cb, ...)
        end
    end
end

---Trigger server handlers
function SocketSP:_triggerServer(event, ...)
    if self.serverHandlers[event] then
        for _, cb in ipairs(self.serverHandlers[event]) do
            pcall(cb, ...)
        end
    end
end

---Destroy socket
function SocketSP:destroy()
    self:disconnect()
    self.clientHandlers = {}
    self.serverHandlers = {}
    self.middlewares = {}
end

return KoniLib.SocketSP
