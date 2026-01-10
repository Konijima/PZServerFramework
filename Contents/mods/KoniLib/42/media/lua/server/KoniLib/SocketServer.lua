if not KoniLib then KoniLib = {} end

local Socket = require("KoniLib/Socket")
local MP = require("KoniLib/MP")

---@class SocketServer
---@field namespace string The namespace this socket belongs to
---@field connections table Connected players with their context
---@field rooms table Room memberships
---@field playerRooms table Reverse lookup: player -> rooms
---@field middlewares table Middleware chains
---@field handlers table Event handlers
KoniLib.SocketServer = {}
KoniLib.SocketServer.__index = KoniLib.SocketServer

local SocketServer = KoniLib.SocketServer

---@class SocketEmitter
---Helper class for chained emission (to/broadcast/except)
local SocketEmitter = {}
SocketEmitter.__index = SocketEmitter

---Create a new server socket
---@param namespace string
---@param options? table
---@return SocketServer
function SocketServer.new(namespace, options)
    local self = setmetatable({}, SocketServer)
    
    self.namespace = namespace
    self.options = options or {}
    
    -- Connected players: { [username] = { player, context, connectedAt } }
    self.connections = {}
    
    -- Rooms: { [roomName] = { [username] = true } }
    self.rooms = {}
    
    -- Player rooms: { [username] = { [roomName] = true } }
    self.playerRooms = {}
    
    -- Middlewares: { [type] = { func1, func2, ... } }
    self.middlewares = {
        [Socket.MIDDLEWARE.CONNECTION] = {},
        [Socket.MIDDLEWARE.DISCONNECT] = {},
        [Socket.MIDDLEWARE.JOIN] = {},
        [Socket.MIDDLEWARE.LEAVE] = {},
        [Socket.MIDDLEWARE.EMIT] = {},
    }
    
    -- Event handlers: { [event] = { callback1, callback2 } }
    self.handlers = {}
    self.onceHandlers = {}
    
    Socket.Log("SocketServer created for: " .. namespace)
    return self
end

-- ==========================================================
-- Middleware System
-- ==========================================================

---Add middleware for a specific type
---@param type string Middleware type (connection, disconnect, join, leave, emit)
---@param middleware function Middleware function
---@return SocketServer self for chaining
function SocketServer:use(type, middleware)
    if not self.middlewares[type] then
        Socket.Log("Warning: Unknown middleware type: " .. tostring(type))
        return self
    end
    table.insert(self.middlewares[type], middleware)
    Socket.Log("Added " .. type .. " middleware for: " .. self.namespace)
    return self
end

---Remove a middleware
---@param type string
---@param middleware function
---@return SocketServer self for chaining
function SocketServer:removeMiddleware(type, middleware)
    if self.middlewares[type] then
        for i, mw in ipairs(self.middlewares[type]) do
            if mw == middleware then
                table.remove(self.middlewares[type], i)
                break
            end
        end
    end
    return self
end

---Run middleware chain
---@param type string Middleware type
---@param player IsoPlayer
---@param ... any Additional arguments for middleware
---@return boolean success
---@return string|table contextOrReason
function SocketServer:_runMiddleware(middlewareType, player, ...)
    local middlewares = self.middlewares[middlewareType] or {}
    local args = {...}
    local context = self:getContext(player) or {}
    
    if #middlewares == 0 then
        return true, context
    end
    
    local index = 0
    local completed = false
    local rejected = false
    local rejectReason = nil
    
    local function next(contextUpdate)
        if rejected then return end
        
        -- Merge context updates
        if contextUpdate and type(contextUpdate) == "table" then
            for k, v in pairs(contextUpdate) do
                context[k] = v
            end
        end
        
        index = index + 1
        local mw = middlewares[index]
        
        if mw then
            -- Build middleware args: player, ...args, context, next, reject
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
            
            local success, err = pcall(mw, unpack(mwArgs))
            if not success then
                Socket.Log("Middleware error: " .. tostring(err))
                rejected = true
                rejectReason = "Internal error"
            end
        else
            completed = true
        end
    end
    
    next()
    
    -- If middleware is async (didn't call next yet), wait briefly
    -- For now, we assume synchronous middleware
    
    if rejected then
        return false, rejectReason
    end
    
    return true, context
end

-- ==========================================================
-- Connection Management
-- ==========================================================

---Get context for a player
---@param player IsoPlayer
---@return table|nil
function SocketServer:getContext(player)
    local username = player:getUsername()
    if self.connections[username] then
        return self.connections[username].context
    end
    return nil
end

---Set context for a player (or update specific key)
---@param player IsoPlayer
---@param keyOrTable string|table Key to set, or full context table
---@param value? any Value if key provided
---@return SocketServer self
function SocketServer:setContext(player, keyOrTable, value)
    local username = player:getUsername()
    if not self.connections[username] then return self end
    
    if type(keyOrTable) == "table" then
        self.connections[username].context = keyOrTable
    else
        self.connections[username].context[keyOrTable] = value
    end
    return self
end

---Get all connected players
---@return table Array of { player, context }
function SocketServer:getConnectedPlayers()
    local result = {}
    for username, data in pairs(self.connections) do
        table.insert(result, {
            player = data.player,
            context = Socket.DeepCopy(data.context)
        })
    end
    return result
end

---Check if a player is connected
---@param player IsoPlayer
---@return boolean
function SocketServer:isConnected(player)
    return self.connections[player:getUsername()] ~= nil
end

---Force disconnect a player
---@param player IsoPlayer
---@param reason? string
function SocketServer:disconnect(player, reason)
    local username = player:getUsername()
    if not self.connections[username] then return end
    
    -- Run disconnect middleware
    self:_runMiddleware(Socket.MIDDLEWARE.DISCONNECT, player)
    
    -- Leave all rooms
    self:leaveAll(player)
    
    -- Remove connection
    self.connections[username] = nil
    
    -- Notify client
    MP.Send(player, Socket.MODULE, Socket.CMD.DISCONNECTED, {
        ns = self.namespace,
        reason = reason or "Disconnected by server"
    })
    
    -- Trigger disconnect event
    self:_trigger(Socket.EVENTS.DISCONNECT, player)
    
    Socket.Log("Player disconnected from " .. self.namespace .. ": " .. username)
end

-- ==========================================================
-- Room Management
-- ==========================================================

---Add a player to a room
---@param player IsoPlayer
---@param room string
---@return boolean success
---@return string|nil error
function SocketServer:join(player, room)
    local username = player:getUsername()
    
    if not self:isConnected(player) then
        return false, "Not connected"
    end
    
    -- Run join middleware
    local success, result = self:_runMiddleware(Socket.MIDDLEWARE.JOIN, player, room)
    if not success then
        return false, result
    end
    
    -- Update context if middleware modified it
    if type(result) == "table" then
        self:setContext(player, result)
    end
    
    -- Add to room
    if not self.rooms[room] then
        self.rooms[room] = {}
    end
    self.rooms[room][username] = true
    
    -- Add to player rooms
    if not self.playerRooms[username] then
        self.playerRooms[username] = {}
    end
    self.playerRooms[username][room] = true
    
    Socket.Log(username .. " joined room: " .. room .. " in " .. self.namespace)
    return true
end

---Remove a player from a room
---@param player IsoPlayer
---@param room string
function SocketServer:leave(player, room)
    local username = player:getUsername()
    
    -- Run leave middleware
    self:_runMiddleware(Socket.MIDDLEWARE.LEAVE, player, room)
    
    -- Remove from room
    if self.rooms[room] then
        self.rooms[room][username] = nil
        -- Clean up empty rooms
        if not next(self.rooms[room]) then
            self.rooms[room] = nil
        end
    end
    
    -- Remove from player rooms
    if self.playerRooms[username] then
        self.playerRooms[username][room] = nil
    end
    
    Socket.Log(username .. " left room: " .. room .. " in " .. self.namespace)
end

---Remove a player from all rooms
---@param player IsoPlayer
function SocketServer:leaveAll(player)
    local username = player:getUsername()
    local rooms = self.playerRooms[username]
    
    if rooms then
        for room, _ in pairs(rooms) do
            if self.rooms[room] then
                self.rooms[room][username] = nil
                if not next(self.rooms[room]) then
                    self.rooms[room] = nil
                end
            end
        end
        self.playerRooms[username] = nil
    end
end

---Kick a player from a room
---@param player IsoPlayer
---@param room string
---@param reason? string
function SocketServer:kick(player, room, reason)
    self:leave(player, room)
    
    MP.Send(player, Socket.MODULE, Socket.CMD.KICKED, {
        ns = self.namespace,
        room = room,
        reason = reason
    })
end

---Get all rooms a player is in
---@param player IsoPlayer
---@return table
function SocketServer:getRooms(player)
    local username = player:getUsername()
    local rooms = {}
    if self.playerRooms[username] then
        for room, _ in pairs(self.playerRooms[username]) do
            table.insert(rooms, room)
        end
    end
    return rooms
end

---Get all players in a room
---@param room string
---@return table Array of players
function SocketServer:getPlayersInRoom(room)
    local players = {}
    if self.rooms[room] then
        for username, _ in pairs(self.rooms[room]) do
            local conn = self.connections[username]
            if conn and conn.player then
                table.insert(players, conn.player)
            end
        end
    end
    return players
end

---Get all room names
---@return table
function SocketServer:getAllRooms()
    local rooms = {}
    for room, _ in pairs(self.rooms) do
        table.insert(rooms, room)
    end
    return rooms
end

-- ==========================================================
-- Event Handling
-- ==========================================================

---Register an event handler
---@param event string Event name
---@param callback function Callback function(player, data, context, ack?)
---@return SocketServer self
function SocketServer:on(event, callback)
    if not self.handlers[event] then
        self.handlers[event] = {}
    end
    table.insert(self.handlers[event], callback)
    return self
end

---Alias for :on() to maintain consistency with SocketSP API
---@param event string Event name
---@param callback function Callback function(player, data, context, ack?)
---@return SocketServer self
function SocketServer:onServer(event, callback)
    return self:on(event, callback)
end

---Register a one-time event handler
---@param event string
---@param callback function
---@return SocketServer self
function SocketServer:once(event, callback)
    if not self.onceHandlers[event] then
        self.onceHandlers[event] = {}
    end
    table.insert(self.onceHandlers[event], callback)
    return self
end

---Alias for :once() to maintain consistency with SocketSP API
---@param event string
---@param callback function
---@return SocketServer self
function SocketServer:onceServer(event, callback)
    return self:once(event, callback)
end

---Remove an event handler
---@param event string
---@param callback? function
---@return SocketServer self
function SocketServer:off(event, callback)
    if callback then
        if self.handlers[event] then
            for i, cb in ipairs(self.handlers[event]) do
                if cb == callback then
                    table.remove(self.handlers[event], i)
                    break
                end
            end
        end
    else
        self.handlers[event] = nil
        self.onceHandlers[event] = nil
    end
    return self
end

---Alias for :off() to maintain consistency with SocketSP API
---@param event string
---@param callback? function
---@return SocketServer self
function SocketServer:offServer(event, callback)
    return self:off(event, callback)
end

---Internal: Trigger event handlers
---@param event string
---@param ... any
function SocketServer:_trigger(event, ...)
    -- Regular handlers
    if self.handlers[event] then
        for _, callback in ipairs(self.handlers[event]) do
            local success, err = pcall(callback, ...)
            if not success then
                Socket.Log("Error in handler for '" .. event .. "': " .. tostring(err))
            end
        end
    end
    
    -- Once handlers
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

-- ==========================================================
-- Emission
-- ==========================================================

---Emit to a specific player or all connected players
---@param event string Event name
---@param data? table Data to send
---@param player? IsoPlayer Specific player (nil = broadcast to all)
---@return SocketServer self
function SocketServer:emit(event, data, player)
    local args = {
        ns = self.namespace,
        event = event,
        data = data or {}
    }
    
    if player then
        -- Send to specific player
        MP.Send(player, Socket.MODULE, Socket.CMD.EMIT, args)
    else
        -- Broadcast to all connected
        for username, conn in pairs(self.connections) do
            if conn.player then
                MP.Send(conn.player, Socket.MODULE, Socket.CMD.EMIT, args)
            end
        end
    end
    return self
end

---Create an emitter for a specific room or player
---@param roomOrPlayer string|IsoPlayer Room name or player object
---@return SocketEmitter
function SocketServer:to(roomOrPlayer)
    if type(roomOrPlayer) == "string" then
        return SocketEmitter.new(self, { room = roomOrPlayer })
    else
        -- Assume it's a player object
        return SocketEmitter.new(self, { player = roomOrPlayer })
    end
end

---Alias for :to()
---@param roomOrPlayer string|IsoPlayer Room name or player object
---@return SocketEmitter
function SocketServer:in_(roomOrPlayer)
    return self:to(roomOrPlayer)
end

---Create an emitter that excludes a specific player
---@param excludePlayer IsoPlayer
---@return SocketEmitter
function SocketServer:broadcast(excludePlayer)
    return SocketEmitter.new(self, { exclude = excludePlayer })
end

---Alias for :broadcast()
---@param excludePlayer IsoPlayer
---@return SocketEmitter
function SocketServer:except(excludePlayer)
    return self:broadcast(excludePlayer)
end

-- ==========================================================
-- SocketEmitter (for chained emission)
-- ==========================================================

---Create a new emitter
---@param server SocketServer
---@param options table
---@return SocketEmitter
function SocketEmitter.new(server, options)
    local self = setmetatable({}, SocketEmitter)
    self.server = server
    self.options = options or {}
    self.rooms = {}
    self.excludes = {}
    self.targetPlayers = {}
    
    if options.room then
        self.rooms[options.room] = true
    end
    if options.player then
        self.targetPlayers[options.player:getUsername()] = options.player
    end
    if options.exclude then
        self.excludes[options.exclude:getUsername()] = true
    end
    
    return self
end

---Chain another room or player
---@param roomOrPlayer string|IsoPlayer Room name or player object
---@return SocketEmitter
function SocketEmitter:to(roomOrPlayer)
    if type(roomOrPlayer) == "string" then
        self.rooms[roomOrPlayer] = true
    else
        self.targetPlayers[roomOrPlayer:getUsername()] = roomOrPlayer
    end
    return self
end

---Chain another exclusion
---@param player IsoPlayer
---@return SocketEmitter
function SocketEmitter:except(player)
    self.excludes[player:getUsername()] = true
    return self
end

---Emit to the configured targets
---@param event string
---@param data? table
function SocketEmitter:emit(event, data)
    local args = {
        ns = self.server.namespace,
        event = event,
        data = data or {}
    }
    
    local sent = {}
    
    -- If targeting specific players, emit to them
    if next(self.targetPlayers) then
        for username, player in pairs(self.targetPlayers) do
            if not self.excludes[username] and not sent[username] then
                MP.Send(player, Socket.MODULE, Socket.CMD.EMIT, args)
                sent[username] = true
            end
        end
    end
    
    -- If rooms specified, emit to those rooms
    if next(self.rooms) then
        for room, _ in pairs(self.rooms) do
            local players = self.server:getPlayersInRoom(room)
            for _, player in ipairs(players) do
                local username = player:getUsername()
                if not self.excludes[username] and not sent[username] then
                    MP.Send(player, Socket.MODULE, Socket.CMD.EMIT, args)
                    sent[username] = true
                end
            end
        end
    end
    
    -- If no rooms and no target players, emit to all connected except excludes
    if not next(self.rooms) and not next(self.targetPlayers) then
        for username, conn in pairs(self.server.connections) do
            if not self.excludes[username] and conn.player then
                MP.Send(conn.player, Socket.MODULE, Socket.CMD.EMIT, args)
            end
        end
    end
end

-- ==========================================================
-- Client Message Handling
-- ==========================================================

---Handle incoming client messages
---@param player IsoPlayer
---@param command string
---@param args table
function SocketServer:_handleClientMessage(player, command, args)
    local username = player:getUsername()
    
    if command == Socket.CMD.CONNECT then
        -- Connection request
        local auth = args.auth or {}
        
        -- Run connection middleware
        local success, result = self:_runMiddleware(Socket.MIDDLEWARE.CONNECTION, player, auth)
        
        if not success then
            -- Rejected
            MP.Send(player, Socket.MODULE, Socket.CMD.ERROR, {
                ns = self.namespace,
                reason = result
            })
            Socket.Log("Connection rejected for " .. username .. ": " .. tostring(result))
            return
        end
        
        -- Store connection
        local context = type(result) == "table" and result or {}
        self.connections[username] = {
            player = player,
            context = context,
            connectedAt = os.time()
        }
        self.playerRooms[username] = {}
        
        -- Send connected confirmation
        MP.Send(player, Socket.MODULE, Socket.CMD.CONNECTED, {
            ns = self.namespace
        })
        
        -- Trigger connect event
        self:_trigger(Socket.EVENTS.CONNECT, player, context)
        
        Socket.Log("Player connected to " .. self.namespace .. ": " .. username)
        
    elseif command == Socket.CMD.DISCONNECT then
        self:disconnect(player, "Client disconnect")
        
    elseif command == Socket.CMD.EMIT then
        -- Client emitting an event
        if not self:isConnected(player) then
            MP.Send(player, Socket.MODULE, Socket.CMD.ERROR, {
                ns = self.namespace,
                reason = "Not connected"
            })
            return
        end
        
        local event = args.event
        local data = args.data or {}
        local ackId = args.ackId
        local context = self:getContext(player)
        
        -- Run emit middleware
        local success, result = self:_runMiddleware(Socket.MIDDLEWARE.EMIT, player, event, data)
        if not success then
            -- Send error back
            MP.Send(player, Socket.MODULE, Socket.CMD.ERROR, {
                ns = self.namespace,
                reason = result
            })
            if ackId then
                MP.Send(player, Socket.MODULE, Socket.CMD.ACK, {
                    ns = self.namespace,
                    ackId = ackId,
                    response = { error = result }
                })
            end
            return
        end
        
        -- Update context if middleware modified it
        if type(result) == "table" then
            context = result
        end
        
        -- Create ack function if needed
        local ack = nil
        if ackId then
            ack = function(response)
                MP.Send(player, Socket.MODULE, Socket.CMD.ACK, {
                    ns = self.namespace,
                    ackId = ackId,
                    response = response or {}
                })
            end
        end
        
        -- Trigger event handlers
        if self.handlers[event] then
            for _, callback in ipairs(self.handlers[event]) do
                local success, err = pcall(callback, player, data, context, ack)
                if not success then
                    Socket.Log("Error in handler for '" .. event .. "': " .. tostring(err))
                end
            end
        end
        
        -- Once handlers
        if self.onceHandlers[event] then
            local handlers = self.onceHandlers[event]
            self.onceHandlers[event] = nil
            for _, callback in ipairs(handlers) do
                local success, err = pcall(callback, player, data, context, ack)
                if not success then
                    Socket.Log("Error in once handler for '" .. event .. "': " .. tostring(err))
                end
            end
        end
        
    elseif command == Socket.CMD.JOIN then
        -- Join room request
        local room = args.room
        local ackId = args.ackId
        
        local success, err = self:join(player, room)
        
        if success then
            MP.Send(player, Socket.MODULE, Socket.CMD.JOINED, {
                ns = self.namespace,
                room = room,
                ackId = ackId
            })
        else
            MP.Send(player, Socket.MODULE, Socket.CMD.ERROR, {
                ns = self.namespace,
                reason = err
            })
            if ackId then
                MP.Send(player, Socket.MODULE, Socket.CMD.ACK, {
                    ns = self.namespace,
                    ackId = ackId,
                    response = { error = err }
                })
            end
        end
        
    elseif command == Socket.CMD.LEAVE then
        -- Leave room request
        local room = args.room
        self:leave(player, room)
        
        MP.Send(player, Socket.MODULE, Socket.CMD.LEFT, {
            ns = self.namespace,
            room = room
        })
    end
end

---Destroy this socket
function SocketServer:destroy()
    -- Disconnect all players
    for username, conn in pairs(self.connections) do
        if conn.player then
            self:disconnect(conn.player, "Namespace destroyed")
        end
    end
    
    self.connections = {}
    self.rooms = {}
    self.playerRooms = {}
    self.handlers = {}
    self.onceHandlers = {}
end

-- ==========================================================
-- MP Handler Registration (Server-side)
-- ==========================================================

local function handleClientCommand(player, command, args)
    if not args or not args.ns then return end
    
    local socket = Socket.get(args.ns)
    if socket then
        socket:_handleClientMessage(player, command, args)
    else
        -- Auto-create namespace on first connection? Or reject?
        -- For now, reject if namespace doesn't exist
        if command == Socket.CMD.CONNECT then
            MP.Send(player, Socket.MODULE, Socket.CMD.ERROR, {
                ns = args.ns,
                reason = "Namespace does not exist"
            })
        end
    end
end

MP.Register(Socket.MODULE, Socket.CMD.CONNECT, function(player, args)
    handleClientCommand(player, Socket.CMD.CONNECT, args)
end)

MP.Register(Socket.MODULE, Socket.CMD.DISCONNECT, function(player, args)
    handleClientCommand(player, Socket.CMD.DISCONNECT, args)
end)

MP.Register(Socket.MODULE, Socket.CMD.EMIT, function(player, args)
    handleClientCommand(player, Socket.CMD.EMIT, args)
end)

MP.Register(Socket.MODULE, Socket.CMD.JOIN, function(player, args)
    handleClientCommand(player, Socket.CMD.JOIN, args)
end)

MP.Register(Socket.MODULE, Socket.CMD.LEAVE, function(player, args)
    handleClientCommand(player, Socket.CMD.LEAVE, args)
end)

-- ==========================================================
-- Player Quit Cleanup
-- ==========================================================

-- Clean up when players quit
if KoniLib.Events and KoniLib.Events.OnPlayerQuit then
    KoniLib.Events.OnPlayerQuit:Add(function(username)
        -- Find player in all namespaces and disconnect
        for ns, socket in pairs(Socket.namespaces) do
            if socket.connections and socket.connections[username] then
                local conn = socket.connections[username]
                if conn.player then
                    -- Run disconnect middleware
                    socket:_runMiddleware(Socket.MIDDLEWARE.DISCONNECT, conn.player)
                    -- Trigger disconnect event
                    socket:_trigger(Socket.EVENTS.DISCONNECT, conn.player)
                end
                -- Leave all rooms
                socket:leaveAll(conn.player or { getUsername = function() return username end })
                -- Remove connection
                socket.connections[username] = nil
                Socket.Log("Player quit cleanup: " .. username .. " from " .. ns)
            end
        end
    end)
end

return KoniLib.SocketServer
