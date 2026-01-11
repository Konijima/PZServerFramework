if isServer() then return end
require "AreaSystem/Definitions"
local MP = require("KoniLib/MP")

AreaSystem.Client = {}
local Client = AreaSystem.Client

Client.Data = {
    Areas = {},
    Shapes = {}
}

-- ==========================================================
-- Network handlers (Receiving from Server)
-- ==========================================================

-- Full Sync (e.g. on Join)
MP.Register("AreaSystem", "SyncData", function(player, args)
    print("[AreaSystem] Client: Received SyncData")
    Client.Data = args -- Replace entire state
    AreaSystem.Events.OnDataChanged:Trigger()
end)

-- Area Updates
MP.Register("AreaSystem", "AreaAdded", function(player, args)
    Client.Data.Areas[args.id] = args
    AreaSystem.Events.OnDataChanged:Trigger()
end)

MP.Register("AreaSystem", "AreaUpdated", function(player, args)
    -- If we have an open UI editing this, we might want to update it?
    -- For now, just update the data store.
    Client.Data.Areas[args.id] = args
    AreaSystem.Events.OnDataChanged:Trigger()
end)

MP.Register("AreaSystem", "AreaRemoved", function(player, args)
    Client.Data.Areas[args.id] = nil
    -- Cleanup linked shapes locally too, though server should send specific shape removes, 
    -- acting on AreaRemove safely cleans up orphans visually immediately.
    for k, v in pairs(Client.Data.Shapes) do
        if v.areaId == args.id then
             Client.Data.Shapes[k] = nil
        end
    end
    AreaSystem.Events.OnDataChanged:Trigger()
end)

-- Shape Updates
MP.Register("AreaSystem", "ShapeAdded", function(player, args)
    Client.Data.Shapes[args.id] = args
    AreaSystem.Events.OnDataChanged:Trigger()
end)

MP.Register("AreaSystem", "ShapeUpdated", function(player, args)
    Client.Data.Shapes[args.id] = args
    AreaSystem.Events.OnDataChanged:Trigger()
end)

MP.Register("AreaSystem", "ShapeRemoved", function(player, args)
    Client.Data.Shapes[args.id] = nil
    AreaSystem.Events.OnDataChanged:Trigger()
end)

-- ==========================================================
-- Public API (Called by UI)
-- ==========================================================

function Client.UpdateArea(area)
    -- Determine if Add or Update
    if Client.Data.Areas[area.id] then
        MP.Send(getPlayer(), "AreaSystem", "UpdateArea", area)
    else
        MP.Send(getPlayer(), "AreaSystem", "AddArea", area)
    end
end

function Client.RemoveArea(id)
    MP.Send(getPlayer(), "AreaSystem", "RemoveArea", { id = id })
end

function Client.UpdateShape(shape)
    if Client.Data.Shapes[shape.id] then
        MP.Send(getPlayer(), "AreaSystem", "UpdateShape", shape)
    else
        MP.Send(getPlayer(), "AreaSystem", "AddShape", shape)
    end
end

function Client.RemoveShape(id)
    MP.Send(getPlayer(), "AreaSystem", "RemoveShape", { id = id })
end

-- ==========================================================
-- Initialization & Utility
-- ==========================================================

function Client.OnInitWorld(playerIndex)
    if not playerIndex then playerIndex = 0 end -- Safety
    local player = getSpecificPlayer(playerIndex)
    
    -- Safety check: OnCreatePlayer might fire before the player object is fully ready (e.g. "Bob")
    -- We can verify existence or username
    if player then
        print("[AreaSystem] Client: OnCreatePlayer("..tostring(playerIndex)..") - Player: " .. tostring(player:getUsername()))
        -- If this is a respawn, request sync. 
        MP.Send(player, "AreaSystem", "RequestSync", {})
    end
end

function Client.CheckOverlap(x1, y1, x2, y2, ignoreShapeId)
    local shapes = Client.Data.Shapes
    for id, shape in pairs(shapes) do
        if id ~= ignoreShapeId then
            local sx, sx2 = math.min(shape.x, shape.x2), math.max(shape.x, shape.x2)
            local sy, sy2 = math.min(shape.y, shape.y2), math.max(shape.y, shape.y2)
            
            if x1 < sx2 and x2 > sx and y1 < sy2 and y2 > sy then
                return true
            end
        end
    end
    return false
end

Events.OnCreatePlayer.Add(Client.OnInitWorld)

print("[AreaSystem] AreaSystem: Client Core Loaded (Network Mode)")

