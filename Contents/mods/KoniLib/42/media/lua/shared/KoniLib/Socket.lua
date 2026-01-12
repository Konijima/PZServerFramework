if not KoniLib then KoniLib = {} end

---@class KoniLib.Socket
---Socket.io-like networking abstraction for Project Zomboid
---Provides namespaces, rooms, middleware, and acknowledgments
KoniLib.Socket = KoniLib.Socket or {}

local Socket = KoniLib.Socket

-- Namespace registry (shared reference, actual instances in client/server)
Socket.namespaces = {}

-- Module name for MP communication
Socket.MODULE = "KoniLib.Socket"

-- Commands
Socket.CMD = {
    -- Client -> Server
    CONNECT = "connect",
    DISCONNECT = "disconnect",
    EMIT = "emit",
    JOIN = "join",
    LEAVE = "leave",
    ACK = "ack",
    
    -- Server -> Client
    CONNECTED = "connected",
    DISCONNECTED = "disconnected",
    ERROR = "error",
    JOINED = "joined",
    LEFT = "left",
    KICKED = "kicked",
}

-- Middleware types
Socket.MIDDLEWARE = {
    CONNECTION = "connection",
    DISCONNECT = "disconnect",
    JOIN = "join",
    LEAVE = "leave",
    EMIT = "emit",
}

-- Built-in events
Socket.EVENTS = {
    CONNECT = "connect",
    DISCONNECT = "disconnect",
    ERROR = "error",
    JOINED = "joined",
    LEFT = "left",
    KICKED = "kicked",
}

local Log = KoniLib.Log

---Log a message if verbose mode is enabled
---@param str string
function Socket.Log(str)
    Log.Print("Socket", str)
end

---Generate a unique ID for acknowledgment tracking
---@return string
function Socket.GenerateAckId()
    -- Use PZ's built-in functions instead of os.time/math.random
    local timestamp = getTimestampMs and getTimestampMs() or 0
    local random = ZombRand and ZombRand(100000, 999999) or 0
    return tostring(timestamp) .. "-" .. tostring(random)
end

---Normalize namespace name (ensure it starts with /)
---@param namespace string
---@return string
function Socket.NormalizeNamespace(namespace)
    if not namespace then return "/" end
    if namespace:sub(1, 1) ~= "/" then
        namespace = "/" .. namespace
    end
    return namespace
end

---Get or create a socket for a namespace
---Returns the appropriate client or server socket based on context
---@param namespace string The namespace (e.g., "/chat", "/trade")
---@param options? table Optional configuration { auth = {} }
---@return SocketClient|SocketServer
function Socket.of(namespace, options)
    namespace = Socket.NormalizeNamespace(namespace)
    options = options or {}
    
    -- Check if already exists
    if Socket.namespaces[namespace] then
        -- If options.auth provided, trigger reconnect with new auth
        if options.auth and isClient() then
            Socket.namespaces[namespace]:connect(options.auth)
        end
        return Socket.namespaces[namespace]
    end
    
    -- Create new socket based on context
    local socket
    if isClient() then
        socket = KoniLib.SocketClient.new(namespace, options)
    elseif isServer() then
        socket = KoniLib.SocketServer.new(namespace, options)
    else
        -- Singleplayer - create both and link them
        socket = KoniLib.SocketSP.new(namespace, options)
    end
    
    Socket.namespaces[namespace] = socket
    Socket.Log("Created socket for namespace: " .. namespace)
    
    return socket
end

---Get an existing socket for a namespace (does not create)
---@param namespace string
---@return SocketClient|SocketServer|nil
function Socket.get(namespace)
    namespace = Socket.NormalizeNamespace(namespace)
    return Socket.namespaces[namespace]
end

---Check if a namespace exists
---@param namespace string
---@return boolean
function Socket.has(namespace)
    namespace = Socket.NormalizeNamespace(namespace)
    return Socket.namespaces[namespace] ~= nil
end

---Destroy a socket namespace
---@param namespace string
function Socket.destroy(namespace)
    namespace = Socket.NormalizeNamespace(namespace)
    local socket = Socket.namespaces[namespace]
    if socket then
        if socket.destroy then
            socket:destroy()
        end
        Socket.namespaces[namespace] = nil
        Socket.Log("Destroyed socket for namespace: " .. namespace)
    end
end

---Deep copy a table (for safe data transmission)
---@param orig table
---@return table
function Socket.DeepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[Socket.DeepCopy(k)] = Socket.DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

return KoniLib.Socket
